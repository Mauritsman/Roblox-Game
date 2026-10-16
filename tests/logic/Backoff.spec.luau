--!nocheck
local Backoff = require("../../src/shared/Logic/Backoff")
local RateLimit = require("../../src/shared/Logic/RateLimit")
local Calendar = require("../../src/shared/Logic/Calendar")

return function(t)
	t.test("backoff delays double up to the cap, plus at most 0.5 s jitter", function()
		t.eq(Backoff.delay(1, 16, 0), 1)
		t.eq(Backoff.delay(2, 16, 0), 2)
		t.eq(Backoff.delay(3, 16, 0), 4)
		t.eq(Backoff.delay(5, 16, 0), 16)
		t.eq(Backoff.delay(9, 16, 0), 16)
		t.near(Backoff.delay(1, 16, 0.999), 1.4995, 1e-6)
		t.eq(Backoff.delay(1, 16, 5), 1.5)
	end)

	t.test("retry stops at the first success and sleeps in between", function()
		local calls, sleeps = 0, {}
		local ok, result, used = Backoff.retry(
			function()
				calls += 1
				if calls < 3 then
					error("busy")
				end
				return "done"
			end,
			5,
			16,
			function(s)
				table.insert(sleeps, s)
			end,
			function()
				return 0
			end
		)
		t.eq(ok, true)
		t.eq(result, "done")
		t.eq(used, 3)
		t.eq(#sleeps, 2)
		t.eq(sleeps[1], 1)
		t.eq(sleeps[2], 2)
	end)

	t.test("retry gives up after the last attempt without a final sleep", function()
		local sleeps = 0
		local ok, err, used = Backoff.retry(
			function()
				error("down")
			end,
			4,
			16,
			function()
				sleeps += 1
			end,
			function()
				return 0
			end
		)
		t.eq(ok, false)
		t.ok(string.find(tostring(err), "down") ~= nil)
		t.eq(used, 4)
		t.eq(sleeps, 3)
	end)

	t.test("rate limit allows a burst, then refills per second", function()
		local bucket = RateLimit.new(5, 0)
		for _ = 1, 5 do
			t.ok(RateLimit.take(bucket, 0, 5, 2))
		end
		t.eq(RateLimit.take(bucket, 0, 5, 2), false)
		t.eq(RateLimit.take(bucket, 0.4, 5, 2), false)
		t.ok(RateLimit.take(bucket, 0.5, 5, 2))
		t.eq(RateLimit.take(bucket, 0.5, 5, 2), false)
		-- never above the burst
		t.ok(RateLimit.take(bucket, 100, 5, 2, 5))
		t.eq(RateLimit.take(bucket, 100, 5, 2), false)
	end)

	t.test("calendar days, weeks (Monday 00:00 UTC) and slots", function()
		t.eq(Calendar.day(0), 0)
		t.eq(Calendar.day(86399), 0)
		t.eq(Calendar.day(86400), 1)
		t.eq(Calendar.dayResetsAt(100), 86400)
		-- Monday 5 Jan 1970 00:00 UTC starts week 0
		t.eq(Calendar.week(345600), 0)
		t.eq(Calendar.week(345599), -1)
		t.eq(Calendar.week(345600 + 604799), 0)
		t.eq(Calendar.week(345600 + 604800), 1)
		t.eq(Calendar.weekResetsAt(345600), 345600 + 604800)
		-- Monday 12 Oct 2026 00:00 UTC = 1791763200
		local monday = 1791763200
		t.eq(Calendar.week(monday) - Calendar.week(monday - 1), 1)
		t.eq(Calendar.slot(3599, 1800), 1)
		t.eq(Calendar.slotEndsAt(3599, 1800), 3600)
	end)
end
