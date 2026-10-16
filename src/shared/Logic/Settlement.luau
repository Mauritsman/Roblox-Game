--!strict
-- Applies one settled round to ONE player's data (inside DataService:Update): payout, stats, stars and star
-- bonus, trophies, collection book, daily contracts, weekly Most Wanted, mastery/star masks and rank rewards.
-- Pure: the other Logic modules and all config come in through `deps` / `cfg` (Logic modules never require each
-- other), so the whole settlement is testable in Lune. Idempotent per roundId via data.recentRounds.

local Settlement = {}

export type Deps = {
	Payout: any,
	HeistRecords: any,
	Collection: any,
	Contracts: any,
	Progression: any,
	Ledger: any,
}

export type Input = {
	roundId: string,
	heistId: string,
	difficulty: string,
	outcome: string, -- "Escaped" | "Busted" | "Shutdown" ("Aborted" never gets here)
	vanLoot: number,
	stars: number,
	maxAlarmTier: number,
	isHotJob: boolean,
	mainLootBanked: boolean,
	objectives: { { id: string, bonusPct: number } },
	banked: { { lootId: string } },
	crewSize: number,
	inVanAtEnd: boolean,
	allInVan: boolean,
	stats: { [string]: number }, -- this player's CrewStats
	now: number,
	week: number,
	mostWantedHeist: string,
	mostWantedItem: string,
	itemExists: (itemId: string) -> boolean,
}

export type Summary = {
	skipped: boolean, -- roundId already settled for this profile
	pay: any, -- Payout.Result
	rankBefore: number,
	rankAfter: number,
	newStars: number,
	starCash: number,
	completed: { any }, -- Contracts.Contract
	contractCash: number,
	mostWanted: { [string]: any },
	mwCash: number,
	newCollection: { string },
	collectionCash: number,
	newItems: { string },
	rankCash: number,
	trophy: boolean,
	totalCash: number,
}

local function whole(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge then
		return 0
	end
	return math.max(0, math.floor(value))
end

local function rankOf(data: any, cfg: any, deps: Deps): number
	local P = cfg.Progression
	return deps.Progression.rankForRep(data.rep, P.RepPerRankStep, P.MaxRank)
end

-- Pays every unpaid rank-up reward. Returns the Cash paid.
function Settlement.claimRankRewards(data: any, cfg: any, deps: Deps): number
	local rank = rankOf(data, cfg, deps)
	local rewards, newRewarded =
		deps.Progression.rankRewards(data.rankRewarded, rank, cfg.Economy.RankUpCashPerRank)
	local total = 0
	for _, reward in rewards do
		total += reward.cash
	end
	data.cash += total
	data.stats.cashEarned = (data.stats.cashEarned or 0) + total
	data.rankRewarded = newRewarded
	return total
end

function Settlement.applyRound(data: any, input: Input, cfg: any, deps: Deps): Summary
	local E = cfg.Economy
	local s: Summary = {
		skipped = false,
		pay = nil,
		rankBefore = rankOf(data, cfg, deps),
		rankAfter = 0,
		newStars = 0,
		starCash = 0,
		completed = {},
		contractCash = 0,
		mostWanted = { done = false },
		mwCash = 0,
		newCollection = {},
		collectionCash = 0,
		newItems = {},
		rankCash = 0,
		trophy = false,
		totalCash = 0,
	}
	if deps.Ledger.contains(data.recentRounds, input.roundId) then
		s.skipped = true
		s.rankAfter = s.rankBefore
		return s
	end
	local heistId, difficulty, now = input.heistId, input.difficulty, input.now
	local tierMultiplier = E.DifficultyPayout[difficulty] or 1
	local realRound = input.outcome == "Escaped" or input.outcome == "Busted"

	local pay = deps.Payout.compute({
		outcome = input.outcome,
		vanLoot = input.vanLoot,
		crewSize = input.crewSize,
		inVanAtEnd = input.inVanAtEnd,
		allInVan = input.allInVan,
		difficulty = difficulty,
		isHotJob = input.isHotJob,
		maxAlarmTier = input.maxAlarmTier,
		objectives = input.objectives,
		fresh = deps.Payout.isFresh(data.recentHeists, heistId, E.FreshWindow),
		firstJobAvailable = not data.daily.firstJobUsed,
	}, E)
	s.pay = pay
	data.cash += pay.cash
	data.rep += pay.rep
	data.stats.cashEarned = (data.stats.cashEarned or 0) + pay.cash
	data.stats.bestPayout = math.max(data.stats.bestPayout or 0, pay.cash)
	if pay.firstJobToday then
		data.daily.firstJobUsed = true
	end
	deps.Ledger.push(data.recentRounds, input.roundId, cfg.Data.RecentRounds)

	if realRound then
		local stats = input.stats
		data.stats.rounds = (data.stats.rounds or 0) + 1
		if pay.escaped then
			data.stats.escapes = (data.stats.escapes or 0) + 1
		end
		if pay.busted then
			data.stats.busts = (data.stats.busts or 0) + 1
		end
		data.stats.rescues = (data.stats.rescues or 0) + whole(stats.rescues)
		data.stats.lootBanked = (data.stats.lootBanked or 0) + whole(stats.lootBanked)
		data.lastDifficulty = difficulty
		deps.Ledger.push(data.recentHeists, heistId, cfg.Data.RecentHeists)

		-- Stars (best per tier, only when this player escaped) and their first-time bonus.
		s.newStars = deps.HeistRecords.record(
			data.heists,
			heistId,
			difficulty,
			input.stars,
			pay.escaped,
			input.vanLoot
		)
		s.starCash = deps.HeistRecords.starCash(s.newStars, E.StarBonus, tierMultiplier)

		-- Trophy wall: every escaped round with the main loot.
		if pay.escaped and input.mainLootBanked then
			data.stats.mainLoot = (data.stats.mainLoot or 0) + 1
			deps.Collection.pushTrophy(data.trophies, {
				loot = "GoldenGouda",
				heist = heistId,
				tier = difficulty,
				crew = input.crewSize,
				at = now,
			}, cfg.Data.TrophyLog)
			s.trophy = true
		end

		-- Collection book: everything banked counts for the whole crew.
		local tracked = deps.Collection.tracked(cfg.Collection.Pages)
		s.newCollection = deps.Collection.record(data.collection, input.banked, tracked)
		for _, pageId in
			deps.Collection.newPages(data.collection, cfg.Collection.Pages, data.collectionRewards)
		do
			data.collectionRewards[pageId] = now
			local item = cfg.Collection.PageReward[pageId]
			if item and input.itemExists(item) and not data.owned[item] then
				data.owned[item] = now
				table.insert(s.newItems, item)
			else
				s.collectionCash += E.CollectionPageCash
			end
		end

		-- Daily contracts.
		s.completed =
			deps.Contracts.apply(data.daily.contracts, deps.Contracts.byId(cfg.Contracts.Templates), {
				outcome = input.outcome,
				escaped = pay.escaped,
				isHotJob = input.isHotJob,
				difficulty = difficulty,
				stars = input.stars,
				mainLootBanked = input.mainLootBanked,
				maxAlarmTier = input.maxAlarmTier,
				stats = stats,
			}, E.QuietJobMaxTier)
		for _, contract in s.completed do
			s.contractCash += contract.reward
		end

		-- Weekly Most Wanted: 3★ on this week's heist on Normal or Hard, once per week.
		local MW = cfg.MostWanted
		if
			heistId == input.mostWantedHeist
			and pay.escaped
			and input.stars >= MW.StarsNeeded
			and MW.Tiers[difficulty]
			and not (data.weekly.week == input.week and data.weekly.mostWantedDone)
		then
			data.weekly = { week = input.week, mostWantedDone = true }
			local item = input.mostWantedItem
			if input.itemExists(item) and not data.owned[item] then
				data.owned[item] = now
				table.insert(s.newItems, item)
				s.mostWanted = { done = true, item = item }
			else
				s.mwCash = E.MostWantedDuplicateCash
				s.mostWanted = { done = true, cash = s.mwCash }
			end
		end

		-- Mastery and star masks.
		local P = cfg.Progression
		for _, item in
			deps.HeistRecords.rewardItems(data.heists, P.MasteryMask, P.MasteryTier, P.StarMasks, data.owned)
		do
			if input.itemExists(item) then
				data.owned[item] = now
				table.insert(s.newItems, item)
			end
		end

		local extra = s.starCash + s.collectionCash + s.contractCash + s.mwCash
		data.cash += extra
		data.stats.cashEarned += extra
	end
	s.rankCash = Settlement.claimRankRewards(data, cfg, deps)
	s.rankAfter = rankOf(data, cfg, deps)
	s.totalCash = pay.cash + s.starCash + s.collectionCash + s.contractCash + s.mwCash + s.rankCash
	return s
end

return Settlement
