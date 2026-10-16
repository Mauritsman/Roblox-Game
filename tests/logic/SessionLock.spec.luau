--!nocheck
-- Two fake servers on one fake store (UpdateAsync semantics: nil from the transform = no write).
local SessionLock = require("../../src/shared/Logic/SessionLock")
local DataSchema = require("../../src/shared/Logic/DataSchema")

local function newStore()
	local store = { values = {}, writes = 0 }
	function store.update(key, transform)
		local new, outcome = transform(DataSchema.deepCopy(store.values[key]))
		if new ~= nil then
			store.values[key] = DataSchema.deepCopy(new)
			store.writes += 1
		end
		return new, outcome
	end
	return store
end

local function loadCtx(session, now, steal, resetCorrupt)
	return {
		session = session,
		job = "job-" .. session,
		place = 1,
		now = now,
		staleSeconds = 600,
		steal = steal or false,
		currentVersion = 1,
		makeDefaults = function()
			return { version = 1, cash = 0 }
		end,
		resetCorrupt = resetCorrupt,
	}
end

local function saveCtx(session, now, data, release)
	return { session = session, now = now, data = data, release = release or false }
end

return function(t)
	t.test("first load creates a record with my lock", function()
		local store = newStore()
		local record, outcome = store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 100))
		end)
		t.eq(outcome, "created")
		t.eq(record.lock.session, "A")
		t.eq(store.values.u_1.data.version, 1)
	end)

	t.test("a fresh foreign lock makes the other server wait (no write)", function()
		local store = newStore()
		store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 100))
		end)
		local writes = store.writes
		local record, outcome = store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("B", 110))
		end)
		t.eq(outcome, "busy")
		t.eq(record, nil)
		t.eq(store.writes, writes)
		t.eq(store.values.u_1.lock.session, "A")
	end)

	t.test("a stale lock is taken", function()
		local store = newStore()
		store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 100))
		end)
		local _, outcome = store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("B", 100 + 601))
		end)
		t.eq(outcome, "stale")
		t.eq(store.values.u_1.lock.session, "B")
	end)

	t.test("my own lock or an empty lock is taken", function()
		local store = newStore()
		store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 100))
		end)
		local _, outcome = store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 105))
		end)
		t.eq(outcome, "taken")
		store.update("u_1", function(raw)
			return SessionLock.save(raw, saveCtx("A", 106, nil, true))
		end)
		local _, outcome2 = store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("B", 107))
		end)
		t.eq(outcome2, "taken")
	end)

	t.test("after N attempts the lock is stolen and the steal counted", function()
		local store = newStore()
		store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 100))
		end)
		local _, outcome = store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("B", 120, true))
		end)
		t.eq(outcome, "stolen")
		t.eq(store.values.u_1.lock.session, "B")
		t.eq(store.values.u_1.steals, 1)
	end)

	t.test("a robbed session's save cancels and writes nothing", function()
		local store = newStore()
		store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 100))
		end)
		store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("B", 120, true))
		end)
		local writes = store.writes
		local record, outcome = store.update("u_1", function(raw)
			return SessionLock.save(raw, saveCtx("A", 130, { version = 1, cash = 999999 }))
		end)
		t.eq(outcome, "lost")
		t.eq(record, nil)
		t.eq(store.writes, writes)
		t.eq(store.values.u_1.data.cash, 0)
	end)

	t.test("save writes data, refreshes the lock time and counts saves", function()
		local store = newStore()
		store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 100))
		end)
		local _, outcome = store.update("u_1", function(raw)
			return SessionLock.save(raw, saveCtx("A", 200, { version = 1, cash = 50 }))
		end)
		t.eq(outcome, "saved")
		t.eq(store.values.u_1.data.cash, 50)
		t.eq(store.values.u_1.lock.at, 200)
		t.eq(store.values.u_1.saveCount, 1)
	end)

	t.test("release clears only its own lock", function()
		local store = newStore()
		store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 100))
		end)
		local _, foreign = store.update("u_1", function(raw)
			return SessionLock.save(raw, saveCtx("B", 101, nil, true))
		end)
		t.eq(foreign, "lost")
		t.eq(store.values.u_1.lock.session, "A")
		local _, own = store.update("u_1", function(raw)
			return SessionLock.save(raw, saveCtx("A", 102, nil, true))
		end)
		t.eq(own, "released")
		t.eq(store.values.u_1.lock, nil)
	end)

	t.test("release without data keeps the stored data", function()
		local store = newStore()
		store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 100))
		end)
		store.update("u_1", function(raw)
			return SessionLock.save(raw, saveCtx("A", 101, { version = 1, cash = 70 }))
		end)
		store.update("u_1", function(raw)
			return SessionLock.save(raw, saveCtx("A", 102, nil, true))
		end)
		t.eq(store.values.u_1.data.cash, 70)
	end)

	t.test("corrupt values are refused until the caller backed them up", function()
		local store = newStore()
		store.values.u_1 = "broken"
		local record, outcome = store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 100))
		end)
		t.eq(outcome, "corrupt")
		t.eq(record, nil)
		t.eq(store.values.u_1, "broken")
		local _, reset = store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 101, false, true))
		end)
		t.eq(reset, "reset")
		t.eq(store.values.u_1.data.cash, 0)
	end)

	t.test("data from a newer version is never locked or overwritten", function()
		local store = newStore()
		store.values.u_1 = { data = { version = 99, cash = 5 }, savedAt = 1, saveCount = 1, steals = 0 }
		local record, outcome = store.update("u_1", function(raw)
			return SessionLock.load(raw, loadCtx("A", 100))
		end)
		t.eq(outcome, "newer")
		t.eq(record, nil)
		t.eq(store.values.u_1.lock, nil)
	end)

	t.test("saving a record that disappeared is refused", function()
		local store = newStore()
		local record, outcome = store.update("u_1", function(raw)
			return SessionLock.save(raw, saveCtx("A", 100, { version = 1 }))
		end)
		t.eq(outcome, "missing")
		t.eq(record, nil)
	end)
end
