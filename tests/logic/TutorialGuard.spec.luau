--!nocheck
local TutorialGuard = require("../../src/shared/Logic/TutorialGuard")
local Config = require("../../src/shared/Config")

local RULES = TutorialGuard.rulesFrom(Config)

return function(t)
	t.test("stirs only for a standing player close by", function()
		t.ok(TutorialGuard.stirs(RULES.stirRadius - 1, false, RULES))
		t.ok(not TutorialGuard.stirs(RULES.stirRadius - 1, true, RULES), "crouching sneaks past")
		t.ok(not TutorialGuard.stirs(RULES.stirRadius + 1, false, RULES))
	end)

	t.test("follows at chase speed while the player runs", function()
		local step, tripped = TutorialGuard.follow(30, true, 0.1, RULES)
		t.near(step, RULES.chaseSpeed * 0.1)
		t.ok(not tripped)
	end)

	t.test("never catches: stops tripDistance short and trips when the player stands still", function()
		local distance = 20
		local trips = 0
		for _ = 1, 100 do
			local step, tripped = TutorialGuard.follow(distance, false, 0.1, RULES)
			distance -= step
			if tripped then
				trips += 1
			end
			t.ok(distance >= RULES.tripDistance - 1e-9, "never closer than tripDistance")
		end
		t.near(distance, RULES.tripDistance)
		t.ok(trips >= 1)
	end)

	t.test("a rolled Gouda (11) pulls away from a guard at 10", function()
		local distance = 6
		for _ = 1, 100 do
			distance += Config.Movement.HeavyRoll * 0.1
			local step = TutorialGuard.follow(distance, true, 0.1, RULES)
			distance -= step
		end
		t.ok(distance > 6 + 5)
	end)

	t.test("sees inside the cone and range, never a hidden player", function()
		t.ok(TutorialGuard.sees(10, 1, false, RULES))
		t.ok(not TutorialGuard.sees(10, 1, true, RULES))
		t.ok(not TutorialGuard.sees(RULES.wakeRange + 1, 1, false, RULES))
		t.ok(not TutorialGuard.sees(10, 0, false, RULES))
	end)
end
