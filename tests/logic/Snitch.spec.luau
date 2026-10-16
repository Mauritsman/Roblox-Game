--!nocheck
local Snitch = require("../../src/shared/Logic/Snitch")
local Detection = require("../../src/shared/Logic/Detection")
local Config = require("../../src/shared/Config")

local S = Config.Snitch

return function(t)
	t.test("Karel (×0.5) needs twice a guard's time up close", function()
		local rate = Detection.fillRate(0, S.Range, { S.KarelFill })
		t.near(1 / rate, 1.6)
		local meter, full = 0, false
		for _ = 1, 15 do
			meter, full = Snitch.step(meter, 0.1, rate, 0.5)
		end
		t.ok(not full)
		meter, full = Snitch.step(meter, 0.1, rate, 0.5)
		t.ok(full)
		t.eq(meter, 1)
	end)

	t.test("the Inspector (×0.67) is quicker than Karel", function()
		local karel = Detection.fillRate(10, S.Range, { S.KarelFill })
		local inspector = Detection.fillRate(10, S.Range, { S.InspectorFill })
		t.ok(inspector > karel)
	end)

	t.test("unseen: the meter decays, never below 0", function()
		local meter = Snitch.step(0.5, 0.5, 0, 0.5)
		t.near(meter, 0.25)
		t.eq(Snitch.step(0.1, 1, 0, 0.5), 0)
	end)

	t.test("one report per player per 30 s", function()
		t.ok(Snitch.canReport(nil, 0, S.Cooldown))
		t.ok(not Snitch.canReport(100, 129, S.Cooldown))
		t.ok(Snitch.canReport(100, 130, S.Cooldown))
	end)
end
