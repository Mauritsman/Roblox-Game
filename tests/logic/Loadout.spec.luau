--!nocheck
local Loadout = require("../../src/shared/Logic/Loadout")
local Perks = require("../../src/shared/Logic/Perks")
local Config = require("../../src/shared/Config")

local PICKABLE = Config.Loadout.Pickable
local SLOTS = Config.Loadout.Slots
local DEFAULT = Config.Loadout.Default

return function(t)
	t.test("meta's loadout: the Crowbar is skipped, order kept", function()
		local picks = Loadout.picks({ "Crowbar", "EMP", "Drone" }, PICKABLE, SLOTS, DEFAULT)
		t.eq(#picks, 2)
		t.eq(picks[1], "EMP")
		t.eq(picks[2], "Drone")
	end)

	t.test("junk, duplicates and unknown names are dropped and filled from the default", function()
		local picks = Loadout.picks({ "EMP", "EMP", "Laser", 42 }, PICKABLE, SLOTS, DEFAULT)
		t.eq(#picks, 2)
		t.eq(picks[1], "EMP")
		t.eq(picks[2], DEFAULT[1])
		local none = Loadout.picks(nil, PICKABLE, SLOTS, DEFAULT)
		t.eq(none[1], DEFAULT[1])
		t.eq(none[2], DEFAULT[2])
	end)

	t.test("never more than the slots", function()
		local picks =
			Loadout.picks({ "Drone", "Noisemaker", "EMP", "BubbleBlaster" }, PICKABLE, SLOTS, DEFAULT)
		t.eq(#picks, SLOTS)
	end)

	t.test("charges from Config, Spare Batteries on the first pick only", function()
		local defaults = Perks.defaultsFrom(Config)
		local charges = Loadout.charges({ "Noisemaker", "BubbleBlaster" }, Config.Gadgets, defaults)
		t.eq(charges.Noisemaker, Config.Gadgets.Noisemaker.Charges)
		t.eq(charges.BubbleBlaster, Config.Gadgets.BubbleBlaster.Charges)
		local spare = Perks.apply(defaults, { SpareBatteries = 1 }, Config.Perks)
		local boosted = Loadout.charges({ "EMP", "Drone" }, Config.Gadgets, spare)
		t.eq(boosted.EMP, Config.Gadgets.EMP.Charges + 1)
		t.eq(boosted.Drone, Config.Gadgets.Drone.Charges)
	end)

	t.test("Panic Pack adds to every pick and leaves the input alone", function()
		local charges = { EMP = 0, Noisemaker = 2 }
		local after = Loadout.panic(charges, { "EMP", "Noisemaker" }, Config.Objectives.PanicPackCharges)
		t.eq(after.EMP, 1)
		t.eq(after.Noisemaker, 3)
		t.eq(charges.EMP, 0)
	end)

	t.test("Gadgets attribute lists the picks first, the Crowbar last", function()
		t.eq(Loadout.list({ "EMP", "Drone" }, "Crowbar"), "EMP,Drone,Crowbar")
		t.eq(Loadout.list({}, nil), "")
	end)

	t.test("stats: tier self-escapes, then perks", function()
		local defaults = Perks.defaultsFrom(Config)
		local easy = Config.DifficultyTiers.Tiers.Easy
		local stats = Loadout.stats(defaults, easy, { SoftShoes = 1 }, Config.Perks, true)
		t.eq(stats.SelfEscapes, easy.SelfEscapes)
		t.eq(stats.Crouch, 9)
		local noPerks = Loadout.stats(defaults, nil, { SoftShoes = 1 }, Config.Perks, false)
		t.eq(noPerks.Crouch, Config.Movement.Crouch)
		t.eq(noPerks.SelfEscapes, Config.Capture.SelfEscapes)
		t.eq(defaults.Crouch, Config.Movement.Crouch, "defaults unchanged")
	end)

	t.test("one player-facing name per gadget (B-004)", function()
		t.eq(Loadout.label("BubbleBlaster", Config.Gadgets), "BUBBLE BLASTER")
		t.eq(Loadout.label("BubbleBlaster", nil), "BUBBLE BLASTER")
		t.eq(Loadout.label("Noisemaker", Config.Gadgets), "NOISEMAKER")
		t.eq(Loadout.label("EMP", Config.Gadgets), "EMP")
		t.eq(Loadout.label("Crowbar", Config.Gadgets), "CROWBAR")
	end)
end
