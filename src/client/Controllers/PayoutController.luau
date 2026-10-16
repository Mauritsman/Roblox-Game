--!strict
-- Payout and results (beta-spec-ux §1.13–1.14): the reward moment after every job.
--   tally 0–6 s (tap = skip) · stars 6–8 s · awards 8–12 s · cash/rep 12–14 s · then NEXT JOB countdown.
-- One-tap feedback (3 drawn faces + up to 2 fixed tags), never blocking NEXT JOB; hidden after 3 skipped
-- rounds in a row (per session). Data: meta's `Payout` table; requests NextJob, ReturnToGarage, Feedback.

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Audio = require(Lib.Audio)
local Hud = require(Lib.Hud)
local Juice = require(Lib.Juice)
local Profile = require(Lib.Profile)
local RoundState = require(Lib.RoundState)
local Screens = require(Lib.Screens)
local Theme = require(Lib.Theme)
local UiText = require(Lib.UiText)

local MomentsController = require(script.Parent.MomentsController)

local PayoutController = {}

local C = Theme.Colors

local payout: { [string]: any }? = nil
local arrivedAt = 0
local readySent = false
local feedbackSent = false
local feedbackSkips = 0
local blur: BlurEffect? = nil

local function num(value: any, default: number?): number
	return if typeof(value) == "number" then value else (default or 0)
end

local function roundConfig(key: string, default: number): number
	local round = (Config :: any).Round
	local value = if typeof(round) == "table" then round[key] else nil
	return if typeof(value) == "number" then value else default
end

-- ── Feedback ─────────────────────────────────────────────────────────────────────────────────────

local function feedbackTags(): { string }
	local analytics = (Config :: any).Analytics
	local tags = if typeof(analytics) == "table" then analytics.FeedbackTags else nil
	if typeof(tags) == "table" and #tags > 0 then
		return tags
	end
	return UiText.FeedbackOrder
end

local function sendFeedback(mood: number, tags: { string })
	if feedbackSent then
		return
	end
	feedbackSent = true
	feedbackSkips = 0
	local p = payout
	Net.request("Feedback", mood, tags, if p then p.roundId else nil)
end

-- A face drawn with frames: a circle, two eyes and a mouth (a rotated bracket, or a bar for neutral).
local function face(parent: Instance, mood: number, order: number): TextButton
	local colors = { [1] = Color3.fromRGB(255, 120, 110), [2] = Color3.fromRGB(255, 210, 90), [3] = C.Good }
	local button = Hud.make("TextButton", {
		Name = "Face" .. mood,
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = colors[mood],
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Selectable = true,
	}, parent)
	Hud.corner(button, 999)
	Hud.stroke(button, C.Stroke, 2)
	for _, x in { 0.33, 0.67 } do
		local eye = Hud.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.38),
			Size = UDim2.fromOffset(7, 9),
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
		}, button)
		Hud.corner(eye, 999)
	end
	if mood == 2 then
		local mouth = Hud.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.68),
			Size = UDim2.fromOffset(22, 4),
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
		}, button)
		Hud.corner(mouth, 2)
	else
		Hud.make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, if mood == 3 then 0.62 else 0.76),
			Size = UDim2.fromOffset(30, 30),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.UiHeavy,
			Text = if mood == 3 then ")" else "(",
			TextSize = 30,
			TextColor3 = C.Panel,
			Rotation = 90,
		}, button)
	end
	return button
end

local function buildFeedback(parent: Instance)
	local box = Hud.frame({ Size = UDim2.fromScale(1, 1) }, parent)
	Hud.list(
		box,
		Enum.FillDirection.Horizontal,
		8,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center
	)
	if feedbackSkips >= Theme.UX.FeedbackHideAfterSkips then
		return
	end
	local label = Hud.text({
		Size = UDim2.fromOffset(70, 40),
		Text = "HOW WAS IT?",
		TextColor3 = C.Muted,
		MaxTextSize = 15,
		LayoutOrder = 0,
	}, box)
	local faces = Hud.frame({ Size = UDim2.fromOffset(184, 56), LayoutOrder = 1 }, box)
	Hud.list(
		faces,
		Enum.FillDirection.Horizontal,
		8,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center
	)
	local tagsRow = Hud.frame({
		Size = UDim2.fromOffset(0, 56),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Visible = false,
	}, box)
	local grid = Hud.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(84, 26),
		CellPadding = UDim2.fromOffset(4, 4),
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = 3,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tagsRow)
	local _ = grid
	local mood = 0
	local picked: { string } = {}
	local sendToken = 0
	local function scheduleSend()
		sendToken += 1
		local token = sendToken
		task.delay(Theme.UX.FeedbackAutoSend, function()
			if token == sendToken and mood > 0 then
				sendFeedback(mood, picked)
				label.Text = "THANKS!"
				label.TextColor3 = C.Good
				tagsRow.Visible = false
				faces.Visible = false
			end
		end)
	end
	PayoutController.flushFeedback = function()
		if mood > 0 then
			sendFeedback(mood, picked)
		end
	end
	for index, m in { 3, 2, 1 } do
		local button = face(faces, m, index)
		button.Activated:Connect(function()
			if feedbackSent then
				return
			end
			mood = m
			Audio.play("UiTap")
			for _, other in faces:GetChildren() do
				if other:IsA("TextButton") then
					other.BackgroundTransparency = if other == button then 0 else 0.6
				end
			end
			Juice.pop(button, 1.2)
			tagsRow.Visible = true
			scheduleSend()
		end)
	end
	for index, tagId in feedbackTags() do
		local tagButton = Hud.button({
			Size = UDim2.fromOffset(84, 26),
			Text = UiText.FeedbackTags[tagId] or UiText.pretty(tagId),
			Kind = "ghost",
			MaxTextSize = 14,
			LayoutOrder = index,
			Radius = 999,
		}, tagsRow)
		-- Tags are 26 px tall inside a 56 px row; the size constraint would force 48, so drop it here.
		local constraint = tagButton:FindFirstChildOfClass("UISizeConstraint")
		if constraint then
			constraint:Destroy()
		end
		tagButton.Activated:Connect(function()
			if feedbackSent then
				return
			end
			local at = table.find(picked, tagId)
			if at then
				table.remove(picked, at)
				Hud.styleButton(tagButton, "ghost")
			elseif #picked < 2 then
				table.insert(picked, tagId)
				Hud.styleButton(tagButton, "primary")
			end
			scheduleSend()
		end)
	end
end

PayoutController.flushFeedback = nil :: (() -> ())?

-- ── Screen ───────────────────────────────────────────────────────────────────────────────────────

local function line(parent: Instance, text: string, color: Color3?, order: number, size: number?): TextLabel
	return Hud.text({
		Size = UDim2.new(1, 0, 0, size or 22),
		Text = text,
		TextColor3 = color or C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = (size or 22) - 4,
		LayoutOrder = order,
	}, parent)
end

local function build(body: Frame): () -> ()
	local p: { [string]: any } = payout or {}
	local busted = p.busted == true or p.outcome == "Busted"
	local alive = true
	local skip = false

	-- Tapping anywhere outside the buttons skips the animation.
	local backdrop = Hud.make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Backdrop,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
	}, body)
	backdrop.Activated:Connect(function()
		skip = true
	end)
	local root = Hud.frame({ Size = UDim2.new(1, -32, 1, -24), Position = UDim2.fromOffset(16, 12) }, body)
	-- Safe area: the payout covers the screen but its content avoids the notch.
	Hud.make("UISizeConstraint", { MaxSize = Vector2.new(980, 560) }, root)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)

	-- Header
	local heist = UiText.heist(p.heistId)
	Hud.text({
		Size = UDim2.new(1, 0, 0, 40),
		Text = if busted then "BUSTED" else "PAYDAY!",
		TextColor3 = if busted then C.Danger else C.Gold,
		Display = true,
		MaxTextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 2,
	}, root)
	local tier = if typeof(p.difficulty) == "string" then p.difficulty else ""
	Hud.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 8),
		Size = UDim2.fromOffset(300, 26),
		Text = string.upper(heist.name) .. (if tier ~= "" then " · " .. string.upper(tier) else ""),
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 18,
	}, root)

	-- Left: tally, bonuses, your cut.
	local left = Hud.panel({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(0.55, -6, 1, -44 - 76),
		BackgroundTransparency = 0.3,
	}, root)
	Hud.padding(left, 12, 8)
	local tally = Hud.make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Selectable = false,
	}, left)
	Hud.list(tally, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left)
	local cutLabel = Hud.text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		Text = "YOUR CUT 0",
		TextColor3 = C.Gold,
		Display = true,
		MaxTextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 2,
	}, left)

	-- Right: stars, awards, rep.
	local right = Hud.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 44),
		Size = UDim2.new(0.45, -6, 1, -44 - 76),
		BackgroundTransparency = 0.3,
	}, root)
	Hud.padding(right, 10, 8)
	local rightList = Hud.make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Selectable = false,
	}, right)
	Hud.list(rightList, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	local starRow = Hud.frame({ Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 1 }, rightList)
	Hud.list(
		starRow,
		Enum.FillDirection.Horizontal,
		10,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	local starLabels: { TextLabel } = {}
	for index = 1, 3 do
		starLabels[index] = Hud.text({
			Size = UDim2.fromOffset(48, 48),
			Text = "★",
			TextColor3 = C.Dim,
			Display = true,
			MaxTextSize = 46,
			LayoutOrder = index,
			Stroke = 2,
		}, starRow)
	end
	local awardsGrid = Hud.frame({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, rightList)
	Hud.make("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 52),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, awardsGrid)
	local repBox = Hud.frame(
		{ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 },
		rightList
	)
	Hud.list(repBox, Enum.FillDirection.Vertical, 3, Enum.HorizontalAlignment.Left)

	-- Bottom: feedback + buttons.
	local bottom = Hud.frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 68),
	}, root)
	local feedbackBox = Hud.frame({ Size = UDim2.new(1, -260, 1, 0) }, bottom)
	buildFeedback(feedbackBox)
	local nextButton = Hud.button({
		Name = "NextJob",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(150, 64),
		Text = "NEXT JOB",
		Kind = "primary",
		MaxTextSize = 24,
	}, bottom)
	local garageButton = Hud.button({
		Name = "Garage",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -158, 0.5, 0),
		Size = UDim2.fromOffset(96, 48),
		Text = "GARAGE",
		Kind = "secondary",
		MaxTextSize = 18,
	}, bottom)
	nextButton.Activated:Connect(function()
		if PayoutController.flushFeedback then
			PayoutController.flushFeedback()
		end
		if not readySent then
			readySent = true
			Net.request("NextJob")
			Hud.styleButton(nextButton, "good")
		end
	end)
	garageButton.Activated:Connect(function()
		if PayoutController.flushFeedback then
			PayoutController.flushFeedback()
		end
		Net.request("ReturnToGarage")
		Screens.close("Payout")
	end)

	-- Capture from "JUST MADE IT!": offer SAVE.
	local capture = MomentsController.lastCapture
	if capture and os.clock() - MomentsController.lastCaptureAt < 90 then
		local save = Hud.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(110, 48),
			Text = "SAVE SHOT",
			Kind = "gold",
			MaxTextSize = 16,
		}, root)
		save.Position = UDim2.new(1, -310, 0, -2)
		save.Activated:Connect(function()
			pcall(function()
				(CaptureService :: any):PromptSaveCapturesToGallery({ capture }, function() end)
			end)
		end)
	end

	for _, list in { tally, rightList } do
		list.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				skip = true
			end
		end)
	end

	Juice.moneyShower(body, if busted then 0 else 24)
	Audio.play("MoneyShower")

	local function wait(seconds: number)
		local untilAt = os.clock() + seconds
		while alive and not skip and os.clock() < untilAt do
			task.wait()
		end
	end

	task.spawn(function()
		-- Tally (0–6 s): one ka-ching per line.
		local items = if typeof(p.items) == "table" then p.items else {}
		local order = 0
		local gap = math.clamp(5 / math.max(#items, 1), 0.12, 0.5)
		for _, item in items do
			if not alive then
				return
			end
			order += 1
			local class = if typeof(item) == "table" then item.class else nil
			local style = Theme.loot(class)
			local name = if typeof(item) == "table" and typeof(item.name) == "string"
				then item.name
				else "Loot"
			local value = if typeof(item) == "table" then num(item.value) else 0
			line(tally, `{style.glyph} {name}  +{Hud.formatNumber(value)}`, style.color, order, 22)
			if not skip then
				Audio.play("KaChing", { pitch = 1 + math.min(order, 10) * 0.02, volume = 0.6 })
				tally.CanvasPosition = Vector2.new(0, 1e5)
			end
			wait(gap)
		end
		if #items == 0 then
			order += 1
			line(tally, if busted then "Half the loot saved" else "No loot this time", C.Muted, order)
		end
		order += 1
		line(tally, `VAN TOTAL {Hud.formatNumber(num(p.vanTotal))}`, C.Text, order, 26)
		if busted then
			order += 1
			line(tally, "Half the loot saved", C.Danger, order)
		end
		local bonuses = if typeof(p.bonuses) == "table" then p.bonuses else {}
		for _, bonus in bonuses do
			if typeof(bonus) == "table" then
				order += 1
				local pct = num(bonus.pct)
				local pctText = if math.abs(pct) <= 5
					then math.floor(pct * 100 + 0.5)
					else math.floor(pct + 0.5)
				line(tally, `{string.upper(tostring(bonus.label or "BONUS"))} +{pctText}%`, C.Good, order)
			end
		end
		if num(p.crewSize, 1) > 1 then
			order += 1
			line(tally, `CREW OF {num(p.crewSize)} · +{(num(p.crewSize) - 1) * 15}%`, C.Info, order)
		end
		if p.firstJobToday == true then
			order += 1
			line(tally, "FIRST JOB TODAY ×2", C.Gold, order)
		end
		if p.caughtHalf == true then
			order += 1
			line(tally, "Left behind: half cut", C.Warn, order)
		end
		wait(0.3)

		-- Stars (6–8 s).
		local stars = if busted then 0 else math.clamp(num(p.stars), 0, 3)
		for index = 1, 3 do
			if index <= stars then
				starLabels[index].TextColor3 = C.Gold
				if not skip then
					Juice.pop(starLabels[index], 1.8)
					Audio.play("StarChime", { pitch = 1 + index * 0.12 })
				end
				wait(0.35)
			end
		end
		if typeof(p.newStars) == "table" and num(p.newStars.count) > 0 then
			local count = num(p.newStars.count)
			local plural = if count == 1 then "" else "S"
			line(
				repBox,
				`+{count} NEW STAR{plural} · +{Hud.formatNumber(num(p.newStars.cash))}`,
				C.Gold,
				1,
				20
			)
		end

		-- Awards (8–12 s): max 4, one per player.
		local awards = if typeof(p.awards) == "table" then p.awards else {}
		for index, award in awards do
			if index > 4 or not alive then
				break
			end
			if typeof(award) == "table" then
				local who = if typeof(award.userId) == "number"
					then Players:GetPlayerByUserId(award.userId)
					else nil
				local crew = Theme.crew(who)
				local entry = UiText.award(award.awardId)
				local card = Hud.panel(
					{ LayoutOrder = index, BackgroundColor3 = C.PanelLight, BackgroundTransparency = 0.1 },
					awardsGrid
				)
				Hud.stroke(card, crew.color, 2, 0.2)
				Hud.text({
					Position = UDim2.fromOffset(6, 4),
					Size = UDim2.new(1, -12, 0, 22),
					Text = `{entry.glyph or "★"} {entry.name}`,
					TextColor3 = C.Gold,
					TextXAlignment = Enum.TextXAlignment.Left,
					Heavy = true,
					MaxTextSize = 16,
				}, card)
				Hud.text({
					Position = UDim2.fromOffset(6, 27),
					Size = UDim2.new(1, -12, 0, 20),
					Text = `{crew.glyph} {if who then Hud.shortName(who.DisplayName, 10) else "Crew"}`,
					TextColor3 = crew.color,
					TextXAlignment = Enum.TextXAlignment.Left,
					MaxTextSize = 14,
				}, card)
				if not skip then
					Juice.pop(card, 1.15)
					Audio.play("UiTap", { pitch = 1.3 })
				end
				wait(0.6)
			end
		end

		-- Cash and Rep (12–14 s).
		local cut = num(p.cut, num(p.cash))
		Juice.countUp(cutLabel, 0, cut, if skip then 0 else 1.2, "YOUR CUT ")
		if num(p.rep) > 0 then
			line(repBox, `+{Hud.formatNumber(num(p.rep))} REP`, C.Info, 2, 20)
		end
		local view = Profile.view
		local into = view and num(view.repIntoRank, -1) or -1
		local need = view and num(view.repForNext, -1) or -1
		if into >= 0 and need > 0 then
			local _, fill =
				Hud.bar(repBox, { Size = UDim2.new(1, 0, 0, 10), LayoutOrder = 3, Radius = 5 }, C.Info)
			fill.Size = UDim2.fromScale(math.clamp(into / need, 0, 1), 1)
		end
		if num(p.rankAfter) > num(p.rankBefore) and num(p.rankBefore) > 0 then
			local rankLabel = line(repBox, `RANK UP! RANK {num(p.rankAfter)}`, C.Gold, 4, 26)
			Juice.pop(rankLabel, 1.4)
			Audio.play("RankUpFanfare")
		end
		local unlocks = if typeof(p.unlocks) == "table" then p.unlocks else {}
		for index, unlock in unlocks do
			local text = if typeof(unlock) == "string" then UiText.pretty(unlock) else tostring(unlock)
			line(repBox, `UNLOCKED: {text}`, C.Good, 10 + index, 20)
		end
		if num(p.contractCash) > 0 then
			line(repBox, `CONTRACTS +{Hud.formatNumber(num(p.contractCash))}`, C.Good, 20, 20)
		end
		if typeof(p.mostWanted) == "table" and p.mostWanted.done == true then
			line(repBox, "MOST WANTED ✓", C.Gold, 21, 20)
		end
		if num(p.balance) > 0 then
			line(repBox, `CASH {Hud.formatNumber(num(p.balance))}`, C.Muted, 30, 18)
		end
		skip = false
		Screens.select(nextButton)

		-- NEXT JOB countdown.
		local total = roundConfig("PayoutSeconds", Theme.UX.PayoutSeconds) + roundConfig("NextJobSeconds", 10)
		while alive do
			local secondsLeft = math.max(0, math.ceil(arrivedAt + total - os.clock()))
			nextButton.Text = if readySent then `READY ✓ {secondsLeft}` else `NEXT JOB {secondsLeft}`
			task.wait(0.25)
		end
	end)

	return function()
		alive = false
	end
end

local function open(data: any)
	if typeof(data) ~= "table" then
		return
	end
	payout = data
	arrivedAt = os.clock()
	readySent = false
	feedbackSent = false
	PayoutController.flushFeedback = nil
	Screens.open("Payout")
end

function PayoutController:Init()
	Screens.register("Payout", {
		title = "PAYOUT",
		fullscreen = true,
		closable = false,
		build = build,
		onClose = function()
			if blur then
				blur:Destroy()
				blur = nil
			end
			if not feedbackSent then
				feedbackSkips += 1
			end
			payout = nil
		end,
	})
end

function PayoutController:Start()
	Net.on("Payout", function(data: any)
		open(data)
		local camera = workspace.CurrentCamera
		if camera and not blur then
			local effect = Instance.new("BlurEffect")
			effect.Name = "PayoutBlur"
			effect.Size = 14
			effect.Parent = camera
			blur = effect
		end
	end)
	RoundState.Changed:Connect(function(name)
		if name ~= "RoundPhase" or Screens.current() ~= "Payout" then
			return
		end
		local phase = RoundState.phase()
		if phase == "Briefing" or phase == "Heist" or phase == "Garage" then
			if PayoutController.flushFeedback then
				PayoutController.flushFeedback()
			end
			Screens.close("Payout")
		end
	end)
end

return PayoutController
