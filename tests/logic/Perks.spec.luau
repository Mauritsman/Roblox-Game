--!nocheck
local Perks = require("../../src/shared/Logic/Perks")
local Config = require("../../src/shared/Config")

local defaults = Perks.defaultsFrom(Config)
local EFFECTS = Config.Perks

local function with(perks)
	return (Perks.apply(defaults, perks, EFFECTS))
end

return function(t)
	t.test("defaults come from Config", function()
		t.eq(defaults.Walk, 16)
		t.eq(defaults.Crouch, 8)
		t.eq(defaults.HeavySolo, 7)
		t.eq(defaults.PocketSlots, 3)
		t.eq(defaults.ThrowRange, 10)
		t.eq(defaults.WarnAt, 15)
		t.eq(defaults.SneezeAt, 20)
		t.eq(defaults.RescueHold, 2)
		t.eq(defaults.SelfEscapeAfter, 15)
		t.eq(defaults.SelfEscapes, 1)
		t.eq(defaults.CrackRadius, 25)
		t.eq(defaults.FirstGadgetBonus, 0)
	end)

	t.test("Sneak: Soft Shoes, Barrel Lungs, Quiet Crowbar", function()
		t.eq(with({ SoftShoes = 1 }).Crouch, 9)
		local lungs = with({ BarrelLungs = 1 })
		t.eq(lungs.SneezeAt, 25)
		t.eq(lungs.WarnAt, 20)
		t.eq(with({ QuietCrowbar = 1 }).CrackRadius, 18)
	end)

	t.test("Muscle: Long Arm, Deep Pockets, Strong Back", function()
		t.eq(with({ LongArm = 1 }).ThrowRange, 12)
		t.eq(with({ DeepPockets = 1 }).PocketSlots, 4)
		t.eq(with({ StrongBack = 1 }).HeavySolo, 8)
	end)

	t.test("Crew: Quick Hands, Escape Artist, Spare Batteries", function()
		t.eq(with({ QuickHands = 1 }).RescueHold, 1.5)
		t.eq(with({ EscapeArtist = 1 }).SelfEscapeAfter, 12)
		t.eq(with({ SpareBatteries = 1 }).FirstGadgetBonus, 1)
	end)

	t.test("unknown ids are ignored", function()
		local stats, applied = Perks.apply(defaults, { Jetpack = 1, SoftShoes = 1 }, EFFECTS)
		t.eq(#applied, 1)
		t.eq(applied[1], "SoftShoes")
		t.eq(stats.Crouch, 9)
		t.eq(stats.Jetpack, nil)
	end)

	t.test("map form: falsy and 0 values are not equipped", function()
		local stats, applied = Perks.apply(
			defaults,
			{ SoftShoes = 1, LongArm = true, DeepPockets = 0, StrongBack = false },
			EFFECTS
		)
		t.eq(#applied, 2)
		t.eq(stats.Crouch, 9)
		t.eq(stats.ThrowRange, 12)
		t.eq(stats.PocketSlots, 3)
		t.eq(stats.HeavySolo, 7)
	end)

	t.test("list form and three perks together", function()
		local stats, applied = Perks.apply(defaults, { "StrongBack", "QuickHands", "SoftShoes" }, EFFECTS)
		t.eq(table.concat(applied, ","), "QuickHands,SoftShoes,StrongBack")
		t.eq(stats.HeavySolo, 8)
		t.eq(stats.RescueHold, 1.5)
		t.eq(stats.Crouch, 9)
	end)

	t.test("no perks / nil = defaults; defaults are never changed", function()
		local stats = with(nil)
		t.eq(stats.Crouch, 8)
		with({ SoftShoes = 1, DeepPockets = 1 })
		t.eq(defaults.Crouch, 8)
		t.eq(defaults.PocketSlots, 3)
	end)

	t.test("effects with an unknown stat are skipped", function()
		local stats = Perks.apply(defaults, { Odd = 1 }, { Odd = { { Stat = "Nope", Set = 5 } } })
		t.eq(stats.Nope, nil)
	end)

	t.test("Add and Mul effects", function()
		local stats = Perks.apply(defaults, { X = 1 }, { X = { { Stat = "Walk", Add = 2, Mul = 0.5 } } })
		t.eq(stats.Walk, 9)
	end)

	t.test("Config.Perks: the advisor's 9 perks, every effect hits a real stat", function()
		local expected = {
			"BarrelLungs",
			"DeepPockets",
			"EscapeArtist",
			"LongArm",
			"QuickHands",
			"QuietCrowbar",
			"SoftShoes",
			"SpareBatteries",
			"StrongBack",
		}
		local ids = {}
		for id, effects in EFFECTS do
			table.insert(ids, id)
			for _, effect in effects do
				t.ok(
					type(defaults[effect.Stat]) == "number",
					id .. " → unknown stat " .. tostring(effect.Stat)
				)
			end
		end
		table.sort(ids)
		t.eq(table.concat(ids, ","), table.concat(expected, ","))
	end)

	t.test("charges: Config charges, Spare Batteries on the first pick, extra on all", function()
		local base = {}
		for name, gadget in Config.Gadgets do
			base[name] = gadget.Charges
		end
		local plain = Perks.charges({ "Noisemaker", "EMP" }, base, defaults)
		t.eq(plain.Noisemaker, 3)
		t.eq(plain.EMP, 2)
		local spare = Perks.charges({ "Noisemaker", "EMP" }, base, with({ SpareBatteries = 1 }))
		t.eq(spare.Noisemaker, 4)
		t.eq(spare.EMP, 2)
		local panic = Perks.charges({ "BubbleBlaster", "Drone" }, base, defaults, 1)
		t.eq(panic.BubbleBlaster, 4)
		t.eq(panic.Drone, 2)
		t.eq(Perks.charges({ "Mystery" }, base, defaults).Mystery, 0)
	end)
end
