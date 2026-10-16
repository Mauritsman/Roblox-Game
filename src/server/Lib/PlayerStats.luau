--!strict
-- Per-player numbers for every mechanics package (beta-spec §7.4): the Config defaults, then the job's difficulty
-- tier (self-escapes), then the equipped perks (ProgressionService:GetPerks through Lib/Meta). Pure maths:
-- Logic/Loadout.stats. Never read these numbers straight from Config.
--
--   PlayerStats.StatsOf(player)              → Logic/Perks Stats (cached for the round, else computed now)
--   PlayerStats.Refresh(player, difficulty?) → re-reads the perks and caches the result (LoadoutService:ResetRound
--                                              at Briefing and JUMP IN)
--   PlayerStats.Clear(player)
-- LoadoutService:StatsOf(player) is the same function (integration.md). The cache is dropped when the player's
-- Activity changes, so perks equipped in the Garage count from the next job on; outside a crew round the
-- numbers are computed without a tier (the mini-job has none).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Difficulty = require(ReplicatedStorage.Shared.Logic.Difficulty)
local Loadout = require(ReplicatedStorage.Shared.Logic.Loadout)
local Perks = require(ReplicatedStorage.Shared.Logic.Perks)

local Meta = require(script.Parent.Meta)

local PlayerStats = {}

export type Stats = Perks.Stats

local DEFAULTS = Perks.defaultsFrom(Config)

local cache: { [Player]: Stats } = {}
local hooked: { [Player]: boolean } = {}

local function tierRow(difficulty: string?): Loadout.TierRow?
	if not Config.Features.Difficulty or difficulty == nil then
		return nil
	end
	local row = Difficulty.tier(Config.DifficultyTiers :: any, difficulty)
	return row
end

local function compute(player: Player, difficulty: string?): Stats
	local perks = if Config.Features.Perks then Meta.GetPerks(player) else nil
	local stats = Loadout.stats(
		DEFAULTS :: any,
		tierRow(difficulty),
		perks,
		Config.Perks :: any,
		Config.Features.Perks == true
	)
	return stats :: any
end

local function hook(player: Player)
	if hooked[player] then
		return
	end
	hooked[player] = true
	player:GetAttributeChangedSignal(Tags.Activity):Connect(function()
		cache[player] = nil
	end)
end

-- The job's difficulty for a player now: the round's tier for the crew, none elsewhere.
local function currentDifficulty(player: Player): string?
	if player:GetAttribute(Tags.Activity) ~= "Crew" then
		return nil
	end
	local value = ReplicatedStorage:GetAttribute(Tags.Difficulty)
	return if type(value) == "string" then value else Config.DifficultyTiers.Default
end

function PlayerStats.StatsOf(player: Player): Stats
	local cached = cache[player]
	if cached then
		return cached
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return DEFAULTS
	end
	local stats = compute(player, currentDifficulty(player))
	if player:GetAttribute(Tags.Activity) == "Crew" and player.Parent then
		hook(player)
		cache[player] = stats
	end
	return stats
end

function PlayerStats.Refresh(player: Player, difficulty: string?): Stats
	local stats = compute(player, difficulty or currentDifficulty(player))
	if player.Parent then
		hook(player)
		cache[player] = stats
	end
	return stats
end

function PlayerStats.Clear(player: Player)
	cache[player] = nil
end

-- Stats with no perks and no tier (tests, NPC defaults).
function PlayerStats.Defaults(): Stats
	return DEFAULTS
end

Players.PlayerRemoving:Connect(function(player)
	cache[player] = nil
	hooked[player] = nil
end)

return PlayerStats
