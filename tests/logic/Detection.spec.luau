--!nocheck
local Detection = require("../../src/shared/Logic/Detection")
local Config = require("../../src/shared/Config")

local rates = {
	CrouchFillRate = Config.Guard.CrouchFillRate,
	CarryFillRate = Config.Guard.CarryFillRate,
	LockdownFillRate = Config.Guard.LockdownFillRate,
	SleepyFillRate = Config.Modifiers.SleepyGuards.FillRate,
}
local ranges = {
	RangeLit = Config.Guard.RangeLit,
	RangeDark = Config.Guard.RangeDark,
	FlashlightRange = Config.Guard.FlashlightRange,
}

local function v(x, y, z)
	return { x = x, y = y, z = z }
end

return function(t)
	t.test("meter: 0.8 s up close, 2.0 s at the edge, linear in between", function()
		t.near(Detection.fillSeconds(0, 35), 0.8)
		t.near(Detection.fillSeconds(35, 35), 2.0)
		t.near(Detection.fillSeconds(17.5, 35), 1.4)
		t.near(Detection.fillSeconds(9, 18), 1.4)
	end)

	t.test("defaults match Config.Guard", function()
		t.eq(Detection.DEFAULT_NEAR, Config.Guard.FillSecondsNear)
		t.eq(Detection.DEFAULT_FAR, Config.Guard.FillSecondsFar)
	end)

	t.test("outside the range or with a zero range it never fills", function()
		t.eq(Detection.fillSeconds(36, 35), math.huge)
		t.eq(Detection.fillSeconds(0, 0), math.huge)
		t.eq(Detection.fillRate(36, 35), 0)
	end)

	t.test("factors are rates and multiply", function()
		t.near(Detection.fillSeconds(0, 35, { 0.5 }), 1.6) -- crouch doubles the time
		t.near(Detection.fillSeconds(0, 35, { 1.25 }), 0.64)
		t.near(Detection.fillSeconds(0, 35, { 0.5, 1.25 }), 0.8 / 0.625)
		t.near(Detection.fillSeconds(35, 35, { 1.5, 1.33, 1.2 }), 2.0 / (1.5 * 1.33 * 1.2))
		t.near(Detection.fillSeconds(0, 35, { a = 2, b = 2 }), 0.2) -- maps work too
		t.eq(Detection.fillSeconds(0, 35, { 0 }), math.huge)
	end)

	t.test("custom near/far", function()
		t.near(Detection.fillSeconds(0, 20, nil, 1, 3), 1)
		t.near(Detection.fillSeconds(20, 20, nil, 1, 3), 3)
	end)

	t.test("fillRate is the inverse of fillSeconds", function()
		t.near(Detection.fillRate(0, 35), 1 / 0.8)
		t.near(Detection.fillRate(35, 35, { 2 }), 1)
	end)

	t.test("factorsFor: crouch only with free hands", function()
		t.near(Detection.multiply(Detection.factorsFor({ crouching = true }, rates)), 0.5)
		t.near(
			Detection.multiply(Detection.factorsFor({ crouching = true, carryClass = "Small" }, rates)),
			0.5
		)
		t.near(
			Detection.multiply(Detection.factorsFor({ crouching = true, carryClass = "Medium" }, rates)),
			1.25
		)
	end)

	t.test("factorsFor: carry classes", function()
		t.near(Detection.multiply(Detection.factorsFor({ carryClass = "Medium" }, rates)), 1.25)
		t.near(Detection.multiply(Detection.factorsFor({ carryClass = "Heavy" }, rates)), 1.5)
		t.near(Detection.multiply(Detection.factorsFor({ carryClass = "Main" }, rates)), 1.5)
		t.near(Detection.multiply(Detection.factorsFor({}, rates)), 1)
	end)

	t.test("factorsFor: sleepy, lockdown, tier and extra all multiply", function()
		local f = Detection.factorsFor({
			carryClass = "Heavy",
			sleepyGuards = true,
			lockdown = true,
			tierFillRate = 1.2,
			extra = 0.5,
		}, rates)
		t.eq(#f, 5)
		t.near(Detection.multiply(f), 1.5 * 0.7 * 1.33 * 1.2 * 0.5)
	end)

	t.test("levelFor: alarm ladder 100/200/300", function()
		local th = Config.Alarm.LevelThresholds
		t.eq(Detection.levelFor(0, th), 0)
		t.eq(Detection.levelFor(99, th), 0)
		t.eq(Detection.levelFor(100, th), 1)
		t.eq(Detection.levelFor(250, th), 2)
		t.eq(Detection.levelFor(300, th), 3)
		t.eq(Detection.levelFor(1000, th), 3)
		t.eq(Detection.levelFor(50, {}), 0)
	end)

	t.test("rangeFor: lit 35, dark 18, Power Cut flashlight 22", function()
		t.eq(Detection.rangeFor(true, false, ranges), 35)
		t.eq(Detection.rangeFor(false, false, ranges), 18)
		t.eq(Detection.rangeFor(true, true, ranges), 22)
		t.eq(Detection.rangeFor(false, true, ranges), 22)
	end)

	t.test("inCone: angle and range", function()
		local eye, fwd = v(0, 0, 0), v(0, 0, -1)
		t.ok(Detection.inCone(eye, fwd, v(0, 0, -10), 35, 35))
		local a34, a36 = math.rad(34), math.rad(36)
		t.ok(Detection.inCone(eye, fwd, v(math.sin(a34) * 10, 0, -math.cos(a34) * 10), 35, 35))
		t.ok(not Detection.inCone(eye, fwd, v(math.sin(a36) * 10, 0, -math.cos(a36) * 10), 35, 35))
		t.ok(not Detection.inCone(eye, fwd, v(0, 0, 10), 35, 35)) -- behind
		t.ok(not Detection.inCone(eye, fwd, v(0, 0, -36), 35, 35)) -- too far
		t.ok(Detection.inCone(eye, v(0, 0, -5), v(0, 0, -10), 35, 35)) -- forward need not be unit length
		t.ok(Detection.inCone(eye, fwd, v(0, 0, 0), 35, 35)) -- same spot
		t.ok(not Detection.inCone(eye, v(0, 0, 0), v(0, 0, -10), 35, 35)) -- no facing
	end)

	t.test("isIgnored: each reason", function()
		local crew = { activity = "Crew", masked = true }
		t.eq(Detection.isIgnored(crew, 10), false)
		t.eq(select(2, Detection.isIgnored({ activity = "Crew", caught = true }, 0)), "Caught")
		t.eq(select(2, Detection.isIgnored({ activity = "Crew", hidden = true }, 0)), "Hidden")
		t.eq(select(2, Detection.isIgnored({ activity = "Garage" }, 0)), "NotCrew")
		t.eq(select(2, Detection.isIgnored({ activity = "Tutorial" }, 0)), "NotCrew")
		t.eq(select(2, Detection.isIgnored({}, 0)), "NotCrew")
		t.eq(select(2, Detection.isIgnored({ activity = "Crew", immuneUntil = 13 }, 10)), "Immune")
		t.eq(Detection.isIgnored({ activity = "Crew", immuneUntil = 13 }, 13), false) -- expired
		t.eq(select(2, Detection.isIgnored({ activity = "Crew", masked = false }, 0)), "Unmasked")
		t.eq(Detection.isIgnored({ activity = "Crew" }, 0), false) -- masked nil = masked (Mask Up off)
	end)
end
