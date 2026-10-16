--!nocheck
-- Guards the shared contracts: tag/attribute spelling and the mechanics Config block.
local Tags = require("../../src/shared/Tags")
local Config = require("../../src/shared/Config")

return function(t)
	t.test("Tags: every value equals its key (except the Charges prefix)", function()
		for key, value in Tags do
			if key == "Charges" then
				t.eq(value, "Charges_")
			else
				t.eq(value, key, key)
			end
		end
	end)

	t.test("Tags: every beta-spec §9.4 tag exists", function()
		local wanted = {
			"Loot",
			"Trace",
			"Npc",
			"LootAnchor",
			"BankZone",
			"Exit",
			"Entrance",
			"HideSpot",
			"Cell",
			"CellSpot",
			"CellDoor",
			"CellDropoff",
			"CellExit",
			"CellGrate",
			"DogZone",
			"KarelHome",
			"HazardAnchor",
			"GarageVan",
			"TutorialTrigger",
			"KeycardDoor",
			"Safe",
		}
		for _, name in wanted do
			t.eq(Tags[name], name, name)
		end
	end)

	t.test("Tags: prototype names still exist", function()
		for _, name in
			{ "Electronic", "SecurityCamera", "Lamp", "Guard", "Pryable", "GadgetPedestal", "Goal" }
		do
			t.eq(Tags[name], name)
		end
	end)

	t.test("Features: every §7 switch is on (advisor)", function()
		t.eq(Config.Features.Difficulty, true)
		t.eq(Config.Features.Objectives, true)
		t.eq(Config.Features.LoudExtras, true)
		t.eq(Config.Features.Perks, true)
	end)

	t.test("Normal tier = the base numbers elsewhere in Config", function()
		local normal = Config.DifficultyTiers.Tiers.Normal
		t.eq(normal.LockdownSeconds, Config.Alarm.LockdownSeconds)
		t.eq(normal.SelfEscapes, Config.Capture.SelfEscapes)
		t.eq(normal.DeviceSeconds, Config.Objectives.DeviceSeconds)
		t.eq(normal.CameraFillSeconds, Config.SecurityCamera.BaseFillSeconds)
		t.eq(normal.FillRate, 1)
		t.eq(normal.AlarmPoints, 1)
		t.eq(normal.ExtraGuards, 0)
		t.eq(Config.Objectives.DeviceSeconds, 45)
	end)

	t.test("every tier in Order has a row and vice versa", function()
		local n = 0
		for name in Config.DifficultyTiers.Tiers do
			n += 1
			t.ok(table.find(Config.DifficultyTiers.Order, name) ~= nil, name)
		end
		t.eq(n, #Config.DifficultyTiers.Order)
	end)

	t.test("loot types: valid classes, rare swaps exist, keycard is worthless", function()
		local classes = { Small = true, Medium = true, Heavy = true, Main = true }
		for name, def in Config.Loot.Types do
			t.ok(classes[def.Class], name .. " class " .. tostring(def.Class))
			t.ok(def.Value >= 0, name)
			if def.RareSwap then
				t.ok(Config.Loot.Types[def.RareSwap] ~= nil, name .. " → " .. def.RareSwap)
			end
		end
		t.eq(Config.Loot.Types.Keycard.Value, 0)
		t.eq(Config.Loot.Types.Keycard.Smelly, nil)
		t.eq(Config.Loot.Types.GoldenGouda.Lockdown, true)
	end)

	t.test("modifiers carry effects only (the Hot Job pays, meta)", function()
		for name, effects in Config.Modifiers do
			for key in effects do
				t.ok(
					string.find(key, "Payout") == nil and string.find(key, "Bonus") == nil,
					name .. "." .. key
				)
			end
		end
	end)

	t.test("loadout default is valid", function()
		t.eq(#Config.Loadout.Default, Config.Loadout.Slots)
		for _, gadget in Config.Loadout.Default do
			t.ok(table.find(Config.Loadout.Pickable, gadget) ~= nil, gadget)
			t.ok(Config.Gadgets[gadget] ~= nil, gadget)
		end
	end)

	t.test("guard counts cover every crew size", function()
		t.eq(#Config.Guard.CountByCrew, Config.Round.MaxCrew)
	end)

	t.test("Tags: adopted map and advisor names exist", function()
		local wanted = {
			"Opener",
			"StaffZone",
			"SecureZone",
			"Ride",
			"RideId",
			"Seats",
			"Speed",
			"LockdownSpeed",
			"Boarding",
			"Stop",
			"LockdownOnly",
			"ColdZone",
			"RhythmMachine",
			"Kind",
			"Period",
			"Active",
			"Radius",
			"GooZone",
			"LaserGrid",
			"MorningLight",
			"Step",
			"RisingPlinth",
			"RiseHeight",
			"PracticeTarget",
			"GarageTV",
			"TrophyBoard",
			"LockdownSwitch",
			"Action",
			"QuietOnly",
			"ArrivesAt",
			"SeeThrough",
			"GuardDoor",
			"Masked",
		}
		for _, name in wanted do
			t.eq(Tags[name], name, name)
		end
	end)
end
