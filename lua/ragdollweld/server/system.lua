---@module "ragdollweld.shared.helpers"
local helpers = include("ragdollweld/shared/helpers.lua")
local ipairs_sparse, boneToPhysBone = helpers.ipairs_sparse, helpers.boneToPhysBone

local state = RagdollWeld.State

local updateAllConVar = CreateConVar(
	"sv_ragdollweld_update",
	"1",
	FCVAR_SPONLY,
	"Whether the system should actively constrain entities or not",
	0,
	1
)

--- @param arcEntity ArcData
local function updateEntity(arcEntity)
	if not arcEntity.updating then
		return
	end

	local outgoing = arcEntity.outgoing
	local entity = arcEntity.entity
	local root = entity:GetPhysicsObject()
	local offsetData = arcEntity.offsetData

	if not IsValid(entity) or not IsValid(outgoing) then
		return
	end

	local fPos, fAng
	local outgoingPhysId = arcEntity.outgoingPhysId
	if outgoingPhysId then
		local physObj = outgoing:GetPhysicsObject()
		if outgoing:GetPhysicsObjectCount() > 1 then
			physObj = outgoing:GetPhysicsObjectNum(outgoingPhysId) or physObj
		end
		fPos, fAng = LocalToWorld(arcEntity.pos, arcEntity.ang, physObj:GetPos(), physObj:GetAngles())
	else
		local bPos, bAng = outgoing:GetBonePosition(arcEntity.id)
		fPos, fAng = LocalToWorld(arcEntity.pos, arcEntity.ang, bPos, bAng)
	end

	if fPos or fAng then
		root:EnableMotion(true)
		root:Wake()
	end

	if fPos then
		root:SetPos(fPos, true)
	end
	if fAng then
		root:SetAngles(fAng)
	end

	if fPos or fAng then
		root:EnableMotion(false)
		root:Wake()
	end

	for _, offset in ipairs(offsetData) do
		local physobj = entity:GetPhysicsObjectNum(offset.childId)
		local parent = entity:GetPhysicsObjectNum(offset.parentId)
		if physobj and parent then
			physobj:EnableMotion(true)
			physobj:Wake()
			local pos, ang = LocalToWorld(offset.pos, offset.ang, parent:GetPos(), parent:GetAngles())
			physobj:SetPos(pos)
			physobj:SetAngles(ang)
			physobj:EnableMotion(false)
			physobj:Wake()
		end
	end
end

local function system()
	if not updateAllConVar:GetBool() then
		return
	end

	for _, arcEntity in ipairs_sparse(state.entities, "ragdollweld_system", state.entityCount ~= state.previousCount) do
		updateEntity(arcEntity)
	end

	state:updateCount()
end

local function thinkSystem()
	if game.SinglePlayer() then
		if isfunction(SMH.PlaybackManager.GetActivePlayback) and SMH.PlaybackManager.GetActivePlayback(Entity(1)) then
			return
		end
	end
	system()
end
hook.Remove("Think", "ragdollweld_system")
hook.Add("Think", "ragdollweld_system", thinkSystem)

local function smhPostFrameSystem(entities)
	if not updateAllConVar:GetBool() then
		return
	end

	for _, entity in ipairs(entities) do
		local data = state.entities[entity:EntIndex()]
		if data then
			updateEntity(data)
		end

		for _, arcEntity in
			ipairs_sparse(state.entities, "ragdollweld_system", state.entityCount ~= state.previousCount)
		do
			if arcEntity.outgoing == entity then
				updateEntity(arcEntity)
			end
		end
		state:updateCount()
	end
end
hook.Remove("SMH_PostFrameEntity", "ragdollweld_system")
hook.Add("SMH_PostFrameEntity", "ragdollweld_system", smhPostFrameSystem)
