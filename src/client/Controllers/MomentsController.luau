--!strict
-- Moments (beta-spec-ux §4): server events become feedback within 100 ms — pops, sounds, banners,
-- stamps — plus the job card (§1.6), the objectives list, the Gouda beacon and the getaway.
-- Missing an event is only cosmetic: state always comes from attributes (HudController).

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Audio = require(Lib.Audio)
local CharState = require(Lib.CharState)
local ClientState = require(Lib.ClientState)
local EdgeArrows = require(Lib.EdgeArrows)
local Hud = require(Lib.Hud)
local Juice = require(Lib.Juice)
local RoundState = require(Lib.RoundState)
local Screens = require(Lib.Screens)
local Theme = require(Lib.Theme)
local UiScale = require(Lib.UiScale)
local UiText = require(Lib.UiText)
local World = require(Lib.World)

local HudController = require(script.Parent.HudController)
local OnboardingController = require(script.Parent.OnboardingController)

local MomentsController = {}

local player = Players.LocalPlayer
local C = Theme.Colors

MomentsController.lastCapture = nil :: any
MomentsController.lastCaptureAt = 0

local goudaLiftedAt = -math.huge
local bankStreakAt = -math.huge
local bankStreak = 0
local objectivesPanel: Frame
local objectiveRows: { [string]: TextLabel } = {}
local jobCard: Frame? = nil
local goudaBeam: Part? = nil

local function isMe(userId: any): boolean
	return userId == player.UserId
end

local function playerOf(userId: any): Player?
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function nameOf(userId: any): string
	local p = playerOf(userId)
	return if p then string.upper(Hud.shortName(p.DisplayName, 10)) else "SOMEONE"
end

local function characterOf(userId: any): Model?
	local p = playerOf(userId)
	return p and p.Character
end

local function lootSound(name: string, class: string?): string
	local n = string.lower(name)
	if string.find(n, "cube") then
		return "PickupCube"
	elseif string.find(n, "jar") or string.find(n, "coin") then
		return "PickupCoins"
	elseif string.find(n, "drawer") or string.find(n, "cash") then
		return "PickupDrawer"
	elseif class == "Main" or string.find(n, "gouda") then
		return "PickupGouda"
	end
	return "PickupWheel"
end

-- ── Loot ─────────────────────────────────────────────────────────────────────────────────────────

local function onLootPicked(userId: any, lootName: any, class: any, value: any)
	if not isMe(userId) then
		return
	end
	local name = if typeof(lootName) == "string" then lootName else "Loot"
	local cls = if typeof(class) == "string" then class else "Small"
	local character = player.Character
	Audio.play(lootSound(name, cls))
	if cls == "Small" then
		if character and typeof(value) == "number" then
			Juice.worldPop(`+{Hud.formatNumber(value)}`, C.Muted, character, { size = 28, hold = 0.4 })
		end
		local target = HudController.pocketTarget
		if target then
			local root = CharState.root()
			local from = root and Juice.screenPoint(root.Position)
			Juice.flyTo(Theme.Loot.Small.glyph, Theme.Loot.Small.color, from, target, 0.25)
		end
		return
	end
	local heavy = cls == "Heavy" or cls == "Main"
	if character then
		Juice.worldPop(
			if heavy then "HEAVY!!" else "HEAVY!",
			Theme.loot(cls).color,
			character,
			{ big = heavy, hold = 0.6 }
		)
	end
	Juice.cameraDip(if heavy then 0.45 else 0.3)
	Audio.play("Grunt")
	if cls == "Medium" then
		OnboardingController.tip("ThrowIt")
	elseif heavy and CharState.get("CarryPartner") == nil then
		OnboardingController.tip("LiftTogether")
	end
end

local function onLootBanked(userId: any, lootName: any, a: any, b: any, c: any)
	-- Payload: (userId, lootName, class, value, vanTotal); older drafts send (userId, lootName, value, vanTotal).
	local value = if typeof(a) == "number" then a elseif typeof(b) == "number" then b else nil
	local _ = c
	local _name = lootName
	if not value then
		return
	end
	local now = os.clock()
	if now - bankStreakAt <= 2 then
		bankStreak = math.min(bankStreak + 1, 5)
	else
		bankStreak = 0
	end
	bankStreakAt = now
	Audio.play("KaChing", { pitch = 1 + bankStreak * 0.05 })
	local van = World.vanPosition()
	local from = van and Juice.screenPoint(van + Vector3.new(0, 3, 0))
	if isMe(userId) then
		Juice.flyTo(`+{Hud.formatNumber(value)}`, C.Gold, from, HudController.meterTarget(), 0.5)
	else
		local p = playerOf(userId)
		local color = Theme.crew(p).color
		Juice.flyTo(
			`+{Hud.formatNumber(value)} {nameOf(userId)}`,
			color,
			from,
			HudController.meterTarget(),
			0.5
		)
	end
end

local function onLootThrown(userId: any)
	local character = characterOf(userId)
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			Audio.playAt("Throw", root)
		end
	end
end

local function onLootCaught(userId: any)
	local character = characterOf(userId)
	if character then
		Juice.worldPop("CATCH!", C.Good, character, { hold = 0.4 })
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			Audio.playAt("Catch", root)
		end
	end
end

local function onLootDropped(userId: any, _lootName: any, position: any)
	local class = if isMe(userId) then CharState.get("CarryClass") else nil
	local key = if class == "Heavy" or class == "Main" then "DropHeavy" else "DropLight"
	if typeof(position) == "Vector3" then
		Audio.playAt(key, position)
	elseif isMe(userId) then
		Audio.play(key)
	end
end

local function onLootDamaged(lootName: any, _value: any, pct: any)
	local left = if typeof(pct) == "number" then pct else nil
	local name = if typeof(lootName) == "string" then string.upper(lootName) else "LOOT"
	local text = if left
		then `{name} CRACKED · {math.floor((if left <= 1 then left * 100 else left) + 0.5)}% LEFT`
		else `{name} CRACKED`
	Hud.toast(text, C.Danger, "✕")
	Audio.play("FragileCrack")
end

-- ── Danger: spotted, captured, rescued ───────────────────────────────────────────────────────────

local BY_TEXT: { [string]: string } = {
	guard = "A GUARD",
	camera = "A CAMERA",
	dog = "BOEF",
	snitch = "A SNITCH",
}

local function onSpotted(userId: any, by: any)
	if isMe(userId) then
		Juice.edgeFlash(C.Danger, 0.3)
		Audio.play("Spotted")
		if CharState.carry() then
			OnboardingController.tip("SpottedDropRun")
		else
			OnboardingController.tip("HideBarrel")
		end
	else
		local who = BY_TEXT[if typeof(by) == "string" then by else "guard"] or "A GUARD"
		Hud.toast(`{who} SPOTTED {nameOf(userId)}`, C.Danger, "!")
	end
end

local function onCaptured(userId: any, stage: any)
	local s = if typeof(stage) == "string" then stage else "grabbed"
	if isMe(userId) then
		if s == "grabbed" then
			Juice.hitstop(0.08)
			Hud.stamp("CAUGHT!", C.Danger, 1, -8)
			Audio.play("Captured")
			OnboardingController.tip("BubbleHim")
		elseif s == "dropped" then
			Hud.banner("YOU'RE LOOSE!", C.Good, 1.5, "RUN!")
		end
		return
	end
	local character = characterOf(userId)
	if s == "grabbed" then
		Hud.toast(`{nameOf(userId)} CAUGHT`, C.Danger, "⛓")
		OnboardingController.tip("FreeAtCell")
	elseif s == "dropped" then
		if character then
			Juice.worldPop("DROPPED!", C.Good, character)
		end
		Hud.toast(`{nameOf(userId)} IS LOOSE!`, C.Good)
	end
end

local function onRescued(userId: any, rescuerId: any, how: any)
	local captive = characterOf(userId)
	if captive then
		Juice.worldPop("FREE!", C.Good, captive)
	end
	if how == "grate" then
		Hud.toast(`{nameOf(userId)} CRAWLED OUT`, C.Good)
		Audio.play("GrateCrawl")
		return
	end
	local rescuer = characterOf(rescuerId)
	if rescuer then
		Juice.worldPop("HERO", C.Gold, rescuer, { offset = 3.5 })
	end
	if typeof(rescuerId) == "number" and rescuerId ~= 0 then
		Hud.toast(`{nameOf(rescuerId)} FREED {nameOf(userId)}`, C.Good)
	end
	Audio.play("CellDoor")
	task.delay(0.3, function()
		Audio.play("Rescue")
	end)
end

-- ── Round moments ────────────────────────────────────────────────────────────────────────────────

local function clearGouda()
	EdgeArrows.clear("Gouda")
	if goudaBeam then
		goudaBeam:Destroy()
		goudaBeam = nil
	end
end

local function onGoudaLifted(userId: any)
	goudaLiftedAt = os.clock()
	clearGouda()
	local character = characterOf(userId)
	if character then
		Juice.worldPop("GOLDEN GOUDA!", C.Gold, character, { big = true, hold = 1 })
	end
	task.delay(0.6, function()
		Audio.play("GoudaDing")
	end)
end

local function onLockdown(_endsAt: any, _reason: any)
	local wait = math.max(0, 1.2 - (os.clock() - goudaLiftedAt))
	task.delay(wait, function()
		Hud.banner("LOCKDOWN", C.Danger, 1.5, "GET TO THE VAN")
	end)
end

local function onShiftChange(endsAt: any)
	local left = if typeof(endsAt) == "number" and endsAt > 1e6 then endsAt - RoundState.now() else 60
	Hud.banner(`SHIFT CHANGE IN {math.max(0, math.floor(left + 0.5))}`, C.Warn, 2.5)
	Audio.play("ShiftChime")
end

local function onDriveWarning(userIds: any)
	local count = if typeof(userIds) == "table" then #userIds else 1
	Hud.banner(`LEAVES {count} BEHIND`, C.Warn, 2.5, "HOLD AGAIN TO GO")
end

local function takeCapture()
	MomentsController.lastCapture = nil
	pcall(function()
		(CaptureService :: any):TakeScreenshotCaptureAsync(function(capture: any)
			MomentsController.lastCapture = capture
			MomentsController.lastCaptureAt = os.clock()
		end)
	end)
end

local function onEscaped(secondsLeft: any)
	local left = if typeof(secondsLeft) == "number" then secondsLeft else 99
	local lastSecond = (Config :: any).Round and (Config :: any).Round.JustMadeItSeconds
		or Theme.UX.LastSecond
	if left <= lastSecond then
		Juice.slowmo(1.2)
		Hud.banner("JUST MADE IT!", C.Gold, 2.2)
		Audio.play("JustMadeIt")
		task.delay(0.4, takeCapture)
	else
		Hud.banner("CLEAN GETAWAY!", C.Good, 2)
	end
end

local function onBusted()
	Hud.stamp("BUSTED", C.Danger, 1.5, -6)
end

-- ── NPCs and gadgets ─────────────────────────────────────────────────────────────────────────────

local function where(a: any, b: any): Vector3?
	if typeof(b) == "Vector3" then
		return b
	elseif typeof(a) == "Vector3" then
		return a
	end
	local character = characterOf(a)
	return if character then character:GetPivot().Position else nil
end

local function onSneeze(userId: any, position: any)
	local pos = where(userId, position)
	if pos then
		Juice.worldPop("ACHOO!", C.Text, pos, { big = true, hold = 0.6 })
		Audio.playAt("Sneeze", pos)
	end
end

local function onBark(_kind: any, position: any)
	local pos = where(_kind, position)
	if pos then
		Juice.worldPop("WOOF!", C.Warn, pos, { hold = 0.4, offset = 2 })
		Audio.playAt("BoefBark", pos)
	end
end

local function onKarel(line: any, position: any)
	local pos = where(nil, position)
	local text = if typeof(line) == "string" and line ~= "" then line else "WHO LEFT THIS OPEN?!"
	if pos then
		Juice.worldPop(string.upper(text), C.Text, pos, { size = 26, hold = 2, rise = 0.5, offset = 3.5 })
		Audio.playAt("KarelShout", pos)
	end
end

local function onRadioCheck(guardPos: any, endsAt: any)
	Hud.toast("RADIO CHECK! Hold ANSWER", C.Warn, "☎")
	if typeof(guardPos) == "Vector3" then
		EdgeArrows.set("Radio", {
			target = function()
				return guardPos
			end,
			glyph = "☎",
			color = C.Warn,
			label = "ANSWER",
		})
		local seconds = if typeof(endsAt) == "number" and endsAt > 1e6 then endsAt - RoundState.now() else 6
		task.delay(math.clamp(seconds, 1, 10), function()
			EdgeArrows.clear("Radio")
		end)
	end
end

local ALARM_REASONS: { [string]: string } = {
	CameraSpotted = "camera saw someone",
	GuardAlert = "guard spotted someone",
	CrackHeard = "CRACK was heard",
	NoisemakerRepeat = "same trick twice",
	PrankUsed = "angry guard",
	TraceFound = "Karel found a trace",
}

-- ── Job card, objectives, Gouda beacon ───────────────────────────────────────────────────────────

local function closeJobCard()
	local card = jobCard
	jobCard = nil
	if card then
		local fade = TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		for _, d in card:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			end
		end
		fade:Play()
		task.delay(0.35, function()
			card:Destroy()
		end)
	end
end

local function showGouda(position: Vector3?)
	clearGouda()
	local function target(): Vector3?
		return position or World.goudaPosition()
	end
	if position then
		local beam = Instance.new("Part")
		beam.Name = "GoudaBeam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Shape = Enum.PartType.Cylinder
		beam.Material = Enum.Material.Neon
		beam.Color = C.Gold
		beam.Transparency = 0.35
		beam.Size = Vector3.new(60, 1.4, 1.4)
		beam.CFrame = CFrame.new(position + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Parent = workspace.CurrentCamera
		goudaBeam = beam
		task.delay(4, function()
			if goudaBeam == beam then
				beam:Destroy()
				goudaBeam = nil
			end
		end)
	end
	EdgeArrows.set(
		"Gouda",
		{ target = target, glyph = Theme.Loot.Main.glyph, color = C.Gold, label = "GOUDA" }
	)
end

local function onJobCard(card: any)
	if typeof(card) ~= "table" then
		return
	end
	closeJobCard()
	local thresholds = {}
	if typeof(card.stars) == "table" then
		for _, v in card.stars do
			if typeof(v) == "number" then
				table.insert(thresholds, v)
			end
		end
	end
	if #thresholds >= 3 then
		HudController.setStars(thresholds)
	end
	local t = HudController.starThresholds

	local layer = UiScale.root("Overlay")
	local panel = Hud.panel({
		Name = "JobCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.1,
		Radius = 14,
	}, layer)
	Hud.stroke(panel, C.Gold, 2, 0.3)
	Hud.padding(panel, 12, 10)
	Hud.list(panel, Enum.FillDirection.Vertical, 6)
	jobCard = panel
	local heistName = if typeof(card.heistName) == "string"
		then card.heistName
		else UiText.heist(card.heistId or RoundState.get("HeistId")).name
	Hud.text({
		Size = UDim2.new(1, 0, 0, 34),
		Text = string.upper(heistName),
		Display = true,
		MaxTextSize = 30,
		TextColor3 = C.Gold,
		LayoutOrder = 1,
	}, panel)
	local pills = Hud.frame({ Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 2 }, panel)
	Hud.list(
		pills,
		Enum.FillDirection.Horizontal,
		6,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	local tier = if typeof(card.difficulty) == "string" then card.difficulty else "Normal"
	local tierInfo = (UiText.Tiers :: any)[tier]
	local mainName = if typeof(card.mainLootName) == "string" and card.mainLootName ~= ""
		then card.mainLootName
		else "Golden Gouda"
	local mainShort = string.upper((string.gsub(mainName, "^Golden ", "")))
	Hud.chip(pills, if tierInfo then tierInfo.name else string.upper(tier), C.Text, { LayoutOrder = 1 })
	local modifierId = card.modifierId or card.modifier
	if card.isHotJob == true then
		Hud.chip(pills, "HOT JOB", C.Gold, { LayoutOrder = 3 })
	end
	if typeof(modifierId) == "string" and modifierId ~= "" then
		local mod = UiText.modifier(modifierId)
		Hud.chip(pills, string.upper(mod.name), C.Accent, { LayoutOrder = 2 })
		if mod.line ~= "" then
			Hud.text({
				Size = UDim2.new(1, 0, 0, 20),
				Text = mod.line,
				TextColor3 = C.Muted,
				MaxTextSize = 17,
				LayoutOrder = 3,
			}, panel)
		end
	end
	Hud.text({
		Size = UDim2.new(1, 0, 0, 22),
		Text = `★ {Hud.formatNumber(t[1])} · ★★ {Hud.formatNumber(t[2])} · ★★★ {mainShort} + {Hud.formatNumber(
			t[3]
		)}`,
		MaxTextSize = 18,
		LayoutOrder = 4,
	}, panel)
	local mainZone = card.mainZone or card.goudaZone
	if typeof(mainZone) == "string" and mainZone ~= "" then
		Hud.text({
			Size = UDim2.new(1, 0, 0, 20),
			Text = `{Theme.Loot.Main.glyph} {mainName}: {mainZone}`,
			TextColor3 = C.Gold,
			MaxTextSize = 17,
			LayoutOrder = 5,
		}, panel)
	end
	local extras = {}
	if typeof(card.lockedEntrances) == "table" and #card.lockedEntrances > 0 then
		table.insert(extras, `{#card.lockedEntrances} doors locked`)
	end
	if card.secondExit == true then
		table.insert(extras, "boat exit open")
	end
	if #extras > 0 then
		Hud.text({
			Size = UDim2.new(1, 0, 0, 18),
			Text = table.concat(extras, " · "),
			TextColor3 = C.Muted,
			MaxTextSize = 15,
			LayoutOrder = 6,
		}, panel)
	end
	if typeof(card.objectives) == "table" and #card.objectives > 0 then
		local names = {}
		for _, objective in card.objectives do
			local id = if typeof(objective) == "table"
				then (objective.type or objective.id or objective.Id)
				else objective
			table.insert(names, UiText.pretty(id))
		end
		Hud.text({
			Size = UDim2.new(1, 0, 0, 18),
			Text = "Objectives: " .. table.concat(names, ", "),
			TextColor3 = C.Info,
			MaxTextSize = 15,
			LayoutOrder = 7,
		}, panel)
	end
	Juice.pop(panel, 1.1)
	local mainPos = card.mainPos or card.goudaPos
	showGouda(if typeof(mainPos) == "Vector3" then mainPos else nil)

	-- Visible 4 s; fades on the first movement after 1.5 s.
	local shownAt = os.clock()
	local root = CharState.root()
	local start = root and root.Position
	task.spawn(function()
		while jobCard == panel do
			local elapsed = os.clock() - shownAt
			local r = CharState.root()
			local moved = start and r and (r.Position - start).Magnitude > 3
			if elapsed >= 4 or (elapsed >= 1.5 and moved) then
				closeJobCard()
				break
			end
			task.wait(0.1)
		end
	end)
end

-- Objective states (contracts §1.2): Locked · Active · Running · Jammed · Done · Failed.
local OBJECTIVE_DONE = { done = true, Done = true, complete = true, Complete = true, completed = true }

local function onObjective(id: any, state: any, data: any)
	if typeof(id) ~= "string" then
		return
	end
	local row = objectiveRows[id]
	if not row then
		row = Hud.chip(
			objectivesPanel,
			"",
			C.Text,
			{ TextSize = 14, LayoutOrder = #objectivesPanel:GetChildren() }
		)
		objectiveRows[id] = row
	end
	local d = if typeof(data) == "table" then data else {}
	local name = if typeof(d.name) == "string" then d.name else UiText.pretty(id)
	local s = if typeof(state) == "string" then state else ""
	if OBJECTIVE_DONE[s] then
		row.Text = `✓ {name}`
		row.TextColor3 = C.Good
	elseif string.lower(s) == "jammed" then
		row.Text = `! {name} JAMMED`
		row.TextColor3 = C.Danger
		Audio.play("AlarmBeep", { pitch = 1.4 })
	elseif string.lower(s) == "failed" then
		row.Text = `✕ {name}`
		row.TextColor3 = C.Danger
	elseif string.lower(s) == "locked" then
		row.Text = `🔒 {name}`
		row.TextColor3 = C.Muted
	elseif typeof(d.progress) == "number" then
		row.Text = `{name} {math.floor(d.progress * (if d.progress <= 1 then 100 else 1))}%`
		row.TextColor3 = C.Text
	else
		row.Text = name
		row.TextColor3 = C.Muted
	end
	objectivesPanel.Visible = true
end

local function resetRound()
	for _, row in objectiveRows do
		row:Destroy()
	end
	table.clear(objectiveRows)
	objectivesPanel.Visible = false
	clearGouda()
	EdgeArrows.clear("Radio")
end

function MomentsController:Init()
	objectivesPanel = Hud.frame({
		Name = "Objectives",
		Size = UDim2.fromOffset(156, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Visible = false,
	}, Hud.slot("Right"))
	Hud.list(objectivesPanel, Enum.FillDirection.Vertical, 3, Enum.HorizontalAlignment.Right)
end

function MomentsController:Start()
	Net.on("Toast", function(message: any)
		if typeof(message) == "string" then
			Hud.toast(message)
		end
	end)
	Net.on("LootPicked", onLootPicked)
	Net.on("LootBanked", onLootBanked)
	Net.on("LootThrown", onLootThrown)
	Net.on("LootCaught", onLootCaught)
	Net.on("LootDropped", onLootDropped)
	Net.on("LootDamaged", onLootDamaged)
	Net.on("LootReturned", function()
		Hud.toast("KAREL TOOK IT BACK", C.Warn, "⌂")
		Audio.play("KarelTsk")
	end)
	Net.on("Spotted", onSpotted)
	Net.on("Captured", onCaptured)
	Net.on("Rescued", onRescued)
	Net.on("MainLootLifted", onGoudaLifted)
	Net.on("GoudaLifted", onGoudaLifted) -- older name
	Net.on("Lockdown", onLockdown)
	Net.on("ShiftChange", onShiftChange)
	Net.on("DriveWarning", onDriveWarning)
	Net.on("Escaped", onEscaped)
	Net.on("Busted", onBusted)
	Net.on("Sneeze", onSneeze)
	Net.on("BoefBark", onBark)
	Net.on("KarelShout", onKarel)
	Net.on("RadioCheck", onRadioCheck)
	Net.on("JobCard", onJobCard)
	Net.on("Objective", onObjective)

	Net.on("Alarm", function(_points: any, _level: any, reason: any, added: any)
		if typeof(added) == "number" and added > 0 then
			local why = ALARM_REASONS[if typeof(reason) == "string" then reason else ""] or ""
			Hud.toast(if why ~= "" then `+{added} ALARM · {why}` else `+{added} ALARM`, C.Warn)
		end
	end)
	Net.on("Crack", function(position: any, heard: any, _name: any)
		if typeof(position) == "Vector3" then
			local loud = typeof(heard) == "number" and heard > 0
			Juice.worldPop("CRACK!", if loud then C.Danger else C.Text, position, { hold = 0.5 })
			Audio.playAt("Crack", position)
			if loud then
				Hud.toast("A guard heard the CRACK", C.Danger, "!")
			end
		end
	end)
	Net.on("EMP", function(position: any, _radius: any, _cams: any, _lamps: any, drones: any)
		if typeof(position) == "Vector3" then
			Juice.worldPop("BZZT!", C.Info, position, { big = true, hold = 0.5 })
			Audio.playAt("Bzzt", position)
		end
		if
			typeof(drones) == "table"
			and (table.find(drones, player.Name) or table.find(drones, player.UserId))
		then
			Hud.banner("Oops. EMP hits YOUR stuff too.", C.Info, 2.5)
		end
	end)
	Net.on("RankUp", function(newRank: any, title: any)
		if Screens.current() == "Payout" then
			return
		end
		local sub = if typeof(title) == "string" then `Rank {newRank} · {title}` else `Rank {newRank}`
		Hud.banner("RANK UP!", C.Gold, 2.5, sub)
		Audio.play("RankUpFanfare")
	end)

	-- Mask Up: "SHING".
	CharState.Changed:Connect(function(name)
		if name == "Masked" and CharState.get("Masked") == true then
			local character = CharState.character()
			if character then
				Juice.worldPop("SHING!", C.Text, character, { size = 30, hold = 0.3 })
			end
			Audio.play("Shing")
		end
	end)
	ClientState.Changed:Connect(function(key)
		if key == "drone" and ClientState.drone then
			OnboardingController.tip("DroneLook")
		end
	end)
	RoundState.Changed:Connect(function(name)
		if name == "RoundPhase" then
			local phase = RoundState.phase()
			if phase == "Briefing" or phase == "Garage" or phase == "Payout" then
				resetRound()
				closeJobCard()
			end
		end
	end)

	-- Legacy prototype messages (remove once mechanics' beta round service is merged).
	Net.on("Caught", function(name: any)
		if name == player.DisplayName then
			onCaptured(player.UserId, "grabbed")
		elseif typeof(name) == "string" then
			Hud.toast(`{string.upper(name)} CAUGHT`, C.Danger, "⛓")
		end
	end)
	Net.on("GuardAlert", function(name: any)
		if name == player.Name then
			onSpotted(player.UserId, "guard")
		end
	end)
	Net.on("RunEnded", function(result: any)
		if result == "SUCCESS" then
			Hud.banner("JOB DONE!", C.Good, 4)
		elseif result == "BUSTED" then
			onBusted()
		end
	end)
end

return MomentsController
