--!strict
-- De HUD: alles wat de speler op het scherm ziet. Gebouwd in code, zodat het in Git staat.
-- Ontwerpregels: grote knoppen (≥ 48 px, hoofdknoppen ≥ 64 px), hoog contrast, kleur + vorm,
-- Engelse spelerteksten, niets in de hoeken die Roblox zelf gebruikt (joystick, springknop).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Hud = {}

local player = Players.LocalPlayer

Hud.Colors = {
	Panel = Color3.fromRGB(16, 18, 26),
	Text = Color3.fromRGB(245, 245, 250),
	Muted = Color3.fromRGB(170, 175, 190),
	Accent = Color3.fromRGB(255, 128, 32), -- crew-oranje
	Danger = Color3.fromRGB(255, 70, 70),
	Warn = Color3.fromRGB(255, 200, 60),
	Good = Color3.fromRGB(90, 210, 120),
	Eyes = Color3.fromRGB(80, 160, 255),
	Clear = Color3.fromRGB(255, 210, 60),
	Open = Color3.fromRGB(255, 90, 80),
}

local FONT = Enum.Font.GothamBold
local FONT_BLACK = Enum.Font.GothamBlack

local gui: ScreenGui
local toastList: Frame
local banner: TextLabel
local alarmFrame: Frame
local alarmDots: { Frame } = {}
local alarmLabel: TextLabel
local windowFrame: Frame
local windowRing: Frame
local windowLabel: TextLabel
local windowToken = 0
local loadoutFrame: Frame
local crosshair: Frame
local chainFrame: Frame
local chainTitle: TextLabel
local chainSlots: { [string]: TextLabel } = {}
local chainButton: TextButton
local chainCountdown: TextLabel
local lockdownLabel: TextLabel

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent: Instance, radius: number?)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function panel(props: { [string]: any }, parent: Instance): Frame
	local frame = make("Frame", props, parent)
	frame.BackgroundColor3 = props.BackgroundColor3 or Hud.Colors.Panel
	frame.BackgroundTransparency = props.BackgroundTransparency or 0.25
	frame.BorderSizePixel = 0
	corner(frame)
	return frame
end

local function text(props: { [string]: any }, parent: Instance): TextLabel
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = Hud.Colors.Text,
		TextScaled = true,
	}, nil)
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

function Hud.button(props: { [string]: any }, parent: Instance?): TextButton
	local button = make("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = Hud.Colors.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Font = FONT,
		TextColor3 = Hud.Colors.Text,
		TextScaled = true,
	}, nil)
	for key, value in props do
		(button :: any)[key] = value
	end
	corner(button, 999)
	make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = props.StrokeColor or Color3.new(1, 1, 1),
		Transparency = 0.6,
		Thickness = 2,
	}, button)
	make("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 10 }, button)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	}, button)
	button.Parent = parent or gui
	return button
end

function Hud.gui(): ScreenGui
	return gui
end

function Hud.toast(message: string, color: Color3?)
	local label = text({
		Size = UDim2.new(1, 0, 0, 30),
		Text = message,
		TextColor3 = color or Hud.Colors.Text,
		TextStrokeTransparency = 0.2,
	}, toastList)
	make("UITextSizeConstraint", { MaxTextSize = 24 }, label)
	task.delay(3.2, function()
		local tween = TweenService:Create(
			label,
			TweenInfo.new(0.4),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
	-- Hoogstens 5 meldingen tegelijk.
	local children = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(children, child)
		end
	end
	if #children > 5 then
		children[1]:Destroy()
	end
end

function Hud.banner(message: string, color: Color3, seconds: number?)
	banner.Text = message
	banner.TextColor3 = color
	banner.Visible = true
	banner.TextTransparency = 0
	local token = os.clock()
	banner:SetAttribute("Token", token)
	task.delay(seconds or 2.5, function()
		if banner:GetAttribute("Token") == token then
			banner.Visible = false
		end
	end)
end

local ALARM_COLORS =
	{ [0] = Hud.Colors.Good, [1] = Hud.Colors.Warn, [2] = Hud.Colors.Accent, [3] = Hud.Colors.Danger }

function Hud.setAlarm(level: number, name: string)
	for index, dot in alarmDots do
		dot.BackgroundColor3 = if index <= level then ALARM_COLORS[level] else Color3.fromRGB(70, 72, 84)
	end
	alarmLabel.Text = name
	alarmLabel.TextColor3 = ALARM_COLORS[level] or Hud.Colors.Text
end

-- Het venster (§3.3): krimpende ring met seconden, voor de hele crew.
function Hud.showWindow(kind: string, seconds: number)
	windowToken += 1
	local token = windowToken
	windowFrame.Visible = true
	windowRing.Size = UDim2.fromScale(1, 1)
	local ringTween = TweenService:Create(
		windowRing,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0.15, 0.15) }
	)
	ringTween:Play()
	task.spawn(function()
		local endsAt = os.clock() + seconds
		while token == windowToken do
			local left = math.max(0, math.ceil(endsAt - os.clock()))
			windowLabel.Text = `{kind} {left}`
			local closing = left <= 3
			windowLabel.TextColor3 = if closing then Hud.Colors.Danger else Hud.Colors.Text
			local stroke = windowRing:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if closing then Hud.Colors.Danger else Hud.Colors.Eyes
			end
			if left <= 0 then
				break
			end
			task.wait(0.1)
		end
		if token == windowToken then
			windowLabel.Text = "CLOSING"
			task.wait(0.6)
			if token == windowToken then
				windowFrame.Visible = false
			end
		end
	end)
end

function Hud.setLoadout(
	entries: {
		{
			name: string,
			label: string?,
			charges: number?,
			selected: boolean,
			step: string,
		}
	},
	slots: number,
	battery: number?
)
	for _, child in loadoutFrame:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	text({
		Size = UDim2.new(1, 0, 0, 20),
		Text = `GADGETS ({#entries}/{slots})`,
		TextColor3 = Hud.Colors.Muted,
		LayoutOrder = 0,
	}, loadoutFrame)
	for index, entry in entries do
		local row = panel({
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = index,
			BackgroundTransparency = if entry.selected then 0.05 else 0.45,
		}, loadoutFrame)
		local stepColor = if entry.step == "EYES"
			then Hud.Colors.Eyes
			elseif entry.step == "CLEAR" then Hud.Colors.Clear
			else Hud.Colors.Open
		make("UIStroke", {
			Color = stepColor,
			Thickness = if entry.selected then 3 else 1,
			Transparency = if entry.selected then 0 else 0.5,
		}, row)
		local chargeText = if entry.charges == nil or entry.charges < 0 then "" else ` ×{entry.charges}`
		local extra = ""
		if entry.name == "Drone" and battery then
			extra = ` {math.floor(battery * 100)}%`
		end
		text({
			Size = UDim2.new(1, -12, 1, -6),
			Position = UDim2.fromOffset(6, 3),
			Text = `{index}  {(entry.label or entry.name):upper()}{chargeText}{extra}`,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if entry.selected then Hud.Colors.Text else Hud.Colors.Muted,
		}, row)
	end
	if #entries == 0 then
		text({
			Size = UDim2.new(1, 0, 0, 40),
			Text = "Press E at a glowing\npedestal by the van",
			TextColor3 = Hud.Colors.Warn,
			LayoutOrder = 1,
		}, loadoutFrame)
	end
end

function Hud.setCrosshair(visible: boolean)
	crosshair.Visible = visible
end

-- Chain Call-paneel (§3.4).
function Hud.showChain(snapshot: { [string]: any }?, mode: string?)
	if not snapshot then
		chainFrame.Visible = false
		chainCountdown.Visible = false
		return
	end
	chainFrame.Visible = true
	chainTitle.Text = `CHAIN CALL · {snapshot.caller}`
	for step, label in chainSlots do
		local who = snapshot.slots and snapshot.slots[step]
		label.Text = if who then `{step} ✓\n{who}` else `{step}\n…`
		label.TextTransparency = if who then 0 else 0.35
	end
	if mode == "caller" then
		chainButton.Text = "GO"
		chainButton.Visible = not snapshot.counting
	elseif mode == "join" then
		chainButton.Text = "I'M IN"
		chainButton.Visible = not snapshot.counting
	else
		chainButton.Visible = false
	end
end

function Hud.chainButton(): TextButton
	return chainButton
end

function Hud.countdown(seconds: number, onNow: (() -> ())?)
	chainCountdown.Visible = true
	task.spawn(function()
		for left = seconds, 1, -1 do
			chainCountdown.Text = tostring(left)
			chainCountdown.TextColor3 = Hud.Colors.Warn
			task.wait(1)
		end
		chainCountdown.Text = "NOW"
		chainCountdown.TextColor3 = Hud.Colors.Good
		if onNow then
			onNow()
		end
		task.wait(1.2)
		chainCountdown.Visible = false
	end)
end

function Hud.lockdown(seconds: number)
	lockdownLabel.Visible = true
	task.spawn(function()
		local endsAt = os.clock() + seconds
		while lockdownLabel.Visible do
			local left = math.max(0, math.ceil(endsAt - os.clock()))
			lockdownLabel.Text = `LOCKDOWN · POLICE IN {left}`
			if left <= 0 then
				break
			end
			task.wait(0.25)
		end
	end)
end

function Hud.clearLockdown()
	lockdownLabel.Visible = false
end

function Hud.init()
	gui = make("ScreenGui", {
		Name = "CrowbarCrewHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)

	-- Alarmladder linksboven.
	alarmFrame = panel({
		Size = UDim2.fromOffset(190, 46),
		Position = UDim2.fromOffset(12, 12),
	}, gui)
	for index = 1, 3 do
		local dot = make("Frame", {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(12 + (index - 1) * 20, 16),
			BackgroundColor3 = Color3.fromRGB(70, 72, 84),
			BorderSizePixel = 0,
		}, alarmFrame)
		corner(dot, 999)
		table.insert(alarmDots, dot)
	end
	alarmLabel = text({
		Size = UDim2.new(1, -86, 0, 26),
		Position = UDim2.fromOffset(78, 10),
		Text = "QUIET",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Hud.Colors.Good,
	}, alarmFrame)

	-- Venster-ring bovenaan in het midden.
	windowFrame = make("Frame", {
		Size = UDim2.fromOffset(150, 150),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	windowRing = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, windowFrame)
	corner(windowRing, 999)
	make("UIStroke", { Color = Hud.Colors.Eyes, Thickness = 6 }, windowRing)
	windowLabel = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1.6, 0, 0, 34),
		Text = "",
		Font = FONT_BLACK,
		TextStrokeTransparency = 0,
	}, windowFrame)

	-- Chain Call-paneel onder de ring.
	chainFrame = panel({
		Size = UDim2.fromOffset(360, 120),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Visible = false,
	}, gui)
	chainTitle = text({
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.fromOffset(8, 6),
		Text = "CHAIN CALL",
		TextColor3 = Hud.Colors.Accent,
	}, chainFrame)
	local stepColors = { EYES = Hud.Colors.Eyes, CLEAR = Hud.Colors.Clear, OPEN = Hud.Colors.Open }
	for index, step in { "EYES", "CLEAR", "OPEN" } do
		local box = panel({
			Size = UDim2.fromOffset(108, 46),
			Position = UDim2.fromOffset(12 + (index - 1) * 114, 34),
			BackgroundTransparency = 0.5,
		}, chainFrame)
		make("UIStroke", { Color = stepColors[step], Thickness = 2 }, box)
		chainSlots[step] = text({
			Size = UDim2.new(1, -8, 1, -6),
			Position = UDim2.fromOffset(4, 3),
			Text = step,
			TextColor3 = stepColors[step],
		}, box)
	end
	chainButton = Hud.button({
		Name = "ChainButton",
		Size = UDim2.fromOffset(140, 30),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
		Text = "I'M IN",
		BackgroundColor3 = Hud.Colors.Accent,
		BackgroundTransparency = 0,
	}, chainFrame)
	chainCountdown = text({
		Size = UDim2.fromOffset(240, 120),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Text = "3",
		Font = FONT_BLACK,
		TextStrokeTransparency = 0,
		Visible = false,
	}, gui)

	-- Gadgets rechtsboven.
	loadoutFrame = make("Frame", {
		Size = UDim2.fromOffset(210, 160),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, loadoutFrame)

	-- Meldingen en grote banner.
	toastList = make("Frame", {
		Size = UDim2.fromOffset(520, 190),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, toastList)
	banner = text({
		Size = UDim2.new(0.8, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Font = FONT_BLACK,
		TextStrokeTransparency = 0,
		Visible = false,
	}, gui)
	lockdownLabel = text({
		Size = UDim2.new(0.6, 0, 0, 40),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		TextColor3 = Hud.Colors.Danger,
		Font = FONT_BLACK,
		TextStrokeTransparency = 0,
		Visible = false,
	}, gui)

	-- Richtpunt in het midden (touch, controller en drone).
	crosshair = make("Frame", {
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.2,
		Visible = false,
	}, gui)
	corner(crosshair, 999)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5 }, crosshair)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return Hud
