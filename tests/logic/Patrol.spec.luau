--!nocheck
local Patrol = require("../../src/shared/Logic/Patrol")

local function v(x, y, z)
	return { x = x, y = y, z = z }
end

local ROUTES = {
	{
		Id = "Hall",
		Priority = 1,
		Variants = {
			{ { Pos = v(0, 0, 0), Wait = 2 }, { Pos = v(10, 0, 0) }, { Pos = v(10, 9, 10) } },
			{ { Pos = v(5, 0, 5) }, { Pos = v(15, 0, 5) } },
		},
	},
	{ Id = "Yard", Variants = { { { Pos = v(1, 0, 1) } } } },
}

return function(t)
	t.test("variant: finds route and variant, falls back to the first variant", function()
		t.eq(#Patrol.variant(ROUTES, "Hall", 1), 3)
		t.eq(#Patrol.variant(ROUTES, "Hall", 2), 2)
		t.eq(#Patrol.variant(ROUTES, "Hall", 7), 3)
		t.eq(Patrol.variant(ROUTES, "Nope", 1), nil)
		t.eq(Patrol.variant(nil, "Hall", 1), nil)
		t.eq(Patrol.variant(ROUTES, nil, 1), nil)
	end)

	t.test("steps: plan waits win, else the waypoint's Wait, never negative", function()
		local points = Patrol.variant(ROUTES, "Hall", 1)
		local steps = Patrol.steps(points, { 1.5, nil, -2 })
		t.eq(#steps, 3)
		t.eq(steps[1].wait, 1.5)
		t.eq(steps[2].wait, 0)
		t.eq(steps[3].wait, 0)
		local own = Patrol.steps(points, nil)
		t.eq(own[1].wait, 2)
	end)

	t.test("steps skip waypoints without a position", function()
		t.eq(#Patrol.steps({ { Pos = v(0, 0, 0) }, { Wait = 3 } }, nil), 1)
	end)

	t.test("fromPositions: the old GuardRoute list", function()
		local steps = Patrol.fromPositions({ v(8, 0, -18), v(48, 0, -18) })
		t.eq(#steps, 2)
		t.eq(steps[2].wait, 0)
	end)

	t.test("nextIndex loops", function()
		t.eq(Patrol.nextIndex(1, 3), 2)
		t.eq(Patrol.nextIndex(3, 3), 1)
		t.eq(Patrol.nextIndex(1, 0), 1)
	end)

	t.test("startIndex clamps out-of-range starts to 1", function()
		t.eq(Patrol.startIndex(2, 3), 2)
		t.eq(Patrol.startIndex(4, 3), 1)
		t.eq(Patrol.startIndex(nil, 3), 1)
		t.eq(Patrol.startIndex(0, 3), 1)
	end)

	t.test("spreadStart spreads guards over a shared fallback loop", function()
		t.eq(Patrol.spreadStart(1, 2, 4), 1)
		t.eq(Patrol.spreadStart(2, 2, 4), 3)
		t.eq(Patrol.spreadStart(3, 3, 4), 3)
		t.eq(Patrol.spreadStart(1, 1, 0), 1)
	end)

	t.test("changesFloor: y 0 → y 9 uses pathfinding, small steps do not", function()
		t.ok(Patrol.changesFloor(v(0, 0, 0), v(0, 9, 0), 4))
		t.ok(not Patrol.changesFloor(v(0, 0, 0), v(0, 2, 0), 4))
	end)

	t.test("arrived: horizontal range and same floor", function()
		t.ok(Patrol.arrived(1.5, 0, v(0, 0, 0), 2, 4))
		t.ok(not Patrol.arrived(2.5, 0, v(0, 0, 0), 2, 4))
		t.ok(not Patrol.arrived(1, 0, v(0, 9, 0), 2, 4))
	end)
end
