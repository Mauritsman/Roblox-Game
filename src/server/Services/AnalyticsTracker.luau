--!strict
-- Analytics wrapper (owner: meta). Not called AnalyticsService so it can't be mixed up with Roblox's.
-- Every call is one pcall and never breaks gameplay. AnalyticsService only records in the published game, so in
-- Studio the tracker prints "[Analytics] …" instead of calling it (docs/beta-spec-meta.md §6).
--
-- Mechanics reports gameplay moments by NAME; the tracker maps names to step numbers so the order stays meta's:
--   AnalyticsTracker:OnboardingStep(player, "GoudaLifted")
--   AnalyticsTracker:RoundStep(player, roundId, "FirstLootBanked")

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local Net = require(ReplicatedStorage.Shared.Net)

local RequestGuard = require(script.Parent.Parent.Meta.RequestGuard)
local DataService = require(script.Parent.DataService)

local A = MetaConfig.Analytics

local AnalyticsTracker = {}

local IS_STUDIO = RunService:IsStudio()

local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

type RoundState = { roundId: string, steps: { [number]: boolean } }

local onboardingIndex: { [string]: number } = {}
for i, name in A.OnboardingSteps do
	onboardingIndex[name] = i
end
local roundIndex: { [string]: number } = {}
for i, name in A.RoundSteps do
	roundIndex[name] = i
end

local roundState: { [Player]: RoundState } = {}
local pendingDeparture: { [Player]: boolean } = {}
local roundsThisSession: { [Player]: number } = {}
local feedbackRounds: { [Player]: { [string]: boolean } } = {}

local function studioPrint(text: string)
	if IS_STUDIO and A.StudioPrint then
		print(`[Analytics] {text}`)
	end
end

local function fieldsOf(fields: { string }?): { [string]: any }?
	if not fields or #fields == 0 then
		return nil
	end
	local result: { [string]: any } = {}
	for i, value in fields do
		if FIELD_KEYS[i] then
			result[FIELD_KEYS[i]] = string.sub(tostring(value), 1, 50)
		end
	end
	return result
end

local function safe(label: string, fn: () -> ())
	if IS_STUDIO then
		return
	end
	local ok, err = pcall(fn :: any)
	if not ok then
		warn(`[Analytics] {label} failed: {err}`)
	end
end

-- Custom event: name, optional value and up to 3 low-cardinality text fields.
function AnalyticsTracker:Custom(player: Player?, name: string, value: number?, fields: { string }?)
	local shown = if fields then table.concat(fields, ", ") else ""
	studioPrint(`{name} {if player then player.Name else "-"} = {value or 1} {shown}`)
	if not player then
		return -- AnalyticsService needs a player; server-wide events only print
	end
	safe(name, function()
		AnalyticsService:LogCustomEvent(player :: Player, name, value or 1, fieldsOf(fields))
	end)
end

-- Economy event. flow = "Source" | "Sink"; transactionType = an Enum.AnalyticsEconomyTransactionType name.
function AnalyticsTracker:Economy(
	player: Player,
	flow: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	sku: string
)
	if amount <= 0 then
		return
	end
	studioPrint(`economy {flow} {player.Name} {amount} Cash ({transactionType}, {sku}) → {endingBalance}`)
	safe("economy", function()
		local flowType = if flow == "Sink"
			then Enum.AnalyticsEconomyFlowType.Sink
			else Enum.AnalyticsEconomyFlowType.Source
		AnalyticsService:LogEconomyEvent(
			player,
			flowType,
			"Cash",
			amount,
			endingBalance,
			transactionType,
			sku
		)
	end)
end

-- Onboarding funnel, once per player ever (stored in onboarding.steps). Also tells the client (ux hints).
function AnalyticsTracker:OnboardingStep(player: Player, name: string)
	local canonical = A.StepAliases[name] or name
	local step = onboardingIndex[canonical]
	if not step then
		warn(`[Analytics] unknown onboarding step "{name}"`)
		return
	end
	task.spawn(function()
		local data = DataService:WaitForData(player, 15)
		if not data or data.onboarding.steps[canonical] then
			return
		end
		local recorded = DataService:Update(player, "OnboardingStep", function(d)
			d.onboarding.steps[canonical] = true
		end)
		if not recorded then
			return
		end
		studioPrint(`onboarding {player.Name} {step} {canonical}`)
		safe("onboarding", function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, canonical)
		end)
		Net.send(player, "Onboarding", step, canonical)
	end)
end

local function logRoundStep(player: Player, roundId: string, step: number, name: string)
	local current = roundState[player]
	local state: RoundState
	if current and current.roundId == roundId then
		state = current
	else
		state = { roundId = roundId, steps = {} }
		roundState[player] = state
	end
	if state.steps[step] then
		return
	end
	state.steps[step] = true
	studioPrint(`round {player.Name} {roundId} {step} {name}`)
	safe("round funnel", function()
		AnalyticsService:LogFunnelStepEvent(player, "Round", roundId, step, name)
	end)
end

-- Round funnel step by name, once per player and round. The first step reported for a new roundId also logs a
-- pending "VanDeparted" (LobbyService:GetSelectedJob marks it before the roundId exists).
function AnalyticsTracker:RoundStep(player: Player, roundId: string, name: string)
	local step = roundIndex[name]
	if not step or type(roundId) ~= "string" or roundId == "" then
		warn(`[Analytics] bad round step "{name}"`)
		return
	end
	local state = roundState[player]
	if (not state or state.roundId ~= roundId) and pendingDeparture[player] and step ~= 1 then
		pendingDeparture[player] = nil
		logRoundStep(player, roundId, 1, A.RoundSteps[1])
	end
	if step == 1 then
		pendingDeparture[player] = nil
	end
	logRoundStep(player, roundId, step, name)
end

-- LobbyService calls this at departure when no roundId is known yet.
function AnalyticsTracker:MarkDeparted(player: Player, roundId: string?)
	if roundId then
		self:RoundStep(player, roundId, A.RoundSteps[1])
	else
		pendingDeparture[player] = true
	end
end

-- Called by EconomyService when a real round is settled (counts rounds for SessionEnded).
function AnalyticsTracker:RoundSettled(player: Player)
	roundsThisSession[player] = (roundsThisSession[player] or 0) + 1
end

local function onFeedback(player: Player, mood: any, tags: any, roundId: any)
	local moodValue = RequestGuard.int(mood, 1, 3)
	local round = if type(roundId) == "string" and #roundId <= 64 then roundId else nil
	if not moodValue or not round then
		return
	end
	local seen = feedbackRounds[player]
	if not seen then
		seen = {}
		feedbackRounds[player] = seen
	end
	if seen[round] then
		return
	end
	seen[round] = true
	local clean: { string } = {}
	if type(tags) == "table" then
		for _, tag in tags do
			local id = RequestGuard.id(tag)
			if id and table.find(A.FeedbackTags, id) and not table.find(clean, id) and #clean < 2 then
				table.insert(clean, id)
			end
		end
	end
	local heist = ReplicatedStorage:GetAttribute("HeistId")
	AnalyticsTracker:Custom(player, "FeedbackTap", moodValue, {
		clean[1] or "-",
		clean[2] or "-",
		if type(heist) == "string" then heist else "-",
	})
end

function AnalyticsTracker:Start()
	RequestGuard.on("Feedback", onFeedback, { burst = 2, perSecond = 0.2 })

	DataService.Logged:Connect(function(name: string, player: Player?, value: number)
		AnalyticsTracker:Custom(player, name, value)
	end)
	DataService.Leaving:Connect(function(player: Player, seconds: number)
		AnalyticsTracker:Custom(player, "SessionEnded", seconds, { tostring(roundsThisSession[player] or 0) })
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			roundState[player] = nil
			pendingDeparture[player] = nil
			roundsThisSession[player] = nil
			feedbackRounds[player] = nil
		end)
	end)

	-- Onboarding step 1: the server knows when a new player spawns.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			local data = DataService:WaitForData(player, 15)
			if data and not data.onboarding.done then
				AnalyticsTracker:OnboardingStep(player, "Spawned")
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return AnalyticsTracker
