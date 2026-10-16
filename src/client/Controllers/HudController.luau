--!strict
-- The heist HUD (beta-spec-ux §1.7–1.9, §1.12): status bar (loot meter, alarm, police/round timer), effect
-- chips, crew list, carry chip + pockets, key-cap strip (keyboard/gamepad), drive panel, van and teammate
-- arrows, lockdown sweep and siren. State comes from attributes, so late joiners see the same HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Audio = require(Lib.Audio)
local CharState = require(Lib.CharState)
local ClientState = require(Lib.ClientState)
local Device = require(Lib.Device)
local EdgeArrows = require(Lib.EdgeArrows)
local Hud = require(Lib.Hud)
local Juice = require(Lib.Juice)
local Profile = require(Lib.Profile)
local RoundState = require(Lib.RoundState)
local Screens = require(Lib.Screens)
local Theme = require(Lib.Theme)
local UiText = require(Lib.UiText)
local World = require(Lib.World)

local HudController = {}

local player = Players.LocalPlayer
local C = Theme.Colors

local DEFAULT_STARS = { 500, 1500, 2500 }

-- Status bar
local statusBar: Frame
local meterFill: Frame
local meterValue: TextLabel
local starTicks: { TextLabel } = {}
local alarmPips: { Frame } = {}
local alarmWord: TextLabel
local timerLabel: TextLabel
local stopAlarmPulse: (() -> ())? = nil
local lastAlarm = 0
local lastTickSecond = -1

-- Other parts
local chipsRow: Frame
local chips: { [string]: { label: TextLabel, endsAt: number, text: string } } = {}
local exitChip: TextLabel? = nil
local crewList: Frame
local crewDirty = true
local carryChip: Frame
local carryText: TextLabel
local carrySub: TextLabel
local pocketRow: Frame
local pocketDots: { Frame } = {}
local strip: Frame
local drivePanel: Frame
local inviteButton: TextButton
local gearButton: TextButton

local lootValues: { [string]: number } = {}

HudController.starThresholds = DEFAULT_STARS

local function stars(): { number }
	return HudController.starThresholds
end

-- ── Status bar ───────────────────────────────────────────────────────────────────────────────────

local function buildStatusBar()
	statusBar = Hud.panel({
		Name = "HeistBar",
		Size = UDim2.fromOffset(340, 62),
		LayoutOrder = 1,
	}, Hud.slot("Status"))
	local back, fill = Hud.bar(statusBar, {
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -96, 0, 12),
		Radius = 6,
	}, Theme.Loot.Medium.color)
	meterFill = fill
	for index = 1, 3 do
		local tick = Hud.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.fromOffset(22, 18),
			Text = "★",
			TextColor3 = C.Dim,
			Display = true,
			MaxTextSize = 18,
			Stroke = 1.5,
		}, statusBar)
		starTicks[index] = tick
		local mark = Hud.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = C.Text,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Name = "Mark" .. index,
		}, back)
		local _ = mark
	end
	meterValue = Hud.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(78, 28),
		Text = "0",
		TextXAlignment = Enum.TextXAlignment.Right,
		Display = true,
		MaxTextSize = 24,
		Stroke = 1.5,
	}, statusBar)
	for index = 1, 3 do
		local pip = Hud.make("Frame", {
			Position = UDim2.fromOffset(10 + (index - 1) * 17, 42),
			Size = UDim2.fromOffset(13, 13),
			BackgroundColor3 = C.Dim,
			BorderSizePixel = 0,
		}, statusBar)
		Hud.corner(pip, 999)
		Hud.stroke(pip, C.Stroke, 1)
		alarmPips[index] = pip
	end
	alarmWord = Hud.text({
		Position = UDim2.fromOffset(64, 38),
		Size = UDim2.fromOffset(150, 20),
		Text = "QUIET",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Alarm[0].color,
		MaxTextSize = 18,
	}, statusBar)
	timerLabel = Hud.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 36),
		Size = UDim2.fromOffset(130, 24),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		Display = true,
		MaxTextSize = 22,
		Stroke = 1.5,
	}, statusBar)
end

local function placeStarTicks()
	local thresholds = stars()
	local top = thresholds[3] or 2500
	local barWidth = 340 - 96
	for index, tick in starTicks do
		local alpha = math.clamp((thresholds[index] or top) / top, 0, 1)
		tick.Position = UDim2.fromOffset(10 + alpha * barWidth, 21)
		local mark = (meterFill.Parent :: Frame):FindFirstChild("Mark" .. index) :: Frame?
		if mark then
			mark.Position = UDim2.fromScale(alpha, 0)
			mark.Visible = index < 3
		end
	end
end

local function refreshLoot(animate: boolean)
	local value = RoundState.number("VanLoot") or 0
	local thresholds = stars()
	local top = thresholds[3] or 2500
	meterFill.Size = UDim2.fromScale(math.clamp(value / top, 0, 1), 1)
	meterValue.Text = Hud.formatNumber(value)
	for index, tick in starTicks do
		local reached = value >= (thresholds[index] or math.huge)
		local was = tick.TextColor3 == C.Gold
		tick.TextColor3 = if reached then C.Gold else C.Dim
		if reached and not was and animate then
			Juice.pop(tick, 1.8)
			Audio.play("StarChime", { pitch = 1 + index * 0.1 })
		end
	end
	if animate then
		Juice.pop(meterValue, 1.2)
	end
end

local function refreshAlarm(animate: boolean)
	local level = RoundState.number("AlarmLevel") or 0
	local style = Theme.Alarm[math.clamp(level, 0, 3)]
	for index, pip in alarmPips do
		pip.BackgroundColor3 = if index <= level then style.color else C.Dim
	end
	local names = (Config.Alarm and Config.Alarm.LevelNames) or {}
	alarmWord.Text = names[level] or style.label
	alarmWord.TextColor3 = style.color
	if level > lastAlarm and animate then
		local pip = alarmPips[math.clamp(level, 1, 3)]
		if pip then
			Juice.pop(pip, 1.4)
		end
		Audio.play("AlarmBeep", { pitch = 0.9 + level * 0.15 })
	end
	if stopAlarmPulse then
		stopAlarmPulse()
		stopAlarmPulse = nil
	end
	if level == 2 then
		stopAlarmPulse = Juice.pulse(alarmWord, 1.2)
	end
	lastAlarm = level
end

local function refreshTimer()
	local seconds, police = RoundState.timer()
	if not seconds then
		timerLabel.Text = ""
		return
	end
	local shown = math.max(0, seconds)
	if police then
		timerLabel.Text = `POLICE {Hud.formatTime(shown)}`
		timerLabel.TextColor3 = C.Danger
		local whole = math.ceil(shown)
		if whole <= 10 and whole > 0 and whole ~= lastTickSecond then
			lastTickSecond = whole
			Audio.play("CountdownTick", { pitch = 1 + (10 - whole) * 0.03 })
			Juice.pop(timerLabel, 1.25)
		end
	else
		timerLabel.Text = Hud.formatTime(shown)
		local shiftLeft = RoundState.left("ShiftChangeAt")
		local amber = (shiftLeft ~= nil and shiftLeft <= 0) or shown <= Theme.UX.ShiftWarning
		timerLabel.TextColor3 = if amber then C.Warn else C.Text
	end
end

-- ── Effect chips (Net `Window`) ──────────────────────────────────────────────────────────────────

local function showChip(kind: string, seconds: number)
	local existing = chips[kind]
	if existing then
		existing.endsAt = os.clock() + seconds
		Juice.pop(existing.label)
		return
	end
	local label = Hud.chip(chipsRow, kind, C.Info, { TextSize = 15 })
	chips[kind] = { label = label, endsAt = os.clock() + seconds, text = kind }
	Juice.pop(label)
end

local function refreshChips()
	local now = os.clock()
	for kind, chip in chips do
		local left = chip.endsAt - now
		if left <= 0 then
			chip.label:Destroy()
			chips[kind] = nil
		else
			chip.label.Text = `{chip.text} {math.ceil(left)}`
			chip.label.TextColor3 = if left <= 3 then C.Danger else C.Info
		end
	end
	-- Maps 2–3: the lockdown exit only arrives at ExitArrivesAt.
	local exitLeft = RoundState.left("ExitArrivesAt")
	if exitLeft and exitLeft > 0 and RoundState.statusMode() == "Heist" then
		if not exitChip then
			exitChip = Hud.chip(chipsRow, "", C.Warn, { TextSize = 15, LayoutOrder = -1 })
		end
		local chip = exitChip :: TextLabel
		chip.Text = `EXIT IN {Hud.formatTime(exitLeft)}`
	elseif exitChip then
		exitChip:Destroy()
		exitChip = nil
	end
	chipsRow.Visible = next(chips) ~= nil or exitChip ~= nil
end

-- ── Crew list ────────────────────────────────────────────────────────────────────────────────────

local function statusOf(p: Player): (string, Color3)
	if RoundState.statusMode() ~= "Heist" and RoundState.activity(p) ~= "Crew" then
		return "", C.Muted
	end
	local character = p.Character
	if not character then
		return "", C.Muted
	end
	local captured = character:GetAttribute("Captured")
	if captured == "Cell" then
		return "CELL", C.Danger
	elseif captured == "Carried" or character:GetAttribute("Caught") == true then
		return "CAUGHT", C.Danger
	end
	if character:GetAttribute("InVan") == true then
		return "VAN", C.Good
	end
	if character:GetAttribute("Hidden") == true then
		return "HIDDEN", C.Muted
	end
	local class = character:GetAttribute("CarryClass")
	if typeof(class) == "string" and class ~= "" then
		local style = Theme.loot(class)
		return style.glyph, style.color
	end
	local pockets = character:GetAttribute("Pockets")
	if typeof(pockets) == "number" and pockets > 0 then
		return `{Theme.Loot.Small.glyph}{pockets}`, Theme.Loot.Small.color
	end
	return "", C.Muted
end

local function rebuildCrew()
	crewDirty = false
	for _, child in crewList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local mode = RoundState.statusMode()
	local list = if mode == "Garage" then Players:GetPlayers() else RoundState.crew()
	for index, p in list do
		local style = Theme.crew(p)
		local row = Hud.panel({
			Size = UDim2.fromOffset(156, 28),
			LayoutOrder = index,
			BackgroundTransparency = 0.35,
			Radius = 8,
		}, crewList)
		Hud.text({
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.fromOffset(20, 22),
			Text = style.glyph,
			TextColor3 = style.color,
			Display = true,
			MaxTextSize = 18,
		}, row)
		Hud.text({
			Position = UDim2.fromOffset(28, 4),
			Size = UDim2.new(1, -84, 0, 20),
			Text = Hud.shortName(p.DisplayName),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if p == player then C.Text else C.Muted,
			MaxTextSize = 16,
		}, row)
		local text, color = statusOf(p)
		Hud.text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 4),
			Size = UDim2.fromOffset(52, 20),
			Text = text,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = color,
			Heavy = true,
			MaxTextSize = 15,
		}, row)

		-- Arrow to a caught teammate (wristband icon), for free players.
		local key = "Caught_" .. p.UserId
		local caught = text == "CELL" or text == "CAUGHT"
		if p ~= player and caught and mode == "Heist" and CharState.captured() == nil then
			if not EdgeArrows.has(key) then
				EdgeArrows.set(key, {
					target = function()
						return EdgeArrows.playerTarget(p)() or World.cellPosition()
					end,
					glyph = "⛓",
					color = C.Danger,
					label = `FREE {string.upper(Hud.shortName(p.DisplayName, 8))}`,
				})
			end
		elseif EdgeArrows.has(key) then
			EdgeArrows.clear(key)
		end
	end
end

-- ── Carry chip, pockets and the key-cap strip ────────────────────────────────────────────────────

local function refreshCarry()
	local class = CharState.get("CarryClass")
	local carrying = typeof(class) == "string" and class ~= "" and class ~= "Small"
	carryChip.Visible = carrying and RoundState.statusMode() == "Heist"
	if carrying then
		local style = Theme.loot(class)
		local name = CharState.get("CarryLoot")
		local displayName = if typeof(name) == "string" and name ~= "" then name else style.label
		local value = lootValues[displayName]
		local valueText = if value then "  " .. Hud.formatNumber(value) else ""
		carryText.Text = `{style.glyph} {string.upper(displayName)}{valueText}`
		carryText.TextColor3 = style.color
		local _, role = CharState.carry()
		local partnerId = CharState.get("CarryPartner")
		local partner = if typeof(partnerId) == "number" and partnerId ~= 0
			then Players:GetPlayerByUserId(partnerId)
			else nil
		local heavy = class == "Heavy" or class == "Main"
		local weight = if heavy then "●●○" else "●○○"
		local sub = weight
		local subColor = C.Muted
		if partner then
			local crew = Theme.crew(partner)
			sub = if role == "Help"
				then `HELPING {string.upper(Hud.shortName(partner.DisplayName, 8))} {crew.glyph}`
				else `WITH {string.upper(Hud.shortName(partner.DisplayName, 8))} {crew.glyph}`
			subColor = crew.color
		elseif CharState.get("Rolling") == true then
			sub = weight .. "  ROLLING · LOUD"
			subColor = C.Warn
		end
		carrySub.Text = sub
		carrySub.TextColor3 = subColor
	end
end

local function refreshPockets()
	local count = CharState.pockets()
	local slots = math.max(3, count)
	local show = RoundState.statusMode() == "Heist"
		and RoundState.activity() ~= "Garage"
		and CharState.captured() == nil
	pocketRow.Visible = show
	for index = 1, 4 do
		local dot = pocketDots[index]
		dot.Visible = index <= slots
		local filled = index <= count
		dot.BackgroundColor3 = if filled then Theme.Loot.Small.color else C.Panel
		dot.BackgroundTransparency = if filled then 0 else 0.4
	end
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

local function stripRow(
	parent: Instance,
	order: number,
	key: string,
	text: string,
	color: Color3?,
	selected: boolean?
)
	local row = Hud.frame({
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order,
	}, parent)
	Hud.list(
		row,
		Enum.FillDirection.Horizontal,
		6,
		Enum.HorizontalAlignment.Right,
		Enum.VerticalAlignment.Center
	)
	Hud.keycap(row, key, 26).LayoutOrder = 1
	local chip = Hud.chip(
		row,
		text,
		color or C.Text,
		{ LayoutOrder = 2, TextSize = 16, Size = UDim2.fromOffset(0, 28) }
	)
	if selected then
		local stroke = chip:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = C.Gold
			stroke.Transparency = 0
			stroke.Thickness = 2
		end
	end
end

local function refreshStrip()
	for _, child in strip:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local input = Device.input()
	local show = input ~= "Touch" and RoundState.statusMode() == "Heist" and not Screens.isOpen()
	strip.Visible = show
	if not show then
		return
	end
	local gamepad = input == "Gamepad"
	local mode = ClientState.mode
	if mode == "Cell" or mode == "Carried" or mode == "Spectate" then
		return
	end
	local carry, role = CharState.carry()
	if carry then
		if role == "Help" then
			stripRow(strip, 2, if gamepad then "X" else "G", "LET GO", C.Muted)
			return
		end
		stripRow(strip, 2, if gamepad then "X" else "G", "DROP", C.Muted)
		if carry == "Medium" then
			stripRow(strip, 1, if gamepad then "R2" else "LMB", "HOLD · THROW", Theme.Loot.Medium.color)
		else
			local rolling = CharState.get("Rolling") == true
			stripRow(
				strip,
				1,
				if gamepad then "R2" else "LMB",
				if rolling then "STOP ROLL" else "ROLL",
				Theme.Loot.Heavy.color
			)
		end
		return
	end
	local list = gadgetList()
	local slot = 0
	for index, name in list do
		if name ~= "Crowbar" then
			slot += 1
			local charges = player:GetAttribute("Charges_" .. name)
			local entry = UiText.gadget(name)
			local chargeText = if typeof(charges) == "number" and charges >= 0 then ` ×{charges}` else ""
			local key = if gamepad then (if slot == 1 then "LB" else "") else tostring(index)
			stripRow(
				strip,
				10 + index,
				if key == "" then "·" else key,
				string.upper(entry.name) .. chargeText,
				nil,
				index == ClientState.selectedSlot
			)
		end
	end
	if slot > 0 then
		stripRow(strip, 1, if gamepad then "R2" else "LMB", "USE GADGET", C.Accent)
	end
end

-- ── Drive panel (inside the van zone) ────────────────────────────────────────────────────────────

local function refreshDrive()
	for _, child in drivePanel:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local show = RoundState.statusMode() == "Heist" and CharState.get("InVan") == true
	drivePanel.Visible = show
	if not show then
		return
	end
	for index, p in RoundState.crew() do
		local character = p.Character
		local text, color
		if character and character:GetAttribute("InVan") == true then
			text, color = `✓ {Hud.shortName(p.DisplayName, 8)}`, C.Good
		elseif
			character
			and (character:GetAttribute("Captured") ~= nil or character:GetAttribute("Caught") == true)
		then
			text, color = `⛓ {Hud.shortName(p.DisplayName, 8)}`, C.Danger
		else
			text, color = `… {Hud.shortName(p.DisplayName, 8)}`, C.Warn
		end
		Hud.chip(drivePanel, text, color, { LayoutOrder = index, TextSize = 14 })
	end
end

-- ── Van arrow, lockdown sweep, visibility ────────────────────────────────────────────────────────

local function refreshVanArrow()
	local mode = RoundState.statusMode()
	local carrying = CharState.carry() ~= nil or CharState.pockets() > 0
	local want = mode == "Heist"
		and (carrying or RoundState.isLoud())
		and CharState.captured() == nil
		and CharState.get("InVan") ~= true
	if want and not EdgeArrows.has("Van") then
		EdgeArrows.set("Van", { target = World.vanPosition, glyph = "▣", color = C.Good, label = "VAN" })
	elseif not want and EdgeArrows.has("Van") then
		EdgeArrows.clear("Van")
	end
end

local loudShown = false
local function refreshLoud()
	local loud = RoundState.isLoud() and RoundState.statusMode() == "Heist"
	if loud ~= loudShown then
		loudShown = loud
		Juice.edgeSweep(loud)
		Audio.loop("SirenLoop", loud)
	end
end

local function refreshVisibility()
	local mode = RoundState.statusMode()
	statusBar.Visible = mode == "Heist"
	inviteButton.Visible = mode ~= "Heist"
	refreshCarry()
	refreshPockets()
	refreshStrip()
	refreshDrive()
	refreshVanArrow()
	refreshLoud()
	crewDirty = true
end

-- ── Build ────────────────────────────────────────────────────────────────────────────────────────

function HudController:Init()
	buildStatusBar()

	chipsRow = Hud.frame({
		Name = "Chips",
		Size = UDim2.fromOffset(340, 26),
		LayoutOrder = 2,
		Visible = false,
	}, Hud.slot("Status"))
	Hud.list(chipsRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)

	drivePanel = Hud.frame({
		Name = "DrivePanel",
		Size = UDim2.fromOffset(340, 26),
		LayoutOrder = 4,
		Visible = false,
	}, Hud.slot("Status"))
	Hud.list(drivePanel, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center)

	-- Right column: invite + gear, crew list.
	local topRow = Hud.frame({
		Name = "TopRow",
		Size = UDim2.fromOffset(156, 48),
		LayoutOrder = 1,
	}, Hud.slot("Right"))
	Hud.list(topRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
	inviteButton = Hud.button({
		Name = "Invite",
		Size = UDim2.fromOffset(48, 48),
		Text = "+",
		Kind = "ghost",
		LayoutOrder = 1,
		MaxTextSize = 30,
	}, topRow)
	inviteButton.Activated:Connect(function()
		local ok = pcall(function()
			SocialService:PromptGameInvite(player)
		end)
		if not ok then
			Hud.toast("Invites work in the live game", C.Muted)
		end
	end)
	gearButton = Hud.button({
		Name = "Gear",
		Size = UDim2.fromOffset(48, 48),
		Text = "⚙",
		Kind = "ghost",
		LayoutOrder = 2,
		MaxTextSize = 28,
	}, topRow)
	gearButton.Activated:Connect(function()
		Screens.open("Settings")
	end)

	crewList = Hud.frame({
		Name = "CrewList",
		Size = UDim2.fromOffset(156, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, Hud.slot("Right"))
	Hud.list(crewList, Enum.FillDirection.Vertical, 3, Enum.HorizontalAlignment.Right)

	-- Bottom: carry chip and pockets.
	carryChip = Hud.panel({
		Name = "Carry",
		Size = UDim2.fromOffset(280, 50),
		LayoutOrder = 1,
		Visible = false,
	}, Hud.slot("Bottom"))
	carryText = Hud.text({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 24),
		Text = "",
		Display = true,
		MaxTextSize = 22,
		Stroke = 1.5,
	}, carryChip)
	carrySub = Hud.text({
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "",
		TextColor3 = C.Muted,
		MaxTextSize = 15,
	}, carryChip)
	pocketRow = Hud.frame({
		Name = "Pockets",
		Size = UDim2.fromOffset(140, 26),
		LayoutOrder = 2,
		Visible = false,
	}, Hud.slot("Bottom"))
	Hud.list(
		pocketRow,
		Enum.FillDirection.Horizontal,
		8,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	for index = 1, 4 do
		local dot = Hud.make("Frame", {
			Name = "Pocket" .. index,
			Size = UDim2.fromOffset(22, 22),
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, pocketRow)
		Hud.corner(dot, 999)
		Hud.make("UIStroke", { Color = Theme.Loot.Small.color, Thickness = 2, Transparency = 0.2 }, dot)
		pocketDots[index] = dot
	end
	HudController.pocketTarget = pocketRow

	strip = Hud.slot("Strip")
end

HudController.pocketTarget = nil :: Frame?

-- Where flying "+150" numbers should land.
function HudController.meterTarget(): GuiObject?
	return meterValue
end

function HudController.rememberLoot(name: string, value: number)
	lootValues[name] = value
	refreshCarry()
end

function HudController.setStars(thresholds: { number })
	if #thresholds >= 3 then
		HudController.starThresholds = thresholds
		placeStarTicks()
		refreshLoot(false)
	end
end

function HudController:Start()
	placeStarTicks()
	refreshLoot(false)
	refreshAlarm(false)
	refreshTimer()
	refreshVisibility()

	RoundState.Changed:Connect(function(name)
		if name == "VanLoot" then
			refreshLoot(true)
		elseif name == "AlarmLevel" then
			refreshAlarm(true)
		elseif name == "RoundPhase" or name == "Approach" then
			if name == "RoundPhase" and RoundState.phase() == "Briefing" then
				HudController.starThresholds = DEFAULT_STARS
				placeStarTicks()
				refreshLoot(false)
				lastAlarm = 0
				lastTickSecond = -1
			end
			refreshVisibility()
		end
	end)
	CharState.Changed:Connect(function(name)
		if name == "Player:Activity" then
			refreshVisibility()
			return
		end
		if
			name == "Player:Gadgets"
			or name == "Player:Loadout"
			or string.sub(name, 1, 15) == "Player:Charges_"
		then
			refreshStrip()
			return
		end
		if string.sub(name, 1, 7) == "Player:" then
			return -- other player attributes (DroneBattery, Cash…) don't change the heist HUD
		end
		refreshCarry()
		refreshPockets()
		refreshStrip()
		refreshDrive()
		refreshVanArrow()
		crewDirty = true
	end)
	ClientState.Changed:Connect(function(key)
		if key == "selectedSlot" or key == "mode" or key == "drone" then
			refreshStrip()
		end
	end)
	Hud.LoadoutChanged:Connect(refreshStrip)
	Device.Changed:Connect(function(what)
		if what == "input" then
			refreshStrip()
		end
	end)
	Screens.Changed:Connect(refreshStrip)

	Net.on("Window", function(kind: any, seconds: any)
		if typeof(kind) == "string" and typeof(seconds) == "number" then
			showChip(kind, seconds)
		end
	end)
	Net.on("LootPicked", function(_userId: any, lootName: any, _class: any, value: any)
		if typeof(lootName) == "string" and typeof(value) == "number" then
			HudController.rememberLoot(lootName, value)
		end
	end)

	-- Crew list follows everyone's attributes.
	local function watchPlayer(p: Player)
		p.AttributeChanged:Connect(function()
			crewDirty = true
		end)
		local function watchCharacter(character: Model)
			character.AttributeChanged:Connect(function(name)
				if name == "InVan" or name == "Captured" or name == "Caught" then
					refreshDrive()
				end
				crewDirty = true
			end)
			crewDirty = true
		end
		p.CharacterAdded:Connect(watchCharacter)
		if p.Character then
			watchCharacter(p.Character)
		end
	end
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(p)
		EdgeArrows.clear("Caught_" .. p.UserId)
		crewDirty = true
	end)
	Profile.Changed:Connect(function(what)
		if what == "save" and Profile.saveStatus == "Trouble" then
			Hud.toast("Saving is slow. Your progress is safe.", C.Warn)
		end
	end)

	while true do
		refreshTimer()
		refreshChips()
		if crewDirty then
			rebuildCrew()
		end
		task.wait(0.2)
	end
end

return HudController
