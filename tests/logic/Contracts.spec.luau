--!nocheck
local Contracts = require("../../src/shared/Logic/Contracts")
local Rng = require("../../src/shared/Logic/Rng")
local MetaConfig = require("../../src/shared/MetaConfig")

local C = MetaConfig.Contracts
local ALL = { heistsUnlocked = { GoldenWheel = true }, hardUnlocked = true }
local NONE = { heistsUnlocked = {}, hardUnlocked = false }

local function gen(seed, ctx)
	return Contracts.generate(C.Templates, ctx or ALL, C.Rewards, C.MaxNeedsCrew, Rng.new(seed))
end

local function facts(overrides)
	local base = {
		outcome = "Escaped",
		escaped = true,
		isHotJob = false,
		difficulty = "Normal",
		stars = 1,
		mainLootBanked = false,
		maxAlarmTier = 2,
		stats = {},
	}
	for k, v in overrides or {} do
		base[k] = v
	end
	return base
end

return function(t)
	t.test("three contracts: one Easy, one Medium, one Hard with tier rewards", function()
		local list = gen(1)
		t.eq(#list, 3)
		t.eq(list[1].tier, "Easy")
		t.eq(list[2].tier, "Medium")
		t.eq(list[3].tier, "Hard")
		t.eq(list[1].reward, 250)
		t.eq(list[2].reward, 350)
		t.eq(list[3].reward, 500)
		t.eq(list[1].progress, 0)
		t.eq(list[1].done, false)
	end)

	t.test("same player and day → same contracts (every server)", function()
		local seed = Contracts.seedFor(123456789, 20377)
		local a, b = gen(seed), gen(seed)
		for i = 1, 3 do
			t.eq(a[i].id, b[i].id)
		end
		t.eq(Contracts.seedFor(1, 2), 33)
	end)

	t.test("never more than one NeedsCrew, never duplicates, requirements respected", function()
		local byId = Contracts.byId(C.Templates)
		for seed = 1, 300 do
			local list = gen(seed, NONE)
			local crew, seen = 0, {}
			for _, c in list do
				local template = byId[c.id]
				if template.NeedsCrew then
					crew += 1
				end
				t.ok(not seen[c.id], "duplicate " .. c.id)
				seen[c.id] = true
				t.ok(c.id ~= "DistractBoef", "needs Golden Wheel unlocked")
				t.ok(c.id ~= "HardJob", "needs Hard unlocked")
			end
			t.ok(crew <= 1, "seed " .. seed)
			t.eq(#list, 3)
		end
	end)

	t.test("counters from crew stats and round facts", function()
		local byId = Contracts.byId(C.Templates)
		t.eq(Contracts.amountFor(byId.BankItems, facts({ stats = { lootBanked = 3 } }), 1), 3)
		t.eq(Contracts.amountFor(byId.BankItems, facts({ stats = {} }), 1), 0)
		t.eq(Contracts.amountFor(byId.FinishJobs, facts({ outcome = "Busted", escaped = false }), 1), 1)
		t.eq(Contracts.amountFor(byId.FinishJobs, facts({ outcome = "Aborted" }), 1), 0)
		t.eq(Contracts.amountFor(byId.FinishJobs, facts({ outcome = "Shutdown" }), 1), 0)
		t.eq(Contracts.amountFor(byId.TwoStars, facts({ stars = 2 }), 1), 1)
		t.eq(Contracts.amountFor(byId.TwoStars, facts({ stars = 1 }), 1), 0)
		t.eq(Contracts.amountFor(byId.HotJob, facts({ isHotJob = true }), 1), 1)
		t.eq(Contracts.amountFor(byId.HotJob, facts({ isHotJob = true, escaped = false }), 1), 0)
		t.eq(Contracts.amountFor(byId.StealGouda, facts({ mainLootBanked = true }), 1), 1)
		t.eq(Contracts.amountFor(byId.QuietJob, facts({ maxAlarmTier = 1 }), 1), 1)
		t.eq(Contracts.amountFor(byId.QuietJob, facts({ maxAlarmTier = 2 }), 1), 0)
		t.eq(Contracts.amountFor(byId.HardJob, facts({ difficulty = "Hard" }), 1), 1)
		t.eq(Contracts.amountFor(byId.BubbleGuards, facts({ stats = { bubbledGuards = 0 / 0 } }), 1), 0)
	end)

	t.test("apply caps progress and completes each contract once", function()
		local byId = Contracts.byId(C.Templates)
		local list = {
			{ id = "BankItems", tier = "Easy", target = 5, progress = 3, reward = 250, done = false },
			{ id = "TwoStars", tier = "Medium", target = 1, progress = 0, reward = 350, done = false },
		}
		local done = Contracts.apply(list, byId, facts({ stats = { lootBanked = 4 }, stars = 1 }), 1)
		t.eq(#done, 1)
		t.eq(done[1].id, "BankItems")
		t.eq(list[1].progress, 5)
		t.eq(list[1].done, true)
		t.eq(list[2].progress, 0)
		local again = Contracts.apply(list, byId, facts({ stats = { lootBanked = 4 } }), 1)
		t.eq(#again, 0)
	end)

	t.test("reroll swaps for another contract of the same tier", function()
		local list = gen(7)
		local before = list[2].id
		local ok = Contracts.reroll(list, 2, C.Templates, ALL, C.Rewards, C.MaxNeedsCrew, Rng.new(99))
		t.eq(ok, true)
		t.eq(list[2].tier, "Medium")
		t.ok(list[2].id ~= before)
		t.ok(list[2].id ~= list[1].id and list[2].id ~= list[3].id)
	end)

	t.test("reroll refuses finished contracts and bad indices", function()
		local list = gen(7)
		list[1].done = true
		t.eq(select(2, Contracts.reroll(list, 1, C.Templates, ALL, C.Rewards, 1, Rng.new(1))), "Done")
		t.eq(select(2, Contracts.reroll(list, 4, C.Templates, ALL, C.Rewards, 1, Rng.new(1))), "Invalid")
	end)
end
