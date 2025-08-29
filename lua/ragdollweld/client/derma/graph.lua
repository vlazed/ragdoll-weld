---@module "ragdollweld.shared.helpers"
local helpers = include("ragdollweld/shared/helpers.lua")
local getName = helpers.getEntityName

local GRAVITY = 5
local FORCE = 7500
local MASS = 0.5
local SIZE_SCALE = 30

local WIDTH, HEIGHT = ScrW(), ScrH()

---@class ragdollweld_node: EntityNode
---@field outgoingArc ragdollweld_node
local PANEL = {}

function PANEL:Init()
	self.entity = NULL

	self.icon = vgui.Create("SpawnIcon", self)

	self.size = 1
	self.sizeVector = Vector(1, 1, 0)
	self.mass = 1

	self.force = Vector()
	self.pos = Vector()

	self.color = ColorAlpha(self:GetSkin().Colours.Label.Dark, 128)
	self.icon:SetColor(self.color)

	function self.icon.DoClick()
		self:OnSelected()
	end

	function self.icon.OnCursorEntered()
		self:OnHover(true)
	end
	function self.icon.OnCursorExited()
		self:OnHover(false)
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
local function applyForces(nodes, w, h)
	local length = #nodes
	for _, node in ipairs(nodes) do
		-- local gravity = -GRAVITY * node.pos
		-- node.force = gravity
		local force = Vector(
			w * 0.5 - (node.pos.x + node.sizeVector.x * 0.5),
			h * 0.5 - (node.pos.y + node.sizeVector.y * 0.5),
			0
		)
		force:Mul(GRAVITY)
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
		local otherNode = node.outgoingArc

		if otherNode then
			local halfNodeSize1 = node.size * 0.5
			local halfNodeSize2 = otherNode.size * 0.5

			local x1, y1 = node:GetPos()
			local x2, y2 = otherNode:GetPos()
			x1, y1 = x1 + halfNodeSize1, y1 + halfNodeSize1
			x2, y2 = x2 + halfNodeSize2, y2 + halfNodeSize2
			local vx, vy = (x2 - x1), (y2 - y1)
			local d = math.sqrt(vx * vx + vy * vy)
			local ux, uy = vx / d, vy / d
			local bodyVerts, headVerts =
				drawArrow(x1, y1, x2 - halfNodeSize2 * ux, y2 - halfNodeSize2 * uy, SIZE_SCALE / 8, SIZE_SCALE / 4)
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
	for _, node in ipairs(self.nodeArray) do
		local pos = node.pos
		node:SetPos(pos.x, pos.y)
		node:SetSize(node.size, node.size)
	end
end

function PANEL:Think()
	if #self.nodeArray > 0 then
		applyForces(self.nodeArray, self:GetWide(), self:GetTall())
		applyPosition(self.nodeArray)
	end
end

vgui.Register("ragdollweld_graph", PANEL, "DPanel")
