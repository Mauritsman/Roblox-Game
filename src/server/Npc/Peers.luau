--!strict
-- Runtime lookups of services from other packages (docs/team/integration.md: "skip gracefully when absent"),
-- on top of mechanics A's Lib/Optional, plus the per-player helpers package B needs. Only call these at runtime
-- (inside Start, events or loops), never while modules are still being required.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Logic.Perks)

local Optional = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Optional"))

local Peers = {}

-- The service module, or nil when that package is not merged (or failed to load).
function Peers.get(name: string): any
	return Optional.get(name)
end

-- Calls `service:method(...)` when it exists. Returns (called, results…); errors are caught and warned.
function Peers.call(name: string, method: string, ...: any): (boolean, ...any)
	return Optional.call(name, method, ...)
end

-- Per-player numbers after perks (LoadoutService:StatsOf); Config defaults when that is missing.
local defaults: Perks.Stats? = nil
function Peers.stats(player: Player): Perks.Stats
	local called, stats = Peers.call("LoadoutService", "StatsOf", player)
	if called and type(stats) == "table" then
		return stats :: any
	end
	if defaults == nil then
		defaults = Perks.defaultsFrom(Config)
	end
	return defaults :: Perks.Stats
end

-- Round stats (StatsService:Event). Package B's names (Logic/RoundStats): Caught, Rescue, HeroDrop, Sneeze,
-- TraceCleaned, BoefFed, BoefDistracted, Seen, HidFromChase.
function Peers.event(name: string, player: Player?, data: { [string]: any }?)
	if player then
		Peers.call("StatsService", "Event", name, player, data or {})
	end
end

-- MovementService:Refresh after changing a movement attribute (Hidden, Captured, Caught, Slipping, …).
function Peers.refreshMovement(player: Player)
	Peers.call("MovementService", "Refresh", player)
end

return Peers
