include("ragdollweld/client/derma/graph.lua")

---@module "ragdollweld.shared.helpers"
local helpers = include("ragdollweld/shared/helpers.lua")
local getName = helpers.getEntityName

local SAVE_PATH = "ragdollweld"

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

---Source: https://github.com/vlazed/PenAkTools/blob/9f1d96e188be8639bc556ff4e14a32ca64ed6383/GARRYS%20MOD%20SCRIPTS/macroreplacementver2/lua/autorun/client/concommand_macro.lua#L606
---Need more good custom preset vgui 😭
---@param cPanel DForm|ControlPanel
---@param savepath string
---@return PresetSaver
local function savePanel(cPanel, savepath)
	---@class PresetSaver: DPanel
	local base = vgui.Create("DPanel")
	base:SetTall(30)
	base:SetPaintBackground(false)
	cPanel:AddItem(base)

	base.box = vgui.Create("DComboBox", base)
	base.box:SetPos(0, 5)

	local function refreshList()
		base.box:Clear()

		local files = file.Find(savepath .. "/" .. "*.txt", "DATA")
		for k, file in ipairs(files) do
			file = string.sub(file, 1, -5)

			base.box:AddChoice(file, file)
		end
	end

	refreshList()

	---@param data ArcData
	function base:OnSelect(data) end

	function base.box:OnSelect(id, val)
		local f = file.Read(savepath .. "/" .. val .. ".txt", "DATA")
		local data = util.JSONToTable(f)
		if not data then
			return
		end

		return base:OnSelect(data)
	end

	---@return ArcData?
	function base:OnSave() end

	base.butt = vgui.Create("DImageButton", base)
	base.butt:SetSize(18, 18)
	base.butt:SetImage("icon16/disk.png")
	base.butt:SetTooltip("Save")

	function base.butt:DoClick()
		local savew = vgui.Create("DFrame")
		savew:SetSize(200, 105)
		savew:Center()
		savew:MakePopup()
		savew:DoModal()
		savew:SetTitle("Save Preset")
		savew:SetBackgroundBlur(true)

		local wx, wy = savew:GetSize()

		savew.label = vgui.Create("DLabel", savew)
		savew.label:SetText("Enter preset name to be saved:")
		savew.label:SizeToContents()
		savew.label:SetPos(wx / 2 - savew.label:GetWide() / 2, 30)

		savew.entry = vgui.Create("DTextEntry", savew)
		savew.entry:SetSize(190, 20)
		savew.entry:SetPos(5, 50)

		savew.sbutt = vgui.Create("DButton", savew)
		savew.sbutt:SetText("Save")
		savew.sbutt:SetSize(60, 20)
		savew.sbutt:SetPos(5, 76)
		function savew.sbutt:DoClick()
			local name = string.Trim(savew.entry:GetText())

			if not file.IsDir(savepath, "DATA") then
				file.CreateDir(savepath)
			end

			local data = base:OnSave()

			if not data or not data.id then
				notification.AddLegacy("Error: There must be valid data to save!", NOTIFY_ERROR, 5)
				return
			end

			local json = util.TableToJSON(data)
			file.Write(savepath .. "/" .. name .. ".txt", json)

			notification.AddLegacy("Arc saved!", NOTIFY_GENERIC, 5)
			surface.PlaySound("buttons/button14.wav")

			refreshList()
			savew:Close()
		end

		savew.cbutt = vgui.Create("DButton", savew)
		savew.cbutt:SetText("Cancel")
		savew.cbutt:SetSize(60, 20)
		savew.cbutt:SetPos(wx - 65, 76)
		function savew.cbutt:DoClick()
			savew:Close()
		end
	end

	base.editb = vgui.Create("DImageButton", base)
	base.editb:SetSize(18, 18)
	base.editb:SetImage("icon16/cross.png")
	base.editb:SetTooltip("Delete Presets")

	function base.editb:DoClick()
		local frame = vgui.Create("DFrame")
		local wx, wy = 300, 200
		frame:SetSize(wx, wy)
		frame:Center()
		frame:MakePopup()
		frame:DoModal()
		frame:SetTitle("Weld Presets")
		frame:SetBackgroundBlur(true)

		function frame:OnClose()
			refreshList()
		end

		frame.list = vgui.Create("DListView", frame)
		frame.list:SetSize(150, wy - 25)
		frame.list:SetPos(0, 25)
		frame.list:AddColumn("Preset")
		frame.list:SetMultiSelect(false)

		local files = file.Find(savepath .. "*.txt", "DATA")
		for k, file in ipairs(files) do
			file = string.sub(file, 1, -5)

			frame.list:AddLine(file)
		end

		frame.delete = vgui.Create("DButton", frame)
		frame.delete:SetSize(70, 30)
		frame.delete:SetText("Delete")
		frame.delete:SetPos(190, 60)

		function frame.delete:DoClick()
			local selected, pnl = frame.list:GetSelectedLine()
			if not selected then
				return
			end

			local name = savepath .. "/" .. pnl:GetValue() .. ".txt"

			if file.Exists(name, "DATA") then
				file.Delete(name)
			end
			frame.list:RemoveLine(selected)
		end

		frame.exit = vgui.Create("DButton", frame)
		frame.exit:SetSize(70, 30)
		frame.exit:SetText("Close")
		frame.exit:SetPos(190, 120)

		function frame.exit:DoClick()
			frame:Close()
		end
	end

	function base:PerformLayout(width)
		base.box:SetSize(width - 55, 20)

		base.butt:SetPos(width - 45, 5)
		base.editb:SetPos(width - 20, 5)
	end

	return base
end

---@param cPanel DForm|ControlPanel
---@return EntityData
local function dataDisplay(cPanel)
	local container = makeCategory(cPanel, "Arc Data", "DForm")
	---@cast container EntityData

	container.preset = savePanel(container, SAVE_PATH)

	---@diagnostic disable: assign-type-mismatch
	---INFO: The DForm methods return Panel instead of their respective types
	container.entity = NULL
	container.label = container:Help("No entity selected")
	container.pos = container:TextEntry("Position", "")
	container.ang = container:TextEntry("Angles", "")
	container.pos:SetUpdateOnType(true)
	container.ang:SetUpdateOnType(true)

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

---@param str string?
---@return Vector
local function stringToVector(str)
	local split = string.Split(str or "", " ")
	return Vector(tonumber(split[1]) or 0, tonumber(split[2]) or 0, tonumber(split[3]) or 0)
end

---@param str string?
---@return Angle
local function stringToAngle(str)
	local split = string.Split(str or "", " ")
	return Angle(tonumber(split[1]) or 0, tonumber(split[2]) or 0, tonumber(split[3]) or 0)
end

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
		data.id:SetMinMax(0, math.max(entity:GetBoneCount() - 1, 0))
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

	function data.preset:OnSelect(d)
		--Preserve outgoing / incoming entities
		d.incoming = data.data.incoming
		d.outgoing = data.data.outgoing
		d.entity = data.data.entity

		update(d, false)
	end

	function data.preset:OnSave()
		return data.data
	end

	function data.update:DoClick()
		-- print(data.data)
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

	function data.ang:OnValueChange(newAng)
		if filling then
			return
		end
		if data.data then
			data.data.ang = stringToAngle(newAng)
			print(data.data.ang)
			update(data.data, false)
		end
	end

	function data.pos:OnValueChange(newPos)
		if filling then
			return
		end
		if data.data then
			data.data.pos = stringToVector(newPos)
			-- print(data.data.pos)
			update(data.data, false)
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
		elseif data.data then
			fillData(data.data.entity)
		end
	end)
end

return ui
