--!strict
-- The UI kit (ux): building blocks for every screen, plus the fixed HUD "slots" other controllers fill.
-- Everything is built in code. Design rules (beta-spec-ux): buttons ≥ 48 px (main 64), contrast ≥ 4.5:1,
-- colour + shape, text min 12 px (18 px for anything read during action), English player text.
--
-- Layout slots (Hud.slot(name)):
--   Status       top-centre column: status bar, effect chips, hint pill, drive panel
--   Right        top-right column: gear/invite row, crew list, objectives
--   Bottom       bottom-centre: carry chip + pockets
--   Strip        bottom-right (keyboard/gamepad only): gadget and primary-action key caps
--   Banner       30% height (Overlay layer)
--   Toasts       62% height (Overlay layer)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Lib = script.Parent
local Audio = require(Lib.Audio)
local Settings = require(Lib.Settings)
local Theme = require(Lib.Theme)
local UiScale = require(Lib.UiScale)

local Hud = {}

export type Props = { [string]: any }

-- Colours: Theme plus the names older controllers (GadgetController, DroneController) still use.
Hud.Colors = {
	Panel = Theme.Colors.Panel,
	Text = Theme.Colors.Text,
	Muted = Theme.Colors.Muted,
	Accent = Theme.Colors.Accent,
	Danger = Theme.Colors.Danger,
	Warn = Theme.Colors.Warn,
	Good = Theme.Colors.Good,
	Gold = Theme.Colors.Gold,
	Info = Theme.Colors.Info,
	Eyes = Theme.Colors.Info,
	Clear = Theme.Colors.Warn,
	Open = Color3.fromRGB(255, 90, 80),
}

Hud.LoadoutChanged = Signal.new() :: Signal.Signal<>

local SPECIAL = {
	MaxTextSize = true,
	MinTextSize = true,
	Display = true,
	Kind = true,
	Sound = true,
	Stroke = true,
	Radius = true,
	StrokeColor = true,
	Heavy = true,
}

local slots: { [string]: Frame } = {}
local hudGui: ScreenGui
local crosshair: Frame
local bannerLabel: TextLabel
local bannerSub: TextLabel
local bannerFrame: Frame
local bannerToken = 0

function Hud.make(className: string, props: Props?, parent: Instance?): any
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			if not SPECIAL[key] then
				(inst :: any)[key] = value
			end
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Hud.corner(parent: Instance, radius: number?): UICorner
	return Hud.make("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Size.Radius) }, parent)
end

function Hud.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Hud.make("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = if parent:IsA("TextLabel") or parent:IsA("TextButton")
			then Enum.ApplyStrokeMode.Contextual
			else Enum.ApplyStrokeMode.Border,
	}, parent)
end

function Hud.padding(parent: Instance, x: number, y: number?): UIPadding
	return Hud.make("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y or x),
		PaddingBottom = UDim.new(0, y or x),
	}, parent)
end

function Hud.list(
	parent: Instance,
	direction: Enum.FillDirection?,
	padding: number?,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
): UIListLayout
	return Hud.make("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
	}, parent)
end

function Hud.frame(props: Props, parent: Instance?): Frame
	local frame = Hud.make("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0 }, nil)
	for key, value in props do
		if not SPECIAL[key] then
			(frame :: any)[key] = value
		end
	end
	frame.Parent = parent
	return frame
end

-- Dark rounded panel (25% transparent by default).
function Hud.panel(props: Props, parent: Instance?): Frame
	local frame = Hud.make("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		BorderSizePixel = 0,
	}, nil)
	for key, value in props do
		if not SPECIAL[key] then
			(frame :: any)[key] = value
		end
	end
	Hud.corner(frame, props.Radius)
	frame.Parent = parent
	return frame
end

-- Text label. Special props: Display (FredokaOne), Heavy, MaxTextSize, MinTextSize, Stroke (dark outline).
function Hud.text(props: Props, parent: Instance?): TextLabel
	local label = Hud.make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = if props.Display
			then Theme.Fonts.Display
			elseif props.Heavy then Theme.Fonts.UiHeavy
			else Theme.Fonts.Ui,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		TextWrapped = true,
		BorderSizePixel = 0,
	}, nil)
	for key, value in props do
		if not SPECIAL[key] then
			(label :: any)[key] = value
		end
	end
	if label.TextScaled then
		Hud.make("UITextSizeConstraint", {
			MaxTextSize = props.MaxTextSize or 28,
			MinTextSize = props.MinTextSize or Theme.Size.MinText,
		}, label)
	end
	if props.Stroke then
		Hud.stroke(label, Theme.Colors.Stroke, if typeof(props.Stroke) == "number" then props.Stroke else 1.5)
	end
	label.Parent = parent
	return label
end

local KIND_COLORS: { [string]: { bg: Color3, text: Color3, transparency: number } } = {
	primary = { bg = Theme.Colors.Accent, text = Theme.Colors.Panel, transparency = 0 },
	gold = { bg = Theme.Colors.Gold, text = Theme.Colors.Panel, transparency = 0 },
	good = { bg = Theme.Colors.Good, text = Theme.Colors.Panel, transparency = 0 },
	danger = { bg = Theme.Colors.Danger, text = Theme.Colors.Panel, transparency = 0 },
	secondary = { bg = Theme.Colors.PanelLight, text = Theme.Colors.Text, transparency = 0.05 },
	ghost = { bg = Theme.Colors.Panel, text = Theme.Colors.Text, transparency = 0.35 },
	disabled = { bg = Theme.Colors.Dim, text = Theme.Colors.Muted, transparency = 0.2 },
}

function Hud.styleButton(button: GuiButton, kind: string)
	local style = KIND_COLORS[kind] or KIND_COLORS.secondary
	button.BackgroundColor3 = style.bg
	button.BackgroundTransparency = style.transparency
	if button:IsA("TextButton") then
		button.TextColor3 = style.text
	end
	button:SetAttribute("Kind", kind)
end

-- Button: ≥ 48 px, rounded, press feedback, tap sound, gamepad-selectable.
-- Special props: Kind ("primary" | "secondary" | "gold" | "good" | "danger" | "ghost" | "disabled"),
-- Sound (key or false), MaxTextSize, Radius.
function Hud.button(props: Props, parent: Instance?): TextButton
	local button = Hud.make("TextButton", {
		AutoButtonColor = false,
		BorderSizePixel = 0,
		FontFace = Theme.Fonts.UiHeavy,
		TextScaled = true,
		Selectable = true,
		Size = UDim2.fromOffset(120, Theme.Size.MinButton),
		Text = "",
	}, nil)
	for key, value in props do
		if not SPECIAL[key] then
			(button :: any)[key] = value
		end
	end
	Hud.styleButton(button, props.Kind or "secondary")
	if props.BackgroundColor3 then
		button.BackgroundColor3 = props.BackgroundColor3
	end
	if props.TextColor3 then
		button.TextColor3 = props.TextColor3
	end
	Hud.corner(button, props.Radius or 12)
	Hud.make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = props.StrokeColor or Color3.new(1, 1, 1),
		Transparency = 0.75,
		Thickness = 2,
	}, button)
	Hud.make("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 22, MinTextSize = 12 }, button)
	Hud.make(
		"UISizeConstraint",
		{ MinSize = Vector2.new(Theme.Size.MinButton, Theme.Size.MinButton) },
		button
	)
	Hud.padding(button, 8, 4)
	local press = Hud.make("UIScale", { Name = "Press" }, button)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(press, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	local function release()
		TweenService:Create(press, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	local soundKey = if props.Sound == nil then "UiTap" else props.Sound
	if soundKey then
		button.Activated:Connect(function()
			Audio.play(soundKey)
		end)
	end
	button.Parent = parent
	return button
end

-- Small pill with auto width (fixed text size, scales with UIScale).
function Hud.chip(parent: Instance?, text: string, color: Color3?, props: Props?): TextLabel
	local chip = Hud.make("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		FontFace = Theme.Fonts.UiHeavy,
		Text = text,
		TextSize = 15,
		TextColor3 = color or Theme.Colors.Text,
	}, nil)
	if props then
		for key, value in props do
			if not SPECIAL[key] then
				(chip :: any)[key] = value
			end
		end
	end
	Hud.corner(chip, 999)
	Hud.padding(chip, 10, 2)
	Hud.make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or Theme.Colors.Muted,
		Transparency = 0.4,
		Thickness = 1.5,
	}, chip)
	chip.Parent = parent
	return chip
end

-- Key cap ("E", "LMB", "R2") for keyboard/gamepad hints.
function Hud.keycap(parent: Instance?, key: string, size: number?): TextLabel
	local s = size or 26
	local cap = Hud.make("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(s, s),
		BackgroundColor3 = Theme.Colors.Text,
		BorderSizePixel = 0,
		FontFace = Theme.Fonts.UiHeavy,
		Text = key,
		TextSize = math.floor(s * 0.6),
		TextColor3 = Theme.Colors.Panel,
	}, nil)
	Hud.corner(cap, 6)
	Hud.padding(cap, 5, 0)
	Hud.make("UISizeConstraint", { MinSize = Vector2.new(s, s) }, cap)
	cap.Parent = parent
	return cap
end

-- Thin horizontal bar; returns the fill frame (Size.X.Scale = progress).
function Hud.bar(parent: Instance, props: Props, color: Color3): (Frame, Frame)
	local back = Hud.panel(props, parent)
	back.BackgroundColor3 = Theme.Colors.Dim
	back.BackgroundTransparency = 0.2
	back.ClipsDescendants = true
	local fill = Hud.make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, back)
	Hud.corner(fill, props.Radius)
	return back, fill
end

export type Ring = { frame: Frame, set: (alpha: number) -> (), setColor: (color: Color3) -> () }

-- Radial progress ring: a pie drawn BEHIND a round control, `size` px wide. Put it as a sibling under the
-- control (lower ZIndex) or as a child with ZIndex below. alpha 0 = empty, 1 = full circle.
function Hud.progressRing(parent: Instance, size: number, color: Color3, zIndex: number?): Ring
	local frame = Hud.make("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = zIndex or 0,
	}, parent)
	local gradients: { UIGradient } = {}
	local discs: { Frame } = {}
	for index = 1, 2 do
		local right = index == 1
		local clip = Hud.make("Frame", {
			Size = UDim2.fromScale(0.5, 1),
			Position = UDim2.fromScale(if right then 0.5 else 0, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = zIndex or 0,
		}, frame)
		local disc = Hud.make("Frame", {
			Size = UDim2.fromScale(2, 1),
			Position = UDim2.fromScale(if right then -1 else 0, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = zIndex or 0,
		}, clip)
		Hud.corner(disc, 999)
		local gradient = Hud.make("UIGradient", {
			Transparency = if right
				then NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(0.501, 1),
					NumberSequenceKeypoint.new(1, 1),
				})
				else NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.499, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 0),
				}),
		}, disc)
		table.insert(gradients, gradient)
		table.insert(discs, disc)
	end
	local function set(alpha: number)
		local a = math.clamp(alpha, 0, 1)
		frame.Visible = a > 0.001
		gradients[1].Rotation = math.clamp(a * 360, 0, 180)
		gradients[2].Rotation = math.clamp((a - 0.5) * 360, 0, 180)
	end
	local function setColor(c: Color3)
		for _, disc in discs do
			disc.BackgroundColor3 = c
		end
	end
	set(0)
	return { frame = frame, set = set, setColor = setColor }
end

function Hud.formatNumber(value: number): string
	local n = math.floor(value + 0.5)
	local negative = n < 0
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return if negative then "-" .. out else out
end

function Hud.formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function Hud.shortName(name: string, maxLength: number?): string
	local limit = maxLength or 10
	if #name <= limit then
		return name
	end
	return string.sub(name, 1, limit - 1) .. "…"
end

function Hud.slot(name: string): Frame
	local slot = slots[name]
	assert(slot, `Hud slot {name} does not exist (Hud.init not called?)`)
	return slot
end

function Hud.gui(): ScreenGui
	return hudGui
end

-- Toast: short line at 62% height, max 4 at a time, gone after 3 s.
function Hud.toast(message: string, color: Color3?, glyph: string?)
	local list = slots.Toasts
	if not list then
		return
	end
	local label =
		Hud.chip(list, if glyph then `{glyph}  {message}` else message, color or Theme.Colors.Text, {
			Size = UDim2.fromOffset(0, 30),
			TextSize = 17,
			LayoutOrder = os.clock() * 1000 // 1,
		})
	label.BackgroundTransparency = 0.2
	local count = 0
	local children = {}
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			count += 1
			table.insert(children, child)
		end
	end
	if count > Theme.UX.ToastsAlive then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	task.delay(3, function()
		if not label.Parent then
			return
		end
		local tween = TweenService:Create(
			label,
			TweenInfo.new(0.35),
			{ TextTransparency = 1, BackgroundTransparency = 1 }
		)
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

-- Big banner at 30% height (FredokaOne). Music ducks under it.
function Hud.banner(message: string, color: Color3, seconds: number?, sub: string?)
	if not bannerFrame then
		return
	end
	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = message
	bannerLabel.TextColor3 = color
	bannerSub.Text = sub or ""
	bannerSub.Visible = sub ~= nil and sub ~= ""
	bannerFrame.Visible = true
	bannerLabel.TextTransparency = 0
	bannerSub.TextTransparency = 0
	local scale = bannerFrame:FindFirstChildOfClass("UIScale")
	if scale then
		if Settings.reduceMotion() then
			scale.Scale = 1
		else
			scale.Scale = 0.6
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
	local hold = seconds or 2.5
	Audio.duck(hold)
	task.delay(hold, function()
		if token ~= bannerToken then
			return
		end
		local fade = TweenService:Create(bannerLabel, TweenInfo.new(0.3), { TextTransparency = 1 })
		TweenService:Create(bannerSub, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		fade:Play()
		fade.Completed:Wait()
		if token == bannerToken then
			bannerFrame.Visible = false
		end
	end)
end

function Hud.clearBanner()
	bannerToken += 1
	if bannerFrame then
		bannerFrame.Visible = false
	end
end

-- Stamp ("CAUGHT!", "BUSTED"): slams in tilted above everything.
function Hud.stamp(message: string, color: Color3, seconds: number?, rotation: number?)
	local top = UiScale.root("Top")
	local label = Hud.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0.8, 0, 0, 110),
		Text = message,
		TextColor3 = color,
		Display = true,
		MaxTextSize = 96,
		Rotation = rotation or -8,
		Stroke = 4,
	}, top)
	local scale = Hud.make("UIScale", {}, label)
	if Settings.reduceMotion() then
		label.TextTransparency = 1
		TweenService:Create(label, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	else
		scale.Scale = 2.2
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 1,
		}):Play()
	end
	task.delay(seconds or 1.2, function()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
		local fade = TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
end

function Hud.setCrosshair(visible: boolean)
	if crosshair then
		crosshair.Visible = visible
	end
end

-- Kept for GadgetController (mechanics): the HUD reads gadgets from attributes, this only signals a refresh.
function Hud.setLoadout(_entries: any, _slots: any, _battery: any)
	Hud.LoadoutChanged:Fire()
end

local function column(name: string, props: Props, parent: Instance, layout: () -> ()): Frame
	local frame = Hud.frame(props, parent)
	frame.Name = name
	slots[name] = frame
	layout()
	return frame
end

local initialized = false
function Hud.init()
	if initialized then
		return
	end
	initialized = true
	hudGui = UiScale.root("Hud")
	local overlay = UiScale.root("Overlay")

	column(
		"Status",
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(340, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		},
		hudGui,
		function()
			Hud.list(slots.Status, Enum.FillDirection.Vertical, 4)
		end
	)

	column(
		"Right",
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 6),
			Size = UDim2.fromOffset(156, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		},
		hudGui,
		function()
			Hud.list(slots.Right, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Right)
		end
	)

	column(
		"Bottom",
		{
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.fromOffset(300, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		},
		hudGui,
		function()
			Hud.list(
				slots.Bottom,
				Enum.FillDirection.Vertical,
				6,
				Enum.HorizontalAlignment.Center,
				Enum.VerticalAlignment.Bottom
			)
		end
	)

	column(
		"Strip",
		{
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -12),
			Size = UDim2.fromOffset(260, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		},
		hudGui,
		function()
			Hud.list(
				slots.Strip,
				Enum.FillDirection.Vertical,
				6,
				Enum.HorizontalAlignment.Right,
				Enum.VerticalAlignment.Bottom
			)
		end
	)

	column(
		"Toasts",
		{
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.74),
			Size = UDim2.fromOffset(520, 140),
		},
		overlay,
		function()
			Hud.list(
				slots.Toasts,
				Enum.FillDirection.Vertical,
				4,
				Enum.HorizontalAlignment.Center,
				Enum.VerticalAlignment.Bottom
			)
		end
	)

	bannerFrame = Hud.frame({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.86, 0, 0, 96),
		Visible = false,
	}, overlay)
	slots.Banner = bannerFrame
	Hud.make("UIScale", {}, bannerFrame)
	bannerLabel = Hud.text({
		Size = UDim2.new(1, 0, 0, 66),
		Text = "",
		Display = true,
		MaxTextSize = 60,
		Stroke = 3,
	}, bannerFrame)
	bannerSub = Hud.text({
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 28),
		Text = "",
		MaxTextSize = 22,
		Stroke = 2,
	}, bannerFrame)

	crosshair = Hud.make("Frame", {
		Name = "Crosshair",
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.2,
		Visible = false,
	}, UiScale.root("World"))
	Hud.corner(crosshair, 999)
	Hud.make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5 }, crosshair)
end

return Hud
