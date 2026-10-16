--!nocheck
-- End-to-end settlement of one player's round on a real profile (spec scenarios 101–103 and friends).
local Settlement = require("../../src/shared/Logic/Settlement")
local DataSchema = require("../../src/shared/Logic/DataSchema")
local Payout = require("../../src/shared/Logic/Payout")
local HeistRecords = require("../../src/shared/Logic/HeistRecords")
local Collection = require("../../src/shared/Logic/Collection")
local Contracts = require("../../src/shared/Logic/Contracts")
local Progression = require("../../src/shared/Logic/Progression")
local Ledger = require("../../src/shared/Logic/Ledger")
local MetaConfig = require("../../src/shared/MetaConfig")
local Catalog = require("../../src/shared/Catalog")

local DEPS = {
	Payout = Payout,
	HeistRecords = HeistRecords,
	Collection = Collection,
	Contracts = Contracts,
	Progression = Progression,
	Ledger = Ledger,
}
local STARTER = { equipped = Catalog.DefaultEquipped, loadout = Catalog.DefaultLoadout }

local function profile()
	return DataSchema.defaults(1000, STARTER)
end

local counter = 0
local function round(overrides)
	counter += 1
	local base = {
		roundId = "round-" .. counter,
		heistId = "GoldenWheel",
		difficulty = "Normal",
		outcome = "Escaped",
		vanLoot = 1000,
		stars = 1,
		maxAlarmTier = 2,
		isHotJob = false,
		mainLootBanked = false,
		objectives = {},
		banked = { { lootId = "CheeseWheel" } },
		crewSize = 1,
		inVanAtEnd = true,
		allInVan = true,
		stats = {},
		now = 5000,
		week = 10,
		mostWantedHeist = "PralinePalace",
		mostWantedItem = "BoefSnout",
		itemExists = function(id)
			return Catalog.get(id) ~= nil
		end,
	}
	for k, v in overrides or {} do
		base[k] = v
	end
	return base
end

local function apply(data, overrides)
	return Settlement.applyRound(data, round(overrides), MetaConfig, DEPS)
end

return function(t)
	t.test("scenario 101: first solo round → 2,500 Cash, 1,100 Rep, Rank 2", function()
		local d = profile()
		local s = apply(d)
		t.eq(s.pay.cash, 2000) -- first escaped job today ×2
		t.eq(s.newStars, 1)
		t.eq(s.starCash, 300)
		t.eq(s.rankCash, 200)
		t.eq(s.totalCash, 2500)
		t.eq(d.cash, 2500)
		t.eq(d.rep, 1100)
		t.eq(s.rankBefore, 1)
		t.eq(s.rankAfter, 2)
		t.eq(d.rankRewarded, 2)
		t.eq(d.daily.firstJobUsed, true)
		t.eq(d.stats.rounds, 1)
		t.eq(d.stats.escapes, 1)
		t.eq(d.stats.cashEarned, 2500)
		t.eq(d.recentHeists[1], "GoldenWheel")
		t.eq(d.collection.CheeseWheel, 1)
	end)

	t.test("scenario 102: the same roundId twice pays once", function()
		local d = profile()
		local r = round()
		local first = Settlement.applyRound(d, r, MetaConfig, DEPS)
		local cash = d.cash
		local second = Settlement.applyRound(d, r, MetaConfig, DEPS)
		t.eq(first.skipped, false)
		t.eq(second.skipped, true)
		t.eq(d.cash, cash)
		t.eq(d.stats.rounds, 1)
	end)

	t.test("scenario 103: 3★ round adds 2 new stars, opens Hard and Praline Palace", function()
		local d = profile()
		apply(d)
		local before = d.cash
		local s = apply(d, { vanLoot = 2600, stars = 3, mainLootBanked = true })
		t.eq(s.newStars, 2)
		t.eq(s.starCash, 600)
		t.eq(s.trophy, true)
		t.eq(#d.trophies, 1)
		t.eq(d.stats.mainLoot, 1)
		t.eq(s.pay.firstJobToday, false)
		local tiers = HeistRecords.tiers(
			d.heists,
			"GoldenWheel",
			MetaConfig.Difficulty.Order,
			MetaConfig.Difficulty.Unlock
		)
		t.eq(tiers.Hard, true)
		local open, route = HeistRecords.isUnlocked(
			d.heists,
			s.rankAfter,
			"PralinePalace",
			MetaConfig.Progression.HeistUnlock
		)
		t.eq(open, true)
		t.eq(route, "Stars")
		-- 2,600 solo, no ×2 = 2,600 Cash + 600 stars (+ rank-ups)
		t.eq(d.cash - before, 2600 + 600 + s.rankCash)
	end)

	t.test("Busted keeps the daily ×2 for later and gives no stars", function()
		local d = profile()
		local s = apply(d, { outcome = "Busted", inVanAtEnd = false, allInVan = false, stars = 0 })
		t.eq(s.pay.cash, 500)
		t.eq(s.pay.rep, 600)
		t.eq(d.daily.firstJobUsed, false)
		t.eq(s.newStars, 0)
		t.eq(d.stats.busts, 1)
		t.eq(d.stats.rounds, 1)
	end)

	t.test("Shutdown: share + 100 Rep, no stars, no contracts, no ×2, not a round", function()
		local d = profile()
		d.daily.contracts =
			{ { id = "FinishJobs", tier = "Easy", target = 1, progress = 0, reward = 250, done = false } }
		local s = apply(d, { outcome = "Shutdown", stars = 3, mainLootBanked = true })
		t.eq(s.pay.cash, 1000)
		t.eq(s.pay.rep, 1100)
		t.eq(s.newStars, 0)
		t.eq(#s.completed, 0)
		t.eq(d.daily.firstJobUsed, false)
		t.eq(d.stats.rounds, 0)
		t.eq(s.trophy, false)
	end)

	t.test("contracts complete and pay once", function()
		local d = profile()
		d.daily.contracts = {
			{ id = "FinishJobs", tier = "Easy", target = 2, progress = 1, reward = 250, done = false },
			{ id = "BankHeavy", tier = "Medium", target = 1, progress = 0, reward = 350, done = false },
		}
		local s = apply(d, { stats = { heavyBanked = 1 } })
		t.eq(#s.completed, 2)
		t.eq(s.contractCash, 600)
		local s2 = apply(d, { stats = { heavyBanked = 1 } })
		t.eq(s2.contractCash, 0)
	end)

	t.test("Most Wanted: 3★ on Normal or Hard on the week's heist, once per week", function()
		local d = profile()
		local easy = apply(d, { heistId = "PralinePalace", difficulty = "Easy", stars = 3, vanLoot = 2600 })
		t.eq(easy.mostWanted.done, false)
		local s = apply(d, { heistId = "PralinePalace", stars = 3, vanLoot = 2600 })
		t.eq(s.mostWanted.done, true)
		t.eq(s.mostWanted.item, "BoefSnout")
		t.ok(d.owned.BoefSnout ~= nil)
		local again = apply(d, { heistId = "PralinePalace", stars = 3, vanLoot = 2600 })
		t.eq(again.mostWanted.done, false)
		-- next week, item already owned → 1,500 Cash
		local nextWeek = apply(d, { heistId = "PralinePalace", stars = 3, vanLoot = 2600, week = 11 })
		t.eq(nextWeek.mostWanted.done, true)
		t.eq(nextWeek.mwCash, 1500)
	end)

	t.test("a full collection page gives the Cheese Monocle once", function()
		local d = profile()
		local banked = {}
		for _, id in MetaConfig.Collection.Pages.GoldenWheel do
			table.insert(banked, { lootId = id })
		end
		local s = apply(d, { banked = banked })
		t.eq(#s.newCollection, #banked)
		t.ok(table.find(s.newItems, "CheeseMonocle") ~= nil)
		t.ok(d.owned.CheeseMonocle ~= nil)
		local s2 = apply(d, { banked = banked })
		t.eq(#s2.newItems, 0)
		t.eq(s2.collectionCash, 0)
	end)

	t.test("3★ on Hard grants the heist mask", function()
		local d = profile()
		local s = apply(d, { difficulty = "Hard", stars = 3, vanLoot = 2600, mainLootBanked = true })
		t.ok(table.find(s.newItems, "GoudaVisor") ~= nil)
		t.eq(s.starCash, 3 * 420)
	end)

	t.test("crew member left in the cell: half share, stars not counted", function()
		local d = profile()
		local s = apply(d, { crewSize = 2, vanLoot = 2000, inVanAtEnd = false, allInVan = false, stars = 2 })
		t.eq(s.pay.cash, 575)
		t.eq(s.newStars, 0)
		t.eq(d.daily.firstJobUsed, false)
	end)

	t.test("Fresh after two rounds of history on other heists", function()
		local d = profile()
		d.recentHeists = { "PralinePalace", "TulipAuction" }
		d.daily.firstJobUsed = true
		local s = apply(d)
		t.eq(s.pay.cash, 1200)
	end)
end
