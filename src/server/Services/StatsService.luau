--!strict
-- Per-round player stats for awards, RoundResult and analytics (beta-spec §8). Pure counting is in
-- Logic/RoundStats (event names listed there).
--
--   StatsService:Event(name, player, data?)     record a moment (any service; data = {amount?, value?, …})
--   StatsService.Event:Connect(fn)              listen to recorded moments (name, player, data)
-- `Event` is both: a Signal you can Connect to, and callable with method syntax to record (contracts.md lists it
-- as a signal, integration.md as an entry point).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Awards = require(ReplicatedStorage.Shared.Logic.Awards)
local RoundStats = require(ReplicatedStorage.Shared.Logic.RoundStats)
local Signal = require(ReplicatedStorage.Shared.Signal)

local StatsService = {}

local counters: { [number]: RoundStats.Counters } = {}

local function countersFor(userId: number): RoundStats.Counters
	local list = counters[userId]
	if not list then
		list = RoundStats.new()
		counters[userId] = list
	end
	return list
end

local function record(name: any, player: any, data: any)
	if type(name) ~= "string" or typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	RoundStats.add(countersFor(player.UserId), name, if type(data) == "table" then data else nil)
end

local eventSignal = Signal.new() :: any
setmetatable(eventSignal, {
	__call = function(signal: any, _self: any, name: any, player: any, data: any)
		record(name, player, data)
		signal:Fire(name, player, data)
	end,
})
StatsService.Event = eventSignal

-- Clears every counter (called by RoundService at Briefing).
function StatsService:Reset()
	table.clear(counters)
end

-- A copy of one player's counters.
function StatsService:Get(player: Player): RoundStats.Counters
	return table.clone(countersFor(player.UserId))
end

function StatsService:Count(player: Player, name: string): number
	return RoundStats.get(countersFor(player.UserId), name)
end

-- meta's CrewStats for one player.
function StatsService:CrewStats(player: Player): { [string]: number }
	return RoundStats.crewStats(countersFor(player.UserId))
end

-- One award per player: {[userId] = awardId}.
function StatsService:Awards(players: { Player }): { [number]: string }
	local byPlayer: { [number]: any } = {}
	for _, player in players do
		byPlayer[player.UserId] = RoundStats.awardStats(countersFor(player.UserId))
	end
	return Awards.assign(byPlayer)
end

return StatsService
