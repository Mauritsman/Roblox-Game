--!nocheck
local PerkTree = require("../../src/shared/Logic/PerkTree")
local MetaConfig = require("../../src/shared/MetaConfig")

local TREE = MetaConfig.PerkTree

local function fresh()
	return { unlocked = {}, equipped = {}, respecs = 0 }
end

return function(t)
	t.test("find and cost per row", function()
		local branch, row = PerkTree.find(TREE, "BarrelLungs")
		t.eq(branch, "Sneak")
		t.eq(row, 2)
		t.eq(PerkTree.cost(TREE, "SoftShoes"), 1)
		t.eq(PerkTree.cost(TREE, "DeepPockets"), 2)
		t.eq(PerkTree.cost(TREE, "SpareBatteries"), 3)
		t.eq(PerkTree.cost(TREE, "Nope"), 0)
	end)

	t.test("a row needs the row above in the same branch", function()
		local perks = fresh()
		local ok, reason = PerkTree.unlock(TREE, perks, "BarrelLungs", 10)
		t.eq(ok, false)
		t.eq(reason, "Locked")
		t.ok((PerkTree.unlock(TREE, perks, "SoftShoes", 10)))
		t.ok((PerkTree.unlock(TREE, perks, "BarrelLungs", 10)))
		local ok2, reason2 = PerkTree.unlock(TREE, perks, "DeepPockets", 10)
		t.eq(ok2, false)
		t.eq(reason2, "Locked")
	end)

	t.test("points are checked and derived from unlocked perks", function()
		local perks = fresh()
		t.eq(select(2, PerkTree.unlock(TREE, perks, "SoftShoes", 0)), "NoPoints")
		t.ok((PerkTree.unlock(TREE, perks, "SoftShoes", 2)))
		t.eq(PerkTree.available(TREE, perks.unlocked, 2), 1)
		t.eq(select(2, PerkTree.unlock(TREE, perks, "BarrelLungs", 2)), "NoPoints")
		t.eq(select(2, PerkTree.unlock(TREE, perks, "SoftShoes", 10)), "Owned")
		t.eq(select(2, PerkTree.unlock(TREE, perks, "Laser", 10)), "Unknown")
	end)

	t.test("owning everything costs 18 points", function()
		local perks = fresh()
		for _, branch in TREE.BranchOrder do
			for _, id in TREE.Branches[branch] do
				t.ok((PerkTree.unlock(TREE, perks, id, 18)), id)
			end
		end
		t.eq(PerkTree.spent(TREE, perks.unlocked), 18)
		t.eq(PerkTree.available(TREE, perks.unlocked, 18), 0)
	end)

	t.test("equip: max 3, unlocked only, no duplicates", function()
		local perks = fresh()
		for _, id in { "SoftShoes", "LongArm", "QuickHands", "BarrelLungs" } do
			PerkTree.unlock(TREE, perks, id, 10)
		end
		local ok, _, clean = PerkTree.validateEquip(TREE, perks, { "SoftShoes", "LongArm", "QuickHands" })
		t.eq(ok, true)
		t.eq(#clean, 3)
		t.eq(
			select(
				2,
				PerkTree.validateEquip(TREE, perks, { "SoftShoes", "LongArm", "QuickHands", "BarrelLungs" })
			),
			"TooMany"
		)
		t.eq(select(2, PerkTree.validateEquip(TREE, perks, { "StrongBack" })), "NotOwned")
		t.eq(select(2, PerkTree.validateEquip(TREE, perks, { "SoftShoes", "SoftShoes" })), "Duplicate")
		t.eq(select(2, PerkTree.validateEquip(TREE, perks, { "Laser" })), "Unknown")
		t.eq(select(2, PerkTree.validateEquip(TREE, perks, "SoftShoes")), "Invalid")
		t.eq(select(2, PerkTree.validateEquip(TREE, perks, { a = "SoftShoes" })), "Invalid")
		t.eq((PerkTree.validateEquip(TREE, perks, {})), true)
	end)

	t.test("respec refunds every point and empties the slots", function()
		local perks = fresh()
		PerkTree.unlock(TREE, perks, "SoftShoes", 10)
		PerkTree.unlock(TREE, perks, "BarrelLungs", 10)
		perks.equipped = { "SoftShoes" }
		t.eq(PerkTree.respec(TREE, perks), 3)
		t.eq(next(perks.unlocked), nil)
		t.eq(#perks.equipped, 0)
		t.eq(perks.respecs, 1)
		t.eq(PerkTree.available(TREE, perks.unlocked, 10), 10)
	end)

	t.test("repair drops unknown perks and over-spent trees", function()
		local perks = {
			unlocked = { SoftShoes = true, OldPerk = true },
			equipped = { "OldPerk", "SoftShoes" },
			respecs = 0,
		}
		t.eq(PerkTree.repair(TREE, perks, 5), true)
		t.eq(perks.unlocked.OldPerk, nil)
		t.eq(#perks.equipped, 1)
		local over =
			{ unlocked = { SoftShoes = true, BarrelLungs = true }, equipped = { "SoftShoes" }, respecs = 0 }
		t.eq(PerkTree.repair(TREE, over, 1), true)
		t.eq(next(over.unlocked), nil)
		local fine = { unlocked = { SoftShoes = true }, equipped = { "SoftShoes" }, respecs = 0 }
		t.eq(PerkTree.repair(TREE, fine, 1), false)
	end)

	t.test("equippedSet gives {perkId = 1} for mechanics", function()
		local perks = { unlocked = { SoftShoes = true }, equipped = { "SoftShoes", "LongArm" }, respecs = 0 }
		local set = PerkTree.equippedSet(perks)
		t.eq(set.SoftShoes, 1)
		t.eq(set.LongArm, nil)
	end)
end
