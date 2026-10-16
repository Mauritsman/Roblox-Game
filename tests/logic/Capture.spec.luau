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
end
