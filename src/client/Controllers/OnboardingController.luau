--!strict
-- Onboarding (beta-spec-ux §3): one hint at a time in the hint pill (≤ 5 words + icon), driven by the
-- server's `Hint(key, text, icon, worldPos?)` (mechanics) and `Onboarding(step)` (meta funnel steps).
-- Also: progressive disclosure of the touch buttons in the mini-job, the one-time Garage tour, and
-- first-time tips (max 2 times ever each, max 1 per 30 s, off with the Hints setting).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Audio = require(Lib.Audio)
local CharState = require(Lib.CharState)
local Device = require(Lib.Device)
local EdgeArrows = require(Lib.EdgeArrows)
local Hud = require(Lib.Hud)
local Juice = require(Lib.Juice)
local Profile = require(Lib.Profile)
local RoundState = require(Lib.RoundState)
local Settings = require(Lib.Settings)
local Theme = require(Lib.Theme)
local UiText = require(Lib.UiText)
local World = require(Lib.World)

local TouchController = require(script.Parent.TouchController)

local OnboardingController = {}

local C = Theme.Colors

local pill: Frame
local pillGlyph: TextLabel
local pillText: TextLabel
local currentKey: string? = nil
local shownAt = 0
local lastServerHint = -math.huge
local stopPulse: (() -> ())? = nil
local beacon: Part? = nil
local funnelStep = 0
local tourStep = 0
local lastTipAt = -math.huge
local tipCounts: { [string]: number } = {}

-- Icons the server may name in Hint(…, icon).
local ICONS: { [string]: string } = {
	wheel = Theme.Loot.Medium.glyph,
	cheese = Theme.Loot.Medium.glyph,
	van = "▣",
	crouch = "▾",
	pocket = Theme.Loot.Small.glyph,
	crown = Theme.Loot.Main.glyph,
	gouda = Theme.Loot.Main.glyph,
	roll = Theme.Loot.Heavy.glyph,
	heavy = Theme.Loot.Heavy.glyph,
	hide = "◍",
	stick = "✥",
	gadget = "⚙",
	board = "☰",
	free = "⛓",
}

local function iconFor(icon: any): string
	if typeof(icon) ~= "string" or icon == "" then
		return "★"
	end
	return ICONS[string.lower(icon)] or (if utf8.len(icon) == 1 then icon else "★")
end

local function clearBeacon()
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
	EdgeArrows.clear("Hint")
end

local function setBeacon(position: Vector3?)
	clearBeacon()
	if not position then
		return
	end
	local part = Instance.new("Part")
	part.Name = "HintBeacon"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = C.Gold
	part.Transparency = 0.55
	part.Size = Vector3.new(30, 0.6, 0.6)
	part.CFrame = CFrame.new(position + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = workspace.CurrentCamera
	beacon = part
	EdgeArrows.set("Hint", {
		target = function()
			return position
		end,
		glyph = "★",
		color = C.Gold,
		onScreen = false,
	})
end

function OnboardingController.showHint(key: string, text: string, icon: any, worldPos: Vector3?)
	if currentKey == key and pillText.Text == text then
		return
	end
	currentKey = key
	shownAt = os.clock()
	pillGlyph.Text = iconFor(icon)
	pillText.Text = text
	pillGlyph.TextColor3 = C.Gold
	pill.Visible = true
	Juice.pop(pill, 1.2)
	Audio.play("HintBlip")
	if stopPulse then
		stopPulse()
		stopPulse = nil
	end
	setBeacon(worldPos)
end

-- done = show a green check for 0.4 s first.
function OnboardingController.clearHint(done: boolean?)
	if not currentKey then
		return
	end
	currentKey = nil
	if stopPulse then
		stopPulse()
		stopPulse = nil
	end
	clearBeacon()
	if done then
		pillGlyph.Text = "✓"
		pillGlyph.TextColor3 = C.Good
		task.delay(0.4, function()
			if currentKey == nil then
				pill.Visible = false
			end
		end)
	else
		pill.Visible = false
	end
end

-- First-time tips during real jobs.
function OnboardingController.tip(id: string)
	if not Settings.hints() or RoundState.activity() == "Tutorial" then
		return
	end
	local text = UiText.Tips[id]
	if not text then
		return
	end
	local seen = Profile.get("seenTips")
	local stored = if typeof(seen) == "table" and typeof(seen[id]) == "number" then seen[id] else 0
	local count = math.max(stored, tipCounts[id] or 0)
	if count >= Theme.UX.TipMaxShows or os.clock() - lastTipAt < Theme.UX.TipCooldown then
		return
	end
	tipCounts[id] = count + 1
	lastTipAt = os.clock()
	if table.find(MetaConfig.Data.TipIds, id) then
		Net.request("TipSeen", id)
	end
	if currentKey == nil then
		OnboardingController.showHint("tip:" .. id, text, "★")
		task.delay(4, function()
			if currentKey == "tip:" .. id then
				OnboardingController.clearHint(false)
			end
		end)
	else
		Hud.toast(text, C.Gold, "★")
	end
end

-- ── Mini-job funnel (meta step numbers) ──────────────────────────────────────────────────────────

local function moveHint(): string
	local input = Device.input()
	if input == "Touch" then
		return "Move with the stick"
	elseif input == "Gamepad" then
		return "Move with left stick"
	end
	return "Move with WASD"
end

local STEP_HINTS: { [number]: { text: string, icon: string, place: string? } } = {
	[1] = { text = "Grab the cheese", icon = "wheel" },
	[2] = { text = "Grab the cheese", icon = "wheel" },
	[3] = { text = "Bring it to the van", icon = "van", place = "van" },
	[4] = { text = "Sneak past the guard", icon = "crouch" },
	[5] = { text = "Grab the Golden Gouda", icon = "crown", place = "gouda" },
	[6] = { text = "Roll it to the van", icon = "roll", place = "van" },
}

local function placeFor(name: string?): Vector3?
	if name == "van" then
		return World.vanPosition()
	elseif name == "gouda" then
		return World.goudaPosition()
	end
	return nil
end

local function watchForMovement()
	local r = CharState.root()
	local start = r and r.Position
	task.delay(4, function()
		if funnelStep ~= 1 or not start then
			return
		end
		local now = CharState.root()
		if now and (now.Position - start).Magnitude < 8 and os.clock() - lastServerHint > 3 then
			OnboardingController.showHint("move", moveHint(), "stick")
			while funnelStep == 1 do
				local current = CharState.root()
				if current and (current.Position - start).Magnitude >= 8 then
					OnboardingController.showHint("step2", "Grab the cheese", "wheel")
					break
				end
				task.wait(0.25)
			end
		end
	end)
end

-- ── Garage tour (once, never blocking) ───────────────────────────────────────────────────────────

local TOUR = {
	{ text = "Pick two gadgets", icon = "gadget", tag = "GadgetRack" },
	{ text = "Choose a job", icon = "board", tag = "JobBoard" },
	{ text = "Hop in the van", icon = "van", tag = "GarageVan" },
}

local function showTour()
	local step = TOUR[tourStep]
	if not step then
		if tourStep > #TOUR then
			OnboardingController.clearHint(true)
		end
		return
	end
	OnboardingController.showHint(
		"tour" .. tourStep,
		step.text,
		step.icon,
		World.position(World.tagged(step.tag))
	)
end

-- Called by GarageController when the player sets a loadout (1) or votes (2); departing ends it.
function OnboardingController.tourProgress(done: number)
	if tourStep == 0 or tourStep > #TOUR then
		return
	end
	if done >= tourStep then
		tourStep = done + 1
		showTour()
	end
end

local function onStep(step: number)
	if step <= funnelStep then
		return
	end
	funnelStep = step
	TouchController.requestRefresh()
	if step == 8 then
		tourStep = 1
		task.delay(1, showTour)
		return
	end
	if step == 7 then
		OnboardingController.clearHint(true)
		return
	end
	task.delay(0.5, function()
		-- The server's own Hint wins when it sent one around the same time.
		if os.clock() - lastServerHint < 1.5 or funnelStep ~= step then
			return
		end
		local hint = STEP_HINTS[step]
		if hint then
			OnboardingController.showHint("step" .. step, hint.text, hint.icon, placeFor(hint.place))
		end
	end)
	if step == 1 then
		watchForMovement()
	end
end

function OnboardingController:Init()
	pill = Hud.panel({
		Name = "HintPill",
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
		Visible = false,
		BackgroundTransparency = 0.1,
		Radius = 20,
	}, Hud.slot("Status"))
	Hud.stroke(pill, C.Gold, 2, 0.2)
	Hud.padding(pill, 14, 4)
	Hud.list(
		pill,
		Enum.FillDirection.Horizontal,
		8,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	pillGlyph = Hud.make("TextLabel", {
		Size = UDim2.fromOffset(28, 30),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		TextSize = 24,
		TextColor3 = C.Gold,
		Text = "★",
		LayoutOrder = 1,
	}, pill)
	pillText = Hud.make("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.UiHeavy,
		TextSize = 20,
		TextColor3 = C.Text,
		Text = "",
		LayoutOrder = 2,
	}, pill)
	Hud.stroke(pillText, C.Stroke, 1.5)

	-- Progressive disclosure in the mini-job: CROUCH at the sneak step, GADGET (as ROLL) at the Gouda,
	-- PING after the mini-job.
	TouchController.gate = function(slot: string): boolean
		if RoundState.activity() ~= "Tutorial" then
			return true
		end
		if slot == "Crouch" then
			return funnelStep >= 4
		elseif slot == "Gadget" then
			return funnelStep >= 6
		elseif slot == "Ping" then
			return false
		end
		return true
	end
end

function OnboardingController:Start()
	Net.on("Hint", function(key: any, text: any, icon: any, worldPos: any)
		lastServerHint = os.clock()
		if typeof(text) ~= "string" or text == "" then
			OnboardingController.clearHint(true)
			return
		end
		OnboardingController.showHint(
			if typeof(key) == "string" then key else text,
			text,
			icon,
			if typeof(worldPos) == "Vector3" then worldPos else nil
		)
	end)
	Net.on("Onboarding", function(step: any)
		if typeof(step) == "number" then
			onStep(step)
		end
	end)

	-- Mini-job: in the van → "Hold to drive away"; leaving the mini-job clears hints.
	CharState.Changed:Connect(function(name)
		if name == "InVan" and RoundState.activity() == "Tutorial" and CharState.get("InVan") == true then
			if funnelStep >= 6 and os.clock() - lastServerHint > 1.5 then
				OnboardingController.showHint("drive", "Hold to drive away", "van")
			end
		elseif name == "Player:Activity" and RoundState.activity() ~= "Tutorial" then
			if
				currentKey
				and (string.sub(currentKey, 1, 4) == "step" or currentKey == "move" or currentKey == "drive")
			then
				OnboardingController.clearHint(true)
			end
			TouchController.requestRefresh()
		elseif name == "Player:Loadout" then
			OnboardingController.tourProgress(1)
		end
	end)
	RoundState.Changed:Connect(function(name)
		if name == "VanDepartAt" or (name == "RoundPhase" and RoundState.phase() == "Briefing") then
			if tourStep >= 1 and tourStep <= #TOUR then
				tourStep = #TOUR + 1
				OnboardingController.clearHint(true)
			end
		end
	end)
	Profile.Changed:Connect(function(what)
		-- Joined straight into the mini-job: the first Onboarding message may have come before we listened,
		-- so continue from the steps the profile already has.
		if what == "profile" and funnelStep == 0 and RoundState.activity() == "Tutorial" then
			local onboarding = Profile.get("onboarding")
			local steps = if typeof(onboarding) == "table" then onboarding.steps else nil
			local highest = 0
			if typeof(steps) == "table" then
				for index, name in MetaConfig.Analytics.OnboardingSteps do
					if steps[name] then
						highest = math.max(highest, index)
					end
				end
			end
			onStep(math.max(highest, 1))
		end
		local result = Profile.result
		if what == "result" and result and result.ok and result.action == "Loadout" then
			OnboardingController.tourProgress(1)
		end
	end)

	-- Idle: after 20 s the pill pulses (repeat every 60 s).
	while true do
		task.wait(1)
		if currentKey and not stopPulse then
			local age = os.clock() - shownAt
			if age >= Theme.UX.HintIdlePulse and (age - Theme.UX.HintIdlePulse) % Theme.UX.HintRepeat < 1 then
				stopPulse = Juice.pulse(pill, 1.2)
				task.delay(6, function()
					if stopPulse then
						stopPulse()
						stopPulse = nil
					end
				end)
			end
		end
	end
end

return OnboardingController
