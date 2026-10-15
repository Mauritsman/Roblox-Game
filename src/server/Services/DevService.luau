--!strict
-- Test helper, ONLY active in Roblox Studio (RunService:IsStudio()).
-- Lets Claude hand out gadgets and open doors through the Studio MCP without any
-- buttons having to appear on screen. It does nothing in the published game.

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
	-- Take/return a gadget as if the player pressed the pedestal button.
	Net.onRequest("DevTake", function(player: Player, gadgetName: any)
		if typeof(gadgetName) == "string" then
			LoadoutService:Toggle(player, gadgetName)
		end
	end)
	-- Open a Pryable object as if the player held the Crowbar button (optionally by name, e.g. "CageDoor").
	Net.onRequest("DevPry", function(player: Player, targetName: any)
		for _, target in CollectionService:GetTagged(Tags.Pryable) do
			local nameOk = typeof(targetName) ~= "string" or target.Name == targetName
			if target:IsA("BasePart") and nameOk then
				GadgetService:Pry(player, target)
				return
			end
		end
	end)
end

return DevService
