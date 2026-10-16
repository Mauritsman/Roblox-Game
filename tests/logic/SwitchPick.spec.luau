--!nocheck
local SwitchPick = require("../../src/shared/Logic/SwitchPick")
local Motion = require("../../src/shared/Logic/Motion")

local SHUTTERS = {
	{ id = "NorthBridge", group = "Shutters", pick = 2, exclusive = "Bridge" },
	{ id = "SouthBridge", group = "Shutters", exclusive = "Bridge" },
	{ id = "StaffDoor", group = "Shutters" },
	{ id = "YardDoor", group = "Shutters" },
	{ id = "Siren" }, -- no group: always
}

local function count(set)
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end

return function(t)
	t.test("2 of 4 shutters, never both bridges, ungrouped always", function()
		for seed = 1, 200 do
			local chosen = SwitchPick.choose(SHUTTERS, seed)
			t.ok(chosen.Siren, "ungrouped switch acts")
			t.eq(count(chosen), 3, "seed " .. seed)
			t.ok(not (chosen.NorthBridge and chosen.SouthBridge), "both bridges at seed " .. seed)
		end
	end)

	t.test("deterministic per seed, and seeds vary the choice", function()
		local a = SwitchPick.choose(SHUTTERS, 42)
		local b = SwitchPick.choose(SHUTTERS, 42)
		for id in a do
			t.ok(b[id])
		end
		local seen = {}
		for seed = 1, 50 do
			local chosen = SwitchPick.choose(SHUTTERS, seed)
			local key = {}
			for _, m in SHUTTERS do
				if chosen[m.id] then
					table.insert(key, m.id)
				end
			end
			seen[table.concat(key, ",")] = true
		end
		t.ok(count(seen) >= 3, "several different layouts")
	end)

	t.test("no Pick = the whole group; Pick 0 = none", function()
		local all = SwitchPick.choose({ { id = "a", group = "G" }, { id = "b", group = "G" } }, 1)
		t.ok(all.a and all.b)
		local none = SwitchPick.choose({ { id = "a", group = "G", pick = 0 }, { id = "b", group = "G" } }, 1)
		t.eq(count(none), 0)
	end)

	t.test("hash is stable", function()
		t.eq(SwitchPick.hash("Shutters"), SwitchPick.hash("Shutters"))
		t.ok(SwitchPick.hash("A") ~= SwitchPick.hash("B"))
	end)

	t.test("motion progress and easing", function()
		t.eq(Motion.progress(5, 10, 4), 0)
		t.eq(Motion.progress(12, 10, 4), 0.5)
		t.eq(Motion.progress(20, 10, 4), 1)
		t.eq(Motion.progress(10, 10, 0), 1)
		t.eq(Motion.easeOut(0), 0)
		t.eq(Motion.easeOut(1), 1)
		t.ok(Motion.easeOut(0.5) > 0.5)
		t.ok(Motion.easeIn(0.5) < 0.5)
		t.near(Motion.easeInOut(0.5), 0.5)
	end)

	t.test("balloon approach starts before ArrivesAt, never before the lockdown", function()
		t.eq(Motion.approachStart(100, 20, 8), 112)
		t.eq(Motion.approachStart(100, 5, 8), 100)
	end)
end
