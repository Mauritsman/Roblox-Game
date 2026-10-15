--!strict
-- Testhulp, ALLEEN actief in Roblox Studio (RunService:IsStudio()).
-- Laat Claude via de Studio MCP gadgets geven en deuren openen zonder dat er
-- knoppen op het scherm moeten verschijnen. In de gepubliceerde game doet dit niets.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local GadgetService = require(script.Parent.GadgetService)
local LoadoutService = require(script.Parent.LoadoutService)

local DevService = {}

function DevService:Start()
	if not RunService:IsStudio() then
		return
	end
	-- Gadget nemen/teruglegen alsof de speler de sokkelknop indrukte.
	Net.onRequest("DevTake", function(player: Player, gadgetName: any)
		if typeof(gadgetName) == "string" then
			LoadoutService:Toggle(player, gadgetName)
		end
	end)
	-- Een Pryable-object openen alsof de speler de Crowbar-knop vasthield.
	Net.onRequest("DevPry", function(player: Player)
		for _, target in CollectionService:GetTagged(Tags.Pryable) do
			if target:IsA("BasePart") then
				GadgetService:Pry(player, target)
				return
			end
		end
	end)
end

return DevService
