--!nocheck
local Noise = require("../../src/shared/Logic/Noise")
local Config = require("../../src/shared/Config")

return function(t)
	t.test("busy guards ignore every noise, even a Noisemaker", function()
		for _, kind in Noise.KINDS do
			t.eq(Noise.reaction(kind, false, true), "Ignore", kind)
		end
	end)

	t.test("a Noisemaker distracts, also a guard that is already distracted", function()
		t.eq(Noise.reaction("noisemaker", false, false), "Distract")
		t.eq(Noise.reaction("noisemaker", true, false), "Distract")
	end)

	t.test("a distracted guard hears no CRACK, BZZT or the new kinds", function()
		for _, kind in
			{ "crack", "bzzt", "thud", "rumble", "bark", "sneeze", "squeak", "beep", "splosh", "repeat" }
		do
			t.eq(Noise.reaction(kind, true, false), "Ignore", kind)
		end
	end)

	t.test("repeat = look around; new kinds and unknown kinds = investigate", function()
		t.eq(Noise.reaction("repeat", false, false), "LookAround")
		for _, kind in { "crack", "bzzt", "thud", "rumble", "bark", "sneeze", "squeak", "beep", "splosh" } do
			t.eq(Noise.reaction(kind, false, false), "Investigate", kind)
		end
		t.eq(Noise.reaction("kazoo", false, false), "Investigate")
		t.eq(Noise.reaction(nil, false, false), "Investigate")
	end)

	t.test("search seconds: caller > per kind > default", function()
		local perKind = Config.Guard.NoiseSearch
		t.eq(Noise.searchSeconds("thud", 3, perKind, 8), 3)
		t.eq(Noise.searchSeconds("thud", nil, perKind, 8), perKind.thud)
		t.eq(Noise.searchSeconds("kazoo", nil, perKind, 8), 8)
		t.eq(Noise.searchSeconds(nil, nil, nil, 8), 8)
	end)

	t.test("every Noise kind except noisemaker/repeat/crack/bzzt has a search time in Config", function()
		for _, kind in { "thud", "rumble", "bark", "sneeze", "squeak", "beep", "splosh" } do
			t.ok(type(Config.Guard.NoiseSearch[kind]) == "number", kind)
		end
	end)

	t.test("nearest: smallest distances first, ties by index, count clamps", function()
		local result = Noise.nearest({ 12, 3, 40, 3, 7 }, 2)
		t.eq(#result, 2)
		t.eq(result[1], 2)
		t.eq(result[2], 4)
		t.eq(#Noise.nearest({ 5 }, 2), 1)
		t.eq(#Noise.nearest({}, 2), 0)
		t.eq(Noise.nearest({ 9, 1, 5 }, 3)[3], 1)
	end)
end
