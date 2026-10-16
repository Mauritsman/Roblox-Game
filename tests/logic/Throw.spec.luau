--!nocheck
local Throw = require("../../src/shared/Logic/Throw")
local Config = require("../../src/shared/Config")

local C = Config.Carry

local function v(x, y, z)
	return { x = x, y = y, z = z }
end

return function(t)
	t.test("clamp: inside the range nothing changes", function()
		local target, clamped = Throw.clampTarget(v(0, 3, 0), v(6, 0, 0), C.ThrowRange)
		t.ok(not clamped)
		t.eq(target.x, 6)
		t.eq(target.y, 0)
	end)

	t.test("clamp: too far is pulled back to 10 studs on the same line", function()
		local origin = v(1, 2, 3)
		local target, clamped = Throw.clampTarget(origin, v(21, 2, 3), C.ThrowRange)
		t.ok(clamped)
		t.near(target.x, 11)
		t.near(target.y, 2)
		t.near(Throw.distance(origin, target), 10)
		local diag = Throw.clampTarget(v(0, 0, 0), v(30, 40, 0), 10)
		t.near(diag.x, 6)
		t.near(diag.y, 8) -- 3D: you cannot lob onto a high roof
	end)

	t.test("clamp returns a copy", function()
		local target = v(1, 1, 1)
		local result = Throw.clampTarget(v(0, 0, 0), target, 10)
		result.x = 99
		t.eq(target.x, 1)
	end)

	t.test("Long Arm perk range 12", function()
		local _, clamped = Throw.clampTarget(v(0, 0, 0), v(11.5, 0, 0), 12)
		t.ok(not clamped)
	end)

	t.test("timing: distance / 28, clamped to 0.3–0.8 s", function()
		t.near(Throw.timing(10, C.ThrowSpeed, C.ThrowMin, C.ThrowMax), 10 / 28)
		t.near(Throw.timing(2, C.ThrowSpeed, C.ThrowMin, C.ThrowMax), 0.3)
		t.near(Throw.timing(28, C.ThrowSpeed, C.ThrowMin, C.ThrowMax), 0.8)
		t.near(Throw.timing(5, 0, C.ThrowMin, C.ThrowMax), 0.8)
	end)

	t.test("height: 35% of distance, at least 2", function()
		t.near(Throw.height(10, C.ThrowArc, C.ThrowArcMin), 3.5)
		t.near(Throw.height(4, C.ThrowArc, C.ThrowArcMin), 2)
		t.near(Throw.height(0, C.ThrowArc, C.ThrowArcMin), 2)
	end)

	t.test("point: ends at the hands and at the target", function()
		local a, b = v(0, 3, 0), v(10, 1, 4)
		local p0, p1 = Throw.point(a, b, 0, 3.5), Throw.point(a, b, 1, 3.5)
		t.near(p0.x, 0)
		t.near(p0.y, 3)
		t.near(p1.x, 10)
		t.near(p1.y, 1)
		t.near(p1.z, 4)
		-- alpha outside 0..1 is clamped
		t.near(Throw.point(a, b, 1.5, 3.5).x, 10)
		t.near(Throw.point(a, b, -1, 3.5).y, 3)
	end)

	t.test("point: peak is `height` above the midpoint, halfway", function()
		local a, b = v(0, 0, 0), v(10, 0, 0)
		local mid = Throw.point(a, b, 0.5, 3.5)
		t.near(mid.x, 5)
		t.near(mid.y, 3.5)
		local highest = 0
		for i = 0, 100 do
			highest = math.max(highest, Throw.point(a, b, i / 100, 3.5).y)
		end
		t.near(highest, 3.5)
		-- symmetric
		t.near(Throw.point(a, b, 0.25, 3.5).y, Throw.point(a, b, 0.75, 3.5).y)
	end)

	t.test("point: sloped throw adds the arc on top of the line", function()
		local mid = Throw.point(v(0, 4, 0), v(8, 0, 0), 0.5, 2)
		t.near(mid.y, 2 + 2)
	end)

	t.test("catch: 3.5 in flight, 5 on landing, thrower waits 0.3 s", function()
		local rules =
			{ CatchFlight = C.CatchFlight, CatchLanding = C.CatchLanding, SelfCatchDelay = C.SelfCatchDelay }
		t.ok(Throw.canCatch(3.5, 0.1, false, false, rules))
		t.ok(not Throw.canCatch(3.6, 0.1, false, false, rules))
		t.ok(Throw.canCatch(5, 0.5, false, true, rules))
		t.ok(not Throw.canCatch(5.1, 0.5, false, true, rules))
		t.ok(not Throw.canCatch(1, 0.2, true, false, rules))
		t.ok(Throw.canCatch(1, 0.3, true, false, rules))
	end)
end
