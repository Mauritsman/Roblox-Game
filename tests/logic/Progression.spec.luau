--!nocheck
local Progression = require("../../src/shared/Logic/Progression")
local HeistRecords = require("../../src/shared/Logic/HeistRecords")
local MetaConfig = require("../../src/shared/MetaConfig")

local STEP, MAX = 1000, 20
local P = MetaConfig.Progression

return function(t)
	t.test("rank totals match the §4.1 table", function()
		local expected = {
			0,
			1000,
			3000,
			6000,
			10000,
			15000,
			21000,
			28000,
			36000,
			45000,
			55000,
			66000,
			78000,
			91000,
			105000,
			120000,
			136000,
			153000,
			171000,
			190000,
		}
		for rank, total in expected do
			t.eq(Progression.totalRep(rank, STEP), total, "rank " .. rank)
			t.eq(Progression.rankForRep(total, STEP, MAX), rank, "rankForRep " .. rank)
			if total > 0 then
				t.eq(Progression.rankForRep(total - 1, STEP, MAX), rank - 1, "just below " .. rank)
			end
		end
	end)

	t.test("rankForRep edges and the cap", function()
		t.eq(Progression.rankForRep(0, STEP, MAX), 1)
		t.eq(Progression.rankForRep(999, STEP, MAX), 1)
		t.eq(Progression.rankForRep(1000, STEP, MAX), 2)
		t.eq(Progression.rankForRep(10 ^ 9, STEP, MAX), 20)
	end)

	t.test("progress into the rank and at the cap", function()
		local p = Progression.progress(1500, STEP, MAX)
		t.eq(p.rank, 2)
		t.eq(p.repIntoRank, 500)
		t.eq(p.repForNext, 2000)
		t.eq(p.atMax, false)
		local top = Progression.progress(200000, STEP, MAX)
		t.eq(top.rank, 20)
		t.eq(top.repIntoRank, 10000)
		t.eq(top.repForNext, 0)
		t.eq(top.atMax, true)
	end)

	t.test("skill points: one per rank from Rank 2", function()
		t.eq(Progression.skillPoints(1), 0)
		t.eq(Progression.skillPoints(2), 1)
		t.eq(Progression.skillPoints(20), 19)
	end)

	t.test("titles come from the highest titled rank", function()
		t.eq(Progression.title(1, P.Titles), "Rookie")
		t.eq(Progression.title(2, P.Titles), "Rookie")
		t.eq(Progression.title(4, P.Titles), "Pickpocket")
		t.eq(Progression.title(11, P.Titles), "Mastermind")
		t.eq(Progression.title(20, P.Titles), "Legend of Polderdam")
	end)

	t.test("rank rewards pay every skipped rank once", function()
		local list, newRewarded = Progression.rankRewards(1, 4, 100)
		t.eq(#list, 3)
		t.eq(list[1].rank, 2)
		t.eq(list[1].cash, 200)
		t.eq(list[3].cash, 400)
		t.eq(newRewarded, 4)
		local again = Progression.rankRewards(4, 4, 100)
		t.eq(#again, 0)
	end)

	t.test("stars only rise and new stars are counted", function()
		local records = {}
		t.eq(HeistRecords.record(records, "GoldenWheel", "Normal", 1, true, 600), 1)
		t.eq(HeistRecords.record(records, "GoldenWheel", "Normal", 3, true, 2600), 2)
		t.eq(HeistRecords.record(records, "GoldenWheel", "Normal", 2, true, 1600), 0)
		t.eq(HeistRecords.bestStars(records, "GoldenWheel", "Normal"), 3)
		t.eq(records.GoldenWheel.clears.Normal, 3)
		t.eq(records.GoldenWheel.bestLoot, 2600)
	end)

	t.test("stars need an escape; best loot still counts", function()
		local records = {}
		t.eq(HeistRecords.record(records, "GoldenWheel", "Normal", 2, false, 1800), 0)
		t.eq(HeistRecords.bestStars(records, "GoldenWheel", "Normal"), 0)
		t.eq(records.GoldenWheel.bestLoot, 1800)
		t.eq(records.GoldenWheel.clears.Normal, nil)
	end)

	t.test("star cash = 300 × tier multiplier per new star", function()
		t.eq(HeistRecords.starCash(1, 300, 0.8), 240)
		t.eq(HeistRecords.starCash(1, 300, 1.0), 300)
		t.eq(HeistRecords.starCash(1, 300, 1.4), 420)
		t.eq(HeistRecords.starCash(2, 300, 1.0), 600)
		t.eq(HeistRecords.starCash(0, 300, 1.4), 0)
	end)

	t.test("Hard unlocks per heist at 2★ on Normal", function()
		local records = {}
		local order = MetaConfig.Difficulty.Order
		local rules = MetaConfig.Difficulty.Unlock
		local tiers = HeistRecords.tiers(records, "GoldenWheel", order, rules)
		t.eq(tiers.Easy, true)
		t.eq(tiers.Normal, true)
		t.eq(tiers.Hard, false)
		HeistRecords.record(records, "GoldenWheel", "Easy", 3, true, 3000)
		t.eq(HeistRecords.tiers(records, "GoldenWheel", order, rules).Hard, false)
		HeistRecords.record(records, "GoldenWheel", "Normal", 2, true, 1600)
		t.eq(HeistRecords.tiers(records, "GoldenWheel", order, rules).Hard, true)
		t.eq(HeistRecords.tiers(records, "PralinePalace", order, rules).Hard, false)
	end)

	t.test("Praline Palace: 3★ in total on The Golden Wheel or Rank 4", function()
		local rules = P.HeistUnlock
		local records = {}
		t.eq((HeistRecords.isUnlocked(records, 1, "GoldenWheel", rules)), true)
		t.eq((HeistRecords.isUnlocked(records, 3, "PralinePalace", rules)), false)
		local ok, route = HeistRecords.isUnlocked(records, 4, "PralinePalace", rules)
		t.eq(ok, true)
		t.eq(route, "Rank")
		HeistRecords.record(records, "GoldenWheel", "Easy", 1, true, 600)
		HeistRecords.record(records, "GoldenWheel", "Normal", 2, true, 1600)
		local ok2, route2 = HeistRecords.isUnlocked(records, 1, "PralinePalace", rules)
		t.eq(ok2, true)
		t.eq(route2, "Stars")
		t.eq((HeistRecords.isUnlocked(records, 6, "TulipAuction", rules)), false)
		t.eq((HeistRecords.isUnlocked(records, 7, "TulipAuction", rules)), true)
		t.eq((HeistRecords.isUnlocked(records, 20, "Unknown", rules)), false)
	end)

	t.test("requirement text", function()
		local text = HeistRecords.requirementText("PralinePalace", P.HeistUnlock, MetaConfig.Heists.Names)
		t.eq(text, "3★ on The Golden Wheel or Rank 4")
		t.eq(HeistRecords.requirementText("GoldenWheel", P.HeistUnlock, MetaConfig.Heists.Names), nil)
	end)

	t.test("mastery and star masks are granted once", function()
		local records = {}
		HeistRecords.record(records, "GoldenWheel", "Hard", 3, true, 3000)
		local owned = {}
		local items = HeistRecords.rewardItems(records, P.MasteryMask, P.MasteryTier, P.StarMasks, owned)
		t.eq(#items, 1)
		t.eq(items[1], "GoudaVisor")
		owned.GoudaVisor = 1
		t.eq(#HeistRecords.rewardItems(records, P.MasteryMask, P.MasteryTier, P.StarMasks, owned), 0)
		HeistRecords.record(records, "GoldenWheel", "Normal", 3, true, 3000)
		HeistRecords.record(records, "GoldenWheel", "Easy", 3, true, 3000)
		t.eq(HeistRecords.totalStars(records), 9)
		local more = HeistRecords.rewardItems(records, P.MasteryMask, P.MasteryTier, P.StarMasks, owned)
		t.eq(#more, 1)
		t.eq(more[1], "StarShades")
	end)
end
