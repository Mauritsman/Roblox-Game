--!strict
-- De alarmladder (§9.5): punten gaan alleen omhoog; trede 3 = LOCKDOWN met een ontsnappingstimer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local AlarmService = {}
AlarmService.Points = 0
AlarmService.Level = 0
AlarmService.LevelChanged = Signal.new() :: Signal.Signal<number>

local function levelFor(points: number): number
	local level = 0
	for index, threshold in Config.Alarm.LevelThresholds do
		if points >= threshold then
			level = index
		end
	end
	return level
end

function AlarmService:Add(reason: string, basePoints: number?)
	local points = basePoints or Config.Alarm.Points[reason] or 0
	if Config.Difficulty == "Rookie" then
		points = math.floor(points * Config.Alarm.RookieMultiplier)
	end
	if points <= 0 or AlarmService.Level >= 3 then
		return
	end
	AlarmService.Points += points
	local newLevel = levelFor(AlarmService.Points)
	local changed = newLevel ~= AlarmService.Level
	AlarmService.Level = newLevel
	Net.broadcast("Alarm", AlarmService.Points, AlarmService.Level, reason, points)
	ReplicatedStorage:SetAttribute("AlarmLevel", AlarmService.Level)
	if changed then
		AlarmService.LevelChanged:Fire(newLevel)
	end
end

function AlarmService:Reset()
	AlarmService.Points = 0
	AlarmService.Level = 0
	Net.broadcast("Alarm", 0, 0, "Reset", 0)
	ReplicatedStorage:SetAttribute("AlarmLevel", 0)
	AlarmService.LevelChanged:Fire(0)
end

return AlarmService
