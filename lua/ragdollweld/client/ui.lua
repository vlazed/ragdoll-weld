include("ragdollweld/client/derma/graph.lua")

---@module "ragdollweld.shared.helpers"
local helpers = include("ragdollweld/shared/helpers.lua")
local getName = helpers.getEntityName

local ui = {}

---Helper for DForm
---@param cPanel ControlPanel|DForm
---@param name string
---@param type "ControlPanel"|"DForm"
---@return ControlPanel|DForm
local function makeCategory(cPanel, name, type)
	---@type DForm|ControlPanel
	local category = vgui.Create(type, cPanel)

	category:SetLabel(name)
	cPanel:AddItem(category)
	return category
end

---@param cPanel DForm|ControlPanel
---@return EntityExplorer
local function entityExplorer(cPanel)
	local container = vgui.Create("DPanel", cPanel)
	---@cast container EntityExplorer
	cPanel:AddItem(container)

	container.graph = vgui.Create("ragdollweld_graph", container)
	container.graph:Dock(FILL)
	function container:PerformLayout(w, h)
		container:SetHeight(400)
	end

	return container
end

---@param cPanel DForm|ControlPanel
---@return EntityData
local function dataDisplay(cPanel)
	local container = makeCategory(cPanel, "Arc Data", "DForm")
	---@cast container EntityData

	---@diagnostic disable: assign-type-mismatch
	---INFO: The DForm methods return Panel instead of their respective types
	container.entity = NULL
	container.label = container:Help("No entity selected")
	container.pos = container:TextEntry("Position", "")
	container.ang = container:TextEntry("Angles", "")
	container.update = container:Button("Update", "")
	container.update:SetTooltip("Update position and angle offsets")
	container.phys = container:CheckBox("Use Physical Bone", "")
	container.id = container:NumberWang("Bone Id", "", 0, 256)
	container.id:SetTooltipDelay(0)
	container.updating = container:CheckBox("Should update", "")
	container.updating:SetTooltip(
		"Whether the selected entity should move with respect to its welded entity. Uncheck this to properly update offsets."
	)
	---@diagnostic enable

	return container
end

---@param cPanel DForm|ControlPanel
---@param panelProps PanelProps
---@param panelState PanelState
---@return PanelChildren
function ui.ConstructPanel(cPanel, panelProps, panelState)
	cPanel:Help("#tool.ragdollweld.general")

	local explorer = entityExplorer(cPanel)
	local data = dataDisplay(cPanel)

	return {
		explorer = explorer,
		data = data,
	}
end

local RED = Color(255, 0, 0)
local GREEN = Color(0, 255, 0)

local highlighter = include("highlighter.lua")

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
function ui.HookPanel(panelChildren, panelProps, panelState)
	local explorer = panelChildren.explorer
	local data = panelChildren.data

	---@param entities ArcData[]
	local function refreshGraph(entities)
		explorer.graph:ClearNodes()
		for _, arcData in pairs(entities) do
			explorer.graph:AddEntity(arcData.entity, arcData.outgoing)
		end
	end

	---@param entity Entity
	---@param id integer
	local function updateLabel(entity, id)
		data.id:SetTooltip(entity:GetBoneName(id))
	end

	local filling = false
	---@param entity Entity
	local function fillData(entity)
		local arcData = panelState.entities[entity:EntIndex()]
		filling = true
		if arcData then
			data.data = arcData
			data.label:SetText(getName(entity))
			data.pos:SetValue(tostring(arcData.pos))
			data.ang:SetValue(tostring(arcData.ang))
			data.id:SetValue(arcData.id)
			updateLabel(arcData.outgoing, arcData.id)
			data.phys:SetChecked(arcData.phys)
			data.updating:SetChecked(arcData.updating)
		else
			data.data = nil
			data.label:SetText(getName(entity))
			data.pos:SetValue("")
			data.ang:SetValue("")
			data.id:SetValue(0)
			updateLabel(entity, 0)
			data.phys:SetChecked(false)
			data.updating:SetChecked(false)
		end
		filling = false
	end

	local function update(newData, updateClicked)
		net.Start("ragdollweld_updatemodel")
		net.WriteTable(newData)
		net.WriteBool(updateClicked)
		net.SendToServer()
	end

	function data.update:DoClick()
		if data.data then
			update(data.data, true)
		end
	end

	function data.updating:OnChange(checked)
		if data.data then
			data.data.updating = checked
			update(data.data)
		end
	end

	function data.phys:OnChange(checked)
		if data.data then
			data.data.phys = checked
			update(data.data, true)
		end
	end

	function data.id:OnValueChanged(val)
		if filling then
			return
		end
		if data.data then
			updateLabel(data.data.outgoing, val)
			data.data.id = val
			update(data.data)
		end
	end

	function explorer.graph:OnNodeSelected(node)
		return fillData(node.entity)
	end

	function explorer.graph:OnNodeHover(node, hover)
		local entity = node.entity
		local outgoing = node.outgoingArc
		if hover then
			highlighter.highlights[entity] = RED
		else
			highlighter.highlights[entity] = nil
			highlighter.connections[entity] = nil
		end
		if outgoing then
			local outgoingArc = outgoing.entity
			if hover then
				highlighter.highlights[outgoingArc] = GREEN
				highlighter.connections[entity] = { entity, outgoingArc, data.data and data.data.id or 0 }
			else
				highlighter.highlights[outgoingArc] = nil
			end
		end
	end

	net.Start("ragdollweld_updateview")
	net.SendToServer()

	net.Receive("ragdollweld_updateview", function(len, ply)
		local entities = net.ReadTable()
		local updateGraph = net.ReadBool()

		panelState.entities = entities
		if updateGraph then
			refreshGraph(entities)
		end
	end)
end

return ui
