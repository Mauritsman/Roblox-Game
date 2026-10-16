--!strict
-- Economy (owner: meta): round settlement, Cash in and out, daily contracts and the daily ×2, weekly Most Wanted,
-- collection book and trophies. docs/beta-spec-meta.md §3.
--
-- Mechanics calls EconomyService:SettleRound(result) ONCE per round (Getaway, Busted, mini-job end or the
-- shutdown hook). It is idempotent per roundId (per server and per profile), applies everything for a player in
-- one DataService:Update, saves, logs analytics and sends each crew member a "Payout" message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Calendar = require(ReplicatedStorage.Shared.Logic.Calendar)
local Collection = require(ReplicatedStorage.Shared.Logic.Collection)
local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local DataSchema = require(ReplicatedStorage.Shared.Logic.DataSchema)
local HeistRecords = require(ReplicatedStorage.Shared.Logic.HeistRecords)
local Ledger = require(ReplicatedStorage.Shared.Logic.Ledger)
local Payout = require(ReplicatedStorage.Shared.Logic.Payout)
local Rng = require(ReplicatedStorage.Shared.Logic.Rng)

local Meta = script.Parent.Parent.Meta
local Access = require(Meta.Access)
local Clock = require(Meta.Clock)
local ProfileView = require(Meta.ProfileView)
local RequestGuard = require(Meta.RequestGuard)
local AnalyticsTracker = require(script.Parent.AnalyticsTracker)
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

type PlayerData = DataSchema.PlayerData

export type CrewStats = { [string]: number }
export type CrewEntry = { player: Player, inVanAtEnd: boolean, award: string?, stats: CrewStats? }
export type BankedItem = { lootId: string, name: string, class: string, value: number }
export type RoundResult = {
	roundId: string, -- GUID: the idempotency key
	heistId: string, -- "GoldenWheel" | "PralinePalace" | "TulipAuction" | "MiniJob"
	difficulty: string, -- "Easy" | "Normal" | "Hard" (mini-job: "Normal")
	modifierId: string?,
	isHotJob: boolean?,
	outcome: string, -- "Escaped" | "Busted" | "Aborted" | "Shutdown"
	vanLoot: number, -- base value in the van at the end
	stars: number, -- 0–3 (mechanics' star rules; 1★ needs an escape)
	mainLootBanked: boolean?,
	maxAlarmTier: number?,
	lockdownAtEnd: boolean?,
	durationSeconds: number?,
	objectives: { { id: string, bonusPct: number } }?, -- optional objectives completed
	banked: { BankedItem }?,
	crew: { CrewEntry },
}
export type Settled = { cash: number, rep: number }

local E = MetaConfig.Economy
local TX = Enum.AnalyticsEconomyTransactionType

local EconomyService = {}

-- Fired after a player's round was settled (player, roundId, outcome, heistId).
EconomyService.Settled = Signal.new() :: Signal.Signal<Player, string, string, string>

local settledRounds: { [string]: { [number]: Settled } } = {}
local settledOrder: { string } = {}
local templatesById = Contracts.byId(MetaConfig.Contracts.Templates)
local trackedLoot = Collection.tracked(MetaConfig.Collection.Pages)

-- Daily / weekly reset ---------------------------------------------------------------------------------------

local function contractRng(userId: number, day: number, salt: number): any
	return Rng.new(Contracts.seedFor(userId, day) + salt)
end

-- Inside an Update: new contracts and a fresh daily ×2 when the UTC day changed; Most Wanted per week.
function EconomyService.refreshPeriods(data: PlayerData, userId: number, now: number): boolean
	local changed = false
	local today = Calendar.day(now)
	if data.daily.day ~= today then
		data.daily = {
			day = today,
			contracts = Contracts.generate(
				MetaConfig.Contracts.Templates,
				Access.contractContext(data),
				MetaConfig.Contracts.Rewards,
				MetaConfig.Contracts.MaxNeedsCrew,
				contractRng(userId, today, 0)
			),
			firstJobUsed = false,
			rerolls = 0,
		}
		changed = true
	end
	local week = Calendar.week(now)
	if data.weekly.week ~= week then
		data.weekly = { week = week, mostWantedDone = false }
		changed = true
	end
	return changed
end

local function periodsStale(data: PlayerData, now: number): boolean
	return data.daily.day ~= Calendar.day(now) or data.weekly.week ~= Calendar.week(now)
end

local function refreshPlayer(player: Player)
	local data = DataService:Get(player)
	local now = Clock.now()
	if data and periodsStale(data, now) then
		DataService:Update(player, "DailyReset", function(d)
			EconomyService.refreshPeriods(d, player.UserId, now)
		end)
	end
end

-- Cash in and out --------------------------------------------------------------------------------------------

-- Adds Cash (never Rep) and logs an economy Source event. transactionType: Enum.AnalyticsEconomyTransactionType name.
function EconomyService:Grant(player: Player, amount: number, transactionType: string, sku: string): boolean
	local value = math.floor(amount)
	if value <= 0 then
		return false
	end
	local ok = DataService:Update(player, `Grant:{sku}`, function(data)
		data.cash += value
		data.stats.cashEarned = (data.stats.cashEarned or 0) + value
	end)
	local data = DataService:Get(player)
	if ok and data then
		AnalyticsTracker:Economy(player, "Source", value, data.cash, transactionType, sku)
	end
	return ok
end

-- Takes Cash and applies `apply` in the SAME Update (e.g. grant the bought item). Never goes negative.
-- Returns false, "NotEnoughCash" | "Busy".
function EconomyService:Spend(
	player: Player,
	amount: number,
	sku: string,
	apply: ((PlayerData) -> ())?
): (boolean, string?)
	local value = math.floor(amount)
	local data = DataService:Get(player)
	if not data or value < 0 then
		return false, "Busy"
	end
	if data.cash < value then
		return false, "NotEnoughCash"
	end
	local ok = DataService:Update(player, `Spend:{sku}`, function(d)
		if d.cash < value then
			error("not enough cash")
		end
		d.cash -= value
		d.stats.cashSpent = (d.stats.cashSpent or 0) + value
		if apply then
			apply(d)
		end
	end)
	if not ok then
		return false, "Busy"
	end
	local after = DataService:Get(player)
	AnalyticsTracker:Economy(player, "Sink", value, if after then after.cash else 0, TX.Shop.Name, sku)
	return true, nil
end

-- Round settlement -------------------------------------------------------------------------------------------

local OUTCOMES = { Escaped = true, Busted = true, Aborted = true, Shutdown = true }

local function num(value: any, default: number): number
	return if type(value) == "number" and value == value and value ~= math.huge then value else default
end

local function remember(roundId: string, summary: { [number]: Settled })
	settledRounds[roundId] = summary
	table.insert(settledOrder, roundId)
	if #settledOrder > 200 then
		settledRounds[table.remove(settledOrder, 1) :: string] = nil
	end
end

local function awardsOf(crew: { CrewEntry }): { { userId: number, awardId: string } }
	local list = {}
	for _, entry in crew do
		if typeof(entry.player) == "Instance" and type(entry.award) == "string" then
			table.insert(list, { userId = entry.player.UserId, awardId = entry.award :: string })
		end
	end
	return list
end

local function itemsOf(banked: { BankedItem }): { { name: string, class: string, value: number } }
	local list = {}
	for _, item in banked do
		table.insert(
			list,
			{ name = tostring(item.name), class = tostring(item.class), value = num(item.value, 0) }
		)
	end
	return list
end

local function settleMiniJob(result: RoundResult, crew: { CrewEntry }, summary: { [number]: Settled })
	for _, entry in crew do
		local player = entry.player
		local data = DataService:Get(player)
		if data and not Ledger.contains(data.recentRounds, result.roundId) then
			local welcome = false
			local cash, rep, rankCash = 0, 0, 0
			local rankBefore = Access.rank(data)
			local ok = DataService:Update(player, "MiniJob", function(d)
				Ledger.push(d.recentRounds, result.roundId, MetaConfig.Data.RecentRounds)
				if result.outcome ~= "Aborted" and not d.onboarding.done then
					welcome = true
					cash, rep = E.WelcomeBonus, E.WelcomeRep
					d.cash += cash
					d.rep += rep
					d.stats.cashEarned = (d.stats.cashEarned or 0) + cash
					d.onboarding.done = true
					rankCash = ProgressionService.claimRankRewards(d)
				end
			end)
			if ok then
				summary[player.UserId] = { cash = cash, rep = rep }
				local after = DataService:Get(player) :: PlayerData
				local rankAfter = Access.rank(after)
				if welcome then
					AnalyticsTracker:Economy(
						player,
						"Source",
						cash,
						after.cash,
						TX.Onboarding.Name,
						"Welcome"
					)
					AnalyticsTracker:OnboardingStep(player, "MiniJobEscaped")
					Net.send(player, "Toast", `Welcome bonus +{cash}`)
				end
				ProgressionService:NotifyRankUp(player, rankBefore, rankAfter, rankCash)
				Net.send(player, "Payout", {
					roundId = result.roundId,
					heistId = result.heistId,
					heistName = MetaConfig.Heists.Names[result.heistId] or result.heistId,
					difficulty = "Normal",
					outcome = result.outcome,
					stars = math.clamp(math.floor(num(result.stars, 0)), 0, 3),
					items = itemsOf(result.banked or {}),
					vanTotal = num(result.vanLoot, 0),
					crewSize = 1,
					cut = cash,
					crewBonusPct = 0,
					tierMultiplier = 1,
					bonuses = {},
					busted = false,
					caughtHalf = false,
					firstJobToday = false,
					welcome = welcome,
					cash = cash,
					rep = rep,
					totalCash = cash + rankCash,
					balance = after.cash,
					awards = awardsOf(crew),
					rankBefore = rankBefore,
					rankAfter = rankAfter,
					rankCash = rankCash,
					unlocks = ProgressionService.unlocksBetween(rankBefore, rankAfter),
					newItems = {},
					newStars = { count = 0, cash = 0 },
					contracts = {},
					contractCash = 0,
					mostWanted = { done = false },
					newCollection = {},
					collectionCash = 0,
					trophy = false,
				})
				task.spawn(function()
					DataService:SaveNowAsync(player, "MiniJob")
				end)
			end
		end
	end
end

-- Settles a finished round for every crew member still in the server. Returns {[userId] = {cash, rep}}.
function EconomyService:SettleRound(result: RoundResult): { [number]: Settled }
	if type(result) ~= "table" or type(result.roundId) ~= "string" or result.roundId == "" then
		warn("[Economy] SettleRound needs a roundId")
		return {}
	end
	local cached = settledRounds[result.roundId]
	if cached then
		return cached
	end
	local summary: { [number]: Settled } = {}
	remember(result.roundId, summary)

	local outcome = if OUTCOMES[result.outcome] then result.outcome else "Aborted"
	local heistId = if type(result.heistId) == "string" then result.heistId else MetaConfig.Heists.Default
	local difficulty = if E.DifficultyPayout[result.difficulty]
		then result.difficulty
		else MetaConfig.Difficulty.Default
	local vanLoot = math.max(0, num(result.vanLoot, 0))
	local stars = math.clamp(math.floor(num(result.stars, 0)), 0, 3)
	local maxAlarmTier = num(result.maxAlarmTier, 3)
	local banked: { BankedItem } = if type(result.banked) == "table"
		then result.banked :: { BankedItem }
		else {}
	local objectives = if type(result.objectives) == "table" then result.objectives else {}
	local isHotJob = result.isHotJob == true
	local mainLootBanked = result.mainLootBanked == true

	local crew: { CrewEntry } = {}
	for _, entry in (if type(result.crew) == "table" then result.crew else {}) :: { CrewEntry } do
		if type(entry) == "table" and typeof(entry.player) == "Instance" and entry.player:IsA("Player") then
			if entry.player.Parent == Players then
				table.insert(crew, entry)
			end
		end
	end
	if #crew == 0 or outcome == "Aborted" then
		return summary
	end
	if heistId == MetaConfig.Heists.MiniJob then
		settleMiniJob(result, crew, summary)
		return summary
	end

	local n = #crew
	local allInVan = true
	for _, entry in crew do
		if not entry.inVanAtEnd then
			allInVan = false
		end
	end
	local tierMultiplier = E.DifficultyPayout[difficulty] or 1
	local mwHeist, mwItem, week = ProfileView.mostWanted(Clock.now())
	local realRound = outcome == "Escaped" or outcome == "Busted"
	local heistName = MetaConfig.Heists.Names[heistId] or heistId

	for _, entry in crew do
		local player = entry.player
		local userId = player.UserId
		local data = DataService:Get(player)
		if data and not Ledger.contains(data.recentRounds, result.roundId) then
			local now = Clock.now()
			local stats: CrewStats = if type(entry.stats) == "table" then entry.stats :: CrewStats else {}
			local rankBefore = Access.rank(data)
			local heistsBefore = Access.heists(data)
			local roundsBefore = data.stats.rounds or 0
			local s = {
				pay = (nil :: any) :: Payout.Result,
				newStars = 0,
				starCash = 0,
				completed = {} :: { Contracts.Contract },
				contractCash = 0,
				mostWanted = { done = false } :: { [string]: any },
				mwCash = 0,
				newCollection = {} :: { string },
				collectionCash = 0,
				newItems = {} :: { string },
				rankCash = 0,
				trophy = false,
			}
			local ok = DataService:Update(player, "SettleRound", function(d)
				EconomyService.refreshPeriods(d, userId, now)
				local pay = Payout.compute({
					outcome = outcome,
					vanLoot = vanLoot,
					crewSize = n,
					inVanAtEnd = entry.inVanAtEnd == true,
					allInVan = allInVan,
					difficulty = difficulty,
					isHotJob = isHotJob,
					maxAlarmTier = maxAlarmTier,
					objectives = objectives,
					fresh = Payout.isFresh(d.recentHeists, heistId, E.FreshWindow),
					firstJobAvailable = not d.daily.firstJobUsed,
				}, E)
				s.pay = pay
				d.cash += pay.cash
				d.rep += pay.rep
				d.stats.cashEarned = (d.stats.cashEarned or 0) + pay.cash
				d.stats.bestPayout = math.max(d.stats.bestPayout or 0, pay.cash)
				if pay.firstJobToday then
					d.daily.firstJobUsed = true
				end
				Ledger.push(d.recentRounds, result.roundId, MetaConfig.Data.RecentRounds)

				if realRound then
					d.stats.rounds = roundsBefore + 1
					if pay.escaped then
						d.stats.escapes = (d.stats.escapes or 0) + 1
					end
					if pay.busted then
						d.stats.busts = (d.stats.busts or 0) + 1
					end
					d.stats.rescues = (d.stats.rescues or 0) + math.max(0, math.floor(num(stats.rescues, 0)))
					d.stats.lootBanked = (d.stats.lootBanked or 0)
						+ math.max(0, math.floor(num(stats.lootBanked, 0)))
					d.lastDifficulty = difficulty
					Ledger.push(d.recentHeists, heistId, MetaConfig.Data.RecentHeists)

					-- Stars (best per tier, only when this player escaped) and their first-time bonus.
					s.newStars =
						HeistRecords.record(d.heists, heistId, difficulty, stars, pay.escaped, vanLoot)
					s.starCash = HeistRecords.starCash(s.newStars, E.StarBonus, tierMultiplier)
					d.cash += s.starCash

					-- Trophy wall: every escaped round with the main loot.
					if pay.escaped and mainLootBanked then
						d.stats.mainLoot = (d.stats.mainLoot or 0) + 1
						Collection.pushTrophy(d.trophies, {
							loot = "GoldenGouda",
							heist = heistId,
							tier = difficulty,
							crew = n,
							at = now,
						}, MetaConfig.Data.TrophyLog)
						s.trophy = true
					end

					-- Collection book: everything banked counts for the whole crew.
					s.newCollection = Collection.record(d.collection, banked :: any, trackedLoot)
					for _, pageId in
						Collection.newPages(d.collection, MetaConfig.Collection.Pages, d.collectionRewards)
					do
						d.collectionRewards[pageId] = now
						local item = MetaConfig.Collection.PageReward[pageId]
						if item and Catalog.get(item) and not d.owned[item] then
							d.owned[item] = now
							table.insert(s.newItems, item)
						else
							s.collectionCash += E.CollectionPageCash
						end
					end
					d.cash += s.collectionCash

					-- Daily contracts.
					s.completed = Contracts.apply(d.daily.contracts, templatesById, {
						outcome = outcome,
						escaped = pay.escaped,
						isHotJob = isHotJob,
						difficulty = difficulty,
						stars = stars,
						mainLootBanked = mainLootBanked,
						maxAlarmTier = maxAlarmTier,
						stats = stats,
					}, E.QuietJobMaxTier)
					for _, contract in s.completed do
						s.contractCash += contract.reward
					end
					d.cash += s.contractCash

					-- Weekly Most Wanted: 3★ on this week's heist on Normal or Hard, once per week.
					local MW = MetaConfig.MostWanted
					if
						heistId == mwHeist
						and pay.escaped
						and stars >= MW.StarsNeeded
						and MW.Tiers[difficulty]
						and not (d.weekly.week == week and d.weekly.mostWantedDone)
					then
						d.weekly = { week = week, mostWantedDone = true }
						if not d.owned[mwItem] then
							d.owned[mwItem] = now
							table.insert(s.newItems, mwItem)
							s.mostWanted = { done = true, item = mwItem }
						else
							s.mwCash = E.MostWantedDuplicateCash
							d.cash += s.mwCash
							s.mostWanted = { done = true, cash = s.mwCash }
						end
					end

					-- Mastery and star masks.
					for _, item in
						HeistRecords.rewardItems(
							d.heists,
							MetaConfig.Progression.MasteryMask,
							MetaConfig.Progression.MasteryTier,
							MetaConfig.Progression.StarMasks,
							d.owned
						)
					do
						d.owned[item] = now
						table.insert(s.newItems, item)
					end
					d.stats.cashEarned += s.starCash + s.collectionCash + s.contractCash + s.mwCash
				end
				s.rankCash = ProgressionService.claimRankRewards(d)
			end)

			if ok then
				local pay = s.pay
				local after = DataService:Get(player) :: PlayerData
				local rankAfter = Access.rank(after)
				summary[userId] = { cash = pay.cash, rep = pay.rep }

				-- Newly opened heists and tiers.
				local unlocks = ProgressionService.unlocksBetween(rankBefore, rankAfter)
				local heistsAfter = Access.heists(after)
				for _, id in MetaConfig.Heists.Order do
					local was, now2 = heistsBefore[id], heistsAfter[id]
					if now2.open and not was.open then
						if now2.route == "Stars" then
							table.insert(
								unlocks,
								{ kind = "Heist", id = id, name = MetaConfig.Heists.Names[id] or id }
							)
						end
						AnalyticsTracker:Custom(
							player,
							"HeistUnlocked",
							1,
							{ id, string.lower(now2.route or "") }
						)
					end
					for tier, on in now2.tiers do
						if on and not was.tiers[tier] then
							local name = `{tier} on {MetaConfig.Heists.Names[id] or id}`
							table.insert(unlocks, { kind = "Tier", id = `{id}:{tier}`, name = name })
						end
					end
				end
				for _, item in s.newItems do
					local def = Catalog.get(item)
					table.insert(unlocks, { kind = "Item", id = item, name = if def then def.Name else item })
				end

				-- Analytics.
				local balance = after.cash
				AnalyticsTracker:RoundSettled(player)
				EconomyService.Settled:Fire(player, result.roundId, outcome, heistId)
				AnalyticsTracker:Economy(player, "Source", pay.cash, balance, TX.Gameplay.Name, heistId)
				AnalyticsTracker:Economy(player, "Source", s.starCash, balance, TX.Gameplay.Name, "StarBonus")
				AnalyticsTracker:Economy(
					player,
					"Source",
					s.collectionCash,
					balance,
					TX.Gameplay.Name,
					"Collection"
				)
				AnalyticsTracker:Economy(
					player,
					"Source",
					s.mwCash,
					balance,
					TX.TimedReward.Name,
					"MostWanted"
				)
				for _, contract in s.completed do
					AnalyticsTracker:Economy(
						player,
						"Source",
						contract.reward,
						balance,
						TX.TimedReward.Name,
						contract.id
					)
					AnalyticsTracker:Custom(player, "ContractCompleted", contract.reward, { contract.id })
				end
				AnalyticsTracker:Custom(
					player,
					"RoundEnded",
					num(result.durationSeconds, 0),
					{ heistId, outcome, difficulty }
				)
				if s.newStars > 0 then
					AnalyticsTracker:Custom(
						player,
						"StarEarned",
						HeistRecords.bestStars(after.heists, heistId, difficulty),
						{ heistId, difficulty }
					)
				end
				if s.mostWanted.done then
					AnalyticsTracker:Custom(player, "MostWantedCompleted", 1, { heistId })
				end
				if realRound and roundsBefore == 0 then
					AnalyticsTracker:Custom(player, "FirstRealJob", 1, { heistId })
				end
				if pay.clamped then
					AnalyticsTracker:Custom(player, "PayoutClamped", 1)
				end
				if pay.escaped then
					AnalyticsTracker:RoundStep(player, result.roundId, "Escaped")
				end
				ProgressionService:NotifyRankUp(player, rankBefore, rankAfter, s.rankCash)

				local completedList = {}
				for _, contract in s.completed do
					local template = templatesById[contract.id]
					table.insert(completedList, {
						id = contract.id,
						text = if template then template.Text else contract.id,
						reward = contract.reward,
					})
				end
				Net.send(player, "Payout", {
					roundId = result.roundId,
					heistId = heistId,
					heistName = heistName,
					difficulty = difficulty,
					modifierId = result.modifierId,
					isHotJob = isHotJob,
					outcome = outcome,
					stars = stars,
					items = itemsOf(banked),
					vanTotal = vanLoot,
					crewSize = n,
					cut = Payout.roundHalfUp(pay.share),
					crewBonusPct = pay.crewBonusPct,
					tierMultiplier = pay.tierMultiplier,
					bonuses = pay.bonuses,
					busted = pay.busted,
					caughtHalf = pay.caughtHalf,
					firstJobToday = pay.firstJobToday,
					welcome = false,
					cash = pay.cash,
					rep = pay.rep,
					totalCash = pay.cash
						+ s.starCash
						+ s.contractCash
						+ s.mwCash
						+ s.collectionCash
						+ s.rankCash,
					balance = balance,
					awards = awardsOf(crew),
					rankBefore = rankBefore,
					rankAfter = rankAfter,
					rankCash = s.rankCash,
					unlocks = unlocks,
					newItems = s.newItems,
					newStars = { count = s.newStars, cash = s.starCash },
					contracts = completedList,
					contractCash = s.contractCash,
					mostWanted = s.mostWanted,
					newCollection = s.newCollection,
					collectionCash = s.collectionCash,
					trophy = s.trophy,
				})
				task.spawn(function()
					DataService:SaveNowAsync(player, "SettleRound")
				end)
			end
		end
	end
	return summary
end

-- Requests ---------------------------------------------------------------------------------------------------

local function onReroll(player: Player, index: any)
	local i = RequestGuard.int(index, 1, 3)
	local data = DataService:Get(player)
	if not i or not data then
		return
	end
	local reason: string? = nil
	if data.daily.rerolls >= MetaConfig.Contracts.FreeRerollsPerDay then
		reason = "NoRerolls"
	elseif not data.daily.contracts[i] then
		reason = "Invalid"
	elseif data.daily.contracts[i].done then
		reason = "Done"
	end
	local ok = false
	if not reason then
		local userId = player.UserId
		ok = DataService:Update(player, "RerollContract", function(d)
			local rng = contractRng(userId, d.daily.day, 1000 + d.daily.rerolls * 7 + i)
			local done, why = Contracts.reroll(
				d.daily.contracts,
				i,
				MetaConfig.Contracts.Templates,
				Access.contractContext(d),
				MetaConfig.Contracts.Rewards,
				MetaConfig.Contracts.MaxNeedsCrew,
				rng
			)
			if not done then
				error(why or "refused")
			end
			d.daily.rerolls += 1
		end)
		reason = if ok then nil else "NoOptions"
	end
	Net.send(player, "MetaResult", "Reroll", ok, tostring(i), reason or "")
end

function EconomyService:Start()
	RequestGuard.on("RerollContract", onReroll, { burst = 2, perSecond = 0.5 })

	DataService.Loaded:Connect(function(player: Player)
		refreshPlayer(player)
	end)

	-- New contracts at the UTC day change while online.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				refreshPlayer(player)
			end
		end
	end)
end

return EconomyService
