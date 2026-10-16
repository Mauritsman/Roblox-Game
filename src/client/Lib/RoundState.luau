--!strict
-- Read-only view of the round (beta-spec §9.3): attributes on ReplicatedStorage, plus helpers for timers.
-- Times are server timestamps (workspace:GetServerTimeNow()). Every getter tolerates missing attributes,
-- so the HUD works before mechanics' round service exists (and for late joiners).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local RoundState = {}

RoundState.Changed = Signal.new() :: Signal.Signal<string>

local HEIST_PHASES = { Briefing = true, Heist = true, Lockdown = true, Getaway = true }

function RoundState.get(name: string): any
	return ReplicatedStorage:GetAttribute(name)
end

function RoundState.number(name: string): number?
	local value = ReplicatedStorage:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

function RoundState.string(name: string): string?
	local value = ReplicatedStorage:GetAttribute(name)
	return if typeof(value) == "string" and value ~= "" then value else nil
end

function RoundState.now(): number
	return workspace:GetServerTimeNow()
end

-- Seconds until the timestamp in attribute `name` (nil when not set).
function RoundState.left(name: string): number?
	local at = RoundState.number(name)
	if not at or at <= 0 then
		return nil
	end
	return at - RoundState.now()
end

-- Phase: Garage | Briefing | Heist | Lockdown | Getaway | Payout | NextJob. Without the attribute (prototype
-- server) we are always in a heist.
function RoundState.phase(): string
	return RoundState.string("RoundPhase") or "Heist"
end

function RoundState.hasRoundService(): boolean
	return RoundState.string("RoundPhase") ~= nil
end

function RoundState.heistRunning(): boolean
	return HEIST_PHASES[RoundState.phase()] == true
end

-- The local player's activity: Garage | Crew | Tutorial (beta-spec §1.1).
function RoundState.activity(player: Player?): string
	local p = player or Players.LocalPlayer
	local value = p:GetAttribute("Activity")
	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return if RoundState.hasRoundService() then "Garage" else "Crew"
end

-- Which top bar to show: "Heist" (playing), "LateJoin" (in the Garage while the crew is out) or "Garage".
function RoundState.statusMode(): string
	local activity = RoundState.activity()
	if activity == "Crew" or activity == "Tutorial" then
		return "Heist"
	end
	if RoundState.heistRunning() then
		return "LateJoin"
	end
	return "Garage"
end

function RoundState.isLoud(): boolean
	return RoundState.phase() == "Lockdown" or RoundState.get("Approach") == "Loud"
end

-- The one HUD timer: seconds until the police arrive (PoliceAt), else until the round ends.
function RoundState.timer(): (number?, boolean)
	local police = RoundState.left("PoliceAt")
	if police and RoundState.isLoud() then
		return police, true
	end
	local lockdown = RoundState.left("LockdownEndsAt")
	if lockdown and RoundState.isLoud() then
		return lockdown, true
	end
	return RoundState.left("RoundEndsAt") or police, false
end

-- Crew members in the current round (Activity = Crew), or everyone when there is no round service.
function RoundState.crew(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		local activity = RoundState.activity(p)
		if activity == "Crew" or not RoundState.hasRoundService() then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		local ca = a:GetAttribute("CrewColor")
		local cb = b:GetAttribute("CrewColor")
		local na = if typeof(ca) == "number" then ca else 99
		local nb = if typeof(cb) == "number" then cb else 99
		if na ~= nb then
			return na < nb
		end
		return a.UserId < b.UserId
	end)
	return list
end

local started = false
function RoundState.init()
	if started then
		return
	end
	started = true
	ReplicatedStorage.AttributeChanged:Connect(function(name)
		RoundState.Changed:Fire(name)
	end)
end

return RoundState
