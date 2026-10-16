--!strict
-- Heist board (beta-spec-meta §5.1, beta-spec-ux §1.3): one card per heist (locked ones greyed out with
-- their requirement), a tier selector per card (Easy ×0.8 · Normal ×1 · Hard ×1.4), your stars per tier,
-- FRESH / MOST WANTED chips, and the rotating Hot Job card. Tapping a tier votes: JobVote(cardId, tier).
-- Votes show as crew shapes; the selected card gets a gold outline. Data: meta's `JobBoard` snapshot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Hud = require(Lib.Hud)
local Profile = require(Lib.Profile)
local RoundState = require(Lib.RoundState)
local Theme = require(Lib.Theme)
local UiText = require(Lib.UiText)

local Common = require(script.Parent.Common)

local HeistBoard = {}

local C = Theme.Colors
local player = Players.LocalPlayer

export type Context = { onVote: (() -> ())?, openSettings: (() -> ())? }

type Card = {
	cardId: string,
	heistId: string,
	name: string,
	open: boolean,
	requirement: string?,
	unlockedBy: string?,
	tiers: { { id: string, mult: number, locked: boolean } },
	hot: boolean,
	modifier: string?,
	bonusPct: number?,
	endsAt: number?,
}

local function tierList(raw: any): { { id: string, mult: number, locked: boolean } }
	local out = {}
	local offered: { [string]: number } = {}
	if typeof(raw) == "table" then
		for _, tier in raw do
			if typeof(tier) == "table" and typeof(tier.id) == "string" then
				offered[tier.id] = if typeof(tier.mult) == "number" then tier.mult else 1
			elseif typeof(tier) == "string" then
				offered[tier] = ((UiText.Tiers :: any)[tier] or { mult = 1 }).mult
			end
		end
	end
	local any = next(offered) ~= nil
	for _, id in UiText.TierOrder do
		local info = (UiText.Tiers :: any)[id]
		local mult = offered[id] or info.mult
		-- Without data: Easy and Normal open, Hard locked (Hard needs 2★ on Normal).
		local locked = if any then offered[id] == nil else id == "Hard"
		table.insert(out, { id = id, mult = mult, locked = locked })
	end
	return out
end

local function cards(board: { [string]: any }?): { Card }
	local list: { Card } = {}
	if board and typeof(board.hotJob) == "table" and board.hotJob.open ~= false then
		local hot = board.hotJob
		local heistId = if typeof(hot.heistId) == "string" then hot.heistId else "GoldenWheel"
		table.insert(list, {
			cardId = "HotJob",
			heistId = heistId,
			name = UiText.heist(heistId).name,
			open = true,
			tiers = tierList(hot.tiers),
			hot = true,
			modifier = if typeof(hot.modifier) == "string" then hot.modifier else nil,
			bonusPct = if typeof(hot.bonusPct) == "number" then hot.bonusPct else 0.25,
			endsAt = if typeof(hot.endsAt) == "number" then hot.endsAt else nil,
		})
	end
	local heists = board and board.heists
	if typeof(heists) == "table" and #heists > 0 then
		for _, h in heists do
			if typeof(h) == "table" and typeof(h.heistId) == "string" then
				table.insert(list, {
					cardId = h.heistId,
					heistId = h.heistId,
					name = if typeof(h.name) == "string" then h.name else UiText.heist(h.heistId).name,
					open = h.open ~= false,
					requirement = if typeof(h.requirement) == "string" then h.requirement else nil,
					unlockedBy = if typeof(h.unlockedBy) == "string" then h.unlockedBy else nil,
					tiers = tierList(h.tiers),
					hot = false,
				})
			end
		end
	else
		-- No board yet: the beta's three heists, map 1 open.
		for index, heistId in UiText.HeistOrder do
			table.insert(list, {
				cardId = heistId,
				heistId = heistId,
				name = UiText.heist(heistId).name,
				open = index == 1,
				requirement = UiText.HeistRequirements[heistId],
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
	local votes = Common.byUserId(board.votes)
	local vote = votes[player.UserId]
	if typeof(vote) == "table" then
		return vote.cardId, vote.difficulty
	elseif typeof(vote) == "string" then
		return vote, nil
	end
	return nil, nil
end

local function selectedCard(board: { [string]: any }?): string?
	local selected = board and board.selected
	if typeof(selected) == "string" then
		return selected
	elseif typeof(selected) == "table" then
		return selected.cardId or selected.heistId
	end
	return nil
end

local function isFresh(heistId: string): boolean
	local recent = Profile.get("recentHeists")
	if typeof(recent) ~= "table" or #recent < 2 then
		return false
	end
	return table.find(recent, heistId) == nil
end

local function mostWantedHeist(): string?
	local mw = (Config :: any).MostWanted
	if typeof(mw) ~= "table" or typeof(mw.Rotation) ~= "table" or #mw.Rotation == 0 then
		return nil
	end
	local week = math.floor((os.time() - 345600) / 604800)
	return mw.Rotation[week % #mw.Rotation + 1]
end

local function voterShapes(parent: Instance, board: { [string]: any }?, cardId: string)
	if not board then
		return
	end
	local row = Hud.frame({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 6 }, parent)
	Hud.list(
		row,
		Enum.FillDirection.Horizontal,
		3,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	for userId, vote in Common.byUserId(board.votes) do
		local voteCard = if typeof(vote) == "table" then vote.cardId else vote
		if voteCard == cardId then
			local p = Players:GetPlayerByUserId(userId)
			local crew = Theme.crew(p)
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

local function buildCard(parent: Instance, card: Card, board: { [string]: any }?, ctx: Context, order: number)
	local myCard, myTier = myVote(board)
	local selected = selectedCard(board) == card.cardId
	local heist = UiText.heist(card.heistId)
	local panel = Common.card(parent, {
		Name = "Card_" .. card.cardId,
		Size = UDim2.new(0, 184, 1, -12),
		LayoutOrder = order,
		BackgroundTransparency = if card.open then 0.05 else 0.45,
	})
	if selected then
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
		Text = if card.open then (heist.glyph or "◉") else "🔒",
		TextColor3 = if card.hot then C.Panel else C.Gold,
		Display = true,
		MaxTextSize = 34,
	}, picture)
	if card.hot or selected then
		Hud.chip(picture, if selected then "SELECTED" else "HOT JOB", if selected then C.Gold else C.Panel, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			TextSize = 12,
			Size = UDim2.fromOffset(0, 20),
			BackgroundColor3 = if selected then C.Panel else C.Gold,
		})
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
		local mod = UiText.modifier(card.modifier)
		Hud.chip(chips, string.upper(mod.name), C.Accent, { TextSize = 12, Size = UDim2.fromOffset(0, 20) })
		Hud.chip(chips, `+{math.floor((card.bonusPct or 0.25) * 100 + 0.5)}%`, C.Gold, {
			TextSize = 12,
			Size = UDim2.fromOffset(0, 20),
		})
	elseif card.open then
		if isFresh(card.heistId) then
			Hud.chip(chips, "FRESH +20%", C.Good, { TextSize = 12, Size = UDim2.fromOffset(0, 20) })
		end
		if mostWantedHeist() == card.heistId then
			Hud.chip(chips, "MOST WANTED", C.Gold, { TextSize = 12, Size = UDim2.fromOffset(0, 20) })
		end
	end

	if not card.open then
		Hud.text({
			Size = UDim2.new(1, 0, 0, 52),
			Text = card.requirement or "Locked",
			TextColor3 = C.Muted,
			MaxTextSize = 15,
			LayoutOrder = 4,
		}, panel)
		return
	end
	if card.unlockedBy then
		Hud.text({
			Size = UDim2.new(1, 0, 0, 16),
			Text = `Unlocked by {card.unlockedBy}`,
			TextColor3 = C.Good,
			MaxTextSize = 14,
			LayoutOrder = 4,
		}, panel)
	end
	if card.hot and card.endsAt then
		local left = card.endsAt - RoundState.now()
		if left > 0 then
			Hud.text({
				Size = UDim2.new(1, 0, 0, 16),
				Text = `NEW IN {Hud.formatTime(left)}`,
				TextColor3 = C.Muted,
				MaxTextSize = 14,
				LayoutOrder = 4,
			}, panel)
		end
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
		local info = (UiText.Tiers :: any)[tier.id]
		local stars = Profile.stars(card.heistId, tier.id)
		local chosen = myCard == card.cardId
			and (myTier == tier.id or (myTier == nil and tier.id == "Normal"))
		local button = Hud.button({
			Name = `Tier_{card.cardId}_{tier.id}`,
			Size = UDim2.fromOffset(52, 58),
			Text = "",
			Kind = if tier.locked then "disabled" elseif chosen then "primary" else "secondary",
			LayoutOrder = index,
			Radius = 10,
			AutoButtonColor = false,
		}, tiers)
		Hud.text({
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 2),
			Text = if tier.locked then "🔒" else info.name,
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
			if tier.locked then
				Hud.toast(if tier.id == "Hard" then "Hard: get 2★ on Normal first" else "Locked", C.Muted)
				return
			end
			Net.request("JobVote", card.cardId, tier.id)
			if ctx.onVote then
				ctx.onVote()
			end
		end)
	end
	voterShapes(panel, board, card.cardId)
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
				Size = UDim2.new(1, -150, 0, 40),
				Text = if board
					then "Tap a level to vote · most votes wins"
					else "Loading jobs… you can vote already",
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 15,
				LayoutOrder = 1,
			}, footer)
			local settings = Hud.button({
				Name = "Settings",
				Size = UDim2.fromOffset(130, 48),
				Text = "⚙ SETTINGS",
				Kind = "ghost",
				MaxTextSize = 16,
				LayoutOrder = 2,
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
