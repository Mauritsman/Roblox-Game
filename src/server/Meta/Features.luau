--!strict
-- Reads mechanics' feature switches (Config.Features.Difficulty / .Perks). Missing switch = off, so meta never
-- offers a tier or perk whose effects mechanics has not built yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Features = {}

function Features.on(name: string): boolean
	local features = (Config :: any).Features
	return type(features) == "table" and features[name] == true
end

function Features.snapshot(): { [string]: boolean }
	return { Difficulty = Features.on("Difficulty"), Perks = Features.on("Perks") }
end

return Features
