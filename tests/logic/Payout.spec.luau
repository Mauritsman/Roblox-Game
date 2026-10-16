--!nocheck
local Payout = require("../../src/shared/Logic/Payout")
local MetaConfig = require("../../src/shared/MetaConfig")

local CFG = MetaConfig.Economy

-- Plain escaped solo round on Normal: no bonuses apply unless a test turns them on.
local function input(overrides)
	local base = {
		outcome = "Escaped",
		vanLoot = 1000,
		crewSize = 1,
		inVanAtEnd = true,
		allInVan = true,
		difficulty = "Normal",
		isHotJob = false,
		maxAlarmTier = 2,
		objectives = {},
		fresh = false,
		firstJobAvailable = false,
	}
	for k, v in overrides or {} do
		base[k] = v
	end
	return base
end

local function has(result, id)
	for _, b in result.bonuses do
		if b.id == id then
			return true
		end
	end
	return false
end

return function(t)
	t.test("brief example: solo 1,000 → 1,000 Cash, 1,100 Rep", function()
		local r = Payout.compute(input(), CFG)
		t.eq(r.cash, 1000)
		t.eq(r.rep, 1100)
		t.eq(#r.bonuses, 0)
	end)

	t.test("brief example: four with 3,000 → 1,088 each (round half up)", function()
		local r = Payout.compute(input({ vanLoot = 3000, crewSize = 4, allInVan = false }), CFG)
		t.near(r.share, 1087.5, 1e-9)
		t.eq(r.cash, 1088)
		t.near(r.crewBonusPct, 0.45, 1e-9)
	end)

	t.test("scenario 101: first escaped job of the day doubles Cash but not Rep", function()
		local r = Payout.compute(input({ firstJobAvailable = true }), CFG)
		t.eq(r.cash, 2000)
		t.eq(r.rep, 1100)
		t.eq(r.firstJobToday, true)
	end)

	t.test("Busted: half the van, no bonuses, Rep still counts, ×2 not used", function()
		local r = Payout.compute(
			input({
				outcome = "Busted",
				inVanAtEnd = false,
				maxAlarmTier = 0,
				isHotJob = true,
				firstJobAvailable = true,
			}),
			CFG
		)
		t.eq(r.cash, 500)
		t.eq(r.rep, 600)
		t.eq(r.busted, true)
		t.eq(#r.bonuses, 0)
		t.eq(r.firstJobToday, false)
		t.eq(r.caughtHalf, false)
	end)

	t.test("left in the cell when the van drives: half share, no ×2", function()
		local r = Payout.compute(
			input({
				crewSize = 2,
				vanLoot = 2000,
				inVanAtEnd = false,
				allInVan = false,
				firstJobAvailable = true,
			}),
			CFG
		)
		-- 2000 / 2 × 1.15 = 1150 → × 0.5 = 575
		t.eq(r.cash, 575)
		t.eq(r.caughtHalf, true)
		t.eq(r.firstJobToday, false)
		t.eq(r.escaped, false)
	end)

	t.test("difficulty multiplies Cash and Rep", function()
		t.eq(Payout.compute(input({ difficulty = "Easy" }), CFG).cash, 800)
		t.eq(Payout.compute(input({ difficulty = "Easy" }), CFG).rep, 880)
		t.eq(Payout.compute(input({ difficulty = "Hard" }), CFG).cash, 1400)
		t.eq(Payout.compute(input({ difficulty = "Hard" }), CFG).rep, 1540)
		t.eq(Payout.compute(input({ difficulty = "Unknown" }), CFG).cash, 1000)
	end)

	t.test("Rep is taken before ×2 and includes 100 × tier", function()
		local r = Payout.compute(input({ difficulty = "Hard", firstJobAvailable = true }), CFG)
		t.eq(r.cash, 2800)
		t.eq(r.rep, 1540)
	end)

	t.test("bonuses add up: Quiet Job, Hot Job, Fresh, objective", function()
		local r = Payout.compute(
			input({
				maxAlarmTier = 1,
				isHotJob = true,
				fresh = true,
				objectives = { { id = "Safe", bonusPct = 0.10 } },
			}),
			CFG
		)
		t.ok(has(r, "QuietJob") and has(r, "HotJob") and has(r, "Fresh") and has(r, "Objective:Safe"))
		t.near(r.bonusPct, 0.75, 1e-9)
		t.eq(r.cash, 1750)
	end)

	t.test("Hot Job is a flat +25%", function()
		t.eq(Payout.compute(input({ isHotJob = true }), CFG).cash, 1250)
	end)

	t.test("No One Left Behind only for crews of 2+ with everyone in the van", function()
		t.eq(has(Payout.compute(input({ allInVan = true }), CFG), "NoOneLeftBehind"), false)
		local crew = Payout.compute(input({ crewSize = 2, vanLoot = 2000, allInVan = true }), CFG)
		t.eq(has(crew, "NoOneLeftBehind"), true)
		-- 1150 × 1.10 = 1265
		t.eq(crew.cash, 1265)
		t.eq(has(Payout.compute(input({ crewSize = 2, allInVan = false }), CFG), "NoOneLeftBehind"), false)
	end)

	t.test("one rounding at the end, never in between", function()
		-- 3 players, 1,001 loot: 1001 / 3 × 1.3 = 433.766… → × 1.2 (Quiet) = 520.52 → 521
		local r =
			Payout.compute(input({ crewSize = 3, vanLoot = 1001, allInVan = false, maxAlarmTier = 0 }), CFG)
		t.eq(r.cash, 521)
		-- x.5 rounds up
		t.eq(Payout.roundHalfUp(2.5), 3)
		t.eq(Payout.roundHalfUp(2.4999), 2)
	end)

	t.test("Cash is clamped at MaxPayoutPerRound", function()
		local r = Payout.compute(input({ vanLoot = 100000, firstJobAvailable = true }), CFG)
		t.eq(r.cash, CFG.MaxPayoutPerRound)
		t.eq(r.clamped, true)
	end)

	t.test("Aborted pays nothing", function()
		local r = Payout.compute(input({ outcome = "Aborted" }), CFG)
		t.eq(r.cash, 0)
		t.eq(r.rep, 0)
	end)

	t.test("Shutdown: banked loot share + 100 Rep, no bonuses, no tier, no ×2", function()
		local r = Payout.compute(
			input({
				outcome = "Shutdown",
				vanLoot = 3000,
				crewSize = 4,
				difficulty = "Hard",
				isHotJob = true,
				maxAlarmTier = 0,
				firstJobAvailable = true,
			}),
			CFG
		)
		t.eq(r.cash, 1088)
		t.eq(r.rep, 1188)
		t.eq(#r.bonuses, 0)
		t.eq(r.firstJobToday, false)
	end)

	t.test("bad input is safe", function()
		local r = Payout.compute(input({ vanLoot = -50, crewSize = 0 }), CFG)
		t.eq(r.cash, 0)
		t.eq(r.rep, 100)
	end)

	t.test("Fresh needs a full history without this heist", function()
		t.eq(Payout.isFresh({}, "GoldenWheel", 2), false)
		t.eq(Payout.isFresh({ "PralinePalace" }, "GoldenWheel", 2), false)
		t.eq(Payout.isFresh({ "PralinePalace", "TulipAuction" }, "GoldenWheel", 2), true)
		t.eq(Payout.isFresh({ "GoldenWheel", "PralinePalace" }, "GoldenWheel", 2), false)
		t.eq(Payout.isFresh({ "GoldenWheel", "PralinePalace", "TulipAuction" }, "GoldenWheel", 2), true)
	end)
end
