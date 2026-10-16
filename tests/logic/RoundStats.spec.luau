--!nocheck
local RoundStats = require("../../src/shared/Logic/RoundStats")
local Awards = require("../../src/shared/Logic/Awards")

return function(t)
	t.test("add counts events and values", function()
		local c = RoundStats.new()
		RoundStats.add(c, "Rescue")
		RoundStats.add(c, "Rescue")
		RoundStats.add(c, "BubbledGuard", { amount = 3 })
		RoundStats.add(c, "Custom", { value = 7 })
		t.eq(RoundStats.get(c, "Rescue"), 2)
		t.eq(RoundStats.get(c, "BubbledGuard"), 3)
		t.eq(RoundStats.get(c, "Custom"), 1)
		t.eq(RoundStats.get(c, "CustomValue"), 7)
		t.eq(RoundStats.get(c, "Nothing"), 0)
	end)

	t.test("LootBanked splits by class and main loot", function()
		local c = RoundStats.new()
		RoundStats.add(c, "LootBanked", { value = 25, class = "Small" })
		RoundStats.add(c, "LootBanked", { value = 400, class = "Heavy" })
		RoundStats.add(c, "LootBanked", { value = 1500, class = "Main", main = true })
		RoundStats.add(c, "LootBanked", { value = 150, class = "Medium" })
		t.eq(RoundStats.get(c, "LootBanked"), 4)
		t.eq(RoundStats.get(c, "LootBankedValue"), 2075)
		t.eq(RoundStats.get(c, "SmallBanked"), 1)
		t.eq(RoundStats.get(c, "HeavyBanked"), 2)
		t.eq(RoundStats.get(c, "MainLootBanked"), 1)
	end)

	t.test("awardStats feeds Logic/Awards", function()
		local a, b = RoundStats.new(), RoundStats.new()
		RoundStats.add(a, "LootBanked", { value = 1500, class = "Main", main = true })
		RoundStats.add(b, "Rescue")
		RoundStats.add(b, "Seen")
		local sa, sb = RoundStats.awardStats(a), RoundStats.awardStats(b)
		t.eq(sa.mainLootBanked, true)
		t.eq(sa.lootValueBanked, 1500)
		t.eq(sa.everSeen, false)
		t.eq(sb.rescues, 1)
		t.eq(sb.everSeen, true)
		local result = Awards.assign({ [1] = sa, [2] = sb })
		t.eq(result[1], "GoudaGetter")
		t.eq(result[2], "Jailbreaker")
	end)

	t.test("awardStats: every Awards.Stats field is present", function()
		local s = RoundStats.awardStats(RoundStats.new())
		for _, key in
			{
				"mainLootBanked",
				"rescues",
				"heroDrops",
				"justMadeIt",
				"selfEmp",
				"sneezes",
				"tracesCleaned",
				"uncaughtDrops",
				"bubbledTeammates",
				"throwsCaught",
				"boefFed",
				"deviceRestarts",
				"timesCaught",
				"lootValueBanked",
				"everSeen",
			}
		do
			t.ok(s[key] ~= nil, key)
		end
		t.eq(Awards.assign({ [5] = s })[5], "Sightseer")
	end)

	t.test("crewStats uses meta's names", function()
		local c = RoundStats.new()
		RoundStats.add(c, "LootBanked", { value = 150, class = "Medium" })
		RoundStats.add(c, "Caught")
		RoundStats.add(c, "CarriedTogether")
		RoundStats.add(c, "BoefFed")
		RoundStats.add(c, "BoefDistracted")
		local s = RoundStats.crewStats(c)
		t.eq(s.lootBanked, 1)
		t.eq(s.lootValueBanked, 150)
		t.eq(s.smallBanked, 0)
		t.eq(s.heavyBanked, 0)
		t.eq(s.timesCaught, 1)
		t.eq(s.carriedTogether, 1)
		t.eq(s.boefDistracted, 2)
		t.eq(s.rescues, 0)
		t.eq(s.bubbledGuards, 0)
		t.eq(s.hidFromChase, 0)
	end)

	t.test("stars: thresholds, main loot for 3, escape needed", function()
		local th = { 500, 1500, 2500 }
		t.eq(RoundStats.stars(499, false, true, th), 0)
		t.eq(RoundStats.stars(500, false, true, th), 1)
		t.eq(RoundStats.stars(1500, false, true, th), 2)
		t.eq(RoundStats.stars(3000, false, true, th), 2)
		t.eq(RoundStats.stars(2500, true, true, th), 3)
		t.eq(RoundStats.stars(2400, true, true, th), 2)
		t.eq(RoundStats.stars(5000, true, false, th), 0)
		t.eq(RoundStats.stars(600, false, true, nil), 1)
	end)
end
