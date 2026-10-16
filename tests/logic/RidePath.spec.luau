--!nocheck
local RidePath = require("../../src/shared/Logic/RidePath")

local function v(x, y, z)
	return { x = x, y = y, z = z }
end

-- A 10 × 20 rectangle at y 0 (perimeter 60).
local SQUARE = { v(0, 0, 0), v(10, 0, 0), v(10, 0, 20), v(0, 0, 20) }

return function(t)
	t.test("open path: length, ends clamp", function()
		local path = RidePath.build({ v(0, 0, 0), v(0, 0, 10), v(0, 5, 10) })
		t.ok(not path.loop)
		t.eq(path.length, 15)
		local a = RidePath.pointAt(path, -3)
		t.eq(a.z, 0)
		local b = RidePath.pointAt(path, 99)
		t.eq(b.y, 5)
		t.eq(RidePath.wrap(path, 20), 15)
	end)

	t.test("closed shape becomes a loop automatically", function()
		local points = table.clone(SQUARE)
		table.insert(points, v(0, 0, 0.2))
		local path = RidePath.build(points)
		t.ok(path.loop)
		t.eq(#path.points, 4)
		t.near(path.length, 60, 1e-6)
	end)

	t.test("explicit loop wraps distance and interpolates the closing segment", function()
		local path = RidePath.build(SQUARE, true)
		t.eq(path.length, 60)
		local p, dir = RidePath.pointAt(path, 55) -- on the closing leg (0,0,20) → (0,0,0)
		t.near(p.x, 0)
		t.near(p.z, 5)
		t.near(dir.z, -1)
		local q = RidePath.pointAt(path, 65) -- wraps to 5
		t.near(q.x, 5)
		t.near(q.z, 0)
	end)

	t.test("pointAt and direction on a middle segment", function()
		local path = RidePath.build(SQUARE, true)
		local p, dir = RidePath.pointAt(path, 15) -- 5 along (10,0,0) → (10,0,20)
		t.near(p.x, 10)
		t.near(p.z, 5)
		t.near(dir.x, 0)
		t.near(dir.z, 1)
	end)

	t.test("heading blends at corners and is plain on straights", function()
		local path = RidePath.build(SQUARE, true)
		local straight = RidePath.heading(path, 5, 1)
		t.near(straight.x, 1)
		local corner = RidePath.heading(path, 10, 1) -- the corner at (10,0,0)
		t.ok(corner.x > 0.1 and corner.z > 0.1, "blended between +x and +z")
	end)

	t.test("project finds the nearest distance", function()
		local path = RidePath.build(SQUARE, true)
		local s, d = RidePath.project(path, v(12, 0, 7))
		t.near(s, 17)
		t.near(d, 2)
		local s2 = RidePath.project(path, v(-1, 3, 10))
		t.near(s2, 50)
	end)

	t.test("crossed: forward on a loop, across the wrap, not from the mark itself", function()
		local path = RidePath.build(SQUARE, true)
		t.ok(RidePath.crossed(path, 8, 3, 10))
		t.ok(not RidePath.crossed(path, 8, 1, 10))
		t.ok(RidePath.crossed(path, 58, 4, 1)) -- 58 → 62 wraps past 1
		t.ok(not RidePath.crossed(path, 10, 2, 10)) -- starting on the mark
		t.ok(RidePath.crossed(path, 9, 1, 10)) -- ending on it counts
		t.ok(RidePath.crossed(path, 0, 70, 30)) -- a full lap passes everything
	end)

	t.test("crossed: both directions on an open path", function()
		local path = RidePath.build({ v(0, 0, 0), v(0, 0, 20) })
		t.ok(RidePath.crossed(path, 5, 10, 12))
		t.ok(not RidePath.crossed(path, 5, 10, 2))
		t.ok(RidePath.crossed(path, 15, -10, 8))
		t.ok(not RidePath.crossed(path, 15, -2, 8))
	end)

	t.test("forward distance wraps on loops", function()
		local path = RidePath.build(SQUARE, true)
		t.eq(RidePath.forward(path, 50, 10), 20)
		local open = RidePath.build({ v(0, 0, 0), v(0, 0, 20) })
		t.eq(RidePath.forward(open, 15, 5), -10)
	end)

	t.test("distanceAt is linear in time", function()
		t.eq(RidePath.distanceAt(10, 8, 100, 102.5), 30)
		t.eq(RidePath.distanceAt(10, -4, 100, 101), 6)
	end)

	t.test("serialize and parse round-trip", function()
		local text = RidePath.serialize({ v(1.5, -2, 3.25), v(0, 9.2, -40) })
		local back = RidePath.parse(text)
		t.eq(#back, 2)
		t.near(back[1].x, 1.5)
		t.near(back[1].z, 3.25)
		t.near(back[2].y, 9.2)
		t.eq(#RidePath.parse("1,2,3;oops;4,5,6"), 2)
	end)

	t.test("degenerate paths do not crash", function()
		local one = RidePath.build({ v(1, 2, 3) })
		t.eq(one.length, 0)
		local p = RidePath.pointAt(one, 5)
		t.eq(p.y, 2)
		local empty = RidePath.build({})
		t.eq(RidePath.wrap(empty, 3), 0)
	end)
end
