--!strict
-- Lobby (owner: meta): the Garage job board (a card per heist + the rotating Hot Job), crew votes, the job
-- picked at departure, Garage station prompts, the trophy leaders line and Private Crew.
-- docs/beta-spec-meta.md §5 and the advisor decisions (docs/research/advisor-*.md).
--
-- For mechanics: LobbyService:GetSelectedJob(boarders, roundId?) at departure (van countdown hits 0 or NEXT JOB)
--   → { cardId, heistId, difficulty, modifierId?, isHotJob, mostWanted }

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local MetaTags = require(ReplicatedStorage.Shared.MetaTags)
local Net = require(ReplicatedStorage.Shared.Net)
local Calendar = require(ReplicatedStorage.Shared.Logic.Calendar)
local HeistRecords = require(ReplicatedStorage.Shared.Logic.HeistRecords)
local HotJob = require(ReplicatedStorage.Shared.Logic.HotJob)
local JobBoard = require(ReplicatedStorage.Shared.Logic.JobBoard)
local Rng = require(ReplicatedStorage.Shared.Logic.Rng)

local Meta = script.Parent.Parent.Meta
local Clock = require(Meta.Clock)
local Features = require(Meta.Features)
local ProfileView = require(Meta.ProfileView)
local RequestGuard = require(Meta.RequestGuard)
local Registry = require(script.Parent.Parent.Map.Registry)
local AnalyticsTracker = require(script.Parent.AnalyticsTracker)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local ProgressionService = require(script.Parent.ProgressionService)
local ShopService = require(script.Parent.ShopService)

export type SelectedJob = {
	cardId: string,
	heistId: string,
	difficulty: string,
	modifierId: string?,
	isHotJob: boolean,
	mostWanted: boolean,
}

type HotPick = { slot: number, heistId: string?, modifierId: string, endsAt: number }

local L = MetaConfig.Lobby
local H = MetaConfig.HotJob
local HOT = "HotJob"
local VOTE_PHASES = { Garage = true, Payout = true, NextJob = true }

local LobbyService = {}

local votes: { [number]: JobBoard.Vote } = {}
local boardVersion = 0
local broadcastQueued = false
local lastRound: { [Player]: { roundId: string, at: number } } = {}
local currentHot: HotPick? = nil

-- Helpers ----------------------------------------------------------------------------------------------------

local function available(heistId: string): boolean
	return Registry.get(heistId) ~= nil
end

local function garagePlayers(): { Player }
	local list: { Player } = {}
	for _, player in Players:GetPlayers() do
		if not RequestGuard.inRound(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function tierList(
	offered: { [string]: boolean }
): { { id: string, label: string, mult: number, open: boolean } }
	local list = {}
	for _, tier in MetaConfig.Difficulty.Order do
		table.insert(list, {
			id = tier,
			label = MetaConfig.Difficulty.Labels[tier] or tier,
			mult = MetaConfig.Economy.DifficultyPayout[tier] or 1,
			open = offered[tier] == true,
		})
	end
	return list
end

-- The Hot Job for the current 30-minute slot, given which heists this server has open.
local function hotPick(open: { [string]: boolean }): HotPick
	local now = Clock.now()
	local slot = Calendar.slot(now, H.SlotSeconds)
	local pick = HotJob.pick(Rng.new(HotJob.seedFor(slot)) :: any, MetaConfig.Heists.Order, open, H.Modifiers)
	return {
		slot = slot,
		heistId = pick.heistId,
		modifierId = pick.modifierId,
		endsAt = Calendar.slotEndsAt(now, H.SlotSeconds),
	}
end

-- Open cards for a group of players: {[cardId] = {open, tiers}} plus the union and Hot Job used.
-- The Hot Job is picked from what the whole server has open (`serverHot`), so every board shows the same one;
-- for a smaller group (the boarders) its card is only open when that group has the heist.
local function cardsFor(
	players: { Player },
	serverHot: HotPick?
): ({ [string]: JobBoard.CardState }, { [string]: JobBoard.CrewHeist }, HotPick)
	local union = ProgressionService:CrewHeists(players)
	local cards: { [string]: JobBoard.CardState } = {}
	local open: { [string]: boolean } = {}
	for heistId, entry in union do
		local isOpen = entry.open and available(heistId)
		cards[heistId] = { open = isOpen, tiers = entry.tiers }
		open[heistId] = isOpen
	end
	local hot = serverHot or hotPick(open)
	if hot.heistId then
		local heistId = hot.heistId :: string
		local entry = union[heistId]
		cards[HOT] = { open = open[heistId] == true, tiers = if entry then entry.tiers else {} }
	end
	return cards, union, hot
end

local function serverHotPick(): HotPick
	local _, _, hot = cardsFor(Players:GetPlayers(), nil)
	return hot
end

local function canVoteHot(player: Player): boolean
	local data = DataService:Get(player)
	return data ~= nil and (data.stats.rounds or 0) >= H.MinRoundsToVote
end

-- Board snapshot -----------------------------------------------------------------------------------------------

function LobbyService:BuildBoard(): { [string]: any }
	local players = Players:GetPlayers()
	local cards, union, hot = cardsFor(players, nil)
	currentHot = hot
	local now = Clock.now()
	local mwHeist = ProfileView.mostWanted(now)
	local heists = {}
	for _, heistId in MetaConfig.Heists.Order do
		local entry = union[heistId]
		local isAvailable = available(heistId)
		table.insert(heists, {
			cardId = heistId,
			heistId = heistId,
			name = MetaConfig.Heists.Names[heistId] or heistId,
			available = isAvailable, -- false = "Coming soon" (map not built yet)
			open = cards[heistId] ~= nil and cards[heistId].open,
			requirement = HeistRecords.requirementText(
				heistId,
				MetaConfig.Progression.HeistUnlock,
				MetaConfig.Heists.Names
			),
			unlockedBy = if entry then entry.unlockedBy else nil,
			mostWanted = heistId == mwHeist,
			tiers = tierList(if entry then entry.tiers else {}),
		})
	end
	local hotCard = nil
	if hot.heistId then
		local heistId = hot.heistId :: string
		hotCard = {
			cardId = HOT,
			heistId = heistId,
			name = MetaConfig.Heists.Names[heistId] or heistId,
			modifierId = hot.modifierId,
			modifierName = MetaConfig.Modifiers.Names[hot.modifierId] or hot.modifierId,
			bonusPct = H.BonusPct,
			endsAt = hot.endsAt,
			open = true,
			minRounds = H.MinRoundsToVote, -- players with fewer rounds see it greyed out
			tiers = tierList(cards[HOT].tiers),
		}
	end
	local voteView: { [string]: { cardId: string, difficulty: string } } = {}
	local garage: { number } = {}
	for _, player in garagePlayers() do
		local vote = votes[player.UserId]
		if vote then
			voteView[tostring(player.UserId)] = { cardId = vote.cardId, difficulty = vote.difficulty }
			table.insert(garage, player.UserId)
		end
	end
	local selected = nil
	if #garage > 0 then
		local pick = JobBoard.tally(
			votes,
			garage,
			cards,
			MetaConfig.Difficulty.Order,
			MetaConfig.Heists.Default,
			MetaConfig.Difficulty.Default
		)
		selected = { cardId = pick.cardId, difficulty = pick.difficulty, votes = pick.votes }
	end
	boardVersion += 1
	return {
		version = boardVersion,
		heists = heists,
		hotJob = hotCard,
		mostWanted = { heistId = mwHeist, endsAt = Calendar.weekResetsAt(now) },
		votes = voteView,
		selected = selected,
		difficultyEnabled = Features.on("Difficulty"),
		serverNow = now,
	}
end

local function broadcastBoard()
	if broadcastQueued then
		return
	end
	broadcastQueued = true
	task.defer(function()
		broadcastQueued = false
		local board = LobbyService:BuildBoard()
		Net.broadcast("JobBoard", board)
		local hot = currentHot
		ReplicatedStorage:SetAttribute(MetaTags.HotJobHeist, if hot then hot.heistId else nil)
		ReplicatedStorage:SetAttribute(MetaTags.HotJobModifier, if hot then hot.modifierId else nil)
		ReplicatedStorage:SetAttribute(MetaTags.HotJobEndsAt, if hot then hot.endsAt else nil)
		ReplicatedStorage:SetAttribute(MetaTags.MostWantedHeist, (ProfileView.mostWanted(Clock.now())))
	end)
end

function LobbyService:Refresh()
	broadcastBoard()
end

-- Departure --------------------------------------------------------------------------------------------------

-- The job the boarders play: most votes among boarders, ties → earliest vote, no votes → The Golden Wheel on
-- Normal; the lowest tier any voter of the winning card chose, re-checked against the boarders' unlocks.
function LobbyService:GetSelectedJob(boarders: { Player }, roundId: string?): SelectedJob
	local list: { Player } = {}
	for _, player in boarders do
		if typeof(player) == "Instance" and player:IsA("Player") then
			table.insert(list, player)
		end
	end
	local cards, _, hot = cardsFor(list, serverHotPick())
	local voters: { number } = {}
	for _, player in list do
		table.insert(voters, player.UserId)
		local vote = votes[player.UserId]
		if vote and (not cards[vote.cardId] or not cards[vote.cardId].open) then
			local heistOfCard = if vote.cardId == HOT then hot.heistId or vote.cardId else vote.cardId
			local name = MetaConfig.Heists.Names[heistOfCard] or heistOfCard
			Net.send(player, "Toast", `You need a crew member who unlocked {name}.`)
		end
	end
	local pick = JobBoard.tally(
		votes,
		voters,
		cards,
		MetaConfig.Difficulty.Order,
		MetaConfig.Heists.Default,
		MetaConfig.Difficulty.Default
	)
	local isHot = pick.cardId == HOT and hot.heistId ~= nil
	local heistId = if isHot then hot.heistId :: string else pick.cardId
	local difficulty = if Features.on("Difficulty") then pick.difficulty else MetaConfig.Difficulty.Default
	local mwHeist = ProfileView.mostWanted(Clock.now())
	local job: SelectedJob = {
		cardId = pick.cardId,
		heistId = heistId,
		difficulty = difficulty,
		modifierId = if isHot then hot.modifierId else nil,
		isHotJob = isHot,
		mostWanted = heistId == mwHeist,
	}

	local now = os.clock()
	for _, player in list do
		votes[player.UserId] = nil
		local previous = lastRound[player]
		if previous and now - previous.at <= L.NextJobWindowSeconds then
			AnalyticsTracker:RoundStep(player, previous.roundId, "NextJob")
		end
		lastRound[player] = nil
		AnalyticsTracker:MarkDeparted(player, roundId)
	end
	if list[1] then
		AnalyticsTracker:Custom(
			list[1],
			"JobPicked",
			#list,
			{ heistId, difficulty, if isHot then "yes" else "no" }
		)
	end
	ShopService:PaintVan(list[1])
	broadcastBoard()
	return job
end

-- Requests ---------------------------------------------------------------------------------------------------

local function onVote(player: Player, cardId: any, difficulty: any)
	local id = RequestGuard.id(cardId)
	local tier = RequestGuard.id(difficulty) or MetaConfig.Difficulty.Default
	if not id then
		return
	end
	local phase = ReplicatedStorage:GetAttribute("RoundPhase")
	if RequestGuard.inRound(player) and not (type(phase) == "string" and VOTE_PHASES[phase]) then
		Net.send(player, "MetaResult", "Vote", false, id, "InRound")
		return
	end
	if not table.find(MetaConfig.Difficulty.Order, tier) or not Features.on("Difficulty") then
		tier = MetaConfig.Difficulty.Default
	end
	local cards = cardsFor(Players:GetPlayers(), nil)
	local card = cards[id]
	if not card or not card.open then
		Net.send(player, "MetaResult", "Vote", false, id, "Locked")
		return
	end
	if id == HOT and not canVoteHot(player) then
		Net.send(player, "MetaResult", "Vote", false, id, "NeedRounds")
		return
	end
	if not card.tiers[tier] then
		tier =
			JobBoard.clampTier(tier, card.tiers, MetaConfig.Difficulty.Order, MetaConfig.Difficulty.Default)
	end
	votes[player.UserId] = { cardId = id, difficulty = tier, at = os.clock() }
	local chosen = tier
	DataService:Update(player, "Vote", function(data)
		data.lastDifficulty = chosen
	end)
	Net.send(player, "MetaResult", "Vote", true, id, "")
	broadcastBoard()
end

-- Garage stations ---------------------------------------------------------------------------------------------

local function promptParent(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function hookStation(instance: Instance, tag: string, station: { Screen: string, Action: string })
	local part = promptParent(instance)
	if not part or part:FindFirstChild("MetaStationPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MetaStationPrompt"
	prompt.ActionText = station.Action
	prompt.ObjectText = ""
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = L.StationPromptDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("ContextIcon", tag)
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if
			RequestGuard.inRound(player)
			or not RequestGuard.allow(player, "Station", { burst = 3, perSecond = 1 })
		then
			return
		end
		if tag == MetaTags.JobBoard then
			Net.send(player, "JobBoard", LobbyService:BuildBoard())
		end
		DataService:Sync(player)
		Net.send(player, "OpenScreen", station.Screen)
	end)
end

-- "Sam 4 · Alex 2": main loot banked by the players in this server.
local function updateTrophyLeaders()
	local rows: { { name: string, count: number } } = {}
	for _, player in Players:GetPlayers() do
		local data = DataService:Get(player)
		local count = if data then data.stats.mainLoot or 0 else 0
		if count > 0 then
			table.insert(rows, { name = player.DisplayName, count = count })
		end
	end
	table.sort(rows, function(a, b)
		return a.count > b.count
	end)
	local parts: { string } = {}
	for i = 1, math.min(#rows, 4) do
		table.insert(parts, `{rows[i].name} {rows[i].count}`)
	end
	ReplicatedStorage:SetAttribute(MetaTags.TrophyLeaders, table.concat(parts, " · "))
end

-- Private Crew (published game only) --------------------------------------------------------------------------

type Invite = { from: Player, answers: { [Player]: boolean }, endsAt: number }
local invite: Invite? = nil
local inviteCooldown: { [Player]: number } = {}

local function inReservedServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function teleportCrew(list: { Player })
	for _, player in list do
		DataService:PrepareTeleportAsync(player)
	end
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ShouldReserveServer = true
		TeleportService:TeleportAsync(game.PlaceId, list, options)
	end)
	if not ok then
		warn(`[Lobby] Private Crew teleport failed: {err}`)
		for _, player in list do
			DataService:CancelTeleport(player)
			Net.send(player, "Toast", "Private Crew failed. Try again in a minute.")
		end
	end
end

local function onPrivateCrewStart(player: Player)
	if RunService:IsStudio() or game.PlaceId == 0 then
		Net.send(player, "Toast", "Private Crew works in the live game.")
		return
	end
	if inReservedServer() then
		Net.send(player, "Toast", "You are already in a Private Crew.")
		return
	end
	if invite or RequestGuard.inRound(player) or os.clock() < (inviteCooldown[player] or 0) then
		Net.send(player, "Toast", "Not now.")
		return
	end
	inviteCooldown[player] = os.clock() + L.PrivateCrewCooldownSeconds
	local current: Invite = { from = player, answers = {}, endsAt = os.clock() + L.PrivateCrewInviteSeconds }
	invite = current
	for _, other in garagePlayers() do
		if other ~= player then
			Net.send(other, "PrivateCrewInvite", player.DisplayName, L.PrivateCrewInviteSeconds)
		end
	end
	task.delay(L.PrivateCrewInviteSeconds, function()
		if invite ~= current then
			return
		end
		invite = nil
		local list: { Player } = { player }
		for other, yes in current.answers do
			if yes and other.Parent == Players and not RequestGuard.inRound(other) then
				table.insert(list, other)
			end
		end
		if player.Parent == Players then
			teleportCrew(list)
		end
	end)
end

local function onPrivateCrewAnswer(player: Player, yes: any)
	local current = invite
	if current and current.from ~= player and type(yes) == "boolean" and os.clock() <= current.endsAt then
		current.answers[player] = yes
	end
end

-- Lifecycle --------------------------------------------------------------------------------------------------

function LobbyService:Start()
	RequestGuard.on("JobVote", onVote)
	RequestGuard.on("PrivateCrewStart", onPrivateCrewStart, { burst = 1, perSecond = 0.1 })
	RequestGuard.on("PrivateCrewAnswer", onPrivateCrewAnswer)

	TeleportService.TeleportInitFailed:Connect(function(player: Player)
		DataService:CancelTeleport(player)
	end)

	for tag, station in L.Stations do
		for _, instance in CollectionService:GetTagged(tag) do
			hookStation(instance, tag, station)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			hookStation(instance, tag, station)
		end)
	end

	EconomyService.Settled:Connect(function(player: Player, roundId: string)
		lastRound[player] = { roundId = roundId, at = os.clock() }
		updateTrophyLeaders()
	end)

	DataService.Loaded:Connect(function(player: Player)
		updateTrophyLeaders()
		broadcastBoard()
		-- Onboarding step 8: the first time this player is in the Garage after the mini-job.
		local function check()
			local data = DataService:Get(player)
			if data and data.onboarding.done and player:GetAttribute(MetaTags.Activity) == "Garage" then
				AnalyticsTracker:OnboardingStep(player, "GarageReached")
			end
		end
		player:GetAttributeChangedSignal(MetaTags.Activity):Connect(check)
		check()
	end)
	DataService.Changed:Connect(function(_player: Player, reason: string)
		if
			reason == "SettleRound"
			or reason == "MiniJob"
			or reason == "DevSetRank"
			or reason == "DevSetStars"
		then
			broadcastBoard()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		votes[player.UserId] = nil
		lastRound[player] = nil
		inviteCooldown[player] = nil
		task.defer(function()
			updateTrophyLeaders()
			broadcastBoard()
		end)
	end)

	-- New Hot Job every slot (and keep late joiners' boards fresh).
	task.spawn(function()
		local lastSlot = -1
		while true do
			local slot = Calendar.slot(Clock.now(), H.SlotSeconds)
			if slot ~= lastSlot then
				lastSlot = slot
				broadcastBoard()
			end
			task.wait(L.BoardRefreshSeconds)
		end
	end)
	Players.PlayerAdded:Connect(function()
		broadcastBoard()
	end)
	broadcastBoard()
end

return LobbyService
