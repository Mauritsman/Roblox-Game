--!nocheck
local Melt = require("../../src/shared/Logic/Melt")

return function(t)
	t.test("only moved melting loot outside the cold melts", function()
		t.ok(Melt.melting({ melts = true, state = "Carried", inCold = false, moved = true }))
		t.ok(Melt.melting({ melts = true, state = "Dropped", inCold = false, moved = false }))
		t.ok(Melt.melting({ melts = true, state = "Placed", inCold = false, moved = true })) -- riding a car
		t.ok(not Melt.melting({ melts = true, state = "Placed", inCold = false, moved = false })) -- on its display
		t.ok(not Melt.melting({ melts = true, state = "Carried", inCold = true, moved = true }))
		t.ok(not Melt.melting({ melts = false, state = "Carried", inCold = false, moved = true }))
		t.ok(not Melt.melting({ melts = true, state = "Banked", inCold = false, moved = true }))
	end)

	t.test("Golden Praline: 2% of 2200 = 44 per second", function()
		local loss, pending = Melt.step(0, 2200, 2200, 1, 0.02, 0.5)
		t.eq(loss, 44)
		t.near(pending, 0)
	end)

	t.test("cheap items carry fractions over", function()
		-- 25 × 0.02 = 0.5 per second: nothing in the first second, 1 in the second.
		local loss, pending = Melt.step(0, 25, 25, 1, 0.02, 0.5)
		t.eq(loss, 0)
		t.near(pending, 0.5)
		loss, pending = Melt.step(pending, 25, 25, 1, 0.02, 0.5)
		t.eq(loss, 1)
		t.near(pending, 0)
	end)

	t.test("never below 50% of base, also after fragile damage", function()
		local value, pending, total = 2200, 0, 0
		for _ = 1, 100 do
			local loss
			loss, pending = Melt.step(pending, value, 2200, 1, 0.02, 0.5)
			value -= loss
			total += loss
		end
		t.eq(value, 1100)
		t.eq(total, 1100)
		local loss = Melt.step(0, 1000, 2200, 1, 0.02, 0.5) -- a drop already took it under the floor
		t.eq(loss, 0)
		local last = Melt.step(0, 1120, 2200, 1, 0.02, 0.5) -- 44 would overshoot: stops at 1100
		t.eq(last, 20)
	end)

	t.test("floor rounds up and bad inputs lose nothing", function()
		t.eq(Melt.floor(25, 0.5), 13)
		t.eq(Melt.floor(2200, 0.5), 1100)
		t.eq(Melt.step(0, 100, 0, 1, 0.02, 0.5), 0)
		t.eq(Melt.step(0, 100, 100, 0, 0.02, 0.5), 0)
	end)
end
