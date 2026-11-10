---@module "ragdollweld.shared.helpers"
local helpers = include("ragdollweld/shared/helpers.lua")
local getName = helpers.getEntityName

local GRAVITY = 5
local FORCE = 7500
local MASS = 0.5
local SIZE_SCALE = 30
local ARROW_REPULSION = 600
local ARROW_REPULSION_DISTANCE = 180
local MIN_ZOOM = 0.5
local MAX_ZOOM = 3
local ZOOM_STEP = 0.1

local WIDTH, HEIGHT = ScrW(), ScrH()

---@class ragdollweld_node: EntityNode
---@field outgoingArc ragdollweld_node
local PANEL = {}

local HOVER_COLOR = Color(255, 0, 0)
local OUTGOING_COLOR = Color(0, 255, 0)

function PANEL:Init()
	self.entity = NULL

	self.icon = vgui.Create("SpawnIcon", self)

	self.size = 1
	self.sizeVector = Vector(1, 1, 0)
	self.mass = 1

	self.force = Vector()
	self.pos = Vector()

	---@type Color
	self.nodeColor = ColorAlpha(self:GetSkin().Colours.Label.Dark, 128)
	self.hoverColor = self.nodeColor:Lerp(HOVER_COLOR, 0.5)
	self.outgoingColor = self.nodeColor:Lerp(OUTGOING_COLOR, 0.5)
	self.color = self.nodeColor
	self.icon:SetColor(self.color)

	function self.icon.DoClick()
		self:OnSelected()
	end

	function self.icon.OnCursorEntered()
		self:OnHover(true)
		self.color = self.hoverColor
		if IsValid(self.outgoingArc) then
			self.outgoingArc.color = self.outgoingColor
		end
	end
	function self.icon.OnCursorExited()
		self:OnHover(false)
		self.color = self.nodeColor
		if IsValid(self.outgoingArc) then
			self.outgoingArc.color = self.nodeColor
		end
	end

	self:SetBackgroundColor(self.color)
end

function PANEL:OnHover(hovering) end

function PANEL:OnSelected() end

function PANEL:Paint(w, h)
	draw.RoundedBox(100, 0, 0, w, h, self.color)
end

function PANEL:PerformLayout(w, h)
	self.icon:Dock(FILL)
	self.icon:SetSize(w, h)
end

vgui.Register("ragdollweld_node", PANEL, "DPanel")

---@class ragdollweld_graph: EntityGraph
---@field nodes ragdollweld_node[]
---@field nodeArray ragdollweld_node[]
local PANEL = {}

function PANEL:Init()
	self.nodes = {}
	self.nodeArray = {}

	self.viewOffset = Vector(0, 0, 0)
	self.zoom = 1
	self.zoomTarget = 1
	self.zoomFocus = Vector(0, 0, 0)
	self.zoomFocusWorld = Vector(0, 0, 0)
	self.isPanning = false
	self.panStart = Vector(0, 0, 0)
	self.panAnchor = Vector(0, 0, 0)

	self:SetMouseInputEnabled(true)
end

---@param panel ragdollweld_graph
---@param entity Entity
---@return ragdollweld_node
local function createNode(panel, entity)
	local node = vgui.Create("ragdollweld_node", panel)
	node.entity = entity
	node.icon:SetModel(entity:GetModel())
	function node:OnSelected()
		panel:OnNodeSelected(self)
	end
	function node:OnHover(hovering)
		panel:OnNodeHover(self, hovering)
	end
	node.icon:SetTooltip(getName(entity))

	local x = math.random(0, panel:GetWide())
	local y = math.random(0, panel:GetTall())
	node:SetPos(x, y)
	node.pos = Vector(x, y, 0)

	return node
end

---@param nodes ragdollweld_node[]
---@param node ragdollweld_node
---@return integer
local function getSize(nodes, node)
	local size = SIZE_SCALE
	for _, otherNode in pairs(nodes) do
		if otherNode.outgoingArc == node then
			size = size + 1
		end
	end
	return size
end

function PANEL:ClearNodes()
	for _, node in ipairs(self.nodeArray) do
		node:Remove()
	end

	self.nodes = {}
	self.nodeArray = {}
end

---@param node ragdollweld_node
---@param nodes ragdollweld_node[]
local function setPhysicalParameters(node, nodes)
	local size = getSize(nodes, node)
	node.size = size
	node.sizeVector:SetUnpacked(size, size, 0)
	node.mass = (2 * math.pi * size) * MASS
end

---@param entity Entity
---@param outgoingArc Entity
function PANEL:AddEntity(entity, outgoingArc)
	if not IsValid(entity) or not IsValid(outgoingArc) then
		return
	end

	local node = self.nodes[entity:EntIndex()]
	if not node then
		node = createNode(self, entity)
		self.nodes[entity:EntIndex()] = node
		table.insert(self.nodeArray, node)
	end
	local outgoing = self.nodes[outgoingArc:EntIndex()]
	if not outgoing then
		outgoing = createNode(self, outgoingArc)

		self.nodes[outgoingArc:EntIndex()] = outgoing
		table.insert(self.nodeArray, outgoing)
	end
	node.outgoingArc = outgoing
	setPhysicalParameters(outgoing, self.nodes)
	setPhysicalParameters(node, self.nodes)
end

---https://stackoverflow.com/questions/62286695/is-there-a-simple-ish-algorithm-for-drawing-force-directed-graphs
---@param nodes ragdollweld_node[]
local function applyForces(nodes, w, h, viewOffset, zoom, isPanning)
	local length = #nodes
	local viewCenter = Vector((w * 0.5 - viewOffset.x) / zoom, (h * 0.5 - viewOffset.y) / zoom, 0)
	for _, node in ipairs(nodes) do
		local force = Vector(0, 0, 0)
		if not isPanning then
			force = Vector(
				viewCenter.x - (node.pos.x + node.sizeVector.x * 0.5),
				viewCenter.y - (node.pos.y + node.sizeVector.y * 0.5),
				0
			)
			force:Mul(GRAVITY)
		end
		node.force = force
	end

	-- apply repulsive force between nodes
	for i = 1, length do
		for j = i + 1, length do
			local pos = nodes[i].pos + nodes[i].sizeVector * 0.5
			local dir = (nodes[j].pos + nodes[j].sizeVector * 0.5) - pos
			local force = dir
			force:Div(dir:Length2DSqr() + 0.01)
			force:Mul(FORCE)

			nodes[i].force:Add(-force)
			nodes[j].force:Add(force)
		end
	end

	for _, node in ipairs(nodes) do
		local otherNode = node.outgoingArc
		if otherNode then
			local dis = (node.pos - otherNode.pos) / SIZE_SCALE * 10

			node.force:Sub(dis)
			otherNode.force:Add(dis)
		end
	end

	-- apply repulsion between arrow segments to reduce overlap
	local arrowRepulsionRangeSqr = ARROW_REPULSION_DISTANCE * ARROW_REPULSION_DISTANCE
	for i = 1, length do
		local node = nodes[i]
		local target = node.outgoingArc
		if target then
			local startPos = node.pos + node.sizeVector * 0.5
			local endPos = target.pos + target.sizeVector * 0.5
			local midpoint = (startPos + endPos) / 2

			for j = i + 1, length do
				local other = nodes[j]
				local otherTarget = other.outgoingArc
				if otherTarget then
					local otherStart = other.pos + other.sizeVector * 0.5
					local otherEnd = otherTarget.pos + otherTarget.sizeVector * 0.5
					local otherMidpoint = (otherStart + otherEnd) / 2

					local delta = otherMidpoint - midpoint
					local dist2 = delta:Length2DSqr()
					if dist2 > 0 and dist2 < arrowRepulsionRangeSqr then
						local dist = math.sqrt(dist2)
						local strength = (ARROW_REPULSION_DISTANCE - dist) / ARROW_REPULSION_DISTANCE * ARROW_REPULSION
						delta:Div(dist)
						delta:Mul(strength)

						node.force:Add(-delta * 0.25)
						target.force:Add(-delta * 0.25)
						other.force:Add(delta * 0.25)
						otherTarget.force:Add(delta * 0.25)
					end
				end
			end
		end
	end
end

---@param nodes ragdollweld_node[]
local function applyPosition(nodes)
	for _, node in ipairs(nodes) do
		local vel = node.force / node.mass
		node.pos:Add(vel)
	end
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param thickness number
---@param headSize number
---@return PolygonVertex
---@return PolygonVertex
local function drawArrow(x1, y1, x2, y2, thickness, headSize)
	-- Calculate direction and length
	local angle = math.atan2(y2 - y1, x2 - x1)
	local length = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)

	-- Body vertices
	local bodyHalfThickness = thickness / 2
	local bodyVerts = {
		{
			x = x1 + math.cos(angle + math.pi / 2) * bodyHalfThickness,
			y = y1 + math.sin(angle + math.pi / 2) * bodyHalfThickness,
		},
		{
			x = x1 + math.cos(angle - math.pi / 2) * bodyHalfThickness,
			y = y1 + math.sin(angle - math.pi / 2) * bodyHalfThickness,
		},
		{
			x = x2 - math.cos(angle) * headSize + math.cos(angle - math.pi / 2) * bodyHalfThickness,
			y = y2 - math.sin(angle) * headSize + math.sin(angle - math.pi / 2) * bodyHalfThickness,
		},
		{
			x = x2 - math.cos(angle) * headSize + math.cos(angle + math.pi / 2) * bodyHalfThickness,
			y = y2 - math.sin(angle) * headSize + math.sin(angle + math.pi / 2) * bodyHalfThickness,
		},
	}

	-- Head vertices
	local headVerts = {
		{ x = x2, y = y2 },
		{
			x = x2 - math.cos(angle) * headSize + math.cos(angle + math.pi / 2) * headSize,
			y = y2 - math.sin(angle) * headSize + math.sin(angle + math.pi / 2) * headSize,
		},
		{
			x = x2 - math.cos(angle) * headSize + math.cos(angle - math.pi / 2) * headSize,
			y = y2 - math.sin(angle) * headSize + math.sin(angle - math.pi / 2) * headSize,
		},
	}
	return bodyVerts, headVerts
end

---@param node ragdollweld_node
function PANEL:OnNodeSelected(node) end

---@param node ragdollweld_node
---@param hovering boolean
function PANEL:OnNodeHover(node, hovering) end

function PANEL:Paint(w, h)
	for _, node in ipairs(self.nodeArray) do
		local nodeSize = node.size * self.zoom
		node:SetSize(nodeSize, nodeSize)

		local screenPos = node.pos * self.zoom + self.viewOffset
		node:SetPos(screenPos.x, screenPos.y)

		local otherNode = node.outgoingArc

		if otherNode then
			local halfNodeSize1 = nodeSize * 0.5
			local otherNodeSize = otherNode.size * self.zoom
			local halfNodeSize2 = otherNodeSize * 0.5

			local x1, y1 = screenPos.x + halfNodeSize1, screenPos.y + halfNodeSize1
			local otherScreenPos = otherNode.pos * self.zoom + self.viewOffset
			local x2, y2 = otherScreenPos.x + halfNodeSize2, otherScreenPos.y + halfNodeSize2
			local vx, vy = (x2 - x1), (y2 - y1)
			local d = math.sqrt(vx * vx + vy * vy)
			if d == 0 then
				d = 0.0001
			end
			local ux, uy = vx / d, vy / d
			local bodyVerts, headVerts = drawArrow(
				x1,
				y1,
				x2 - halfNodeSize2 * ux,
				y2 - halfNodeSize2 * uy,
				SIZE_SCALE / 8 * self.zoom,
				SIZE_SCALE / 4 * self.zoom
			)
			surface.SetDrawColor(node.color:Unpack())
			draw.NoTexture()
			-- Draw body
			surface.DrawPoly(bodyVerts)
			-- Draw head
			surface.DrawPoly(headVerts)
		end
	end
end

function PANEL:PerformLayout(w, h)
	-- for _, node in ipairs(self.nodeArray) do
	-- 	local pos = node.pos
	-- 	node:SetPos(pos.x, pos.y)
	-- 	node:SetSize(node.size, node.size)
	-- end
end

function PANEL:OnMousePressed(mousecode)
	if mousecode == MOUSE_LEFT and vgui.GetHoveredPanel() == self then
		self.isPanning = true
		self.panStart = Vector(gui.MouseX(), gui.MouseY(), 0)
		self.panAnchor = Vector(self.viewOffset.x, self.viewOffset.y, self.viewOffset.z)
		self:SetCursor("sizeall")

		-- Hacky polling solution for detecting mouse input even if the mouse isn't focusing on a panel
		hook.Add("Think", "ragdollweld_mousereleased", function()
			if not input.IsMouseDown(MOUSE_LEFT) then
				hook.Remove("Think", "ragdollweld_mousereleased")
				self.isPanning = false
				self:SetCursor("arrow")
			end
		end)
	end
end

-- function PANEL:OnMouseReleased(mousecode)
-- 	if mousecode == MOUSE_LEFT and self.isPanning then
-- 		self.isPanning = false
-- 		self:SetCursor("arrow")
-- 	end
-- end

function PANEL:OnCursorMoved(x, y)
	if self.isPanning then
		local mouse = Vector(gui.MouseX(), gui.MouseY(), 0)
		local diff = mouse - self.panStart
		self.viewOffset = self.panAnchor + diff
	end
end

function PANEL:OnMouseWheeled(delta)
	local oldZoom = self.zoomTarget
	local nextZoom = math.Clamp(self.zoomTarget + delta * ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
	if nextZoom ~= oldZoom then
		local mx, my = self:ScreenToLocal(gui.MouseX(), gui.MouseY())
		self.zoomFocus = Vector(mx, my, 0)
		self.zoomFocusWorld = Vector((mx - self.viewOffset.x) / self.zoom, (my - self.viewOffset.y) / self.zoom, 0)
		self.zoomTarget = nextZoom
	end
	return true
end

function PANEL:Think()
	if self.zoom ~= self.zoomTarget then
		local nextZoom = Lerp(0.18, self.zoom, self.zoomTarget)
		if math.abs(nextZoom - self.zoomTarget) < 0.001 then
			nextZoom = self.zoomTarget
		end
		self.zoom = nextZoom
		self.viewOffset.x = self.zoomFocus.x - self.zoomFocusWorld.x * self.zoom
		self.viewOffset.y = self.zoomFocus.y - self.zoomFocusWorld.y * self.zoom
	end

	if #self.nodeArray > 0 and not self.isPanning then
		applyForces(self.nodeArray, self:GetWide(), self:GetTall(), self.viewOffset, self.zoom, self.isPanning)
		applyPosition(self.nodeArray)
	end
end

vgui.Register("ragdollweld_graph", PANEL, "DPanel")
