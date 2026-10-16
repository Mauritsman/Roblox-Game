--!nocheck
local CrackDevice = require("../../src/shared/Logic/CrackDevice")
local Config = require("../../src/shared/Config")

local SECONDS = Config.Objectives.DeviceSeconds -- 45
local BEEP = Config.Objectives.BeepInterval -- 3

local function run(state, seconds, jams, dt)
	dt = dt or 0.1
	local events = {}
	local steps = math.floor(seconds / dt + 0.5)
	for _ = 1, steps do
		local new
		state, new = CrackDevice.step(state, dt, jams)
		for _, e in new do
			table.insert(events, e)
		end
	end
	return state, events
end

local function countOf(list, value)
	local n = 0
	for _, v in list do
		if v == value then
			n += 1
		end
	end
	return n
end

return function(t)
	t.test("no jams: done after 45 s", function()
		local s, events = run(CrackDevice.new(SECONDS, BEEP), 44.9, {})
		t.ok(not s.done)
		t.near(CrackDevice.remaining(s), 0.1, 1e-6)
		s, events = run(s, 0.1, {})
		t.ok(s.done)
		t.eq(s.progress, 1)
		t.eq(countOf(events, "done"), 1)
	end)

	t.test("a jam stops progress until restart", function()
		local s, events = run(CrackDevice.new(SECONDS, BEEP), 30, { 0.5 })
		t.ok(s.jammed)
		t.near(s.progress, 0.5)
		t.eq(countOf(events, "jammed"), 1)
		local before = s.progress
		s = run(s, 20, { 0.5 })
		t.eq(s.progress, before)
		t.ok(not s.done)
	end)

	t.test("jammed: beeps every 3 s (one at the jam)", function()
		local s, events = CrackDevice.step(CrackDevice.new(10, BEEP), 6, { 0.5 })
		t.ok(s.jammed)
		t.eq(countOf(events, "beep"), 1)
		local _, more = CrackDevice.step(s, 3, { 0.5 })
		t.eq(countOf(more, "beep"), 1)
		local _, lots = CrackDevice.step(s, 6.5, { 0.5 })
		t.eq(countOf(lots, "beep"), 2)
		local _, none = CrackDevice.step(s, 2.9, { 0.5 })
		t.eq(countOf(none, "beep"), 0)
	end)

	t.test("restart continues from the jam; total run time stays 45 s", function()
		local jams = { 0.3, 0.7 }
		local s = run(CrackDevice.new(SECONDS, BEEP), 20, jams) -- jammed at 13.5 s of running
		t.ok(s.jammed)
		t.eq(s.jamsHit, 1)
		s = CrackDevice.restart(s)
		t.ok(not s.jammed)
		s = run(s, 18, jams) -- jams again at 31.5 s of running
		t.ok(s.jammed)
		t.eq(s.jamsHit, 2)
		t.near(s.progress, 0.7)
		s = CrackDevice.restart(s)
		s = run(s, 13.4, jams)
		t.ok(not s.done)
		s = run(s, 0.2, jams)
		t.ok(s.done)
	end)

	t.test("one big step never runs past a jam point", function()
		local s, events = CrackDevice.step(CrackDevice.new(SECONDS, BEEP), 100, { 0.4 })
		t.ok(s.jammed)
		t.near(s.progress, 0.4)
		t.eq(countOf(events, "done"), 0)
	end)

	t.test("step and restart do not change the state they get", function()
		local s = CrackDevice.new(SECONDS, BEEP)
		CrackDevice.step(s, 10, {})
		t.eq(s.progress, 0)
		local jammed = CrackDevice.step(s, 30, { 0.5 })
		CrackDevice.restart(jammed)
		t.ok(jammed.jammed)
	end)

	t.test("done device ignores further steps; zero dt does nothing", function()
		local s = run(CrackDevice.new(1, BEEP), 1.1, {})
		t.ok(s.done)
		local again, events = CrackDevice.step(s, 5, {})
		t.ok(again.done)
		t.eq(#events, 0)
		local fresh, none = CrackDevice.step(CrackDevice.new(10), 0, {})
		t.eq(fresh.progress, 0)
		t.eq(#none, 0)
	end)

	t.test("tier run times (Easy 35, Normal 45, Hard 55)", function()
		local tiers = Config.DifficultyTiers.Tiers
		for _, name in { "Easy", "Normal", "Hard" } do
			local seconds = tiers[name].DeviceSeconds
			local s = run(CrackDevice.new(seconds), seconds + 0.1, {})
			t.ok(s.done, name)
			local early = run(CrackDevice.new(seconds), seconds - 0.5, {})
			t.ok(not early.done, name)
		end
	end)

	t.test("jamPoints: one per roll, sorted, inside the window, in separate slices", function()
		local window = Config.Plan.DeviceJamWindow
		local one = CrackDevice.jamPoints({ 0.5 }, window)
		t.eq(#one, 1)
		t.near(one[1], window[1] + (window[2] - window[1]) * 0.5)
		local two = CrackDevice.jamPoints({ 0.99, 0 }, window)
		t.eq(#two, 2)
		t.ok(two[1] < two[2])
		local mid = (window[1] + window[2]) / 2
		t.ok(two[1] <= mid + 1e-9 and two[2] >= mid - 1e-9)
		for _, p in two do
			t.ok(p >= window[1] and p <= window[2])
		end
		t.eq(#CrackDevice.jamPoints({}, window), 0)
		t.near(CrackDevice.jamPoints({ 1 }, { 0.2, 0.8 })[1], 0.8)
		t.near(CrackDevice.jamPoints({ 0 }, { 0.2, 0.8 })[1], 0.2)
	end)
end
