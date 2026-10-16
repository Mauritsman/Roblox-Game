--!nocheck
local Hiding = require("../../src/shared/Logic/Hiding")
local Config = require("../../src/shared/Config")

local H = Config.Hiding

return function(t)
	t.test("empty hands or pocket loot may hide", function()
		t.ok(Hiding.canHide({ activity = "Crew" }, 0))
		t.ok(Hiding.canHide({ activity = "Crew", carryClass = "Small" }, 0))
		t.ok(Hiding.canHide({ activity = "Tutorial" }, 0))
		t.ok(Hiding.canHide({}, 0)) -- prototype: no Activity yet
	end)

	t.test("a wheel (or heavier) in your hands: refused", function()
		for _, class in { "Medium", "Heavy", "Main" } do
			local ok, reason = Hiding.canHide({ activity = "Crew", carryClass = class }, 0)
			t.ok(not ok)
			t.eq(reason, "HandsFull")
		end
	end)

	t.test("other refusals", function()
		t.eq(select(2, Hiding.canHide({ activity = "Garage" }, 0)), "NotInRound")
		t.eq(select(2, Hiding.canHide({ activity = "Crew", caught = true }, 0)), "Caught")
		t.eq(select(2, Hiding.canHide({ activity = "Crew", hidden = true }, 0)), "AlreadyHidden")
		t.eq(select(2, Hiding.canHide({ activity = "Crew", occupied = true }, 0)), "Taken")
		t.eq(select(2, Hiding.canHide({ activity = "Crew", operating = true }, 0)), "Busy")
		t.eq(select(2, Hiding.canHide({ activity = "Crew", lockoutUntil = 10 }, 9)), "TooSoon")
		t.ok(Hiding.canHide({ activity = "Crew", lockoutUntil = 10 }, 10))
	end)

	t.test("every refusal has a short toast", function()
		for _, reason in { "NotInRound", "Caught", "AlreadyHidden", "HandsFull", "Busy", "Taken", "TooSoon" } do
			t.ok(type(Hiding.REFUSALS[reason]) == "string", reason)
		end
	end)

	t.test("timeline: hidden, shake at 15 s, ACHOO at 20 s", function()
		t.eq(Hiding.phase(100, 114.9, H.WarnAt, H.SneezeAt), "Hidden")
		t.eq(Hiding.phase(100, 115, H.WarnAt, H.SneezeAt), "Warn")
		t.eq(Hiding.phase(100, 120, H.WarnAt, H.SneezeAt), "Sneeze")
		t.eq(Hiding.phase(100, 120, 20, 25), "Warn") -- Barrel Lungs
	end)

	t.test("HideExit only after the 0.5 s entry", function()
		t.ok(not Hiding.canExit(100, 100.4, H.Exit))
		t.ok(Hiding.canExit(100, 100.5, H.Exit))
	end)

	t.test("seen getting in: meter ≥ 0.35 or chasing", function()
		local threshold = Config.Guard.SeenEnteringMeter
		t.ok(Hiding.isWitness(0.35, false, threshold))
		t.ok(Hiding.isWitness(0, true, threshold))
		t.ok(not Hiding.isWitness(0.34, false, threshold))
	end)
end
