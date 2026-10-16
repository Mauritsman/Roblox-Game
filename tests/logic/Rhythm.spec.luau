--!nocheck
local Rhythm = require("../../src/shared/Logic/Rhythm")

return function(t)
	t.test("fountain: active for 4 s every 30 s", function()
		local timer = Rhythm.new(30, 4, 100)
		t.ok(Rhythm.isActive(timer, 100))
		t.ok(Rhythm.isActive(timer, 103.9))
		t.ok(not Rhythm.isActive(timer, 104))
		t.ok(not Rhythm.isActive(timer, 129.9))
		t.ok(Rhythm.isActive(timer, 130.5))
		t.eq(Rhythm.cycle(timer, 130.5), 1)
		t.near(Rhythm.untilNext(timer, 125), 5)
	end)

	t.test("phase and cycle before t0 stay consistent", function()
		local timer = Rhythm.new(6, 2, 100)
		t.near(Rhythm.phase(timer, 99), 5)
		t.eq(Rhythm.cycle(timer, 99), -1)
	end)

	t.test("period 0 = always active (sprinklers)", function()
		local timer = Rhythm.new(0, 0, 0)
		t.ok(Rhythm.isActive(timer, 12345))
		t.eq(Rhythm.cycle(timer, 50), 0)
		t.eq(Rhythm.untilNext(timer, 1), math.huge)
	end)

	t.test("retime keeps the fraction (clock angle) continuous", function()
		local timer = Rhythm.new(12, 12, 0)
		local now = 15 -- 3 s into a 12 s sweep = 0.25
		local fast = Rhythm.retime(timer, now, 6, 6)
		t.near(Rhythm.fraction(fast, now), 0.25)
		t.near(Rhythm.fraction(fast, now + 1.5), 0.5)
		t.eq(fast.period, 6)
	end)

	t.test("periodFor: explicit lockdown period, speed-up factor, unchanged", function()
		t.eq(Rhythm.periodFor(12, false, 6, true, 0.5), 12)
		t.eq(Rhythm.periodFor(12, true, 6, false, 0.5), 6)
		t.eq(Rhythm.periodFor(30, true, nil, true, 0.5), 15)
		t.eq(Rhythm.periodFor(30, true, nil, false, 0.5), 30)
	end)

	t.test("ellipse points", function()
		local x, z = Rhythm.ellipse(-10, 0, 18, 30, 0)
		t.near(x, 8)
		t.near(z, 0)
		x, z = Rhythm.ellipse(-10, 0, 18, 30, math.pi / 2)
		t.near(x, -10)
		t.near(z, 30)
	end)

	t.test("segment distance", function()
		t.near(Rhythm.segmentDistance(5, 3, 0, 0, 10, 0), 3)
		t.near(Rhythm.segmentDistance(-4, 3, 0, 0, 10, 0), 5)
		t.near(Rhythm.segmentDistance(1, 1, 2, 2, 2, 2), math.sqrt(2))
	end)

	t.test("clock beam: lit along the hand, dark beside it", function()
		-- Centre (-10, 0), radii 18 × 30, hand pointing +x (angle 0), half-width 5.
		t.ok(Rhythm.beamHit(0, 2, -10, 0, 18, 30, 0, 5))
		t.ok(not Rhythm.beamHit(0, 8, -10, 0, 18, 30, 0, 5))
		t.ok(not Rhythm.beamHit(15, 0, -10, 0, 18, 30, 0, 5)) -- past the rim
		t.ok(Rhythm.beamHit(-10, 20, -10, 0, 18, 30, math.pi / 2, 5))
	end)

	t.test("meter fills in fillSeconds and drains", function()
		local m = Rhythm.meter(0, 0.4, true, 0.8, 1, 1)
		t.near(m, 0.5)
		m = Rhythm.meter(m, 0.5, true, 0.8, 1, 1)
		t.eq(m, 1)
		m = Rhythm.meter(m, 0.25, false, 0.8, 1, 1)
		t.near(m, 0.75)
		t.near(Rhythm.meter(0, 0.4, true, 0.8, 0.5, 1), 0.25) -- crouching halves the rate
		t.eq(Rhythm.meter(0.1, 1, false, 0.8, 1, 1), 0)
	end)
end
