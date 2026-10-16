--!nocheck
local Awards = require("../../src/shared/Logic/Awards")

local function count(map)
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

return function(t)
	t.test("solo with nothing special: Sightseer", function()
		local result = Awards.assign({ [1] = {} })
		t.eq(result[1], "Sightseer")
	end)

	t.test("one award each, no duplicates", function()
		local result = Awards.assign({
			[10] = { mainLootBanked = true, rescues = 3, lootValueBanked = 2000 },
			[20] = { rescues = 1, lootValueBanked = 500, everSeen = true },
			[30] = { sneezes = 1, lootValueBanked = 900, everSeen = true },
			[40] = { lootValueBanked = 300 },
		})
		t.eq(count(result), 4)
		t.eq(result[10], "GoudaGetter")
		t.eq(result[20], "Jailbreaker") -- the top rescuer already has an award
		t.eq(result[30], "Achoo")
		t.eq(result[40], "Ghost") -- banked and never fully seen
		local seen = {}
		for _, id in result do
			t.ok(not seen[id], "duplicate " .. id)
			seen[id] = true
		end
	end)

	t.test("most rescues wins Jailbreaker", function()
		local result = Awards.assign({ [1] = { rescues = 1 }, [2] = { rescues = 4 }, [3] = { rescues = 2 } })
		t.eq(result[2], "Jailbreaker")
	end)

	t.test("ties go to the lowest UserId", function()
		local result = Awards.assign({ [9] = { rescues = 2 }, [3] = { rescues = 2 } })
		t.eq(result[3], "Jailbreaker")
		t.eq(result[9], "Sightseer")
	end)

	t.test("thresholds: ≥ 2 traces, drops, catches, captures", function()
		t.eq(Awards.assign({ [1] = { tracesCleaned = 1 } })[1], "Sightseer")
		t.eq(Awards.assign({ [1] = { tracesCleaned = 2 } })[1], "KarelsNemesis")
		t.eq(Awards.assign({ [1] = { uncaughtDrops = 1 } })[1], "Sightseer")
		t.eq(Awards.assign({ [1] = { uncaughtDrops = 2 } })[1], "Butterfingers")
		t.eq(Awards.assign({ [1] = { throwsCaught = 2 } })[1], "CheeseCannon")
		t.eq(Awards.assign({ [1] = { timesCaught = 1 } })[1], "Sightseer")
		t.eq(Awards.assign({ [1] = { timesCaught = 2 } })[1], "CellRegular")
	end)

	t.test("every single-stat award", function()
		local cases = {
			{ { heroDrops = 1 }, "BubbleHero" },
			{ { justMadeIt = true }, "JustMadeIt" },
			{ { selfEmp = 1 }, "SelfEmp" },
			{ { bubbledTeammates = 1 }, "OopsBubbled" },
			{ { boefFed = 1 }, "DogWhisperer" },
			{ { deviceRestarts = 1 }, "Safecracker" },
			{ { lootValueBanked = 100, everSeen = true }, "PackMule" },
			{ { lootValueBanked = 100 }, "Ghost" },
		}
		for _, case in cases do
			t.eq(Awards.assign({ [1] = case[1] })[1], case[2])
		end
	end)

	t.test("priority order decides between two awards for one player", function()
		-- Bubble Hero comes before Just Made It; the second player gets the next one he qualifies for.
		local result = Awards.assign({
			[1] = { heroDrops = 1, justMadeIt = true },
			[2] = { justMadeIt = true },
		})
		t.eq(result[1], "BubbleHero")
		t.eq(result[2], "JustMadeIt")
	end)

	t.test("several players can fall back to Sightseer", function()
		local result = Awards.assign({ [1] = {}, [2] = {}, [3] = { boefFed = 1 } })
		t.eq(result[1], "Sightseer")
		t.eq(result[2], "Sightseer")
		t.eq(result[3], "DogWhisperer")
	end)

	t.test("Pack Mule: most value banked among the rest", function()
		local result = Awards.assign({
			[1] = { lootValueBanked = 400, everSeen = true },
			[2] = { lootValueBanked = 900, everSeen = true },
		})
		t.eq(result[2], "PackMule")
		t.eq(result[1], "Sightseer")
	end)

	t.test("empty crew gives an empty result", function()
		t.eq(count(Awards.assign({})), 0)
	end)

	t.test("ids: 16 unique, priority order, fallback last", function()
		local ids = Awards.ids()
		t.eq(#ids, 16)
		t.eq(ids[1], "GoudaGetter")
		t.eq(ids[#ids], "Sightseer")
		local seen = {}
		for _, id in ids do
			t.ok(not seen[id], "duplicate id " .. id)
			seen[id] = true
		end
		t.eq(Awards.TUTORIAL, "FreshCrook")
	end)
end
