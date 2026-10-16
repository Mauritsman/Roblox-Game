--!strict
-- Loading screen (beta-spec-ux §1.1), runs from ReplicatedFirst before anything else is replicated, so it
-- uses no shared modules. Logo, a wobbling cheese wheel (still with reduce motion), 3 progress pips and one
-- tip line. Waits for game:IsLoaded() and a short preload (max 8 s), then fades out in 0.3 s.
-- After 12 s a small "Still loading…" line appears. No skip button.

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TIPS = {
	"Heavy cheese? Lift it with a friend",
	"Walk into the van to bank loot",
	"Hands full? Throw it to a teammate",
	"Caught? Your crew can free you",
	"Hide in a barrel, but don't sneeze",
	"The Golden Gouda starts the lockdown",
	"Bubble a guard to drop a friend",
}

local PANEL = Color3.fromRGB(16, 18, 26)
local GOLD = Color3.fromHex("FFC21A")
local CHEESE = Color3.fromHex("FFD23F")
local MUTED = Color3.fromRGB(170, 175, 190)

local reduceMotion = GuiService.ReducedMotionEnabled

local gui = Instance.new("ScreenGui")
gui.Name = "CC_Loading"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 100
gui.ResetOnSpawn = false

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = PANEL
background.BorderSizePixel = 0
background.Parent = gui

local function label(text: string, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	l.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		if key ~= "MaxTextSize" then
			(l :: any)[key] = value
		end
	end
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 12
	constraint.MaxTextSize = props.MaxTextSize or 64
	constraint.Parent = l
	l.Parent = background
	return l
end

-- Cheese wheel: a yellow disc with a darker rim and three holes.
local wheel = Instance.new("Frame")
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.36)
wheel.Size = UDim2.fromOffset(110, 110)
wheel.BackgroundColor3 = CHEESE
wheel.BorderSizePixel = 0
wheel.Parent = background
local wheelCorner = Instance.new("UICorner")
wheelCorner.CornerRadius = UDim.new(1, 0)
wheelCorner.Parent = wheel
local rim = Instance.new("UIStroke")
rim.Color = Color3.fromRGB(214, 160, 40)
rim.Thickness = 6
rim.Parent = wheel
for _, hole in { { 0.3, 0.35, 18 }, { 0.65, 0.3, 12 }, { 0.55, 0.68, 22 } } do
	local h = Instance.new("Frame")
	h.AnchorPoint = Vector2.new(0.5, 0.5)
	h.Position = UDim2.fromScale(hole[1], hole[2])
	h.Size = UDim2.fromOffset(hole[3], hole[3])
	h.BackgroundColor3 = Color3.fromRGB(230, 180, 50)
	h.BorderSizePixel = 0
	h.Parent = wheel
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = h
end

label("CROWBAR CREW", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.new(0.8, 0, 0, 64),
	TextColor3 = GOLD,
	MaxTextSize = 64,
})

local pips: { Frame } = {}
for index = 1, 3 do
	local pip = Instance.new("Frame")
	pip.AnchorPoint = Vector2.new(0.5, 0.5)
	pip.Position = UDim2.new(0.5, (index - 2) * 26, 0.52, 92)
	pip.Size = UDim2.fromOffset(14, 14)
	pip.BackgroundColor3 = MUTED
	pip.BackgroundTransparency = 0.6
	pip.BorderSizePixel = 0
	pip.Parent = background
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = pip
	pips[index] = pip
end

label(TIPS[math.random(1, #TIPS)], {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -28),
	Size = UDim2.new(0.86, 0, 0, 26),
	TextColor3 = MUTED,
	FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
	MaxTextSize = 22,
})

local slow = label("Still loading…", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -60),
	Size = UDim2.new(0.6, 0, 0, 20),
	TextColor3 = MUTED,
	FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
	MaxTextSize = 17,
	Visible = false,
})

gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

local started = os.clock()
local finished = false

if not reduceMotion then
	wheel.Rotation = -8
	TweenService:Create(
		wheel,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Rotation = 8 }
	):Play()
end

task.spawn(function()
	local step = 0
	while not finished do
		step = step % 3 + 1
		for index, pip in pips do
			pip.BackgroundColor3 = if index <= step then GOLD else MUTED
			pip.BackgroundTransparency = if index <= step then 0 else 0.6
		end
		if os.clock() - started > 12 then
			slow.Visible = true
		end
		task.wait(0.35)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Preload the fonts this screen and the HUD use (max 8 s), then show at least a moment.
local preloaded = false
task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ gui })
	end)
	preloaded = true
end)
while not preloaded and os.clock() - started < 8 do
	task.wait(0.1)
end
while os.clock() - started < 1.2 do
	task.wait(0.1)
end

finished = true
local fade = TweenInfo.new(0.3)
for _, d in gui:GetDescendants() do
	if d:IsA("TextLabel") then
		TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, fade, { Transparency = 1 }):Play()
	end
end
task.wait(0.35)
gui:Destroy()
