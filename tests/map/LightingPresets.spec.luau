--!nocheck
-- LightingPresets (shared): complete presets per area, The Golden Wheel = Atmosphere.BlueNight, the Tulip 5:00
-- steps brighten, lookups by Activity and by position, and every preset applies cleanly through Atmosphere.
local roblox = require("@lune/roblox")
local Mock = require("./MockRoblox")

local Vector3 = roblox.Vector3

local function load()
	local world = Mock.world()
	local LightingPresets = world.require(world.shared.LightingPresets)
	local Atmosphere = world.require(world.server.Map.Common.Atmosphere)
	local Config = world.require(world.shared.Config)
	return world, LightingPresets, Atmosphere, Config
end

return function(t)
	t.test("LightingPresets: GoldenWheel is exactly Atmosphere.BlueNight", function()
		local _, LightingPresets, Atmosphere = load()
		local preset = LightingPresets.Presets.GoldenWheel
		for key, value in Atmosphere.BlueNight do
			t.ok(preset[key] == value, "field " .. key)
		end
		for key in preset do
			t.ok(Atmosphere.BlueNight[key] ~= nil, "no extra field " .. key)
		end
	end)

	t.test("LightingPresets: every preset fills every field with the right type", function()
		local _, LightingPresets, Atmosphere = load()
		local all = {}
		for name, preset in LightingPresets.Presets do
			all[name] = preset
		end
		for step, preset in LightingPresets.TulipMorning do
			all["TulipMorning" .. step] = preset
		end
		for _, name in { "GoldenWheel", "Garage", "MiniJob", "PralinePalace", "TulipAuction" } do
			t.ok(LightingPresets.Presets[name], "preset " .. name)
		end
		for name, preset in all do
			for key, value in Atmosphere.BlueNight do
				t.eq(typeof(preset[key]), typeof(value), name .. "." .. key)
			end
			t.ok(preset.ClockTime >= 0 and preset.ClockTime < 24, name .. " ClockTime")
			t.ok(preset.Brightness > 0 and preset.Brightness <= 5, name .. " Brightness")
			t.ok(math.abs(preset.ExposureCompensation) <= 1, name .. " ExposureCompensation")
			t.ok(preset.HazeDensity >= 0 and preset.HazeDensity <= 1, name .. " HazeDensity")
			t.ok(table.isfrozen(preset), name .. " is frozen")
		end
	end)

	t.test("LightingPresets: areas have their own mood", function()
		local _, LightingPresets = load()
		local P = LightingPresets.Presets
		t.ok(P.Garage.Ambient.R > P.Garage.Ambient.B, "Garage is warm")
		t.ok(P.MiniJob.ClockTime > 17 and P.MiniJob.ClockTime < 20, "MiniJob is dusk")
		t.ok(P.MiniJob.ExposureCompensation > P.GoldenWheel.ExposureCompensation, "MiniJob a bit brighter")
		t.ok(P.PralinePalace.Ambient.R > P.PralinePalace.Ambient.B, "Praline is a warm night")
		t.ok(P.TulipAuction.ClockTime > 5 and P.TulipAuction.ClockTime < 6, "Tulip before dawn")
	end)

	t.test("LightingPresets: Tulip Auction brightens in three steps from 5:00", function()
		local _, LightingPresets = load()
		local steps = LightingPresets.TulipMorning
		t.eq(#steps, 3)
		local previous = LightingPresets.Presets.TulipAuction
		for i, step in steps do
			t.ok(step.ClockTime > previous.ClockTime, "step " .. i .. " later")
			t.ok(step.Brightness > previous.Brightness, "step " .. i .. " brighter")
			t.ok(step.ExposureCompensation > previous.ExposureCompensation, "step " .. i .. " exposure")
			previous = step
		end
	end)

	t.test("LightingPresets: lookups by name, Activity and position", function()
		local _, LightingPresets, _, Config = load()
		t.eq(LightingPresets.get("Nope"), LightingPresets.Presets.GoldenWheel)
		t.eq(LightingPresets.get(nil), LightingPresets.Presets.GoldenWheel)
		t.eq((LightingPresets.forActivity("Garage", "TulipAuction")), "Garage")
		t.eq((LightingPresets.forActivity("Tutorial", nil)), "MiniJob")
		t.eq((LightingPresets.forActivity("Crew", "PralinePalace")), "PralinePalace")
		t.eq((LightingPresets.forActivity("Crew", "Unknown")), "GoldenWheel")
		local g = Config.World.GarageOrigin
		t.eq(LightingPresets.areaAt(Vector3.new(g.X + 40, 5, g.Z - 30)), "Garage")
		for _, o in Config.World.MiniJobOrigins do
			t.eq(LightingPresets.areaAt(Vector3.new(o.X - 20, 3, o.Z + 10)), "MiniJob")
		end
		t.eq(LightingPresets.areaAt(Vector3.new(30, 3, -20)), "Heist")
		t.eq((LightingPresets.presetAt(Vector3.new(0, 0, 0), "TulipAuction")), "TulipAuction")
		t.eq((LightingPresets.presetAt(Vector3.new(g.X, 0, g.Z), "TulipAuction")), "Garage")
	end)

	t.test("LightingPresets: every preset applies through Atmosphere.apply", function()
		local world, LightingPresets, Atmosphere = load()
		for name, preset in LightingPresets.Presets do
			local ok, err = pcall(Atmosphere.apply, preset)
			t.ok(ok, name .. ": " .. tostring(err))
			t.near(world.lighting.ClockTime, preset.ClockTime, 1e-6, name)
		end
		for _, preset in LightingPresets.TulipMorning do
			t.ok(pcall(Atmosphere.apply, preset), "Tulip step applies")
		end
	end)
end
