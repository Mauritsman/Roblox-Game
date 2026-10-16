--!strict
-- The only way mechanics code reaches the meta services (docs/team/integration.md, docs/meta-api.md).
-- Meta is merged, so this calls DataService, LobbyService, ShopService, ProgressionService, EconomyService and
-- AnalyticsTracker directly, but every call is guarded: a missing service or an error returns a safe default
-- (solo job on The Golden Wheel / Normal, loadout {"Crowbar", "Noisemaker", "BubbleBlaster"}, no perks,
-- settle = no-op + warn), so a meta problem never stops a round.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Server = script.Parent.Parent
local Registry = require(Server.Map.Registry)

local Meta = {}

export type Job = {
	cardId: string,
	heistId: string,
	difficulty: string,
	modifierId: string?,
	isHotJob: boolean,
	mostWanted: boolean?,
}

local services: { [string]: any } = {}

local function service(name: string): any
	local cached = services[name]
	if cached ~= nil then
		return if cached == false then nil else cached
	end
	local module = Server.Services:FindFirstChild(name)
	local loaded: any = false
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			loaded = result
		else
			warn(`[Meta] could not load {name}: {result}`)
		end
	end
	services[name] = loaded
	return if loaded == false then nil else loaded
end

local warned: { [string]: boolean } = {}
local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(message)
	end
end

-- service:method(...) guarded. Returns (true, result) or (false, nil).
local function call(name: string, method: string, ...: any): (boolean, any)
	local s = service(name)
	local fn = s and s[method]
	if type(fn) ~= "function" then
		warnOnce(name .. method, `[Meta] {name}:{method} missing: using the default`)
		return false, nil
	end
	local ok, result = pcall(fn, s, ...)
	if not ok then
		warn(`[Meta] {name}:{method} failed: {result}`)
		return false, nil
	end
	return true, result
end

function Meta.defaultJob(): Job
	return {
		cardId = Registry.DefaultHeist,
		heistId = Registry.DefaultHeist,
		difficulty = Config.DifficultyTiers.Default,
		modifierId = nil,
		isHotJob = false,
		mostWanted = false,
	}
end

-- The job the boarders play (votes, Hot Job, lowest tier). Also marks them departed for the round funnel.
function Meta.GetSelectedJob(boarders: { Player }, roundId: string?): Job
	local ok, job = call("LobbyService", "GetSelectedJob", boarders, roundId)
	if ok and type(job) == "table" and type(job.heistId) == "string" then
		return job
	end
	return Meta.defaultJob()
end

-- {"Crowbar", a, b}
function Meta.GetLoadout(player: Player): { string }
	local ok, loadout = call("ShopService", "GetLoadout", player)
	if ok and type(loadout) == "table" and #loadout > 0 then
		return loadout
	end
	local list = { "Crowbar" }
	for _, gadget in Config.Loadout.Default do
		table.insert(list, gadget)
	end
	return list
end

-- {[perkId] = 1} for the equipped perks.
function Meta.GetPerks(player: Player): { [string]: number }
	local ok, perks = call("ProgressionService", "GetPerks", player)
	if ok and type(perks) == "table" then
		return perks
	end
	return {}
end

-- Once per round (idempotent by roundId on meta's side). Returns {[userId] = {cash, rep}} or {}.
function Meta.SettleRound(result: { [string]: any }): { [number]: any }
	local ok, settled = call("EconomyService", "SettleRound", result)
	if ok and type(settled) == "table" then
		return settled
	end
	warnOnce("settle", "[Meta] SettleRound unavailable: the round was not paid out")
	return {}
end

function Meta.OnboardingStep(player: Player, name: string)
	call("AnalyticsTracker", "OnboardingStep", player, name)
end

function Meta.RoundStep(player: Player, roundId: string?, name: string)
	if roundId and roundId ~= "" then
		call("AnalyticsTracker", "RoundStep", player, roundId, name)
	end
end

-- Yields until the player's data is loaded; true when loaded (false: failed, left or no DataService).
function Meta.WaitForData(player: Player, timeout: number?): boolean
	local ok, data = call("DataService", "WaitForData", player, timeout)
	return ok and data ~= nil
end

-- Runs before the final saves on shutdown (settle the running round as "Shutdown"). Falls back to BindToClose.
function Meta.OnBeforeShutdown(fn: () -> ())
	local ok = call("DataService", "OnBeforeShutdown", fn)
	if not ok then
		game:BindToClose(fn)
	end
end

-- Without meta data (failed load, no meta) the mini-job is skipped.
function Meta.IsTutorialDone(player: Player): boolean
	local ok, done = call("ProgressionService", "IsTutorialDone", player)
	if ok then
		return done == true
	end
	return true
end

function Meta.RoundsCompleted(player: Player): number
	local ok, rounds = call("ProgressionService", "RoundsCompleted", player)
	return if ok and type(rounds) == "number" then rounds else 0
end

return Meta
