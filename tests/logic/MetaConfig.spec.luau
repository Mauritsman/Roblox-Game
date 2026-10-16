--!nocheck
-- Consistency of MetaConfig and Catalog: ids unique, every reward exists, prices in the brief's ranges.
local MetaConfig = require("../../src/shared/MetaConfig")
local Catalog = require("../../src/shared/Catalog")

return function(t)
	t.test("catalog ids are unique and items are well formed", function()
		local seen = {}
		local kinds = { Mask = true, Hat = true, Van = true, Gadget = true }
		for _, item in Catalog.List do
			t.ok(not seen[item.Id], "duplicate " .. item.Id)
			seen[item.Id] = true
			t.ok(kinds[item.Kind], item.Id .. " kind")
			t.ok(type(item.Name) == "string" and #item.Name > 0, item.Id .. " name")
			t.ok(item.MinRank >= 1 and item.MinRank <= MetaConfig.Progression.MaxRank, item.Id .. " rank")
			t.ok(#item.Id <= MetaConfig.RateLimit.MaxStringLength, item.Id .. " id length")
			if item.Kind == "Mask" or item.Kind == "Hat" then
				t.ok(item.Fallback ~= nil, item.Id .. " needs a fallback look")
			end
			if item.Kind == "Van" then
				t.ok(item.Color ~= nil and #item.Color == 3, item.Id .. " colour")
			end
			if item.Source == "Shop" then
				t.ok(item.Price ~= nil, item.Id .. " shop item without a price")
			else
				t.eq(item.Price, nil, item.Id .. " only shop items have a price")
			end
		end
		t.eq(Catalog.get("Crowbar"), nil)
	end)

	t.test("prices are within the brief's ranges", function()
		for _, item in Catalog.List do
			if item.Price then
				if item.Kind == "Mask" or item.Kind == "Hat" then
					t.ok(item.Price >= 500 and item.Price <= 3000, item.Id)
				elseif item.Kind == "Van" then
					t.eq(item.Price, 5000, item.Id)
				elseif item.Kind == "Gadget" then
					t.ok(item.Price >= 2000 and item.Price <= 4000, item.Id)
				end
			end
		end
	end)

	t.test("28 cosmetics, 16 of them masks", function()
		local cosmetics, masks = 0, 0
		for _, item in Catalog.List do
			if item.Kind ~= "Gadget" then
				cosmetics += 1
			end
			if item.Kind == "Mask" then
				masks += 1
			end
		end
		t.eq(cosmetics, 28)
		t.eq(masks, 16)
	end)

	t.test("every reward and starter id exists in the catalog", function()
		local P = MetaConfig.Progression
		local ids = {}
		for _, id in MetaConfig.MostWanted.RewardPool do
			table.insert(ids, id)
		end
		for _, id in P.MasteryMask do
			table.insert(ids, id)
		end
		for _, id in P.StarMasks do
			table.insert(ids, id)
		end
		for _, id in MetaConfig.Collection.PageReward do
			table.insert(ids, id)
		end
		for _, id in Catalog.DefaultEquipped do
			table.insert(ids, id)
		end
		for _, id in Catalog.DefaultLoadout do
			table.insert(ids, id)
		end
		for _, id in ids do
			t.ok(Catalog.get(id) ~= nil, "missing catalog item " .. id)
		end
		for _, id in Catalog.DefaultLoadout do
			t.eq(Catalog.get(id).Kind, "Gadget")
			t.eq(Catalog.get(id).Free, true)
		end
		t.eq(Catalog.get(Catalog.DefaultEquipped.Mask).Free, true)
	end)

	t.test("heists: names, unlock rules, collection pages, Most Wanted rotation", function()
		for _, heistId in MetaConfig.Heists.Order do
			t.ok(MetaConfig.Heists.Names[heistId] ~= nil, heistId)
			t.ok(MetaConfig.Progression.HeistUnlock[heistId] ~= nil, heistId)
			t.ok(MetaConfig.Collection.Pages[heistId] ~= nil, heistId)
			t.ok(MetaConfig.Progression.MasteryMask[heistId] ~= nil, heistId)
		end
		for _, heistId in MetaConfig.MostWanted.Rotation do
			t.ok(MetaConfig.Heists.Names[heistId] ~= nil, heistId)
		end
		t.eq(#MetaConfig.MostWanted.Rotation, #MetaConfig.MostWanted.RewardPool)
		t.eq(MetaConfig.Progression.HeistUnlock[MetaConfig.Heists.Default].Rank, nil)
	end)

	t.test("difficulty and economy numbers follow the advisor", function()
		local mult = MetaConfig.Economy.DifficultyPayout
		t.eq(mult.Easy, 0.8)
		t.eq(mult.Normal, 1.0)
		t.eq(mult.Hard, 1.4)
		for _, tier in MetaConfig.Difficulty.Order do
			t.ok(mult[tier] ~= nil, tier)
			t.ok(MetaConfig.Difficulty.Labels[tier] ~= nil, tier)
		end
		t.eq(MetaConfig.HotJob.BonusPct, MetaConfig.Economy.HotJobBonus)
		t.eq(MetaConfig.Economy.HotJobBonus, 0.25)
		t.eq(MetaConfig.Progression.MaxRank, 20)
		t.eq(MetaConfig.Progression.Titles[1] ~= nil, true)
	end)

	t.test("Hot Job modifiers exist and exclude Sleepy Guards", function()
		for _, id in MetaConfig.HotJob.Modifiers do
			t.ok(id ~= "SleepyGuards")
			t.ok(MetaConfig.Modifiers.Names[id] ~= nil, id)
		end
	end)

	t.test("perk tree is 3×3 with unique, named perks", function()
		local tree = MetaConfig.PerkTree
		local seen = {}
		t.eq(#tree.BranchOrder, 3)
		for _, branch in tree.BranchOrder do
			t.eq(#tree.Branches[branch], 3, branch)
			for _, id in tree.Branches[branch] do
				t.ok(not seen[id], id)
				seen[id] = true
				t.ok(tree.Names[id] ~= nil, id)
			end
		end
		t.eq(#tree.RowCost, 3)
		t.eq(tree.MaxEquipped, 3)
	end)

	t.test("contracts: unique ids, every tier has solo options", function()
		local seen = {}
		local solo = { Easy = 0, Medium = 0, Hard = 0 }
		for _, template in MetaConfig.Contracts.Templates do
			t.ok(not seen[template.Id], template.Id)
			seen[template.Id] = true
			t.ok(MetaConfig.Contracts.Rewards[template.Tier] ~= nil, template.Id)
			if not template.NeedsCrew and not template.RequiresHeist and not template.NeedsHard then
				solo[template.Tier] += 1
			end
		end
		for tier, count in solo do
			t.ok(count >= 2, tier .. " needs at least 2 solo contracts for rerolls")
		end
	end)

	t.test("analytics steps and settings", function()
		t.eq(#MetaConfig.Analytics.OnboardingSteps, 8)
		t.eq(#MetaConfig.Analytics.RoundSteps, 6)
		for _, target in MetaConfig.Analytics.StepAliases do
			t.ok(table.find(MetaConfig.Analytics.OnboardingSteps, target) ~= nil, target)
		end
		for key, spec in MetaConfig.Data.SettingsKeys do
			t.ok(spec.Kind == "number" or spec.Kind == "boolean", key)
		end
	end)
end
