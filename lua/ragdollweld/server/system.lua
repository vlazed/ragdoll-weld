---@module "ragdollweld.shared.helpers"
local helpers = include("ragdollweld/shared/helpers.lua")
local ipairs_sparse, boneToPhysBone = helpers.ipairs_sparse, helpers.boneToPhysBone

local state = RagdollWeld.State

local function system()
	for _, arcEntity in ipairs_sparse(state.entities, "ragdollweld_system", state.entityCount ~= state.previousCount) do
		if not arcEntity.updating then
			continue
		end

		local outgoing = arcEntity.outgoing
		local entity = arcEntity.entity
		local root = entity:GetPhysicsObject()
		local id = arcEntity.id
		local offsetData = arcEntity.offsetData
		local physcount = entity:GetPhysicsObjectCount()

		if not IsValid(entity) or not IsValid(outgoing) then
			continue
		end

		local fPos, fAng
		local calculatePhysics
		if arcEntity.phys then
			local physId = boneToPhysBone(outgoing, id)
			if physId >= 0 then
				calculatePhysics = physId
			end
		end

		if calculatePhysics then
			local physObj = outgoing:GetPhysicsObject()
			if outgoing:GetPhysicsObjectCount() > 1 then
				physObj = outgoing:GetPhysicsObjectNum(calculatePhysics)
			end
			fPos, fAng = LocalToWorld(arcEntity.pos, arcEntity.ang, physObj:GetPos(), physObj:GetAngles())
		else
			local bPos, bAng = outgoing:GetBonePosition(id)
			fPos, fAng = LocalToWorld(arcEntity.pos, arcEntity.ang, bPos, bAng)
		end

		if fPos or fAng then
			root:EnableMotion(true)
			root:Wake()
		end

		if fPos then
			root:SetPos(fPos)
		end
		if fAng then
			root:SetAngles(fAng)
		end

		if fPos or fAng then
			root:EnableMotion(false)
			root:Wake()
		end

		for i = 0, physcount - 1 do
			local parent = offsetData[i].parent
			if parent then
				local physobj = entity:GetPhysicsObjectNum(i)
				physobj:EnableMotion(true)
				physobj:Wake()
				local pos, ang = LocalToWorld(offsetData[i].pos, offsetData[i].ang, parent:GetPos(), parent:GetAngles())
				physobj:SetPos(pos)
				physobj:SetAngles(ang)
				physobj:EnableMotion(false)
				physobj:Wake()
			end
		end
	end

	state:updateCount()
end
hook.Remove("Think", "ragdollweld_system")
hook.Add("Think", "ragdollweld_system", system)
