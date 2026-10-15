--!strict
-- Translates server messages into the HUD: alarm, window, caught, CRACK, EMP, end of the run.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local Hud = require(Lib.Hud)

local HudController = {}

local player = Players.LocalPlayer

local REASON_TEXT: { [string]: string } = {
	CameraSpotted = "camera saw someone",
	GuardAlert = "guard spotted someone",
	CrackHeard = "CRACK was heard",
	NoisemakerRepeat = "same trick twice",
}

function HudController:Start()
	Hud.setCrosshair(Actions.preferredInput() ~= "KeyboardAndMouse")
	local startLevel = ReplicatedStorage:GetAttribute("AlarmLevel")
	if typeof(startLevel) == "number" then
		Hud.setAlarm(startLevel, Config.Alarm.LevelNames[startLevel] or "")
	end

	Net.on("Toast", function(message: string)
		Hud.toast(message)
	end)

	Net.on("Alarm", function(points: number, level: number, reason: string, added: number)
		Hud.setAlarm(level, Config.Alarm.LevelNames[level] or "")
		if added > 0 then
			Hud.toast(`+{added} ALARM · {REASON_TEXT[reason] or reason} ({points})`, Hud.Colors.Warn)
		end
		if level == 0 then
			Hud.clearLockdown()
		end
	end)

	Net.on("Window", function(kind: string, seconds: number)
		Hud.showWindow(kind, seconds)
	end)

	Net.on("Caught", function(name: string)
		if name == player.DisplayName then
			Hud.banner("CAUGHT", Hud.Colors.Danger, 2)
			Hud.toast("Back to the van. (Phase 2: the security room)", Hud.Colors.Muted)
		else
			Hud.toast(`{name} GOT CAUGHT`, Hud.Colors.Danger)
		end
	end)

	Net.on("GuardAlert", function(name: string)
		if name == player.Name then
			Hud.banner("!", Hud.Colors.Danger, 1)
			Hud.toast("A guard sees you. RUN or hide!", Hud.Colors.Danger)
		elseif name ~= "" then
			Hud.toast(`A guard is chasing {name}`, Hud.Colors.Danger)
		end
	end)

	Net.on("CameraSpotted", function(name: string)
		Hud.toast(`Camera spotted {name}! Guards are coming`, Hud.Colors.Danger)
	end)

	Net.on("Crack", function(_position: Vector3, heard: number, name: string)
		if heard > 0 then
			Hud.toast(`CRACK! A guard heard {name}`, Hud.Colors.Danger)
		else
			Hud.toast("CRACK! Nobody heard it", Hud.Colors.Good)
		end
	end)

	Net.on(
		"EMP",
		function(_position: Vector3, _radius: number, cams: number, lamps: number, drones: { string })
			local parts = {}
			if cams > 0 then
				table.insert(parts, `{cams} camera{if cams == 1 then "" else "s"}`)
			end
			if lamps > 0 then
				table.insert(parts, `{lamps} lamp{if lamps == 1 then "" else "s"}`)
			end
			if #drones > 0 then
				table.insert(parts, `{#drones} drone{if #drones == 1 then "" else "s"}`)
			end
			Hud.toast(
				if #parts > 0 then `BZZT! Off: {table.concat(parts, ", ")}` else "BZZT! Nothing in range",
				Hud.Colors.Eyes
			)
			if table.find(drones, player.Name) then
				Hud.banner("Oops. EMP hits YOUR stuff too.", Hud.Colors.Eyes, 3)
			end
		end
	)

	Net.on("Lockdown", function(seconds: number)
		Hud.lockdown(seconds)
		Hud.toast("LOCKDOWN! Get out before the police arrive", Hud.Colors.Danger)
	end)

	Net.on("RunEnded", function(result: string, seconds: number, detail: string)
		local color = if result == "SUCCESS"
			then Hud.Colors.Good
			elseif result == "BUSTED" then Hud.Colors.Danger
			else Hud.Colors.Muted
		local text = if result == "SUCCESS"
			then "JOB DONE!"
			elseif result == "BUSTED" then "BUSTED"
			else "RESTART"
		Hud.banner(text, color, 6)
		Hud.toast(`{detail} · {seconds // 60}:{string.format("%02d", seconds % 60)}`, color)
		Hud.clearLockdown()
	end)

	Net.on("RunStarted", function(difficulty: string, windowSeconds: number)
		Hud.setAlarm(0, Config.Alarm.LevelNames[0])
		Hud.clearLockdown()
		Hud.toast(`New run · {difficulty} · window {windowSeconds} s`, Hud.Colors.Accent)
	end)

	Actions.on("Restart", function(phase)
		if phase == "Begin" then
			Net.request("RestartRun")
		end
	end)

	task.delay(1.5, function()
		Hud.toast("Grab gadgets at the glowing pedestals, then break into the hall.", Hud.Colors.Accent)
		Hud.toast(
			"Goal: the GOLDEN GOUDA in the cage. Only silly weapons, nobody gets hurt.",
			Hud.Colors.Text
		)
	end)
end

return HudController
