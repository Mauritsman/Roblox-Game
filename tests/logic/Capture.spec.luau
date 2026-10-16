--!nocheck
local Capture = require("../../src/shared/Logic/Capture")
local Config = require("../../src/shared/Config")

local RANGE = Config.Guard.CaptureDistance -- 3.5
local SECONDS = Config.Guard.GrabSeconds -- 1

return function(t)
	t.test("grab: 1 s within 3.5 studs grabs", function()
		local progress, grabbed = 0, false
		for _ = 1, 9 do
			progress, grabbed = Capture.grabStep(progress, 0.1, 3, RANGE, SECONDS)
			t.ok(not grabbed)
		end
		progress, grabbed = Capture.grabStep(progress, 0.1, 3, RANGE, SECONDS)
		t.ok(grabbed)
	end)

	t.test("grab: stepping out of range resets the timer", function()
		local progress = Capture.grabStep(0, 0.9, 2, RANGE, SECONDS)
		local reset, grabbed = Capture.grabStep(progress, 0.1, 4, RANGE, SECONDS)
		t.eq(reset, 0)
		t.ok(not grabbed)
	end)

	t.test("hero moment: bubble always, Noisemaker within 20 studs", function()
		local radius = Config.Capture.HeroNoisemakerRadius
		t.ok(Capture.heroDrop("bubble", 999, radius))
		t.ok(Capture.heroDrop("noisemaker", 20, radius))
		t.ok(not Capture.heroDrop("noisemaker", 21, radius))
		t.ok(not Capture.heroDrop("crack", 1, radius))
	end)

	t.test("self-escape unlocks 15 s after the cell, once (Easy twice)", function()
		t.eq(Capture.selfEscapeAt(100, Config.Capture.SelfEscapeAfter, 0, 1), 115)
		t.eq(Capture.selfEscapeAt(100, 15, 1, 1), nil)
		t.eq(Capture.selfEscapeAt(100, 15, 1, 2), 115)
		t.eq(Capture.selfEscapeAt(100, 12, 0, 1), 112) -- Escape Artist
	end)

	t.test("canCrawlOut checks cell, count and time", function()
		local base = { captured = "Cell", selfEscapeAt = 115, used = 0, allowed = 1 }
		t.eq(select(2, Capture.canCrawlOut(base, 110)), "NotYet")
		t.ok(Capture.canCrawlOut(base, 115))
		t.eq(
			select(
				2,
				Capture.canCrawlOut({ captured = "Carried", selfEscapeAt = 115, used = 0, allowed = 1 }, 200)
			),
			"NotInCell"
		)
		t.eq(
			select(
				2,
				Capture.canCrawlOut({ captured = "Cell", selfEscapeAt = 115, used = 1, allowed = 1 }, 200)
			),
			"NoneLeft"
		)
		t.eq(select(2, Capture.canCrawlOut({ captured = "Cell", used = 0, allowed = 1 }, 200)), "NotYet")
	end)

	t.test("all caught: every flag, never for an empty crew", function()
		t.ok(Capture.allCaught({ true }))
		t.ok(Capture.allCaught({ true, true, true, true }))
		t.ok(not Capture.allCaught({ true, false }))
		t.ok(not Capture.allCaught({}))
	end)

	t.test("freeSpot finds the first empty cell spot", function()
		t.eq(Capture.freeSpot({}, 4), 1)
		t.eq(Capture.freeSpot({ [1] = "a", [2] = "b" }, 4), 3)
		t.eq(Capture.freeSpot({ [1] = "a" }, 1), nil)
		t.eq(Capture.freeSpot({}, 0), nil)
	end)

	t.test("reach: horizontal distance, another floor is out of reach", function()
		local vertical = Config.Guard.GrabVertical -- 4.5
		t.near(Capture.reach(3, 0, 4, vertical), 5)
		t.near(Capture.reach(3, -2, 0, vertical), 3) -- height difference within the tolerance is ignored
		t.near(Capture.reach(0, 4.5, 2, vertical), 2)
		t.eq(Capture.reach(0, 4.6, 0, vertical), math.huge)
		t.eq(Capture.reach(1, -9, 1, vertical), math.huge) -- upper floor (y 9)
	end)

	t.test("B-007: a guard standing on the player's head still grabs within 1 s", function()
		-- Smoke test: guard root y 6.96, player root y 2.9, 0.3 studs apart sideways. 3D distance 4.07 > 3.5.
		local dx, dy, dz = 0.3, 2.9 - 6.96, 0.1
		t.ok(math.sqrt(dx * dx + dy * dy + dz * dz) > RANGE)
		local reach = Capture.reach(dx, dy, dz, Config.Guard.GrabVertical)
		t.ok(reach <= RANGE)
		local progress, grabbed = 0, false
		for _ = 1, 10 do
			progress, grabbed = Capture.grabStep(progress, 0.1, reach, RANGE, SECONDS)
		end
		t.ok(grabbed)
	end)

	t.test("B-007: a slow walker the guard keeps up with is grabbed after 1 s", function()
		-- Chase at 15, the player crouch-walks away at 8: once within range the guard stays within range.
		local guardX, playerX = -3, 0
		local progress, grabbed, seconds = 0, false, 0
		while not grabbed and seconds < 3 do
			local dt = 1 / 60
			seconds += dt
			playerX += 8 * dt
			guardX = math.min(playerX, guardX + Config.Guard.ChaseSpeed * dt) -- walks into the player (no collision)
			progress, grabbed = Capture.grabStep(
				progress,
				dt,
				Capture.reach(playerX - guardX, 0, 0, Config.Guard.GrabVertical),
				RANGE,
				SECONDS
			)
		end
		t.ok(grabbed)
		t.ok(seconds <= SECONDS + 0.05, string.format("grabbed after %.2f s", seconds))
	end)
end
