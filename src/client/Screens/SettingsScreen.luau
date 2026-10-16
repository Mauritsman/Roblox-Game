--!strict
-- Settings (beta-spec-ux §1.15): Music and SFX volume (10 steps, − / + buttons of 48 px), Reduce motion,
-- Hints, "Mute pings from" (crew chips) and the version. Saved through Settings → SaveSettings (meta).
-- Camera sensitivity is left to Roblox's own menu (scripts cannot change it without forking PlayerModule).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Lib = script.Parent.Parent.Lib
local Audio = require(Lib.Audio)
local Hud = require(Lib.Hud)
local Screens = require(Lib.Screens)
local Settings = require(Lib.Settings)
local Theme = require(Lib.Theme)

local Common = require(script.Parent.Common)

local SettingsScreen = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local function row(parent: Instance, order: number, label: string): Frame
	local frame = Hud.frame({ Size = UDim2.new(1, -8, 0, 52), LayoutOrder = order }, parent)
	Hud.text({
		Size = UDim2.fromScale(0.34, 1),
		Text = label,
		TextXAlignment = Enum.TextXAlignment.Left,
		Heavy = true,
		MaxTextSize = 18,
	}, frame)
	return frame
end

local function volumeRow(parent: Instance, order: number, label: string, key: string)
	local frame = row(parent, order, label)
	local value = math.clamp(math.floor(Settings.number(key, 8) + 0.5), 0, 10)
	local controls = Hud.frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.66, 1),
	}, frame)
	Hud.list(
		controls,
		Enum.FillDirection.Horizontal,
		6,
		Enum.HorizontalAlignment.Right,
		Enum.VerticalAlignment.Center
	)
	local minus = Hud.button({
		Name = key .. "Minus",
		Size = UDim2.fromOffset(48, 48),
		Text = "−",
		LayoutOrder = 1,
		MaxTextSize = 26,
	}, controls)
	local bars = Hud.frame({ Size = UDim2.fromOffset(150, 30), LayoutOrder = 2 }, controls)
	Hud.list(
		bars,
		Enum.FillDirection.Horizontal,
		3,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Bottom
	)
	for step = 1, 10 do
		local bar = Hud.make("Frame", {
			Size = UDim2.fromOffset(12, 8 + step * 2),
			BackgroundColor3 = if step <= value then C.Accent else C.Dim,
			BorderSizePixel = 0,
			LayoutOrder = step,
		}, bars)
		Hud.corner(bar, 3)
	end
	local plus = Hud.button({
		Name = key .. "Plus",
		Size = UDim2.fromOffset(48, 48),
		Text = "+",
		LayoutOrder = 3,
		MaxTextSize = 26,
	}, controls)
	local function change(delta: number)
		local nextValue = math.clamp(value + delta, 0, 10)
		Settings.set(key, nextValue)
		Screens.refresh()
		if key == "Sfx" then
			Audio.play("UiTap")
		end
	end
	minus.Activated:Connect(function()
		change(-1)
	end)
	plus.Activated:Connect(function()
		change(1)
	end)
end

local function toggleRow(parent: Instance, order: number, label: string, key: string)
	local frame = row(parent, order, label)
	local on = Settings.get(key) == true
	local button = Hud.button({
		Name = key .. "Toggle",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(110, 48),
		Text = if on then "ON" else "OFF",
		Kind = if on then "good" else "secondary",
		MaxTextSize = 18,
	}, frame)
	button.Activated:Connect(function()
		Settings.set(key, not on)
		Screens.refresh()
	end)
end

function SettingsScreen.create(): any
	return {
		title = "SETTINGS",
		size = Vector2.new(560, 420),
		build = function(body: Frame): (() -> ())?
			local list = Common.scroller(body, false)
			volumeRow(list, 1, "MUSIC", "Music")
			volumeRow(list, 2, "SOUND", "Sfx")
			toggleRow(list, 3, "REDUCE MOTION", "ReduceMotion")
			toggleRow(list, 4, "HINTS", "Hints")
			local others = {}
			for _, p in Players:GetPlayers() do
				if p ~= player then
					table.insert(others, p)
				end
			end
			if #others > 0 then
				local muteRow = row(list, 5, "MUTE PINGS")
				local chips = Hud.frame({
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromScale(0.66, 1),
				}, muteRow)
				Hud.list(
					chips,
					Enum.FillDirection.Horizontal,
					6,
					Enum.HorizontalAlignment.Right,
					Enum.VerticalAlignment.Center
				)
				for index, p in others do
					local muted = Settings.isMuted(p.UserId)
					local crew = Theme.crew(p)
					local chip = Hud.button({
						Name = "Mute" .. p.UserId,
						Size = UDim2.fromOffset(96, 48),
						Text = `{crew.glyph} {Hud.shortName(p.DisplayName, 7)}`,
						Kind = if muted then "disabled" else "secondary",
						MaxTextSize = 15,
						LayoutOrder = index,
					}, chips)
					chip.Activated:Connect(function()
						Settings.setMuted(p.UserId, not muted)
						Screens.refresh()
					end)
				end
			end
			Hud.text({
				Size = UDim2.new(1, -8, 0, 40),
				Text = `Camera speed: Roblox menu · Crowbar Crew {Config.Version}`,
				TextColor3 = C.Muted,
				MaxTextSize = 14,
				LayoutOrder = 10,
			}, list)
			return nil
		end,
	}
end

return SettingsScreen
