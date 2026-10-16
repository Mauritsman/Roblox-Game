--!nocheck
local LootRules = require("../../src/shared/Logic/LootRules")
local Config = require("../../src/shared/Config")

local RANGE = Config.Loot.GrabRange

local function picker(overrides)
	local p =
		{ userId = 1, free = true, session = "Crew", handsClass = nil, pocketCount = 0, pocketSlots = 3 }
	for k, v in overrides or {} do
		p[k] = v
	end
	return p
end

local function loot(overrides)
	local l = { state = "Placed", class = "Small", session = "Crew" }
	for k, v in overrides or {} do
		l[k] = v
	end
	return l
end

local function pick(p, l)
	local ok, result = LootRules.canPick(p, l, RANGE)
	return ok, result
end

return function(t)
	t.test("small loot goes in the pocket until it is full", function()
		t.eq(select(2, pick(picker(), loot())), "Pocket")
		local ok, reason = pick(picker({ pocketCount = 3 }), loot())
		t.ok(not ok)
		t.eq(reason, "PocketFull")
		t.eq(select(2, pick(picker({ pocketCount = 3, pocketSlots = 4 }), loot())), "Pocket") -- Deep Pockets
	end)

	t.test("small loot can be pocketed with full hands", function()
		t.eq(select(2, pick(picker({ handsClass = "Medium" }), loot())), "Pocket")
	end)

	t.test("medium: Grab with empty hands, refused with full hands", function()
		t.eq(select(2, pick(picker(), loot({ class = "Medium" }))), "Grab")
		t.eq(select(2, pick(picker({ handsClass = "Medium" }), loot({ class = "Medium" }))), "HandsFull")
		t.eq(select(2, pick(picker({ pocketCount = 3 }), loot({ class = "Medium" }))), "Grab") -- pocket irrelevant
	end)

	t.test("heavy and main: Lift", function()
		t.eq(select(2, pick(picker(), loot({ class = "Heavy" }))), "Lift")
		t.eq(select(2, pick(picker(), loot({ class = "Main" }))), "Lift")
		t.eq(select(2, pick(picker({ handsClass = "Heavy" }), loot({ class = "Main" }))), "HandsFull")
	end)

	t.test("dropped and returning (Karel) loot can be taken", function()
		t.eq(select(2, pick(picker(), loot({ state = "Dropped", class = "Medium" }))), "Grab")
		t.eq(select(2, pick(picker(), loot({ state = "Returning", class = "Heavy" }))), "Lift")
	end)

	t.test("help carry: heavy loot held by one other player within range", function()
		local held = { state = "Carried", class = "Heavy", carrierId = 2, carrierDistance = 4 }
		t.eq(select(2, pick(picker(), loot(held))), "Help")
		held.carrierDistance = 6.5
		t.eq(select(2, pick(picker(), loot(held))), "TooFar")
		held.carrierDistance = 4
		held.helperId = 3
		t.eq(select(2, pick(picker(), loot(held))), "TooSlow")
	end)

	t.test("help carry refused: own loot, medium loot, full hands", function()
		t.eq(
			select(2, pick(picker(), loot({ state = "Carried", class = "Heavy", carrierId = 1 }))),
			"TooSlow"
		)
		t.eq(
			select(2, pick(picker(), loot({ state = "Carried", class = "Medium", carrierId = 2 }))),
			"TooSlow"
		)
		local held = loot({ state = "Carried", class = "Main", carrierId = 2, carrierDistance = 2 })
		t.eq(select(2, pick(picker({ handsClass = "Medium" }), held)), "HandsFull")
		t.eq(select(2, pick(picker(), held)), "Help")
	end)

	t.test("refusals: not free, other session, in flight, banked", function()
		t.eq(select(2, pick(picker({ free = false }), loot())), "NotFree")
		t.eq(select(2, pick(picker({ session = "Tutorial1" }), loot())), "WrongSession")
		t.eq(select(2, pick(picker(), loot({ state = "Thrown", class = "Medium" }))), "InFlight")
		t.eq(select(2, pick(picker(), loot({ state = "Banked" }))), "Gone")
		t.eq(select(2, pick(picker(), loot({ state = "Weird" }))), "Gone")
	end)

	t.test("prompt texts", function()
		t.eq(LootRules.ActionText.Help, "Help carry")
		t.eq(LootRules.ActionText.Pocket, "Pocket")
	end)

	t.test("pocketAdd / pocketRemove return new lists", function()
		local pocket = { "CheeseCube" }
		local added, ok = LootRules.pocketAdd(pocket, "TipJar", 3)
		t.ok(ok)
		t.eq(#added, 2)
		t.eq(#pocket, 1)
		local full, ok2 = LootRules.pocketAdd({ "a", "b", "c" }, "d", 3)
		t.ok(not ok2)
		t.eq(#full, 3)
		local removed, ok3 = LootRules.pocketRemove({ "a", "b", "a" }, "a")
		t.ok(ok3)
		t.eq(table.concat(removed, ","), "b,a")
		local _, ok4 = LootRules.pocketRemove({ "a" }, "z")
		t.ok(not ok4)
	end)

	t.test("fragile: −25% of base per landing, floor 25%", function()
		local p, floor = Config.Loot.FragilePenalty, Config.Loot.FragileMinFactor
		t.eq(LootRules.fragileValue(200, 0, p, floor), 200)
		t.eq(LootRules.fragileValue(200, 1, p, floor), 150)
		t.eq(LootRules.fragileValue(200, 2, p, floor), 100)
		t.eq(LootRules.fragileValue(200, 3, p, floor), 50)
		t.eq(LootRules.fragileValue(200, 9, p, floor), 50)
		t.eq(LootRules.fragileValue(25, 1, p, floor), 19) -- 18.75 rounds half up
		t.eq(LootRules.fragileValue(3000, 1, 0.1, 0.25), 2700) -- per-type penalty (Black Tulip)
		t.eq(LootRules.fragileValue(200, -1, p, floor), 200)
	end)

	t.test("melting: 2% per second, floor 50%", function()
		t.eq(LootRules.meltedValue(1000, 0, 0.02, 0.5), 1000)
		t.eq(LootRules.meltedValue(1000, 10, 0.02, 0.5), 800)
		t.eq(LootRules.meltedValue(1000, 100, 0.02, 0.5), 500)
	end)

	t.test("banking only in your own session, never Practice", function()
		t.ok(LootRules.canBank("Crew", "Crew"))
		t.ok(LootRules.canBank("Tutorial2", "Tutorial2"))
		t.ok(not LootRules.canBank("Crew", "Tutorial1"))
		t.ok(not LootRules.canBank("Practice", "Practice"))
	end)

	t.test("grip and anti-teleport", function()
		t.ok(not LootRules.gripLost(9, Config.Carry.Tether))
		t.ok(LootRules.gripLost(9.1, Config.Carry.Tether))
		t.ok(not LootRules.teleported(40, Config.Loot.TeleportGuardStuds))
		t.ok(LootRules.teleported(41, Config.Loot.TeleportGuardStuds))
	end)
end
