--!strict
-- The alarm ladder (beta-spec §3.3): points only go up; tier 3 = LOCKDOWN.
--   * Crew only: points from a player who is not on the crew (mini-job, Garage) are ignored, and nothing counts
--     outside the Heist/Lockdown phases.
--   * Difficulty: points × the tier's AlarmPoints (Easy ×0.75, Hard ×1.25), rounded half up.
--   * Tier 3 calls RoundService:StartLockdown("alarm") (the prototype RoundService listens to LevelChanged).
-- Tier effects live with their owners: guards patrol at 7.5 from tier 2 (GuardService), cameras sweep faster
-- (CameraService), Karel rests half as long from tier 1 (NpcService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Detection = require(ReplicatedStorage.Shared.Logic.Detection)
local Difficulty = require(ReplicatedStorage.Shared.Logic.Difficulty)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Npc = script.Parent.Parent:WaitForChild("Npc")
local Peers = require(Npc.Peers)
local Targets = require(Npc.Targets)

local AlarmService = {}
AlarmService.Points = 0
AlarmService.Level = 0
AlarmService.MaxLevel = 0 -- highest tier this round (RoundResult.maxAlarmTier)
AlarmService.LevelChanged = Signal.new() :: Signal.Signal<number>

local LOCKDOWN_TIER = #Config.Alarm.LevelThresholds

local function setLevel(level: number)
	local changed = level ~= AlarmService.Level
	AlarmService.Level = level
	AlarmService.MaxLevel = math.max(AlarmService.MaxLevel, level)
	ReplicatedStorage:SetAttribute(Tags.AlarmLevel, level)
	if changed then
		AlarmService.LevelChanged:Fire(level)
		if level >= LOCKDOWN_TIER then
			Peers.call("RoundService", "StartLockdown", "alarm")
		end
	end
end

-- Adds alarm points. `player` (optional) = who caused it; non-crew players never raise the crew's alarm.
function AlarmService:Add(reason: string, basePoints: number?, player: Player?)
	if not Targets.inHeist() then
		return
	end
	if player and not Targets.isCrew(player) then
		return
	end
	local base = basePoints or Config.Alarm.Points[reason] or 0
	local points = Difficulty.scalePoints(base, Targets.round().alarmPointsFactor)
	if points <= 0 or AlarmService.Level >= LOCKDOWN_TIER then
		return
	end
	AlarmService.Points += points
	local level = Detection.levelFor(AlarmService.Points, Config.Alarm.LevelThresholds)
	Net.broadcast("Alarm", AlarmService.Points, level, reason, points)
	setLevel(level)
end

-- Straight to tier 3 (DevAlarm, scripted events). Does nothing when already in lockdown.
function AlarmService:ForceLockdown(reason: string)
	if AlarmService.Level >= LOCKDOWN_TIER then
		return
	end
	local top = Config.Alarm.LevelThresholds[LOCKDOWN_TIER]
	local added = math.max(0, top - AlarmService.Points)
	AlarmService.Points = math.max(AlarmService.Points, top)
	Net.broadcast("Alarm", AlarmService.Points, LOCKDOWN_TIER, reason, added)
	setLevel(LOCKDOWN_TIER)
end

-- LOCKDOWN length for this round's difficulty (Easy 75, Normal 60, Hard 50).
function AlarmService:LockdownSeconds(): number
	return Targets.round().lockdownSeconds
end

function AlarmService:Reset()
	AlarmService.Points = 0
	AlarmService.MaxLevel = 0
	Net.broadcast("Alarm", 0, 0, "Reset", 0)
	setLevel(0)
	ReplicatedStorage:SetAttribute(Tags.AlarmLevel, 0)
end

function AlarmService:Init()
	ReplicatedStorage:SetAttribute(Tags.AlarmLevel, 0)
end

return AlarmService
