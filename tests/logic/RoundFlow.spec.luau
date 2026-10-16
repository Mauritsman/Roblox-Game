--!nocheck
local RoundFlow = require("../../src/shared/Logic/RoundFlow")
local Config = require("../../src/shared/Config")

local R = Config.Round

return function(t)
	t.test("departAt: empty zone cancels the countdown", function()
		t.eq(RoundFlow.departAt(10, 20, 0, 3, R.GarageCountdown, R.AllAboardCountdown), nil)
		t.eq(RoundFlow.departAt(10, nil, 0, 0, R.GarageCountdown, R.AllAboardCountdown), nil)
	end)

	t.test("departAt: 15 s with some boarders, 3 s solo or everyone aboard", function()
		t.eq(RoundFlow.departAt(100, nil, 1, 3, 15, 3), 115)
		t.eq(RoundFlow.departAt(100, nil, 1, 1, 15, 3), 103) -- solo
		t.eq(RoundFlow.departAt(100, nil, 3, 3, 15, 3), 103) -- everyone
	end)

	t.test("departAt: only ever gets shorter", function()
		-- countdown running (ends at 112), now everyone boards → 3 s from now
		t.eq(RoundFlow.departAt(105, 112, 2, 2, 15, 3), 108)
		-- running at 3 s, someone joins the Garage (not everyone aboard any more): keeps 3 s
		t.eq(RoundFlow.departAt(106, 108, 2, 3, 15, 3), 108)
		-- a running 15 s countdown is not restarted
		t.eq(RoundFlow.departAt(105, 112, 1, 3, 15, 3), 112)
	end)

	t.test("driveDecision: everyone in a van with loot drives at once", function()
		t.eq(RoundFlow.driveDecision(0, 150, nil, 10, 5), "Drive")
	end)

	t.test("driveDecision: free crew outside warns first, second hold within 5 s drives", function()
		t.eq(RoundFlow.driveDecision(1, 500, nil, 10, 5), "Warn")
		t.eq(RoundFlow.driveDecision(1, 500, 10, 14, 5), "Drive")
		t.eq(RoundFlow.driveDecision(1, 500, 10, 15, 5), "Drive")
		t.eq(RoundFlow.driveDecision(1, 500, 10, 15.1, 5), "Warn")
	end)

	t.test("driveDecision: an empty van also asks twice", function()
		t.eq(RoundFlow.driveDecision(0, 0, nil, 3, 5), "Warn")
		t.eq(RoundFlow.driveDecision(0, 0, 3, 5, 5), "Drive")
	end)

	t.test("exitUsable: normal exits always, QuietOnly closes at lockdown", function()
		t.ok(RoundFlow.exitUsable({}, false, 0))
		t.ok(RoundFlow.exitUsable({}, true, 0))
		t.ok(RoundFlow.exitUsable({ quietOnly = true }, false, 0))
		t.ok(not RoundFlow.exitUsable({ quietOnly = true }, true, 0))
	end)

	t.test("exitUsable: LockdownOnly opens at lockdown once it arrived", function()
		t.ok(not RoundFlow.exitUsable({ lockdownOnly = true }, false, 0))
		t.ok(RoundFlow.exitUsable({ lockdownOnly = true }, true, 0))
		t.ok(not RoundFlow.exitUsable({ lockdownOnly = true, arrivesAt = 120 }, true, 119))
		t.ok(RoundFlow.exitUsable({ lockdownOnly = true, arrivesAt = 120 }, true, 120))
	end)

	t.test("policeOutcome", function()
		t.eq(RoundFlow.policeOutcome(0), "Busted")
		t.eq(RoundFlow.policeOutcome(1), "Escaped")
	end)

	t.test("payoutDone: all ready skips after the minimum, else the full time", function()
		t.ok(not RoundFlow.payoutDone(3, 2, 2, R.PayoutMinSeconds, R.PayoutSeconds))
		t.ok(RoundFlow.payoutDone(8, 2, 2, R.PayoutMinSeconds, R.PayoutSeconds))
		t.ok(not RoundFlow.payoutDone(20, 1, 2, R.PayoutMinSeconds, R.PayoutSeconds))
		t.ok(RoundFlow.payoutDone(30, 0, 2, R.PayoutMinSeconds, R.PayoutSeconds))
		t.ok(not RoundFlow.payoutDone(10, 0, 0, R.PayoutMinSeconds, R.PayoutSeconds))
	end)

	t.test("nextJobDone: everyone answered or time up", function()
		t.ok(not RoundFlow.nextJobDone(2, 1, 2, R.NextJobSeconds))
		t.ok(RoundFlow.nextJobDone(2, 2, 2, R.NextJobSeconds))
		t.ok(RoundFlow.nextJobDone(10, 0, 2, R.NextJobSeconds))
	end)

	t.test("lockdownReason maps raw reasons to the message values", function()
		t.eq(RoundFlow.lockdownReason("main"), "MainLoot")
		t.eq(RoundFlow.lockdownReason("MainLoot"), "MainLoot")
		t.eq(RoundFlow.lockdownReason("alarm"), "Alarm")
		t.eq(RoundFlow.lockdownReason("Alarm"), "Alarm")
		t.eq(RoundFlow.lockdownReason("dev"), "Dev")
		t.eq(RoundFlow.lockdownReason(nil), "Dev")
	end)

	t.test("sanitizeJob: unknown values fall back", function()
		local heists = { GoldenWheel = true, PralinePalace = true }
		local tiers = Config.DifficultyTiers.Tiers
		local mods = Config.Modifiers
		local job = RoundFlow.sanitizeJob(
			{ heistId = "Nope", difficulty = "Insane", modifierId = "Lasers", isHotJob = 1 },
			heists,
			tiers,
			mods,
			"GoldenWheel",
			"Normal"
		)
		t.eq(job.heistId, "GoldenWheel")
		t.eq(job.difficulty, "Normal")
		t.eq(job.modifierId, nil)
		t.eq(job.isHotJob, false)
		t.eq(job.cardId, "GoldenWheel")
		local ok = RoundFlow.sanitizeJob(
			{
				cardId = "HotJob",
				heistId = "PralinePalace",
				difficulty = "Hard",
				modifierId = "RushJob",
				isHotJob = true,
			},
			heists,
			tiers,
			mods,
			"GoldenWheel",
			"Normal"
		)
		t.eq(ok.heistId, "PralinePalace")
		t.eq(ok.difficulty, "Hard")
		t.eq(ok.modifierId, "RushJob")
		t.eq(ok.isHotJob, true)
		t.eq(ok.cardId, "HotJob")
		t.eq(RoundFlow.sanitizeJob(nil, heists, tiers, mods, "GoldenWheel", "Normal").heistId, "GoldenWheel")
	end)

	t.test("roundSeconds: heist value, default, Rush Job", function()
		t.eq(RoundFlow.roundSeconds(480, nil, nil, 360), 480)
		t.eq(RoundFlow.roundSeconds(480, 420, nil, 360), 420)
		t.eq(RoundFlow.roundSeconds(480, 420, "RushJob", 360), 360)
		t.eq(RoundFlow.roundSeconds(480, nil, "PowerCut", 360), 480)
	end)

	t.test("ringOffsets: first at the centre, the rest on the ring", function()
		local list = RoundFlow.ringOffsets(4, 3)
		t.eq(#list, 4)
		t.eq(list[1].x, 0)
		t.eq(list[1].z, 0)
		for i = 2, 4 do
			t.near(math.sqrt(list[i].x ^ 2 + list[i].z ^ 2), 3, 1e-9)
		end
	end)
end
