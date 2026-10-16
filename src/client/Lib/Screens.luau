--!strict
-- Screens: one modal at a time (beta-spec-ux §7.1). Opening a screen hides the touch cluster, turns off
-- Roblox's touch controls, blocks gameplay actions, and selects the first button for gamepads.
-- B (gamepad) or the close button (48 px) closes it.
--
--   Screens.register(name, { title, build = function(body, arg) ... return cleanup end, size?, fullscreen? })
--   Screens.open(name, arg?) / Screens.close(name?) / Screens.refresh(name?) / Screens.current()

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Lib = script.Parent
local Actions = require(Lib.Actions)
local Audio = require(Lib.Audio)
local Device = require(Lib.Device)
local Hud = require(Lib.Hud)
local Settings = require(Lib.Settings)
local Theme = require(Lib.Theme)
local UiScale = require(Lib.UiScale)

local Screens = {}

export type Def = {
	title: string,
	build: (body: Frame, arg: any) -> (() -> ())?,
	size: Vector2?,
	fullscreen: boolean?,
	closable: boolean?,
	onClose: (() -> ())?,
}

Screens.Changed = Signal.new() :: Signal.Signal<string?>

local defs: { [string]: Def } = {}
local currentName: string? = nil
local currentArg: any = nil
local window: Frame? = nil
local body: Frame? = nil
local cleanup: (() -> ())? = nil

function Screens.register(name: string, def: Def)
	defs[name] = def
end

function Screens.current(): string?
	return currentName
end

function Screens.isOpen(): boolean
	return currentName ~= nil
end

local function firstSelectable(root: Instance): GuiObject?
	local best: GuiObject? = nil
	local bestY = math.huge
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Selectable and d.Visible then
			local y = d.AbsolutePosition.Y * 10000 + d.AbsolutePosition.X
			if y < bestY then
				bestY = y
				best = d
			end
		end
	end
	return best
end

-- Puts the gamepad selection on a button (or the first button of the screen).
function Screens.select(target: GuiObject?)
	if Device.input() ~= "Gamepad" then
		return
	end
	task.defer(function()
		local pick = target or (body and firstSelectable(body))
		if pick and pick.Parent then
			GuiService.SelectedObject = pick
		end
	end)
end

local function runCleanup()
	local fn = cleanup
	cleanup = nil
	if fn then
		local ok, err = pcall(fn :: any)
		if not ok then
			warn(`[Screens] cleanup failed: {err}`)
		end
	end
end

local function buildBody(def: Def)
	local b = body
	if not b then
		return
	end
	for _, child in b:GetChildren() do
		child:Destroy()
	end
	local ok, result = pcall(def.build, b, currentArg)
	if not ok then
		warn(`[Screens] building {currentName} failed: {result}`)
		Hud.text({
			Size = UDim2.new(1, 0, 0, 40),
			Text = "Something went wrong here. Close and try again.",
			TextColor3 = Theme.Colors.Muted,
		}, b)
	elseif typeof(result) == "function" then
		cleanup = result
	end
end

function Screens.close(name: string?)
	if not currentName or (name and name ~= currentName) then
		return
	end
	local def = defs[currentName]
	runCleanup()
	if window then
		window:Destroy()
	end
	window = nil
	body = nil
	currentName = nil
	currentArg = nil
	pcall(function()
		GuiService.TouchControlsEnabled = true
	end)
	if GuiService.SelectedObject then
		GuiService.SelectedObject = nil
	end
	Actions.setBlocker(nil)
	if def and def.onClose then
		task.spawn(def.onClose)
	end
	Screens.Changed:Fire(nil)
end

function Screens.open(name: string, arg: any?): boolean
	local def = defs[name]
	if not def then
		warn(`[Screens] unknown screen {name}`)
		return false
	end
	if currentName then
		Screens.close()
	end
	currentName = name
	currentArg = arg

	local layer = UiScale.root(if def.fullscreen then "Fullscreen" else "Modal")
	local root = Hud.frame({ Name = "Screen_" .. name, Size = UDim2.fromScale(1, 1) }, layer)
	window = root
	if def.fullscreen then
		local b = Hud.frame({ Name = "Body", Size = UDim2.fromScale(1, 1) }, root)
		body = b
	else
		local backdrop = Hud.make("TextButton", {
			Name = "Backdrop",
			Size = UDim2.new(1, 200, 1, 200),
			Position = UDim2.fromOffset(-100, -100),
			BackgroundColor3 = Theme.Colors.Backdrop,
			BackgroundTransparency = 0.45,
			AutoButtonColor = false,
			Selectable = false,
			Text = "",
			BorderSizePixel = 0,
		}, root)
		local _ = backdrop
		local size = def.size or Vector2.new(720, 420)
		local panel = Hud.panel({
			Name = "Window",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -16, 1, -16),
			BackgroundTransparency = 0.06,
			Radius = 16,
		}, root)
		Hud.make("UISizeConstraint", { MaxSize = size }, panel)
		Hud.stroke(panel, Theme.Colors.PanelLight, 2)
		local header = Hud.frame({ Name = "Header", Size = UDim2.new(1, 0, 0, 52) }, panel)
		Hud.text({
			Position = UDim2.fromOffset(16, 8),
			Size = UDim2.new(1, -90, 0, 36),
			Text = def.title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Display = true,
			MaxTextSize = 30,
			TextColor3 = Theme.Colors.Gold,
		}, header)
		if def.closable ~= false then
			local close = Hud.button({
				Name = "Close",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 4),
				Size = UDim2.fromOffset(48, 48),
				Text = "✕",
				Kind = "ghost",
				Sound = "UiBack",
				MaxTextSize = 26,
			}, header)
			close.Activated:Connect(function()
				Screens.close()
			end)
		end
		local b = Hud.frame({
			Name = "Body",
			Position = UDim2.fromOffset(12, 54),
			Size = UDim2.new(1, -24, 1, -64),
		}, panel)
		body = b
		local scale = Hud.make("UIScale", {}, panel)
		if not Settings.reduceMotion() then
			scale.Scale = 0.92
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end

	buildBody(def)
	pcall(function()
		GuiService.TouchControlsEnabled = false
	end)
	-- Menus block gameplay input; Back closes, CamPrev/CamNext switch the spectate view.
	Actions.setBlocker(function(action)
		return action ~= "Back" and action ~= "CamPrev" and action ~= "CamNext"
	end)
	Audio.play("UiTap")
	Screens.select(nil)
	Screens.Changed:Fire(name)
	return true
end

-- Rebuilds the open screen (after new data arrived). With a name: only if that screen is open.
function Screens.refresh(name: string?)
	if not currentName or (name and name ~= currentName) then
		return
	end
	local def = defs[currentName]
	if not def then
		return
	end
	local selectedName = GuiService.SelectedObject and GuiService.SelectedObject.Name
	runCleanup()
	buildBody(def)
	if selectedName and body then
		local again = body:FindFirstChild(selectedName, true)
		if again and again:IsA("GuiObject") then
			Screens.select(again)
		end
	end
end

local started = false
function Screens.init()
	if started then
		return
	end
	started = true
	Actions.on("Back", function(phase)
		if phase == "Begin" and currentName then
			local def = defs[currentName]
			if def and def.closable ~= false then
				Audio.play("UiBack")
				Screens.close()
			end
		end
	end)
end

return Screens
