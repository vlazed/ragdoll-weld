---@module "ragdollweld.shared.helpers"
local helpers = include("ragdollweld/shared/helpers.lua")
local getPhysBoneParent, boneToPhysBone = helpers.getPhysBoneParent, helpers.boneToPhysBone

---@class RagdollWeldState
---@field entities ArcData[]
RagdollWeld.State = {
	entities = {},
	entityCount = 0,
	previousCount = 0,
}

---@param entities ArcData[]
---@param clearedEntity Entity
local function clearIncomingArcs(entities, clearedEntity)
	for _, arcData in pairs(entities) do
		arcData.incoming[clearedEntity] = nil
	end
end

---@param entities ArcData[]
---@param node Entity
---@return EntitySet
local function getIncomingArcs(entities, node)
	---@type EntitySet
	local incomingArcs = {}
	for entIndex, _ in pairs(entities) do
		if entities[entIndex].outgoing == node then
			incomingArcs[Entity(entIndex)] = true
		end
	end
	return incomingArcs
end

---@param entities ArcData[]
---@param updateGraph boolean
local function updateView(entities, updateGraph)
	---@type ArcData[]
	local copy = table.Copy(entities)
	for _, entry in pairs(copy) do
		entry.offsetData = nil
		entry.incoming = nil
	end
	net.Start("ragdollweld_updateview")
	net.WriteTable(copy)
	net.WriteBool(updateGraph)
	net.Broadcast()
end

---@param entity Entity
---@return OffsetData[]
local function getOffset(entity)
	---@type OffsetData[]
	local offsetData = {}
	for i = 0, entity:GetPhysicsObjectCount() - 1 do
		offsetData[i] = {}
		local parentId = getPhysBoneParent(entity, i)
		if parentId < 0 then
			continue
		end

		local child, parent = entity:GetPhysicsObjectNum(i), entity:GetPhysicsObjectNum(parentId)
		offsetData[i].pos, offsetData[i].ang =
			WorldToLocal(child:GetPos(), child:GetAngles(), parent:GetPos(), parent:GetAngles())
		offsetData[i].parent = parent
	end

	return offsetData
end

---@param entity Entity
---@param outgoing Entity
---@param phys boolean
---@param id integer
---@return Vector, Angle
local function getPosAng(entity, outgoing, phys, id)
	local root = entity:GetPhysicsObject()

	local pos, ang
	if phys then
		local outgoingObject = outgoing:GetPhysicsObject()
		local physId = boneToPhysBone(outgoing, id)
		if outgoing:GetPhysicsObjectCount() > 1 then
			outgoingObject = outgoing:GetPhysicsObjectNum(physId) or outgoingObject
		end
		pos, ang = WorldToLocal(root:GetPos(), root:GetAngles(), outgoingObject:GetPos(), outgoingObject:GetAngles())
	else
		local bonePos, boneAng = outgoing:GetBonePosition(id)
		pos, ang = WorldToLocal(root:GetPos(), root:GetAngles(), bonePos, boneAng)
	end

	return pos, ang
end

---@param state RagdollWeldState
---@param entity Entity
---@param outgoingArc Entity
local function addEntity(state, entity, outgoingArc, data)
	local phys = Either(data, data and data.phys, true)
	local id = data and data.id or 0

	local pos, ang = getPosAng(entity, outgoingArc, phys, id)
	local data = {
		entity = entity,
		outgoing = outgoingArc,
		incoming = getIncomingArcs(state.entities, entity),
		pos = pos,
		ang = ang,
		phys = phys,
		id = id,
		updating = true,
		offsetData = getOffset(entity),
	}
	state.entities[entity:EntIndex()] = data
	state.entityCount = state.entityCount + 1

	return data
end

---@param state RagdollWeldState
---@param index integer
local function removeEntity(state, index)
	state.entities[index] = nil
	state.entityCount = state.entityCount - 1
end

---@param entities ArcData[]
---@param outgoingEntity Entity
---@param targetEntity Entity
---@return boolean
local function checkOutgoingCycle(entities, outgoingEntity, targetEntity)
	local outgoingArc = entities[outgoingEntity:EntIndex()]
	-- Does the outgoing entity being selected for welding have its own arcs to other entities?
	if outgoingArc then
		if outgoingArc.outgoing == targetEntity then -- Are we completing a cycle?
			return false
		elseif not entities[outgoingArc.outgoing:EntIndex()] then -- Is the outgoing entity not managed by the system?
			return true
		else
			return checkOutgoingCycle(entities, outgoingArc.outgoing, targetEntity) -- Go down the outgoing entities
		end
	else
		return true
	end
end

---@param index integer
---@param data ArcData
---@param offsetUpdate boolean
function RagdollWeld.State:updateEntity(index, data, offsetUpdate)
	if not self.entities[index] then
		return
	end
	local arcData = self.entities[index]

	local updateOffsets = offsetUpdate or arcData.id ~= data.id or arcData.phys ~= data.phys

	arcData.phys = data.phys
	arcData.updating = data.updating
	arcData.id = data.id

	if offsetUpdate then
		arcData.offsetData = getOffset(arcData.entity)
	end

	if updateOffsets then
		arcData.pos, arcData.ang = getPosAng(arcData.entity, arcData.outgoing, arcData.phys, arcData.id)
	end

	self.entities[index] = arcData

	print("Update")

	arcData.entity.ragdollweld_constraint:SetTable({
		Type = "RagdollWeld",
		Ent1 = arcData.entity,
		Ent2 = arcData.outgoing,
		Data = arcData,
	})

	updateView(self.entities, false)
end

function RagdollWeld.State:validateEntity(entity, outgoingEntity)
	return checkOutgoingCycle(self.entities, outgoingEntity, entity)
end

function RagdollWeld.State:updateCount()
	self.previousCount = self.entityCount
end

---@param entity Entity
---@param outgoingArc Entity
function RagdollWeld.State:addEntity(entity, outgoingArc, data)
	local entIndex = entity:EntIndex()
	if not self.entities[entIndex] then
		addEntity(self, entity, outgoingArc, data)
		entity:CallOnRemove("ragdollweld_cleanup", function()
			removeEntity(self, entIndex)
			clearIncomingArcs(self.entities, entity)
			updateView(self.entities, true)
		end)
		outgoingArc:CallOnRemove("ragdollweld_cleanup", function()
			removeEntity(self, outgoingArc:EntIndex())
			clearIncomingArcs(self.entities, outgoingArc)
			updateView(self.entities, true)
		end)

		updateView(self.entities, true)

		return data
	end
end

---@param entity Entity
function RagdollWeld.State:removeEntity(entity)
	local entIndex = entity:EntIndex()
	if self.entities[entIndex] then
		removeEntity(self, entIndex)
		clearIncomingArcs(self.entities, entity)
		entity:RemoveCallOnRemove("ragdollweld_cleanup")
		updateView(self.entities, true)
	end
end

---@param ent1 Entity
---@param ent2 Entity
function RagdollWeld.AddWeld(ent1, ent2, data)
	if not IsValid(ent1) then
		return
	end
	if not IsValid(ent2) then
		return
	end

	local data = RagdollWeld.State:addEntity(ent1, ent2, data)

	local anchor = constraint.CreateStaticAnchorPoint(ent2:GetPos())

	constraint.AddConstraintTable(ent1, anchor, ent2)

	anchor:SetTable({
		Type = "RagdollWeld",
		Ent1 = ent1,
		Ent2 = ent2,
		Data = data,
	})

	ent1.ragdollweld_constraint = anchor

	return anchor
end

duplicator.RegisterConstraint("RagdollWeld", RagdollWeld.AddWeld, "Ent1", "Ent2", "Data")

---@param ent Entity
function RagdollWeld.RemoveWeld(ent)
	if not IsValid(ent) then
		return false
	end

	RagdollWeld.State:removeEntity(ent)

	return constraint.RemoveConstraints(ent, "RagdollWeld")
end

net.Receive("ragdollweld_updatemodel", function(len, ply)
	---@type ArcData
	local data = net.ReadTable()
	local offsetUpdate = net.ReadBool()
	local entity = data.entity
	RagdollWeld.State:updateEntity(entity:EntIndex(), data, offsetUpdate)
end)

net.Receive("ragdollweld_updateview", function(len, ply)
	updateView(RagdollWeld.State.entities, true)
end)
