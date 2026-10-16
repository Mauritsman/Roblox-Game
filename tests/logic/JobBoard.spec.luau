--!nocheck
local JobBoard = require("../../src/shared/Logic/JobBoard")
local HotJob = require("../../src/shared/Logic/HotJob")
local Rng = require("../../src/shared/Logic/Rng")
local MetaConfig = require("../../src/shared/MetaConfig")

local TIERS = { "Easy", "Normal", "Hard" }
local ORDER = MetaConfig.Heists.Order

local function cards(hardOn)
	return {
		GoldenWheel = { open = true, tiers = { Easy = true, Normal = true, Hard = hardOn or false } },
		PralinePalace = { open = true, tiers = { Easy = true, Normal = true, Hard = false } },
		TulipAuction = { open = false, tiers = { Easy = true, Normal = true, Hard = false } },
	}
end

return function(t)
	t.test("union: open when anyone has it, unlockedBy the first who does", function()
		local members = {
			{
				name = "Ann",
				heists = { GoldenWheel = { open = true, tiers = { Easy = true, Normal = true } } },
			},
			{
				name = "Sam",
				heists = {
					GoldenWheel = { open = true, tiers = { Easy = true, Normal = true, Hard = true } },
					PralinePalace = { open = true, tiers = { Easy = true, Normal = true } },
				},
			},
		}
		local u = JobBoard.union(members, ORDER, TIERS)
		t.eq(u.GoldenWheel.open, true)
		t.eq(u.GoldenWheel.unlockedBy, "Ann")
		t.eq(u.GoldenWheel.tiers.Hard, true)
		t.eq(u.PralinePalace.open, true)
		t.eq(u.PralinePalace.unlockedBy, "Sam")
		t.eq(u.PralinePalace.tiers.Hard, false)
		t.eq(u.TulipAuction.open, false)
	end)

	t.test("most votes among the boarders wins", function()
		local votes = {
			[1] = { cardId = "GoldenWheel", difficulty = "Normal", at = 1 },
			[2] = { cardId = "PralinePalace", difficulty = "Normal", at = 2 },
			[3] = { cardId = "PralinePalace", difficulty = "Normal", at = 3 },
		}
		local s = JobBoard.tally(votes, { 1, 2, 3 }, cards(), TIERS, "GoldenWheel", "Normal")
		t.eq(s.cardId, "PralinePalace")
		t.eq(s.votes, 2)
		t.eq(s.fromDefault, false)
		-- voter 3 did not board → tie → earliest vote wins
		local s2 = JobBoard.tally(votes, { 1, 2 }, cards(), TIERS, "GoldenWheel", "Normal")
		t.eq(s2.cardId, "GoldenWheel")
	end)

	t.test("no votes → default card on Normal", function()
		local s = JobBoard.tally({}, { 1 }, cards(), TIERS, "GoldenWheel", "Normal")
		t.eq(s.cardId, "GoldenWheel")
		t.eq(s.difficulty, "Normal")
		t.eq(s.fromDefault, true)
	end)

	t.test("votes on closed or unknown cards do not count", function()
		local votes = {
			[1] = { cardId = "TulipAuction", difficulty = "Normal", at = 1 },
			[2] = { cardId = "Moon", difficulty = "Normal", at = 2 },
		}
		local s = JobBoard.tally(votes, { 1, 2 }, cards(), TIERS, "GoldenWheel", "Normal")
		t.eq(s.cardId, "GoldenWheel")
		t.eq(s.fromDefault, true)
	end)

	t.test("the crew plays the lowest tier any voter of the winning card chose", function()
		local votes = {
			[1] = { cardId = "GoldenWheel", difficulty = "Hard", at = 1 },
			[2] = { cardId = "GoldenWheel", difficulty = "Easy", at = 2 },
		}
		local s = JobBoard.tally(votes, { 1, 2 }, cards(true), TIERS, "GoldenWheel", "Normal")
		t.eq(s.difficulty, "Easy")
		local s2 = JobBoard.tally({ [1] = votes[1] }, { 1 }, cards(true), TIERS, "GoldenWheel", "Normal")
		t.eq(s2.difficulty, "Hard")
	end)

	t.test("a tier the boarders do not have steps down", function()
		local votes = { [1] = { cardId = "GoldenWheel", difficulty = "Hard", at = 1 } }
		local s = JobBoard.tally(votes, { 1 }, cards(false), TIERS, "GoldenWheel", "Normal")
		t.eq(s.difficulty, "Normal")
		t.eq(JobBoard.clampTier("Hard", { Easy = true }, TIERS, "Normal"), "Easy")
		t.eq(JobBoard.clampTier("Easy", { Normal = true }, TIERS, "Normal"), "Normal")
		t.eq(JobBoard.clampTier("Weird", { Easy = true, Normal = true }, TIERS, "Normal"), "Normal")
		t.eq(JobBoard.clampTier("Hard", {}, TIERS, "Normal"), "Normal")
	end)

	t.test("Hot Job: same slot → same job", function()
		local open = { GoldenWheel = true, PralinePalace = true, TulipAuction = true }
		for slot = 1, 50 do
			local a = HotJob.pick(Rng.new(HotJob.seedFor(slot)), ORDER, open, MetaConfig.HotJob.Modifiers)
			local b = HotJob.pick(Rng.new(HotJob.seedFor(slot)), ORDER, open, MetaConfig.HotJob.Modifiers)
			t.eq(a.heistId, b.heistId)
			t.eq(a.modifierId, b.modifierId)
		end
	end)

	t.test("Hot Job: never a locked heist, never Sleepy Guards, modifier independent of unlocks", function()
		local onlyOne = { GoldenWheel = true }
		local all = { GoldenWheel = true, PralinePalace = true, TulipAuction = true }
		local seenHeists = {}
		for slot = 1, 200 do
			local a = HotJob.pick(Rng.new(HotJob.seedFor(slot)), ORDER, onlyOne, MetaConfig.HotJob.Modifiers)
			local b = HotJob.pick(Rng.new(HotJob.seedFor(slot)), ORDER, all, MetaConfig.HotJob.Modifiers)
			t.eq(a.heistId, "GoldenWheel")
			t.ok(a.modifierId ~= "SleepyGuards")
			t.eq(a.modifierId, b.modifierId)
			seenHeists[b.heistId] = true
		end
		t.ok(seenHeists.PralinePalace and seenHeists.TulipAuction, "rotation reaches every heist")
		t.eq(HotJob.pick(Rng.new(1), ORDER, {}, MetaConfig.HotJob.Modifiers).heistId, nil)
	end)
end
