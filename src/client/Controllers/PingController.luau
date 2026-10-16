--!strict
-- Pings (beta-spec-ux §2.1): SPOT (tap PING / Q / R1) marks what you point at; holding opens the quick wheel
-- with 6 fixed words (no free chat). Shortcuts: Z = GO, X = WAIT, D-pad ↑ GO ↓ WAIT ← HELP → TO THE VAN.
-- The wheel has one shared 10 s cooldown (advisor). Each ping kind has its own shape, colour and sound;
-- pings from muted players (Settings) are not shown.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local Audio = require(Lib.Audio)
local ClientState = require(Lib.ClientState)
local Device = require(Lib.Device)
local EdgeArrows = require(Lib.EdgeArrows)
local Hud = require(Lib.Hud)
local Settings = require(Lib.Settings)
local Theme = require(Lib.Theme)
local UiScale = require(Lib.UiScale)

local GadgetController = require(script.Parent.GadgetController)

local PingController = {}

local player = Players.LocalPlayer
local C = Theme.Colors

local KIND_STYLE: { [string]: { glyph: string, label: string } } = {
	guard = { glyph = "◆", label = "GUARD" },
	camera = { glyph = "■", label = "CAMERA" },
	lock = { glyph = "▲", label = "OPEN HERE" },
	loot = { glyph = "★", label = "LOOT" },
	drone = { glyph = "●", label = "DRONE" },
	go = { glyph = "▼", label = "GO HERE" },
}

local activeByTarget: { [Instance]: BillboardGui } = {}
local quickReadyAt = 0
local nextPingKey = 0

-- ── Presets ──────────────────────────────────────────────────────────────────────────────────────

local function presets(): { Theme.Preset }
	local fromConfig = Config.Ping and (Config.Ping :: any).QuickPresets
	if typeof(fromConfig) == "table" and #fromConfig >= 6 then
		local list = {}
		for _, key in fromConfig do
			if typeof(key) == "string" then
				table.insert(list, Theme.preset(key))
			end
		end
		return list
	end
	return Theme.QuickPresets
end

local function presetByLabel(label: string): string
	for _, preset in presets() do
		if preset.label == label or preset.key == label then
			return preset.key
		end
	end
	return label
end

function PingController.cooldownLeft(): number
	return math.max(0, quickReadyAt - os.clock())
end

-- 0 = ready, 1 = just used (for the ring on the PING button).
function PingController.cooldownAlpha(): number
	local left = PingController.cooldownLeft()
	return if left <= 0 then 0 else left / Theme.UX.QuickCooldown
end

local function sendQuick(key: string)
	if PingController.cooldownLeft() > 0 then
		Audio.play("UiBack")
		Hud.toast(`Wait {math.ceil(PingController.cooldownLeft())} s`, C.Muted)
		return
	end
	quickReadyAt = os.clock() + Theme.UX.QuickCooldown
	Net.request("Quick", key)
end

-- ── SPOT ─────────────────────────────────────────────────────────────────────────────────────────

local function spot()
	if ClientState.drone then
		return -- DroneController spots from the drone
	end
	if ClientState.mode == "Cell" then
		-- From the security camera feed: the centre of the view, with the camera index.
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local size = camera.ViewportSize
		local ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 200)
		if hit then
			Net.request("Spot", hit.Instance, hit.Position, ClientState.camIndex)
		end
		return
	end
	local hit = GadgetController.pointerHit(300)
	if hit then
		Net.request("Spot", hit.Instance, hit.Position)
	end
end

-- Spot from the cell feed: a viewport point, or an input position (fromInput = true, GUI-inset space).
function PingController.spotAtScreen(position: Vector2, fromInput: boolean?)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local ray = if fromInput
		then camera:ScreenPointToRay(position.X, position.Y)
		else camera:ViewportPointToRay(position.X, position.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200)
	if hit then
		Net.request("Spot", hit.Instance, hit.Position, ClientState.camIndex)
	end
end

-- ── Wheel ────────────────────────────────────────────────────────────────────────────────────────

type Wheel = { frame: Frame, slices: { { key: string, label: TextLabel, angle: number } }, center: Vector2 }

local wheel: Wheel? = nil
local wheelSelection: string? = nil

local function openWheel(centerPx: Vector2)
	if wheel then
		return
	end
	local layer = UiScale.root("Overlay")
	local scale = UiScale.get()
	local inset = GuiService:GetGuiInset()
	local center = (centerPx - inset) / scale
	local frame = Hud.frame({
		Name = "QuickWheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(250, 250),
	}, layer)
	local hub = Hud.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(64, 64),
		Radius = 999,
	}, frame)
	local cooling = PingController.cooldownLeft() > 0
	Hud.text({
		Size = UDim2.fromScale(1, 1),
		Text = if cooling then `{math.ceil(PingController.cooldownLeft())}s` else "SAY",
		TextColor3 = if cooling then C.Muted else C.Text,
		Display = true,
		MaxTextSize = 18,
	}, hub)
	local slices = {}
	local list = presets()
	for index, preset in list do
		local angle = (index - 1) * (360 / #list) -- 0 = up, clockwise
		local rad = math.rad(angle)
		local offset = Vector2.new(math.sin(rad), -math.cos(rad)) * 92
		local label = Hud.chip(frame, `{preset.glyph} {preset.label}`, if cooling then C.Muted else C.Text, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
			Size = UDim2.fromOffset(0, 34),
			TextSize = 16,
		})
		table.insert(slices, { key = preset.key, label = label, angle = angle })
	end
	wheel = { frame = frame, slices = slices, center = centerPx }
	wheelSelection = nil
	Audio.play("UiTap", { pitch = 0.9 })
end

local function updateWheel(direction: Vector2)
	local w = wheel
	if not w then
		return
	end
	local picked: string? = nil
	if direction.Magnitude > 22 then
		local angle = (math.deg(math.atan2(direction.X, -direction.Y)) + 360) % 360
		local best = math.huge
		for _, slice in w.slices do
			local diff = math.abs(((angle - slice.angle + 540) % 360) - 180)
			if diff < best then
				best = diff
				picked = slice.key
			end
		end
	end
	if picked ~= wheelSelection then
		wheelSelection = picked
		for _, slice in w.slices do
			local on = slice.key == picked
			slice.label.BackgroundColor3 = if on then C.Accent else C.Panel
			slice.label.TextColor3 = if on then C.Panel else C.Text
		end
		if picked then
			Audio.play("UiTap", { pitch = 1.2 })
		end
	end
end

local function closeWheel(send: boolean)
	local w = wheel
	if not w then
		return
	end
	wheel = nil
	w.frame:Destroy()
	if send and wheelSelection then
		sendQuick(wheelSelection)
	end
	wheelSelection = nil
end

-- PING button on touch: tap = SPOT, hold 0.3 s = wheel (slide, release).
function PingController.attachButton(button: GuiButton)
	local downAt: number? = nil
	local startPos: Vector2? = nil
	local active: InputObject? = nil
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			return
		end
		active = input
		downAt = os.clock()
		startPos = Vector2.new(input.Position.X, input.Position.Y)
		local token = downAt
		task.delay(Theme.UX.PingHoldSeconds, function()
			if downAt == token and active and not ClientState.drone then
				local a = button.AbsolutePosition + button.AbsoluteSize / 2 + GuiService:GetGuiInset()
				openWheel(Vector2.new(a.X - 110, a.Y - 120))
			end
		end)
	end)
	UserInputService.InputChanged:Connect(function(input)
		if active and input == (active :: any) and wheel and startPos then
			updateWheel(Vector2.new(input.Position.X, input.Position.Y) - startPos)
		end
	end)
	local function finish()
		if not active then
			return
		end
		active = nil
		downAt = nil
		if wheel then
			closeWheel(true)
		elseif ClientState.drone then
			Actions.fire("Spot", "Begin")
		else
			spot()
			Audio.play("PingSpot")
		end
	end
	button.InputEnded:Connect(function(input)
		if input == active or input.UserInputType == Enum.UserInputType.MouseButton1 then
			finish()
		end
	end)
	-- Moves and releases outside the button still steer and close the wheel.
	UserInputService.TouchMoved:Connect(function(touch)
		if active and wheel and startPos and touch == (active :: any) then
			updateWheel(Vector2.new(touch.Position.X, touch.Position.Y) - startPos)
		end
	end)
	UserInputService.TouchEnded:Connect(function(touch)
		if touch == active then
			finish()
		end
	end)
end

-- ── Showing pings ────────────────────────────────────────────────────────────────────────────────

local function adorneeFor(target: Instance?): BasePart?
	if not target then
		return nil
	end
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		local head = target:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head
		end
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function senderMuted(data: { [string]: any }): boolean
	local from = data.fromUserId or data.userId
	return typeof(from) == "number" and Settings.isMuted(from)
end

local function showPing(data: any)
	if typeof(data) ~= "table" or senderMuted(data) then
		return
	end
	local style = KIND_STYLE[data.kind] or KIND_STYLE.go
	local color: Color3 = if typeof(data.color) == "Color3" then data.color else C.Accent
	local adornee = adorneeFor(data.target)
	local anchor: Part? = nil
	if not adornee and typeof(data.position) == "Vector3" then
		local newAnchor = Instance.new("Part")
		newAnchor.Anchored = true
		newAnchor.CanCollide = false
		newAnchor.CanQuery = false
		newAnchor.CanTouch = false
		newAnchor.Transparency = 1
		newAnchor.Size = Vector3.one * 0.2
		newAnchor.Position = data.position
		newAnchor.Parent = workspace.CurrentCamera
		anchor = newAnchor
		adornee = newAnchor
	end
	if not adornee then
		return
	end
	if data.target and activeByTarget[data.target] then
		activeByTarget[data.target]:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Ping"
	gui.Size = UDim2.fromOffset(130, 56)
	gui.StudsOffset = Vector3.new(0, if data.kind == "guard" then 3.6 else 2.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = adornee
	Hud.text({
		Size = UDim2.new(1, 0, 0, 32),
		Text = style.glyph,
		TextColor3 = color,
		Display = true,
		MaxTextSize = 30,
		Stroke = 2,
	}, gui)
	Hud.text({
		Position = UDim2.fromOffset(0, 33),
		Size = UDim2.new(1, 0, 0, 20),
		Text = if data.auto then style.label else `{style.label} · {data.from or ""}`,
		MaxTextSize = 16,
		Stroke = 1.5,
	}, gui)
	gui.Parent = player:WaitForChild("PlayerGui")
	if data.target then
		activeByTarget[data.target] = gui
	end
	nextPingKey += 1
	local arrowKey = "Ping_" .. nextPingKey
	if not data.auto then
		Audio.play(if data.kind == "guard" then "PingGuard" else "PingSpot")
		local target = adornee
		EdgeArrows.set(arrowKey, {
			target = function()
				return if target and target.Parent then target.Position else nil
			end,
			glyph = style.glyph,
			color = color,
			onScreen = false,
		})
	end
	local duration = if typeof(data.duration) == "number" then data.duration else 8
	task.delay(duration, function()
		EdgeArrows.clear(arrowKey)
		if gui.Parent then
			gui:Destroy()
		end
		if data.target and activeByTarget[data.target] == gui then
			activeByTarget[data.target] = nil
		end
		if anchor then
			anchor:Destroy()
		end
	end)
end

local function showQuick(fromName: any, preset: any, color: any, userId: any)
	if typeof(userId) == "number" and Settings.isMuted(userId) then
		return
	end
	local style = Theme.preset(if typeof(preset) == "string" then preset else "?")
	local c: Color3 = if typeof(color) == "Color3" then color else C.Accent
	Hud.toast(`{fromName}: {style.label}`, c, style.glyph)
	Audio.play("PingQuick", { pitch = style.pitch })
	local sender = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	local head = sender and sender.Character and sender.Character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(170, 40)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.AlwaysOnTop = true
		gui.Adornee = head
		local chip = Hud.chip(gui, `{style.glyph} {style.label}`, C.Panel, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, 34),
			TextSize = 18,
			BackgroundColor3 = c,
			BackgroundTransparency = 0,
		})
		local _ = chip
		gui.Parent = player:WaitForChild("PlayerGui")
		task.delay(2.5, function()
			gui:Destroy()
		end)
	end
end

function PingController:Start()
	Net.on("Ping", showPing)
	Net.on("Quick", showQuick)

	-- Q / R1: tap = SPOT, hold = wheel (mouse or right stick steers).
	local spotDownAt: number? = nil
	Actions.on("Spot", function(phase)
		if ClientState.drone then
			return
		end
		if phase == "Begin" then
			spotDownAt = os.clock()
			local token = spotDownAt
			task.delay(Theme.UX.PingHoldSeconds, function()
				if spotDownAt == token and Actions.isHeld("Spot") then
					local camera = workspace.CurrentCamera
					local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
					openWheel(
						if Device.input() == "KeyboardAndMouse"
							then UserInputService:GetMouseLocation()
							else size / 2
					)
				end
			end)
		else
			spotDownAt = nil
			if wheel then
				closeWheel(true)
			else
				spot()
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		local w = wheel
		if not w then
			return
		end
		if Device.input() == "Gamepad" then
			for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
				if state.KeyCode == Enum.KeyCode.Thumbstick2 then
					updateWheel(Vector2.new(state.Position.X, -state.Position.Y) * 100)
				end
			end
		elseif Device.input() == "KeyboardAndMouse" then
			updateWheel(UserInputService:GetMouseLocation() - w.center)
		end
	end)

	local function shortcut(action: string, label: string)
		Actions.on(action, function(phase)
			if phase ~= "Begin" or GuiService.SelectedObject ~= nil then
				return
			end
			sendQuick(presetByLabel(label))
		end)
	end
	shortcut("QuickGo", "GO")
	shortcut("QuickWait", "WAIT")
	shortcut("QuickHelp", "HELP")
	shortcut("QuickVan", "TO THE VAN")
end

return PingController
