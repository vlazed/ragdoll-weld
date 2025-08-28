local highlighter = {
	---@type {[Entity]: Color}
	highlights = {},
	---@type {[Entity]: {[1]: Entity, [2]: Entity}}
	connections = {},
}

local BLUE = Color(0, 0, 255)

hook.Remove("PostDrawHUD", "ragdollweld_connect_entities")
hook.Add("PostDrawHUD", "ragdollweld_connect_entities", function()
	cam.Start3D()

	render.SetColorMaterialIgnoreZ()
	for _, entityPair in pairs(highlighter.connections) do
		render.DrawLine(entityPair[1]:GetPos(), entityPair[2]:GetPos(), BLUE, true)
	end

	cam.End3D()
end)

hook.Remove("PreDrawHalos", "ragdollweld_highlight_entities")
hook.Add("PreDrawHalos", "ragdollweld_highlight_entities", function()
	for entity, color in pairs(highlighter.highlights) do
		halo.Add({ entity }, color, 0.5, 0.5, 1, false, true)
	end
end)

return highlighter
