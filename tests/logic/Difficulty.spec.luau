--!nocheck
local Difficulty = require("../../src/shared/Logic/Difficulty")
local Config = require("../../src/shared/Config")

local TIERS = Config.DifficultyTiers
local base = Difficulty.base(Config)

local function check(t, round, expected, label)
	for key, value in expected do
		if type(value) == "number" then
			t.near(round[key], value, 1e-9, label .. "." .. key)
		else
			t.eq(round[key], value, label .. "." .. key)
		end
	end
end

return function(t)
	t.test("base = Normal numbers from Config", function()
		check(t, base, {
			fillRate = 1,
			extraGuards = 0,
			cameraFillSeconds = 2,
			alarmPointsFactor = 1,
			lockdownSeconds = 60,
			selfEscapes = 1,
			radioChecks = true,
			deviceSeconds = 45,
		}, "base")
	end)

	t.test("Easy column", function()
		check(t, Difficulty.apply(base, TIERS.Tiers.Easy), {
			fillRate = 0.8,
			extraGuards = 0,
			cameraFillSeconds = 3,
			alarmPointsFactor = 0.75,
			lockdownSeconds = 75,
			selfEscapes = 2,
			radioChecks = false,
			deviceSeconds = 35,
		}, "Easy")
	end)

	t.test("Normal column changes nothing", function()
		check(t, Difficulty.apply(base, TIERS.Tiers.Normal), base, "Normal")
	end)

	t.test("Hard column", function()
		check(t, Difficulty.apply(base, TIERS.Tiers.Hard), {
			fillRate = 1.2,
			extraGuards = 1,
			cameraFillSeconds = 1.6,
			alarmPointsFactor = 1.25,
			lockdownSeconds = 50,
			selfEscapes = 1,
			radioChecks = true,
			deviceSeconds = 55,
		}, "Hard")
	end)

	t.test("only three tiers in the beta, Normal is the default", function()
		t.eq(#TIERS.Order, 3)
		t.eq(TIERS.Order[1], "Easy")
		t.eq(TIERS.Order[2], "Normal")
		t.eq(TIERS.Order[3], "Hard")
		t.eq(TIERS.Default, "Normal")
		t.eq(TIERS.Tiers.BigCheese, nil)
	end)

	t.test("unknown or missing tier falls back to Normal", function()
		local row, name = Difficulty.tier(TIERS, nil)
		t.eq(name, "Normal")
		t.eq(row, TIERS.Tiers.Normal)
		local _, big = Difficulty.tier(TIERS, "BigCheese")
		t.eq(big, "Normal")
		local hard, hardName = Difficulty.tier(TIERS, "Hard")
		t.eq(hardName, "Hard")
		t.eq(hard.ExtraGuards, 1)
	end)

	t.test("rates multiply onto a modified base (Sleepy Guards on Hard)", function()
		local sleepy = table.clone(base)
		sleepy.fillRate = Config.Modifiers.SleepyGuards.FillRate
		t.near(Difficulty.apply(sleepy, TIERS.Tiers.Hard).fillRate, 0.84)
	end)

	t.test("radio checks need both base and tier", function()
		local noRadio = table.clone(base)
		noRadio.radioChecks = false
		t.eq(Difficulty.apply(noRadio, TIERS.Tiers.Hard).radioChecks, false)
	end)

	t.test("apply does not change base", function()
		Difficulty.apply(base, TIERS.Tiers.Easy)
		t.eq(base.lockdownSeconds, 60)
		t.eq(base.fillRate, 1)
	end)

	t.test("alarm points scale with half-up rounding", function()
		t.eq(Difficulty.scalePoints(40, 0.75), 30)
		t.eq(Difficulty.scalePoints(10, 0.75), 8) -- 7.5
		t.eq(Difficulty.scalePoints(15, 0.75), 11) -- 11.25
		t.eq(Difficulty.scalePoints(10, 1.25), 13) -- 12.5
		t.eq(Difficulty.scalePoints(15, 1.25), 19) -- 18.75
		t.eq(Difficulty.scalePoints(40, 1), 40)
	end)
end
