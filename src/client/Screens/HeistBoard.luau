--!strict
-- Heist board (docs/meta-api.md §3, beta-spec-ux §1.3): one card per heist (locked ones greyed out with
-- their requirement, unbuilt maps "Coming soon"), a tier selector per card (Easy ×0.8 · Normal ×1 · Hard ×1.4),
-- your stars per tier, FRESH / MOST WANTED chips, and the rotating Hot Job card (greyed for players with
-- < 2 rounds: "Play 2 rounds first"). Tapping a tier votes: JobVote(cardId, difficulty). Votes show as crew
-- shapes; the selected card gets a gold outline and "Crew plays: Normal". Data: meta's `JobBoard` snapshot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Hud = require(Lib.Hud)
local Profile = require(Lib.Profile)
local Theme = require(Lib.Theme)
local UiText = require(Lib.UiText)

local Common = require(script.Parent.Common)

local HeistBoard = {}

local C = Theme.Colors
local player = Players.LocalPlayer

export type Context = { onVote: (() -> ())?, openSettings: (() -> ())? }

type Tier = { id: string, label: string, mult: number, open: boolean }
type Card = {
	cardId: string,
	heistId: string,
	name: string,
	available: boolean,
	open: boolean,
	requirement: string?,
	unlockedBy: string?,
	mostWanted: boolean,
	tiers: { Tier },
	hot: boolean,
	modifierName: string?,
	bonusPct: number?,
	endsAt: number?,
}

local function heistName(heistId: string): string
	return MetaConfig.Heists.Names[heistId] or UiText.heist(heistId).name
end

local function tierList(raw: any): { Tier }
	local out: { Tier } = {}
	local given: { [string]: any } = {}
	if typeof(raw) == "table" then
		for _, tier in raw do
			if typeof(tier) == "table" and typeof(tier.id) == "string" then
				given[tier.id] = tier
			end
		end
	end
	local haveData = next(given) ~= nil
	for _, id in MetaConfig.Difficulty.Order do
		local info = (UiText.Tiers :: any)[id]
		local tier = given[id]
		if tier or not haveData then
			table.insert(out, {
				id = id,
				label = if tier and typeof(tier.label) == "string" then tier.label else info.name,
				mult = if tier and typeof(tier.mult) == "number" then tier.mult else info.mult,
				-- Without data: Easy and Normal open, Hard locked (Hard needs 2★ on Normal).
				open = if tier then tier.open ~= false else id ~= "Hard",
			})
		end
	end
	return out
end

local function cards(board: { [string]: any }?): { Card }
	local list: { Card } = {}
	if board and typeof(board.hotJob) == "table" then
		local hot = board.hotJob
		local heistId = if typeof(hot.heistId) == "string" then hot.heistId else "GoldenWheel"
		table.insert(list, {
			cardId = if typeof(hot.cardId) == "string" then hot.cardId else "HotJob",
			heistId = heistId,
			name = if typeof(hot.name) == "string" then hot.name else heistName(heistId),
			available = true,
			open = hot.open ~= false,
			requirement = if hot.open == false
				then `Play {if typeof(hot.minRounds) == "number" then hot.minRounds else 2} rounds first`
				else nil,
			mostWanted = false,
			tiers = tierList(hot.tiers),
			hot = true,
			modifierName = if typeof(hot.modifierName) == "string"
				then hot.modifierName
				elseif typeof(hot.modifierId) == "string" then UiText.modifier(hot.modifierId).name
				else nil,
			bonusPct = if typeof(hot.bonusPct) == "number" then hot.bonusPct else 0.25,
			endsAt = if typeof(hot.endsAt) == "number" then hot.endsAt else nil,
		})
	end
	local heists = board and board.heists
	if typeof(heists) == "table" and #heists > 0 then
		for _, h in heists do
			if typeof(h) == "table" and typeof(h.heistId) == "string" then
				table.insert(list, {
					cardId = if typeof(h.cardId) == "string" then h.cardId else h.heistId,
					heistId = h.heistId,
					name = if typeof(h.name) == "string" then h.name else heistName(h.heistId),
					available = h.available ~= false,
					open = h.open ~= false and h.available ~= false,
					requirement = if typeof(h.requirement) == "string" then h.requirement else nil,
					unlockedBy = if typeof(h.unlockedBy) == "string" then h.unlockedBy else nil,
					mostWanted = h.mostWanted == true,
					tiers = tierList(h.tiers),
					hot = false,
				})
			end
		end
	else
		-- No board yet: the beta's heists, map 1 open.
		for index, heistId in MetaConfig.Heists.Order do
			table.insert(list, {
				cardId = heistId,
				heistId = heistId,
				name = heistName(heistId),
				available = true,
				open = index == 1,
				requirement = UiText.HeistRequirements[heistId],
				mostWanted = false,
				tiers = tierList(nil),
				hot = false,
			})
		end
	end
	return list
end

local function myVote(board: { [string]: any }?): (string?, string?)
	if not board then
		return nil, nil
	end
	local vote = Common.byUserId(board.votes)[player.UserId]
	if typeof(vote) == "table" then
		return vote.cardId, vote.difficulty
	end
	return nil, nil
end

local function selected(board: { [string]: any }?): (string?, string?)
	local s = board and board.selected
	if typeof(s) == "table" then
		return s.cardId, s.difficulty
	elseif typeof(s) == "string" then
		return s, nil
	end
	return nil, nil
end

local function isFresh(heistId: string): boolean
	local fresh = Profile.get("freshHeists")
	if typeof(fresh) == "table" then
		return table.find(fresh, heistId) ~= nil or fresh[heistId] == true
	end
	return false
end

local function voterShapes(parent: Instance, board: { [string]: any }?, cardId: string, order: number)
	if not board then
		return
	end
	local row = Hud.frame({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order }, parent)
	Hud.list(
		row,
		Enum.FillDirection.Horizontal,
		3,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	for userId, vote in Common.byUserId(board.votes) do
		if typeof(vote) == "table" and vote.cardId == cardId then
			local crew = Theme.crew(Players:GetPlayerByUserId(userId))
			Hud.text({
				Size = UDim2.fromOffset(18, 18),
				Text = crew.glyph,
				TextColor3 = crew.color,
				Display = true,
				MaxTextSize = 16,
				Stroke = 1,
			}, row)
		end
	end
end

local function smallChip(parent: Instance, text: string, color: Color3, background: Color3?)
	Hud.chip(parent, text, color, {
		TextSize = 12,
		Size = UDim2.fromOffset(0, 20),
		BackgroundColor3 = background or C.Panel,
	})
end

local function buildCard(parent: Instance, card: Card, board: { [string]: any }?, ctx: Context, order: number)
	local myCard, myTier = myVote(board)
	local selectedCard, selectedTier = selected(board)
	local isSelected = selectedCard == card.cardId
	local heist = UiText.heist(card.heistId)
	local panel = Common.card(parent, {
		Name = "Card_" .. card.cardId,
		Size = UDim2.new(0, 184, 1, -12),
		LayoutOrder = order,
		BackgroundTransparency = if card.open then 0.05 else 0.45,
	})
	if isSelected then
		Common.outline(panel, C.Gold, 3)
	elseif myCard == card.cardId then
		Common.outline(panel, C.Accent, 2)
	end
	Hud.padding(panel, 8, 8)
	Hud.list(panel, Enum.FillDirection.Vertical, 5)

	-- Picture placeholder (block + icon until thumbnails exist).
	local picture = Hud.panel({
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = if card.hot then C.Accent else C.Panel,
		BackgroundTransparency = if card.open then 0.1 else 0.5,
		LayoutOrder = 1,
	}, panel)
	Hud.text({
		Size = UDim2.fromScale(1, 1),
		Text = if not card.available then "…" elseif card.open then (heist.glyph or "◉") else "🔒",
		TextColor3 = if card.hot then C.Panel else C.Gold,
		Display = true,
		MaxTextSize = 34,
	}, picture)
	if card.hot or isSelected then
		Hud.chip(
			picture,
			if isSelected then "SELECTED" else "HOT JOB",
			if isSelected then C.Gold else C.Panel,
			{
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 4),
				TextSize = 12,
				Size = UDim2.fromOffset(0, 20),
				BackgroundColor3 = if isSelected then C.Panel else C.Gold,
			}
		)
	end
	Hud.text({
		Size = UDim2.new(1, 0, 0, 24),
		Text = card.name,
		Display = true,
		MaxTextSize = 20,
		TextColor3 = if card.open then C.Text else C.Muted,
		LayoutOrder = 2,
	}, panel)

	local chips = Hud.frame({ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 3 }, panel)
	Hud.list(
		chips,
		Enum.FillDirection.Horizontal,
		4,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	if card.hot then
		if card.modifierName then
			smallChip(chips, string.upper(card.modifierName), C.Accent)
		end
		smallChip(chips, `+{math.floor((card.bonusPct or 0.25) * 100 + 0.5)}%`, C.Gold)
	elseif card.open then
		if isFresh(card.heistId) then
			smallChip(chips, "FRESH +20%", C.Good)
		end
		if card.mostWanted then
			smallChip(chips, "MOST WANTED", C.Gold)
		end
	end

	if not card.available then
		Hud.text({
			Size = UDim2.new(1, 0, 0, 40),
			Text = "Coming soon",
			TextColor3 = C.Muted,
			Display = true,
			MaxTextSize = 18,
			LayoutOrder = 4,
		}, panel)
		return
	end
	if not card.open then
		Hud.text({
			Size = UDim2.new(1, 0, 0, 52),
			Text = card.requirement or "Locked",
			TextColor3 = C.Muted,
			MaxTextSize = 15,
			LayoutOrder = 4,
		}, panel)
		voterShapes(panel, board, card.cardId, 6)
		return
	end
	local info = if isSelected and selectedTier
		then `Crew plays: {((UiText.Tiers :: any)[selectedTier] or { name = selectedTier }).name}`
		elseif card.unlockedBy then `Unlocked by {card.unlockedBy}`
		elseif card.hot and card.endsAt then `NEW IN {Hud.formatTime(card.endsAt - Profile.osNow())}`
		else nil
	if info then
		Hud.text({
			Size = UDim2.new(1, 0, 0, 16),
			Text = info,
			TextColor3 = if isSelected then C.Gold elseif card.unlockedBy then C.Good else C.Muted,
			MaxTextSize = 14,
			LayoutOrder = 4,
		}, panel)
	end

	-- Tier selector: tap = vote.
	local tiers = Hud.frame({ Size = UDim2.new(1, 0, 0, 62), LayoutOrder = 5 }, panel)
	Hud.list(
		tiers,
		Enum.FillDirection.Horizontal,
		4,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	for index, tier in card.tiers do
		local name = ((UiText.Tiers :: any)[tier.id] or { name = string.upper(tier.id) }).name
		local stars = Profile.stars(card.heistId, tier.id)
		local chosen = myCard == card.cardId
			and (myTier == tier.id or (myTier == nil and tier.id == "Normal"))
		local button = Hud.button({
			Name = `Tier_{card.cardId}_{tier.id}`,
			Size = UDim2.fromOffset(52, 58),
			Text = "",
			Kind = if not tier.open then "disabled" elseif chosen then "primary" else "secondary",
			LayoutOrder = index,
			Radius = 10,
		}, tiers)
		Hud.text({
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 2),
			Text = if tier.open then name else "🔒",
			TextColor3 = button.TextColor3,
			Heavy = true,
			MaxTextSize = 13,
			MinTextSize = 9,
		}, button)
		Hud.text({
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(0, 20),
			Text = `×{tier.mult}`,
			TextColor3 = button.TextColor3,
			MaxTextSize = 13,
			MinTextSize = 9,
		}, button)
		Hud.text({
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.fromOffset(0, 36),
			Text = Common.stars(stars),
			TextColor3 = if stars > 0 then C.Gold else button.TextColor3,
			MaxTextSize = 12,
			MinTextSize = 8,
		}, button)
		button.Activated:Connect(function()
			if not tier.open then
				Hud.toast(if tier.id == "Hard" then "Hard: get 2★ on Normal first" else "Locked", C.Muted)
				return
			end
			Net.request("JobVote", card.cardId, tier.id)
			if ctx.onVote then
				ctx.onVote()
			end
		end)
	end
	voterShapes(panel, board, card.cardId, 6)
end

function HeistBoard.create(ctx: Context): any
	return {
		title = "HEIST BOARD",
		size = Vector2.new(820, 440),
		build = function(body: Frame): (() -> ())?
			local board = Profile.board
			local content = Common.content(body, 52)
			local row = Common.scroller(content, true)
			for index, card in cards(board) do
				buildCard(row, card, board, ctx, index)
			end
			local footer = Common.footer(body, 52)
			Hud.text({
				Size = UDim2.new(1, -300, 0, 40),
				Text = if board then "Tap a level to vote · most votes wins" else "Loading jobs…",
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 15,
				LayoutOrder = 1,
			}, footer)
			local crew = Hud.button({
				Name = "PrivateCrew",
				Size = UDim2.fromOffset(150, 48),
				Text = "PRIVATE CREW",
				Kind = "ghost",
				MaxTextSize = 15,
				LayoutOrder = 2,
			}, footer)
			crew.Activated:Connect(function()
				Net.request("PrivateCrewStart")
			end)
			local settings = Hud.button({
				Name = "Settings",
				Size = UDim2.fromOffset(130, 48),
				Text = "⚙ SETTINGS",
				Kind = "ghost",
				MaxTextSize = 16,
				LayoutOrder = 3,
			}, footer)
			settings.Activated:Connect(function()
				if ctx.openSettings then
					ctx.openSettings()
				end
			end)
			return nil
		end,
	}
end

return HeistBoard
