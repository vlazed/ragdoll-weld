RagdollWeld = RagdollWeld or {}

if SERVER then
	AddCSLuaFile("ragdollweld/shared/helpers.lua")
	AddCSLuaFile("ragdollweld/client/derma/graph.lua")
	AddCSLuaFile("ragdollweld/client/highlighter.lua")
	AddCSLuaFile("ragdollweld/client/ui.lua")

	include("ragdollweld/server/net.lua")
	include("ragdollweld/server/state.lua")
	include("ragdollweld/server/system.lua")
end
