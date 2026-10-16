--!nocheck
local DataSchema = require("../../src/shared/Logic/DataSchema")

local STARTER =
	{ equipped = { Mask = "PaperBag", Van = "GetawayWhite" }, loadout = { "Noisemaker", "BubbleBlaster" } }

return function(t)
	t.test("defaults are complete and at the current version", function()
		local d = DataSchema.defaults(1000, STARTER)
		t.eq(d.version, DataSchema.CURRENT)
		t.eq(d.cash, 0)
		t.eq(d.rep, 0)
		t.eq(d.rankRewarded, 1)
		t.eq(d.equipped.Mask, "PaperBag")
		t.eq(d.equipped.Van, "GetawayWhite")
		t.eq(#d.loadout, 2)
		t.eq(d.onboarding.done, false)
		t.eq(d.firstSeen, 1000)
		for _, key in DataSchema.StatKeys do
			t.eq(d.stats[key], 0, key)
		end
		for _, key in { "owned", "robuxOwned", "heists", "collection", "receipts", "purchases", "seenTips" } do
			t.ok(type(d[key]) == "table", key)
		end
	end)

	t.test("defaults never share tables with the starter or each other", function()
		local a = DataSchema.defaults(1, STARTER)
		local b = DataSchema.defaults(1, STARTER)
		a.loadout[1] = "Drone"
		a.equipped.Mask = "TulipMask"
		a.stats.rounds = 5
		t.eq(b.loadout[1], "Noisemaker")
		t.eq(STARTER.loadout[1], "Noisemaker")
		t.eq(STARTER.equipped.Mask, "PaperBag")
		t.eq(b.stats.rounds, 0)
	end)

	t.test("reconcile fills missing keys deeply and keeps unknown keys", function()
		local data = { cash = 50, stats = { rounds = 3 }, futureFeature = { x = 1 } }
		local repaired = DataSchema.reconcile(data, DataSchema.defaults(1, STARTER))
		t.ok(repaired > 0)
		t.eq(data.cash, 50)
		t.eq(data.stats.rounds, 3)
		t.eq(data.stats.escapes, 0)
		t.eq(data.futureFeature.x, 1)
		t.eq(data.equipped.Mask, "PaperBag")
	end)

	t.test("reconcile repairs wrong types and never merges lists", function()
		local data = DataSchema.defaults(1, STARTER)
		data.cash = "lots"
		data.loadout = { "Drone" }
		DataSchema.reconcile(data, DataSchema.defaults(1, STARTER))
		t.eq(data.cash, 0)
		t.eq(#data.loadout, 1)
		t.eq(data.loadout[1], "Drone")
	end)

	t.test("v0 fixture migrates and keeps its money and unknown keys", function()
		local status, data, steps =
			DataSchema.prepare({ Cash = 1200, Rep = 3000, legacyFlag = true }, 5, STARTER)
		t.eq(status, "ok")
		t.eq(steps, 1)
		t.eq(data.version, 1)
		t.eq(data.cash, 1200)
		t.eq(data.rep, 3000)
		t.eq(data.Cash, nil)
		t.eq(data.legacyFlag, true)
		t.eq(data.stats.rounds, 0)
	end)

	t.test("current data passes unchanged", function()
		local d = DataSchema.defaults(1, STARTER)
		d.cash = 777
		local status, data, steps = DataSchema.prepare(d, 2, STARTER)
		t.eq(status, "ok")
		t.eq(steps, 0)
		t.eq(data.cash, 777)
	end)

	t.test("newer version is reported, never migrated", function()
		local status, data = DataSchema.prepare({ version = DataSchema.CURRENT + 98, cash = 5 }, 1, STARTER)
		t.eq(status, "newer")
		t.eq(data, nil)
	end)

	t.test("non-table or broken version is corrupt", function()
		t.eq((DataSchema.prepare("garbage", 1, STARTER)), "corrupt")
		t.eq((DataSchema.prepare(42, 1, STARTER)), "corrupt")
		t.eq((DataSchema.prepare({ version = "x" }, 1, STARTER)), "corrupt")
		t.eq((DataSchema.prepare({ version = -1 }, 1, STARTER)), "corrupt")
		t.eq((DataSchema.prepare({ version = 0.5 }, 1, STARTER)), "corrupt")
	end)

	t.test("sanitize keeps money whole and non-negative", function()
		local d = DataSchema.defaults(1, STARTER)
		d.cash = -50
		d.rep = 10.9
		d.stats.rounds = 0 / 0
		d.rankRewarded = 0
		DataSchema.sanitize(d)
		t.eq(d.cash, 0)
		t.eq(d.rep, 10)
		t.eq(d.stats.rounds, 0)
		t.eq(d.rankRewarded, 1)
	end)

	t.test("deepCopy makes an independent copy", function()
		local a = { x = { y = { 1, 2 } } }
		local b = DataSchema.deepCopy(a)
		b.x.y[1] = 9
		t.eq(a.x.y[1], 1)
	end)
end
