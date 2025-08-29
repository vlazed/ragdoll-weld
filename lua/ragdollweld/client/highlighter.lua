local highlighter = {
	---@type {[Entity]: Color}
	highlights = {},
	---@type {[Entity]: {[1]: Entity, [2]: Entity, [3]: integer}}
	connections = {},
}

local BLUE = Color(0, 0, 255)

hook.Remove("PostDrawHUD", "ragdollweld_connect_entities")
hook.Add("PostDrawHUD", "ragdollweld_connect_entities", function()
	cam.Start3D()

	render.SetColorMaterialIgnoreZ()
	for i, entityPair in pairs(highlighter.connections) do
		if not IsValid(entityPair[1]) or not IsValid(entityPair[2]) then
			highlighter.highlights[i] = nil
			continue
		end
		local endPos = entityPair[2]:GetBonePosition(entityPair[3]) or entityPair[2]:GetPos()
		render.DrawLine(entityPair[1]:GetPos(), endPos, BLUE, true)
	end

	cam.End3D()
end)

hook.Remove("PreDrawHalos", "ragdollweld_highlight_entities")
hook.Add("PreDrawHalos", "ragdollweld_highlight_entities", function()
	for entity, color in pairs(highlighter.highlights) do
		if not IsValid(entity) then
			highlighter.highlights[entity] = nil
			continue
		end
		halo.Add({ entity }, color, 0.5, 0.5, 1, false, true)
	end
end)

return highlighter
