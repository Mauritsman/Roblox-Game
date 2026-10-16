--!nocheck
local RoundPlan = require("../../src/shared/Logic/RoundPlan")
local Config = require("../../src/shared/Config")

local RULES = RoundPlan.rulesFrom(Config)

-- Stable text form of any value (sorted keys), to compare whole plans.
local function dump(value)
	if type(value) ~= "table" then
		return tostring(value)
	end
	local keys = {}
	for k in value do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, k in keys do
		table.insert(parts, tostring(k) .. "=" .. dump(value[k]))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function reversed(list)
	local out = {}
	for i = #list, 1, -1 do
		table.insert(out, list[i])
	end
	return out
end

local function route(id, priority)
	local function loop(offset)
		return {
			{ Pos = { x = offset, y = 0, z = 0 }, Wait = 2 },
			{ Pos = { x = offset + 10, y = 0, z = 0 }, Wait = 2 },
			{ Pos = { x = offset + 10, y = 0, z = 10 }, Wait = 2 },
			{ Pos = { x = offset, y = 0, z = 10 }, Wait = 2 },
		}
	end
	return { Id = id, Priority = priority, Variants = { loop(0), loop(20) } }
end

-- A map-1-like heist: Small 12 (2 openers), Medium 12, Heavy 4, Main 3, 3 keycard spots, 2 safe spots.
local function map1(overrides)
	local anchors = {}
	local function add(prefix, class, n, extra)
		for i = 1, n do
			local a = { Id = string.format("%s%02d", prefix, i), Class = class }
			for k, v in extra or {} do
				a[k] = v
			end
			table.insert(anchors, a)
		end
	end
	add("S", "Small", 12)
	anchors[1].Opener = true
	anchors[2].Opener = true
	add("M", "Medium", 12)
	add("H", "Heavy", 4)
	add("G", "Main", 3)
	add("K", "Small", 3, { Group = "Keycard" })
	add("V", "Small", 2, { Group = "OfficeSafe" })
	local info = {
		heistId = "GoldenWheel",
		anchors = anchors,
		loot = {
			{ Type = "CheeseCube", Count = 6 },
			{ Type = "TipJar", Count = 2 },
			{ Type = "CashDrawer", Count = 1 },
			{ Type = "CheeseWheel", Count = 8 },
			{ Type = "BigWheel", Count = 2 },
			{ Type = "GoldenGouda", Count = 1 },
		},
		lootTypes = Config.Loot.Types,
		entrances = { "E1", "E2", "E3", "E4" },
		exits = { { Id = "Van", Kind = "Van" }, { Id = "Boat", Kind = "Boat", Optional = true } },
		routes = {
			route("R1", 1),
			route("R2", 1),
			route("R3", 2),
			route("R4", 2),
			route("R5", 3),
			route("R6", 3),
		},
		hazards = { "W1", "W2", "W3", "W4", "W5", "W6", "W7", "W8" },
		objectives = {
			{ Id = "OfficeCard", Type = "Keycard", Required = true },
			{
				Id = "OfficeSafe",
				Type = "Safe",
				Required = false,
				Loot = { { Type = "CashDrawer", Count = 2 } },
			},
		},
		hasDog = true,
		rules = RULES,
	}
	for k, v in overrides or {} do
		info[k] = v
	end
	return info
end

local NORMAL = { heistId = "GoldenWheel", difficulty = "Normal" }

local function anchorById(info)
	local map = {}
	for _, a in info.anchors do
		map[a.Id] = a
	end
	return map
end

local function contains(list, value)
	return table.find(list, value) ~= nil
end

return function(t)
	t.test("rulesFrom reads Config", function()
		t.eq(RULES.NpcCap, 7)
		t.eq(RULES.LockedEntrances, 2)
		t.eq(RULES.SecondExitChance, 0.5)
		t.eq(RULES.TierExtraGuards.Hard, 1)
		t.eq(RULES.TierExtraGuards.Easy, 0)
		t.eq(RULES.ModifierGuards.DoubleShift, 1)
		t.eq(RULES.ModifierNpcs.HealthInspector, 1)
		t.eq(RULES.ModifierHazards.WetFloor, 6)
	end)

	t.test("determinism: same seed, same plan", function()
		for seed = 1, 20 do
			local a = RoundPlan.generate(seed, map1(), 3, NORMAL)
			local b = RoundPlan.generate(seed, map1(), 3, NORMAL)
			t.eq(dump(a), dump(b), "seed " .. seed)
		end
	end)

	t.test("input order does not matter (CollectionService order is random)", function()
		local info = map1()
		local shuffled = map1({
			anchors = reversed(info.anchors),
			entrances = reversed(info.entrances),
			exits = reversed(info.exits),
			routes = reversed(info.routes),
			hazards = reversed(info.hazards),
		})
		for seed = 1, 10 do
			local job = { heistId = "GoldenWheel", difficulty = "Normal", modifierId = "WetFloor" }
			t.eq(
				dump(RoundPlan.generate(seed, info, 4, job)),
				dump(RoundPlan.generate(seed, shuffled, 4, job))
			)
		end
	end)

	t.test("different seeds give different rounds", function()
		local seen = {}
		local distinct = 0
		for seed = 1, 20 do
			local key = dump(RoundPlan.generate(seed, map1(), 2, NORMAL).loot)
			if not seen[key] then
				seen[key] = true
				distinct += 1
			end
		end
		t.ok(distinct >= 15, "only " .. distinct .. " distinct loot layouts")
	end)

	t.test("counts per class, every anchor used once, classes match", function()
		local info = map1()
		local byId = anchorById(info)
		for seed = 1, 50 do
			local plan = RoundPlan.generate(seed, info, 2, NORMAL)
			local perClass = { Small = 0, Medium = 0, Heavy = 0, Main = 0 }
			local used = {}
			for _, item in plan.loot do
				t.ok(not used[item.anchorId], "anchor used twice: " .. item.anchorId)
				used[item.anchorId] = true
				local anchor = byId[item.anchorId]
				t.eq(anchor.Class, item.class, item.anchorId)
				t.eq(anchor.Group, nil, "group anchor used for loot")
				perClass[item.class] += 1
			end
			t.eq(perClass.Small, 9)
			t.eq(perClass.Medium, 8)
			t.eq(perClass.Heavy, 2)
			t.eq(perClass.Main, 1)
			t.eq(#plan.warnings, 0, table.concat(plan.warnings, "; "))
		end
	end)

	t.test("never more than 1 rare; rare only replaces a wheel; it does happen", function()
		local info = map1()
		local withRare = 0
		for seed = 1, 300 do
			local plan = RoundPlan.generate(seed, info, 1, NORMAL)
			local rares, wheels = 0, 0
			for _, item in plan.loot do
				if item.type == "BlueMoon" then
					rares += 1
				elseif item.type == "CheeseWheel" then
					wheels += 1
				end
			end
			t.ok(rares <= 1, "seed " .. seed .. ": " .. rares .. " Blue Moons")
			t.eq(rares, plan.rareCount)
			t.eq(rares + wheels, 8)
			if rares == 1 then
				withRare += 1
			end
		end
		-- 1 − 0.95^8 ≈ 34% of rounds have a Blue Moon
		t.ok(withRare > 50 and withRare < 160, "rounds with a Blue Moon: " .. withRare)
	end)

	t.test("the main loot is on a Main anchor", function()
		local byId = anchorById(map1())
		for seed = 1, 50 do
			local plan = RoundPlan.generate(seed, map1(), 4, NORMAL)
			t.ok(plan.mainAnchor ~= nil)
			t.eq(byId[plan.mainAnchor].Class, "Main")
		end
	end)

	t.test("at least one opener anchor gets loot", function()
		for seed = 1, 100 do
			local plan = RoundPlan.generate(seed, map1(), 1, NORMAL)
			local filled = false
			for _, item in plan.loot do
				if item.anchorId == "S01" or item.anchorId == "S02" then
					filled = true
				end
			end
			t.ok(filled, "seed " .. seed)
		end
	end)

	t.test("entrances: 2 of 4 locked, the rest open", function()
		for seed = 1, 30 do
			local plan = RoundPlan.generate(seed, map1(), 2, NORMAL)
			t.eq(#plan.lockedEntrances, 2)
			t.eq(#plan.openEntrances, 2)
			for _, id in plan.lockedEntrances do
				t.ok(not contains(plan.openEntrances, id))
			end
		end
	end)

	t.test("entrances: never all locked", function()
		local one = RoundPlan.generate(1, map1({ entrances = { "E1" } }), 2, NORMAL)
		t.eq(#one.lockedEntrances, 0)
		t.eq(#one.openEntrances, 1)
		local two = RoundPlan.generate(1, map1({ entrances = { "E1", "E2" } }), 2, NORMAL)
		t.eq(#two.lockedEntrances, 1)
		local none = RoundPlan.generate(1, map1({ entrances = {} }), 2, NORMAL)
		t.eq(#none.openEntrances, 0)
	end)

	t.test("exits: van always, boat about half the time", function()
		local boats = 0
		for seed = 1, 200 do
			local plan = RoundPlan.generate(seed, map1(), 2, NORMAL)
			t.ok(contains(plan.activeExits, "Van"))
			if contains(plan.activeExits, "Boat") then
				boats += 1
				t.ok(plan.secondExit)
			else
				t.ok(contains(plan.inactiveExits, "Boat"))
				t.ok(not plan.secondExit)
			end
		end
		t.ok(boats > 70 and boats < 130, "boat active " .. boats .. "/200")
	end)

	t.test("exits: an only-optional exit is forced active", function()
		local plan = RoundPlan.generate(3, map1({ exits = { { Id = "Boat", Optional = true } } }), 1, NORMAL)
		t.eq(plan.activeExits[1], "Boat")
	end)

	t.test("guards by crew size on map 1: 2/3/3/4, Double Shift +1, capped", function()
		for crew, expected in { 2, 3, 3, 4 } do
			local plan = RoundPlan.generate(7, map1(), crew, NORMAL)
			t.eq(plan.guardCount, expected, "crew " .. crew)
			t.eq(#plan.guards, expected)
			t.eq(plan.otherNpcs, 2) -- Karel + Boef
		end
		local ds = { difficulty = "Normal", modifierId = "DoubleShift" }
		t.eq(RoundPlan.generate(7, map1(), 4, ds).guardCount, 5)
		local hardDs = { difficulty = "Hard", modifierId = "DoubleShift" }
		t.eq(RoundPlan.generate(7, map1(), 4, hardDs).guardCount, 5) -- 6 wanted, cap 7 − 2
		t.eq(RoundPlan.generate(7, map1(), 1, { difficulty = "Hard" }).guardCount, 3)
		t.eq(RoundPlan.generate(7, map1({ guardBonus = 1 }), 1, NORMAL).guardCount, 3)
	end)

	t.test("routes: lowest priority first, ties shuffled", function()
		local orders = {}
		for seed = 1, 60 do
			local two = RoundPlan.generate(seed, map1(), 1, NORMAL) -- 2 guards
			local ids = { two.guards[1].routeId, two.guards[2].routeId }
			t.ok(contains(ids, "R1") and contains(ids, "R2"), "seed " .. seed)
			orders[ids[1]] = true
			local three = RoundPlan.generate(seed, map1(), 2, NORMAL) -- 3 guards
			local third = three.guards[3].routeId
			t.ok(third == "R3" or third == "R4", "third guard on " .. tostring(third))
		end
		t.ok(orders.R1 and orders.R2, "tie order never shuffled")
	end)

	t.test("guard variant, start waypoint and waits stay in range", function()
		for seed = 1, 40 do
			local plan = RoundPlan.generate(seed, map1(), 4, NORMAL)
			for _, g in plan.guards do
				t.ok(g.variant >= 1 and g.variant <= 2)
				t.ok(g.start >= 1 and g.start <= 4)
				t.eq(#g.waits, 4)
				for _, w in g.waits do
					t.ok(w >= 1 and w <= 3, "wait " .. w) -- 2 ± 1
				end
			end
		end
	end)

	t.test("waits never go below 0", function()
		local info = map1()
		for _, r in info.routes do
			for _, variant in r.Variants do
				for _, p in variant do
					p.Wait = 0.2
				end
			end
		end
		for seed = 1, 20 do
			for _, g in RoundPlan.generate(seed, info, 4, NORMAL).guards do
				for _, w in g.waits do
					t.ok(w >= 0)
				end
			end
		end
	end)

	t.test("too few routes: reused with a warning; no routes: fallback", function()
		local few = RoundPlan.generate(1, map1({ routes = { route("A", 1) } }), 4, NORMAL)
		t.eq(#few.guards, 4)
		t.eq(few.guards[4].routeId, "A")
		t.ok(#few.warnings > 0)
		local none = RoundPlan.generate(1, map1({ routes = {} }), 3, NORMAL)
		t.eq(#none.guards, 3)
		t.eq(none.guards[1].routeId, nil)
		t.ok(#none.warnings > 0)
	end)

	t.test("Health Inspector: counts as an NPC and takes a spare route", function()
		local job = { difficulty = "Normal", modifierId = "HealthInspector" }
		for seed = 1, 20 do
			local plan = RoundPlan.generate(seed, map1(), 4, job)
			t.eq(plan.otherNpcs, 3)
			t.eq(plan.guardCount, 4)
			t.ok(plan.inspector ~= nil)
			for _, g in plan.guards do
				t.ok(g.routeId ~= plan.inspector.routeId)
			end
		end
		t.eq(RoundPlan.generate(1, map1(), 4, NORMAL).inspector, nil)
	end)

	t.test("Wet Floor: 6 distinct puddles; otherwise none", function()
		local job = { difficulty = "Normal", modifierId = "WetFloor" }
		for seed = 1, 20 do
			local plan = RoundPlan.generate(seed, map1(), 2, job)
			t.eq(#plan.hazards, 6)
			local seen = {}
			for _, id in plan.hazards do
				t.ok(not seen[id])
				seen[id] = true
			end
		end
		t.eq(#RoundPlan.generate(1, map1(), 2, NORMAL).hazards, 0)
		local short = RoundPlan.generate(1, map1({ hazards = { "W1", "W2" } }), 2, job)
		t.eq(#short.hazards, 2)
		t.ok(#short.warnings > 0)
	end)

	t.test("keycard: on a keycard anchor or on a guard, both happen", function()
		local onGuard, onAnchor = 0, 0
		for seed = 1, 200 do
			local plan = RoundPlan.generate(seed, map1(), 2, NORMAL)
			local card = plan.objectives[1]
			t.eq(card.id, "OfficeCard")
			t.ok(card.required)
			t.eq(card.bonusPct, 0)
			t.eq(#card.anchors, 3)
			if card.onGuard then
				onGuard += 1
				t.ok(card.guardIndex >= 1 and card.guardIndex <= plan.guardCount)
				t.eq(card.anchorId, nil)
			else
				onAnchor += 1
				t.ok(contains({ "K01", "K02", "K03" }, card.anchorId))
			end
		end
		t.ok(onGuard > 70 and onAnchor > 70, onGuard .. " on a guard, " .. onAnchor .. " on an anchor")
	end)

	t.test("keycard without anchors hangs on a guard", function()
		local info = map1()
		local kept = {}
		for _, a in info.anchors do
			if a.Group ~= "Keycard" then
				table.insert(kept, a)
			end
		end
		info.anchors = kept
		for seed = 1, 10 do
			local card = RoundPlan.generate(seed, info, 2, NORMAL).objectives[1]
			t.ok(card.onGuard)
		end
	end)

	t.test("safe: 1–2 jams inside the window, its loot on its own anchors, +10%", function()
		local window = Config.Plan.DeviceJamWindow
		local counts = {}
		for seed = 1, 100 do
			local plan = RoundPlan.generate(seed, map1(), 2, NORMAL)
			local safe = plan.objectives[2]
			t.eq(safe.id, "OfficeSafe")
			t.eq(safe.bonusPct, Config.Objectives.BonusPct)
			local n = #safe.jamPoints
			t.ok(n >= 1 and n <= 2, "jams " .. n)
			counts[n] = true
			for i, p in safe.jamPoints do
				t.ok(p >= window[1] and p <= window[2])
				if i > 1 then
					t.ok(p > safe.jamPoints[i - 1])
				end
			end
			t.eq(#safe.loot, 2)
			for _, item in safe.loot do
				t.ok(item.anchorId == "V01" or item.anchorId == "V02")
				t.eq(item.type, "CashDrawer")
			end
		end
		t.ok(counts[1] and counts[2], "both 1 and 2 jams happen")
	end)

	t.test("max 1 optional objective per heist", function()
		local info = map1()
		table.insert(info.objectives, { Id = "SecondSafe", Type = "Safe", Required = false })
		local kept = {}
		for seed = 1, 60 do
			local plan = RoundPlan.generate(seed, info, 2, NORMAL)
			local optional = 0
			for _, o in plan.objectives do
				if not o.required then
					optional += 1
					kept[o.id] = true
				end
			end
			t.eq(optional, 1)
			t.eq(#plan.objectives, 2)
		end
		t.ok(kept.OfficeSafe and kept.SecondSafe, "the optional one is picked at random")
	end)

	t.test("mini-job: fixed anchors always filled, no Karel, no dog", function()
		local info = {
			heistId = "MiniJob",
			anchors = {
				{ Id = "Wheel", Class = "Medium", Fixed = true },
				{ Id = "Cube1", Class = "Small", Fixed = true },
				{ Id = "Cube2", Class = "Small", Fixed = true },
				{ Id = "Gouda", Class = "Main", Fixed = true },
			},
			loot = {
				{ Type = "CheeseWheel", Count = 1 },
				{ Type = "CheeseCube", Count = 1 },
				{ Type = "GoldenGouda", Count = 1 },
			},
			lootTypes = Config.Loot.Types,
			exits = { { Id = "Van" } },
			hasKarel = false,
			rules = RULES,
		}
		local plan = RoundPlan.generate(5, info, 1, {})
		t.eq(#plan.loot, 4) -- both cubes, though Count = 1
		t.eq(plan.mainAnchor, "Gouda")
		t.eq(plan.otherNpcs, 0)
	end)

	t.test("too few anchors: places what fits and warns", function()
		local info = map1({ loot = { { Type = "BigWheel", Count = 9 } } })
		local plan = RoundPlan.generate(1, info, 1, NORMAL)
		t.eq(#plan.loot, 4)
		t.ok(#plan.warnings > 0)
	end)

	t.test("unknown loot types and modifiers are harmless", function()
		local info = map1({ loot = { { Type = "Mystery", Count = 2 }, { Type = "TipJar", Count = 1 } } })
		local plan = RoundPlan.generate(1, info, 1, { modifierId = "Disco" })
		t.eq(#plan.loot, 1)
		t.ok(#plan.warnings > 0)
		t.eq(plan.guardCount, 2)
	end)

	t.test("plan echoes the job", function()
		local plan = RoundPlan.generate(42, map1(), 2, { difficulty = "Hard", modifierId = "PowerCut" })
		t.eq(plan.seed, 42)
		t.eq(plan.heistId, "GoldenWheel")
		t.eq(plan.difficulty, "Hard")
		t.eq(plan.modifierId, "PowerCut")
	end)
end
