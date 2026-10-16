--!strict
-- Root ScreenGuis (layers) and the UIScale strategy (beta-spec-ux §6):
--   touch:            clamp(viewportHeight / 420, 1.0, 1.4)  (phones stay 1.0, so 48/64 px are real)
--   keyboard/gamepad: clamp(viewportHeight / 720, 1.0, 1.5)  (1080p ≈ 1.5, readable on a TV)
-- HUD layers respect the Roblox safe area (notch, top bar); full-screen layers ignore it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Device = require(script.Parent.Device)

local UiScale = {}

export type Layer = "World" | "Hud" | "Overlay" | "Modal" | "Fullscreen" | "Top"

local ORDER: { [string]: number } = {
	World = 5, -- edge arrows and markers (below the HUD)
	Hud = 10,
	Overlay = 20, -- banners, pops, flying numbers
	Modal = 30, -- one screen at a time (Screens)
	Fullscreen = 40, -- payout, cell feed, vignettes
	Top = 50, -- stamps above everything
}

local roots: { [string]: ScreenGui } = {}
local scales: { UIScale } = {}
local current = 1

UiScale.Changed = Signal.new() :: Signal.Signal<number>

function UiScale.compute(): number
	local height = Device.viewport().Y
	if Device.input() == "Touch" then
		return math.clamp(height / 420, 1, 1.4)
	end
	return math.clamp(height / 720, 1, 1.5)
end

function UiScale.get(): number
	return current
end

local function apply()
	local value = UiScale.compute()
	if math.abs(value - current) < 0.001 and #scales > 0 then
		return
	end
	current = value
	for _, scale in scales do
		scale.Scale = value
	end
	UiScale.Changed:Fire(value)
end

local function playerGui(): PlayerGui
	return Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
end

-- Returns the ScreenGui of a layer (created on first use). Every layer except World gets a UIScale.
function UiScale.root(layer: Layer): ScreenGui
	local existing = roots[layer]
	if existing then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CC_" .. layer
	gui.ResetOnSpawn = false
	gui.DisplayOrder = ORDER[layer] or 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if layer == "Fullscreen" or layer == "Top" or layer == "World" then
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
	else
		gui.IgnoreGuiInset = false
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end
	if layer ~= "World" then
		local scale = Instance.new("UIScale")
		scale.Scale = current
		scale.Parent = gui
		table.insert(scales, scale)
	end
	gui.Parent = playerGui()
	roots[layer] = gui
	return gui
end

-- A ScreenGui that does not scale (the touch cluster scales its buttons itself to match Roblox's jump button).
function UiScale.plainRoot(name: string, order: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui()
	return gui
end

local started = false
function UiScale.init()
	if started then
		return
	end
	started = true
	current = UiScale.compute()
	Device.Changed:Connect(apply)
end

return UiScale
