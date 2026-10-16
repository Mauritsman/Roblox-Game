--!nocheck
local NpcBudget = require("../../src/shared/Logic/NpcBudget")
local Config = require("../../src/shared/Config")

local COUNT = Config.Guard.CountByCrew -- {2, 3, 3, 4}
local CAP = Config.Npc.Cap -- 7
local MAP1_OTHERS = NpcBudget.others({ karel = true, dog = true }) -- Karel + Boef

return function(t)
	t.test("map 1 base by crew size: 2/3/3/4", function()
		t.eq(MAP1_OTHERS, 2)
		for crew, expected in { 2, 3, 3, 4 } do
			t.eq(NpcBudget.guardCount(crew, COUNT, nil, MAP1_OTHERS, CAP), expected, "crew " .. crew)
		end
	end)

	t.test("Double Shift: 3/4/4/5", function()
		for crew, expected in { 3, 4, 4, 5 } do
			t.eq(NpcBudget.guardCount(crew, COUNT, { 0, 1, 0 }, MAP1_OTHERS, CAP), expected, "crew " .. crew)
		end
	end)

	t.test("four players, Double Shift: 5 guards + Karel + Boef = 7 (spec §4.4)", function()
		local guards = NpcBudget.guardCount(4, COUNT, { 0, 1, 0 }, MAP1_OTHERS, CAP)
		t.eq(guards + MAP1_OTHERS, 7)
	end)

	t.test("Hard + Double Shift is capped at cap − others", function()
		t.eq(NpcBudget.guardCount(4, COUNT, { 0, 1, 1 }, MAP1_OTHERS, CAP), 5)
	end)

	t.test("maps 2–3 guard bonus +1", function()
		local others = NpcBudget.others({ karel = true, extra = 1 }) -- Karel + Robo-Mop
		t.eq(NpcBudget.guardCount(1, COUNT, { 1 }, others, CAP), 3)
		t.eq(NpcBudget.guardCount(4, COUNT, { 1 }, others, CAP), 5)
	end)

	t.test("the Inspector takes a slot", function()
		local others = NpcBudget.others({ karel = true, dog = true, inspector = 1 })
		t.eq(others, 3)
		t.eq(NpcBudget.guardCount(4, COUNT, { 0, 1, 1 }, others, CAP), 4)
	end)

	t.test("always at least 1 guard", function()
		t.eq(NpcBudget.guardCount(1, COUNT, nil, 7, CAP), 1)
		t.eq(NpcBudget.guardCount(1, COUNT, nil, 9, CAP), 1)
		t.eq(NpcBudget.guardCount(1, COUNT, { -5 }, 0, CAP), 1)
	end)

	t.test("crew sizes outside 1..4 clamp to the list", function()
		t.eq(NpcBudget.baseFor(0, COUNT), 2)
		t.eq(NpcBudget.baseFor(6, COUNT), 4)
		t.eq(NpcBudget.baseFor(2.7, COUNT), 3)
		t.eq(NpcBudget.baseFor(3, {}), 1)
	end)

	t.test("a number works as base and as bonus", function()
		t.eq(NpcBudget.guardCount(3, 2, 1, 0, CAP), 3)
	end)

	t.test("others counts each kind", function()
		t.eq(NpcBudget.others({}), 0)
		t.eq(NpcBudget.others({ karel = true }), 1)
		t.eq(NpcBudget.others({ karel = true, dog = true, extra = 2, inspector = 1 }), 5)
	end)
end
