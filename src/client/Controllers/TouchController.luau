--!strict
-- The touch cluster (beta-spec-ux §2.2): max 3 action buttons + 1 context button, in an arc above and to
-- the left of Roblox's jump button. Buttons never move; they change icon, label and colour by mode:
--   CONTEXT 72 · GADGET (primary) 64 · CROUCH 56 · PING 52
-- Only visible when touch is the preferred input and no menu is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local CharState = require(Lib.CharState)
local ClientState = require(Lib.ClientState)
local Device = require(Lib.Device)
local Hud = require(Lib.Hud)
local RoundState = require(Lib.RoundState)
local Screens = require(Lib.Screens)
local Theme = require(Lib.Theme)
local UiScale = require(Lib.UiScale)
local UiText = require(Lib.UiText)

local ContextController = require(script.Parent.ContextController)
local PingController = require(script.Parent.PingController)

local TouchController = {}

local player = Players.LocalPlayer
local C = Theme.Colors

-- Other controllers (onboarding) may hide slots: TouchController.gate(slotName) → false hides it.
TouchController.gate = nil :: ((slot: string) -> boolean)?
TouchController.Changed = Signal.new() :: Signal.Signal<>

type Slot = {
	name: string,
	holder: Frame,
	button: TextButton,
	glyph: TextLabel,
	label: TextLabel,
	sub: TextLabel,
	badge: TextLabel,
	ring: Hud.Ring,
	size: number,
}

local gui: ScreenGui
local container: Frame
local slots: { [string]: Slot } = {}
local swapBadge: TextButton
local built = false

local function touchScale(): number
	return math.clamp(Device.viewport().Y / 420, 1, 1.4)
end

local function makeSlot(name: string, size: number, color: Color3): Slot
	local holder = Hud.frame({
		Name = name,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(size + 10, size + 10),
	}, container)
	local ring = Hud.progressRing(holder, size + 10, C.Good, 1)
	local button = Hud.make("TextButton", {
		Name = "Button",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 2,
		Selectable = false,
	}, holder)
	Hud.corner(button, 999)
	Hud.make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.new(1, 1, 1),
		Transparency = 0.55,
		Thickness = 2,
	}, button)
	local glyph = Hud.text({
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.6, 0.42),
		Text = "",
		Display = true,
		MaxTextSize = 40,
		Stroke = 1.5,
		ZIndex = 3,
	}, button)
	local label = Hud.text({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.74),
		Size = UDim2.fromScale(0.9, 0.26),
		Text = name,
		Heavy = true,
		MaxTextSize = 15,
		MinTextSize = 9,
		Stroke = 1,
		ZIndex = 3,
	}, button)
	local sub = Hud.text({
		Name = "Sub",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(150, 18),
		Text = "",
		TextColor3 = C.Warn,
		Heavy = true,
		MaxTextSize = 14,
		Stroke = 1.5,
		ZIndex = 3,
		Visible = false,
	}, holder)
	local badge = Hud.make("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 2, 0, -2),
		Size = UDim2.fromOffset(28, 20),
		BackgroundColor3 = C.Panel,
		FontFace = Theme.Fonts.UiHeavy,
		TextSize = 13,
		TextColor3 = C.Text,
		Text = "",
		Visible = false,
		ZIndex = 4,
	}, holder)
	Hud.corner(badge, 999)
	return {
		name = name,
		holder = holder,
		button = button,
		glyph = glyph,
		label = label,
		sub = sub,
		badge = badge,
		ring = ring,
		size = size,
	}
end

local function findJump(): GuiObject?
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump:IsA("GuiObject") and jump.AbsoluteSize.X > 0 then
		-- Share the coordinate space with Roblox's touch GUI.
		if touchGui and touchGui:IsA("ScreenGui") then
			gui.IgnoreGuiInset = touchGui.IgnoreGuiInset
			gui.ScreenInsets = touchGui.ScreenInsets
		end
		return jump
	end
	return nil
end

local function layout()
	if not built then
		return
	end
	local scale = touchScale()
	local jr, jb, js = 25 * scale, 20 * scale, 70 * scale
	local jump = findJump()
	if jump then
		local pos, size = container.AbsolutePosition, container.AbsoluteSize
		jr = pos.X + size.X - (jump.AbsolutePosition.X + jump.AbsoluteSize.X)
		jb = pos.Y + size.Y - (jump.AbsolutePosition.Y + jump.AbsoluteSize.Y)
		js = jump.AbsoluteSize.X
	end
	local k = math.clamp(js / 70, 1, 1.4)
	local function place(slot: Slot, right: number, bottom: number)
		local s = slot.size * k
		slot.holder.Size = UDim2.fromOffset(s + 10, s + 10)
		slot.button.Size = UDim2.fromOffset(s, s)
		slot.ring.frame.Size = UDim2.fromOffset(s + 10, s + 10)
		slot.holder.Position = UDim2.new(1, -(right - 5), 1, -(bottom - 5))
	end
	local T = Theme.Size.Touch
	local contextRight = jr + js + 15 * k
	place(slots.Context, contextRight, jb + 2 * k)
	place(slots.Gadget, jr + 3 * k, jb + js + 18 * k)
	place(slots.Crouch, contextRight + T.Context.size * k + 14 * k, jb + 2 * k)
	place(slots.Ping, contextRight, jb + 2 * k + T.Context.size * k + 18 * k)
end

local function gadgetList(): { string }
	local list = {}
	local raw = player:GetAttribute("Gadgets")
	if typeof(raw) == "string" then
		for name in string.gmatch(raw, "[^,]+") do
			table.insert(list, name)
		end
	end
	return list
end

local function allowed(slot: string): boolean
	local gate = TouchController.gate
	if gate then
		local ok, result = pcall(gate, slot)
		if ok and result == false then
			return false
		end
	end
	return true
end

local function setSlot(
	slot: Slot,
	visible: boolean,
	glyph: string?,
	label: string?,
	color: Color3?,
	dim: boolean?
)
	slot.holder.Visible = visible
	if not visible then
		return
	end
	slot.glyph.Text = glyph or ""
	slot.glyph.Visible = glyph ~= nil and glyph ~= ""
	slot.label.Text = label or ""
	slot.label.Position = if slot.glyph.Visible then UDim2.fromScale(0.5, 0.74) else UDim2.fromScale(0.5, 0.5)
	slot.label.Size = if slot.glyph.Visible then UDim2.fromScale(0.9, 0.26) else UDim2.fromScale(0.9, 0.4)
	slot.button.BackgroundColor3 = color or C.Panel
	slot.button.BackgroundTransparency = if dim then 0.55 else 0.15
	slot.label.TextTransparency = if dim then 0.45 else 0
	slot.glyph.TextTransparency = if dim then 0.45 else 0
end

local function refresh()
	if not built then
		return
	end
	local touch = Device.input() == "Touch"
	local show = touch and not Screens.isOpen() and ClientState.spectating == nil
	container.Visible = show
	Hud.setCrosshair(
		(touch or Device.input() == "Gamepad" or ClientState.drone ~= nil or ClientState.throwAiming)
			and RoundState.statusMode() == "Heist"
			and ClientState.mode ~= "Cell"
	)
	if not show then
		return
	end
	local mode = ClientState.mode
	local heist = RoundState.statusMode() == "Heist"

	-- CONTEXT
	local state = ContextController.state()
	if state then
		setSlot(slots.Context, true, state.glyph, state.label, state.color, state.lockedFor ~= nil)
		slots.Context.sub.Text = state.sub or ""
		slots.Context.sub.TextColor3 = state.subColor or C.Warn
		slots.Context.sub.Visible = state.sub ~= nil
	else
		setSlot(slots.Context, false)
	end

	-- GADGET (primary)
	local carry, role = CharState.carry()
	local gadgetVisible = heist and allowed("Gadget")
	if mode == "Drone" then
		setSlot(slots.Gadget, true, "▲", "UP", C.Info)
	elseif
		not gadgetVisible
		or mode == "Hidden"
		or mode == "Cell"
		or mode == "Carried"
		or mode == "Van"
		or (carry ~= nil and role == "Help")
	then
		setSlot(slots.Gadget, false)
	elseif carry == "Medium" and role == "Lead" then
		local style = Theme.Loot.Medium
		setSlot(
			slots.Gadget,
			true,
			"↷",
			if ClientState.throwAiming then "THROW!" else "THROW",
			if ClientState.throwAiming then C.Accent else style.color
		)
	elseif carry == "Heavy" and role == "Lead" then
		local rolling = CharState.get("Rolling") == true
		setSlot(
			slots.Gadget,
			true,
			Theme.Loot.Heavy.glyph,
			if rolling then "STOP" else "ROLL",
			Theme.Loot.Heavy.color
		)
	else
		local list = gadgetList()
		local selected = list[math.clamp(ClientState.selectedSlot, 1, math.max(1, #list))]
		if selected then
			local entry = UiText.gadget(selected)
			local short = UiText.GadgetShort[selected] or string.upper(entry.name)
			setSlot(
				slots.Gadget,
				true,
				entry.glyph,
				if ClientState.aiming then "USE!" else short,
				if ClientState.aiming then C.Accent else C.PanelLight
			)
			local charges = player:GetAttribute("Charges_" .. selected)
			slots.Gadget.badge.Visible = typeof(charges) == "number" and charges >= 0
			slots.Gadget.badge.Text = if typeof(charges) == "number" then `×{charges}` else ""
		else
			setSlot(slots.Gadget, false)
		end
	end
	if not slots.Gadget.holder.Visible or carry or mode == "Drone" then
		slots.Gadget.badge.Visible = false
	end

	-- Swap badge: the other picked gadget (not the Crowbar).
	local others = {}
	for index, name in gadgetList() do
		if name ~= "Crowbar" and index ~= ClientState.selectedSlot then
			table.insert(others, { index = index, name = name })
		end
	end
	local canSwap = slots.Gadget.holder.Visible and not carry and mode ~= "Drone" and #others > 0
	swapBadge.Visible = canSwap
	if canSwap then
		swapBadge.Text = UiText.gadget(others[1].name).glyph or "⇄"
		swapBadge:SetAttribute("SlotIndex", others[1].index)
	end

	-- CROUCH
	if mode == "Drone" then
		setSlot(slots.Crouch, true, "▼", "DOWN", C.Info)
	elseif not heist or not allowed("Crouch") or mode == "Hidden" or mode == "Cell" or mode == "Carried" then
		setSlot(slots.Crouch, false)
	elseif carry then
		setSlot(slots.Crouch, true, "⊘", "CROUCH", C.Dim, true)
	else
		local crouching = CharState.get("Crouching") == true
		setSlot(slots.Crouch, true, "▾", "CROUCH", if crouching then C.Gold else C.PanelLight)
	end

	-- PING
	if not heist or not allowed("Ping") then
		setSlot(slots.Ping, false)
	else
		setSlot(
			slots.Ping,
			true,
			"◉",
			if mode == "Drone" or mode == "Cell" then "SPOT" else "PING",
			C.PanelLight
		)
	end
	TouchController.Changed:Fire()
end

local function bindHold(button: GuiButton, onDown: () -> (), onUp: (inside: boolean) -> ())
	local active: InputObject? = nil
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			if active then
				return
			end
			active = input
			onDown()
		end
	end)
	local function finish(input: InputObject)
		active = nil
		local p = input.Position
		local a, s = button.AbsolutePosition, button.AbsoluteSize
		local inside = p.X >= a.X - 8 and p.X <= a.X + s.X + 8 and p.Y >= a.Y - 8 and p.Y <= a.Y + s.Y + 8
		onUp(inside)
	end
	button.InputEnded:Connect(function(input)
		if input == active or (active and input.UserInputType == Enum.UserInputType.MouseButton1) then
			finish(input)
		end
	end)
	-- A finger released outside the button still ends the hold.
	UserInputService.TouchEnded:Connect(function(touch)
		if touch == active then
			finish(touch)
		end
	end)
end

local function tap(action: string)
	Actions.fire(action, "Begin")
	task.defer(function()
		Actions.fire(action, "End")
	end)
end

local function build()
	built = true
	gui = UiScale.plainRoot("CC_Touch", 15)
	container = Hud.frame({ Name = "TouchButtons", Size = UDim2.fromScale(1, 1) }, gui)
	local T = Theme.Size.Touch
	slots.Context = makeSlot("Context", T.Context.size, C.Accent)
	slots.Gadget = makeSlot("Gadget", T.Gadget.size, C.PanelLight)
	slots.Crouch = makeSlot("Crouch", T.Crouch.size, C.PanelLight)
	slots.Ping = makeSlot("Ping", T.Ping.size, C.PanelLight)

	-- CONTEXT: press = prompt hold begin / fallback action; release = hold end.
	bindHold(slots.Context.button, function()
		ContextController.press(true)
	end, function()
		ContextController.press(false)
	end)

	-- GADGET: tap = aim, tap again = throw/use, drag off = cancel. Drone: hold = up.
	bindHold(slots.Gadget.button, function()
		if ClientState.drone then
			Actions.setHeld("DroneUp", true)
		end
	end, function(inside)
		if ClientState.drone then
			Actions.setHeld("DroneUp", false)
			return
		end
		if not inside then
			tap("Cancel")
			return
		end
		if ClientState.aiming and not CharState.carry() then
			tap("Primary") -- GadgetController throws while aiming
		else
			tap("TouchGadget")
		end
	end)

	swapBadge = Hud.make("TextButton", {
		Name = "Swap",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.08, 0.08),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		FontFace = Theme.Fonts.Display,
		TextSize = 16,
		TextColor3 = C.Text,
		Text = "⇄",
		ZIndex = 5,
		Visible = false,
	}, slots.Gadget.holder)
	Hud.corner(swapBadge, 999)
	Hud.make("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.4, Thickness = 1.5 }, swapBadge)
	-- 48 px hit area around the small badge.
	local hit = Hud.make("TextButton", {
		Name = "Hit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(48, 48),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 6,
	}, swapBadge)
	hit.Activated:Connect(function()
		local index = swapBadge:GetAttribute("SlotIndex")
		if typeof(index) == "number" then
			tap("Slot" .. index)
		end
	end)

	-- CROUCH: tap. Drone: hold = down.
	bindHold(slots.Crouch.button, function()
		if ClientState.drone then
			Actions.setHeld("DroneDown", true)
		end
	end, function(inside)
		if ClientState.drone then
			Actions.setHeld("DroneDown", false)
		elseif inside and not CharState.carry() then
			tap("Crouch")
		end
	end)

	-- PING: tap = SPOT, hold = quick wheel (PingController).
	PingController.attachButton(slots.Ping.button)

	layout()
	refresh()
end

function TouchController.slot(name: string): GuiObject?
	local slot = slots[name]
	return if slot then slot.button else nil
end

function TouchController:Start()
	local function apply()
		if Device.input() == "Touch" and not built then
			build()
		end
		layout()
		refresh()
	end
	apply()
	Device.Changed:Connect(apply)
	ContextController.Changed:Connect(refresh)
	Screens.Changed:Connect(refresh)
	ClientState.Changed:Connect(function(key)
		if
			key == "aiming"
			or key == "drone"
			or key == "selectedSlot"
			or key == "mode"
			or key == "throwAiming"
			or key == "spectating"
		then
			refresh()
		end
	end)
	CharState.Changed:Connect(refresh)
	RoundState.Changed:Connect(function(name)
		if name == "RoundPhase" then
			refresh()
		end
	end)
	Hud.LoadoutChanged:Connect(refresh)

	-- Rings: hold progress on CONTEXT, grate timer, quick-wheel cooldown on PING.
	RunService.RenderStepped:Connect(function()
		if not built or not container.Visible then
			return
		end
		local state = ContextController.state()
		local progress = ContextController.progress()
		local context = slots.Context
		if state and state.lockedFor and state.lockedTotal then
			context.ring.setColor(C.Muted)
			context.ring.set(1 - state.lockedFor / state.lockedTotal)
		elseif progress then
			context.ring.setColor(C.Good)
			context.ring.set(progress)
		else
			context.ring.set(0)
		end
		local cooldown = PingController.cooldownAlpha()
		slots.Ping.ring.setColor(C.Muted)
		slots.Ping.ring.set(cooldown)
	end)
	-- The jump button appears a moment after spawn: lay out again a few times.
	for _ = 1, 10 do
		task.wait(1)
		layout()
	end
end

return TouchController
