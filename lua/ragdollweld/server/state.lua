---@module "ragdollweld.shared.helpers"
local helpers = include("ragdollweld/shared/helpers.lua")
local getPhysBoneParent = helpers.getPhysBoneParent

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

---@param state RagdollWeldState
---@param entity Entity
---@param outgoingArc Entity
---@param index integer
local function addEntity(state, entity, outgoingArc, index)
	local root = entity:GetPhysicsObject()
	local outgoingRoot = outgoingArc:GetPhysicsObject()
	local pos, ang = WorldToLocal(root:GetPos(), root:GetAngles(), outgoingRoot:GetPos(), outgoingRoot:GetAngles())
	state.entities[index] = {
		entity = entity,
		outgoing = outgoingArc,
		incoming = getIncomingArcs(state.entities, entity),
		pos = pos,
		ang = ang,
		phys = true,
		id = 0,
		updating = true,
		offsetData = getOffset(entity),
	}
	state.entityCount = state.entityCount + 1
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
function RagdollWeld.State:updateEntity(index, data)
	if not self.entities[index] then
		return
	end
	local arcData = self.entities[index]

	arcData.ang = data.ang
	arcData.pos = data.pos
	arcData.id = data.id
	arcData.phys = data.phys
	arcData.updating = data.updating
end

function RagdollWeld.State:validateEntity(entity, outgoingEntity)
	return checkOutgoingCycle(self.entities, outgoingEntity, entity)
end

function RagdollWeld.State:updateCount()
	self.previousCount = self.entityCount
end

---@param entities ArcData[]
local function updateView(entities)
	---@type ArcData[]
	local copy = table.Copy(entities)
	for _, entry in pairs(copy) do
		entry.offsetData = nil
		entry.incoming = nil
	end
	net.Start("ragdollweld_updateview")
	net.WriteTable(copy)
	net.Broadcast()
end

---@param entity Entity
function RagdollWeld.State:addEntity(entity, outgoingArc)
	local entIndex = entity:EntIndex()
	if not self.entities[entIndex] then
		addEntity(self, entity, outgoingArc, entIndex)
		entity:CallOnRemove("ragdollweld_cleanup", function()
			removeEntity(self, entIndex)
			clearIncomingArcs(self.entities, entity)
		end)

		updateView(self.entities)
	end
end

---@param entity Entity
function RagdollWeld.State:removeEntity(entity)
	local entIndex = entity:EntIndex()
	if self.entities[entIndex] then
		removeEntity(self, entIndex)
		clearIncomingArcs(self.entities, entity)
		entity:RemoveCallOnRemove("ragdollweld_cleanup")
		updateView(self.entities)
	end
end

net.Receive("ragdollweld_updatemodel", function(len, ply)
	---@type ArcData
	local data = net.ReadTable()
	local entity = data.entity
	RagdollWeld.State:updateEntity(entity:EntIndex(), data)
end)

net.Receive("ragdollweld_updateview", function(len, ply)
	updateView(RagdollWeld.State.entities)
end)
