--!strict
-- Runtime lookups of services from other packages (docs/team/integration.md: "skip gracefully when absent").
-- Only call these at runtime (inside Start, events or loops), never while modules are still being required.
-- The orchestrator can replace these with direct requires once every package is merged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Logic.Perks)

local servicesFolder = script.Parent.Parent:WaitForChild("Services")

local Peers = {}

local cache: { [string]: any } = {}
local MISSING = {}

-- The service module, or nil when that package is not merged (or failed to load).
function Peers.get(name: string): any
	local cached = cache[name]
	if cached ~= nil then
		return if cached == MISSING then nil else cached
	end
	local module = servicesFolder:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require :: any, module)
		if ok and type(result) == "table" then
			cache[name] = result
			return result
		end
	end
	cache[name] = MISSING
	return nil
end

-- The method `service:method` when both exist, else nil.
function Peers.method(name: string, method: string): ((any, ...any) -> ...any)?
	local service = Peers.get(name)
	if service and type(service[method]) == "function" then
		return service[method]
	end
	return nil
end

-- Calls `service:method(...)` when it exists. Returns (called, results…); errors are caught and warned.
function Peers.call(name: string, method: string, ...: any): (boolean, ...any)
	local service = Peers.get(name)
	if not service or type(service[method]) ~= "function" then
		return false
	end
	local results = table.pack(pcall(service[method], service, ...))
	if not results[1] then
		warn(`[Peers] {name}:{method} failed: {results[2]}`)
		return false
	end
	return true, table.unpack(results, 2, results.n)
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

-- Round stats for awards (StatsService:Event). Names follow Logic/Awards' Stats keys
-- (rescues, heroDrops, sneezes, tracesCleaned, boefFed, timesCaught, everSeen).
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
