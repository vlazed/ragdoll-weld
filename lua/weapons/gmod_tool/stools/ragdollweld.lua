TOOL.Category = "Poser"
TOOL.Name = "#tool.ragdollweld.name"
TOOL.Command = nil
TOOL.ConfigName = ""

local firstReload = true
function TOOL:Think()
	if CLIENT and firstReload then
		self:RebuildControlPanel()
		firstReload = false
	end
end

---Remove the outgoing arc from the entity
---@param tr table|TraceResult
---@return boolean
function TOOL:Reload(tr)
	local entity = tr.Entity
	if not IsValid(entity) or entity:IsPlayer() then
		return false
	end

	if CLIENT then
		return true
	end

	self:ClearObjects()

	RagdollWeld.State:removeEntity(entity)

	return RagdollWeld.RemoveWeld(entity)
end

function TOOL:Holster()
	self:ClearObjects()
end

local function canTool(ent, pl)
	local cantool

	---@diagnostic disable-next-line
	if CPPI and ent.CPPICanTool then
		cantool = ent:CPPICanTool(pl, "ragdollmover")
	else
		cantool = true
	end

	return cantool
end

---Select an entity to target, and then select another entity to set its arc it.
---@param tr table|TraceResult
---@return boolean
function TOOL:LeftClick(tr)
	local entity = tr.Entity
	if not IsValid(entity) or entity:IsPlayer() then
		return false
	end
	if SERVER and not util.IsValidPhysicsObject(entity, tr.PhysicsBone) then
		return false
	end
	if not canTool(entity, self:GetOwner()) then
		return false
	end

	self:SetOperation(2)

	-- Using weld.lua for the logic
	local iNum = self:NumObjects()
	local phys = entity:GetPhysicsObjectNum(tr.PhysicsBone)
	self:SetObject(iNum + 1, entity, tr.HitPos, phys, tr.PhysicsBone, tr.HitNormal)

	if CLIENT then
		if iNum > 0 then
			self:ClearObjects()
		end
		return true
	end

	if iNum == 0 then
		self:SetStage(1)
		return true
	end

	if iNum == 1 then
		local ply = self:GetOwner()
		if not ply:CheckLimit("constraints") then
			self:ClearObjects()
			return false
		end

		-- Get information we're about to use
		local targetEntity, outgoing = self:GetEnt(1), self:GetEnt(2)

		if RagdollWeld.State:validateEntity(targetEntity, outgoing) then
			RagdollWeld.AddWeld(
				targetEntity,
				outgoing,
				{ phys = true, id = outgoing:TranslatePhysBoneToBone(tr.PhysicsBone) }
			)
		else
			ply:SendLua('notification.AddLegacy("Weld failed: attempted to create a cycle.", NOTIFY_ERROR, 3)')
		end

		-- Clear the objects so we're ready to go again
		self:ClearObjects()
	end

	return true
end

---Select an entity to view its data, if it has any
---@param tr table|TraceResult
---@return boolean
function TOOL:RightClick(tr)
	local entity = tr.Entity
	if not IsValid(entity) then
		return false
	end

	if CLIENT then
		return true
	end

	return true
end

if SERVER then
	return
end

TOOL:BuildConVarList()

---@module "ragdollweld.client.ui"
local ui = include("ragdollweld/client/ui.lua")

local panelState = {}

---@param cPanel ControlPanel|DForm
function TOOL.BuildCPanel(cPanel)
	---@type PanelProps
	local panelProps = {}
	local panelChildren = ui.ConstructPanel(cPanel, panelProps, panelState)
	ui.HookPanel(panelChildren, panelProps, panelState)
end

TOOL.Information = {
	{ name = "left", stage = 0 },
	{ name = "left_1", stage = 1, op = 2 },
	{ name = "right", stage = 0 },
	{ name = "reload" },
}
