--!nocheck
local Shop = require("../../src/shared/Logic/Shop")
local Collection = require("../../src/shared/Logic/Collection")
local Ledger = require("../../src/shared/Logic/Ledger")
local Catalog = require("../../src/shared/Catalog")
local MetaConfig = require("../../src/shared/MetaConfig")

local SLOTS = MetaConfig.Progression.SlotRank
local ITEMS = Catalog.ById
local AVAILABLE = { Drone = true, Noisemaker = true, EMP = true, BubbleBlaster = true }

local function who(rank, owned)
	return { owned = owned or {}, robuxOwned = {}, rank = rank }
end

return function(t)
	t.test("free items are owned once the rank is reached", function()
		t.eq(Shop.owns(ITEMS.PaperBag, who(1)), true)
		t.eq(Shop.owns(ITEMS.FlatCap, who(1)), false)
		t.eq(Shop.owns(ITEMS.FlatCap, who(2)), true)
		t.eq(Shop.owns(ITEMS.GoudaGold, who(14)), false)
		t.eq(Shop.owns(ITEMS.GoudaGold, who(15)), true)
		t.eq(Shop.owns(ITEMS.TulipMask, who(1, { TulipMask = 5 })), true)
		t.eq(Shop.owns(ITEMS.TulipMask, { owned = {}, robuxOwned = { TulipMask = 1 }, rank = 1 }), true)
	end)

	t.test("buy: every refusal reason", function()
		t.eq(select(2, Shop.canBuy(nil, who(1), 9999, SLOTS)), "Unknown")
		t.eq(select(2, Shop.canBuy(ITEMS.BoefSnout, who(1), 9999, SLOTS)), "NotForSale")
		t.eq(select(2, Shop.canBuy(ITEMS.TulipMask, who(1, { TulipMask = 1 }), 9999, SLOTS)), "Owned")
		t.eq(select(2, Shop.canBuy(ITEMS.GoldenGoudaMask, who(6), 9999, SLOTS)), "Locked")
		t.eq(select(2, Shop.canBuy(ITEMS.RedBeanie, who(1), 9999, SLOTS)), "Locked")
		t.eq(select(2, Shop.canBuy(ITEMS.CanalBlue, who(3), 9999, SLOTS)), "Locked")
		t.eq(select(2, Shop.canBuy(ITEMS.TulipMask, who(1), 1499, SLOTS)), "NotEnoughCash")
		t.eq((Shop.canBuy(ITEMS.TulipMask, who(1), 1500, SLOTS)), true)
		t.eq((Shop.canBuy(ITEMS.CanalBlue, who(4), 5000, SLOTS)), true)
		t.eq((Shop.canBuy(ITEMS.Periscope, who(2), 2000, SLOTS)), true)
	end)

	t.test("equip: owned only, slot open; the worn hat comes off, masks and vans swap", function()
		t.eq(select(2, Shop.canEquip(ITEMS.TulipMask, who(1), SLOTS)), "NotOwned")
		t.eq(select(2, Shop.canEquip(ITEMS.FlatCap, who(1), SLOTS)), "Locked")
		t.eq(select(2, Shop.canEquip(ITEMS.Drone, who(1), SLOTS)), "Unknown")
		t.eq((Shop.canEquip(ITEMS.FlatCap, who(2), SLOTS)), true)
		local equipped = { Mask = "PaperBag", Van = "GetawayWhite" }
		t.eq(Shop.equip(equipped, ITEMS.FlatCap), "FlatCap")
		t.eq(equipped.Hat, "FlatCap")
		t.eq(Shop.equip(equipped, ITEMS.FlatCap), nil)
		t.eq(equipped.Hat, nil)
		Shop.equip(equipped, ITEMS.TulipMask)
		Shop.equip(equipped, ITEMS.TulipMask)
		t.eq(equipped.Mask, "TulipMask")
	end)

	t.test("loadout: two distinct owned gadgets, never the Crowbar", function()
		local ok, _, clean = Shop.validateLoadout({ "Drone", "EMP" }, ITEMS, who(1), AVAILABLE, 2)
		t.eq(ok, true)
		t.eq(clean[1], "Drone")
		t.eq(select(2, Shop.validateLoadout({ "Drone", "Drone" }, ITEMS, who(1), AVAILABLE, 2)), "Duplicate")
		t.eq(select(2, Shop.validateLoadout({ "Crowbar", "EMP" }, ITEMS, who(1), AVAILABLE, 2)), "Unknown")
		t.eq(select(2, Shop.validateLoadout({ "TulipMask", "EMP" }, ITEMS, who(1), AVAILABLE, 2)), "Unknown")
		t.eq(select(2, Shop.validateLoadout({ "EMP" }, ITEMS, who(1), AVAILABLE, 2)), "Invalid")
		t.eq(
			select(2, Shop.validateLoadout({ "EMP", "Drone", "Noisemaker" }, ITEMS, who(1), AVAILABLE, 2)),
			"TooMany"
		)
		t.eq(select(2, Shop.validateLoadout("EMP", ITEMS, who(1), AVAILABLE, 2)), "Invalid")
		t.eq(
			select(2, Shop.validateLoadout({ a = "EMP", b = "Drone" }, ITEMS, who(1), AVAILABLE, 2)),
			"Invalid"
		)
		t.eq(select(2, Shop.validateLoadout({ 5, "Drone" }, ITEMS, who(1), AVAILABLE, 2)), "Unknown")
	end)

	t.test("loadout: sidegrades need to exist in this build and be owned", function()
		local withPeriscope = table.clone(AVAILABLE)
		t.eq(select(2, Shop.validateLoadout({ "Periscope", "EMP" }, ITEMS, who(5), AVAILABLE, 2)), "Unknown")
		withPeriscope.Periscope = true
		t.eq(
			select(2, Shop.validateLoadout({ "Periscope", "EMP" }, ITEMS, who(5), withPeriscope, 2)),
			"NotOwned"
		)
		t.eq(
			(Shop.validateLoadout({ "Periscope", "EMP" }, ITEMS, who(5, { Periscope = 1 }), withPeriscope, 2)),
			true
		)
	end)

	t.test("sanitizeLoadout falls back to the default", function()
		local clean =
			Shop.sanitizeLoadout({ "Drone", "Gone" }, ITEMS, who(1), AVAILABLE, Catalog.DefaultLoadout)
		t.eq(clean[1], "Noisemaker")
		t.eq(clean[2], "BubbleBlaster")
		local kept =
			Shop.sanitizeLoadout({ "Drone", "EMP" }, ITEMS, who(1), AVAILABLE, Catalog.DefaultLoadout)
		t.eq(kept[1], "Drone")
	end)

	t.test("collection counts banked loot and finds new entries", function()
		local tracked = Collection.tracked(MetaConfig.Collection.Pages)
		t.eq(tracked.Keycard, nil)
		local col = {}
		local new = Collection.record(col, {
			{ lootId = "CheeseCube" },
			{ lootId = "CheeseCube" },
			{ lootId = "Keycard" },
			{ lootId = "GoldenGouda" },
		}, tracked)
		t.eq(#new, 2)
		t.eq(col.CheeseCube, 2)
		t.eq(col.Keycard, nil)
		t.eq(#Collection.record(col, { { lootId = "CheeseCube" } }, tracked), 0)
	end)

	t.test("a full page is rewarded once; empty pages never complete", function()
		local pages = MetaConfig.Collection.Pages
		local col = {}
		for _, id in pages.GoldenWheel do
			col[id] = 1
		end
		local list = Collection.newPages(col, pages, {})
		t.eq(#list, 1)
		t.eq(list[1], "GoldenWheel")
		t.eq(#Collection.newPages(col, pages, { GoldenWheel = 1 }), 0)
		t.eq(Collection.pageComplete(col, {}), false)
		col.BlueMoon = nil
		t.eq(#Collection.newPages(col, pages, {}), 0)
	end)

	t.test("trophy log keeps the newest 30", function()
		local trophies = {}
		for i = 1, 35 do
			Collection.pushTrophy(
				trophies,
				{ loot = "GoldenGouda", heist = "GoldenWheel", tier = "Normal", crew = 1, at = i },
				30
			)
		end
		t.eq(#trophies, 30)
		t.eq(trophies[1].at, 6)
		t.eq(trophies[30].at, 35)
	end)

	t.test("receipt decisions", function()
		local base = {
			playerPresent = true,
			dataLoaded = true,
			alreadyProcessed = false,
			productKnown = true,
			productEnabled = true,
		}
		t.eq(Ledger.decideReceipt(base), "Grant")
		local function with(k, v)
			local s = table.clone(base)
			s[k] = v
			return Ledger.decideReceipt(s)
		end
		t.eq(with("playerPresent", false), "NotProcessedYet")
		t.eq(with("dataLoaded", false), "NotProcessedYet")
		t.eq(with("alreadyProcessed", true), "AlreadyGranted")
		t.eq(with("productKnown", false), "NotProcessedYet")
		t.eq(with("productEnabled", false), "NotProcessedYet")
	end)

	t.test("receipt history keeps the newest entries", function()
		local receipts = {}
		for i = 1, 105 do
			Ledger.recordReceipt(receipts, "p" .. i, i, 100)
		end
		local count = 0
		for _ in receipts do
			count += 1
		end
		t.eq(count, 100)
		t.eq(receipts.p1, nil)
		t.eq(receipts.p5, nil)
		t.eq(receipts.p6, 6)
		t.eq(receipts.p105, 105)
	end)

	t.test("bounded recent lists", function()
		local list = {}
		for i = 1, 12 do
			Ledger.push(list, "r" .. i, 10)
		end
		t.eq(#list, 10)
		t.eq(list[1], "r3")
		t.eq(Ledger.contains(list, "r12"), true)
		t.eq(Ledger.contains(list, "r1"), false)
	end)
end
