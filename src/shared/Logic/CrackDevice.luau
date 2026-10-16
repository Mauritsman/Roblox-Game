--!strict
-- The "Cheese Grater 3000" on a safe (beta-spec §7.3, advisor: 45 s; Easy 35, Hard 55; 1–2 jams).
-- Progress runs 0 → 1 over `seconds`. Jam points are fractions of progress (0–1), so they work for every
-- difficulty. At a jam point the device stops, beeps every `beepInterval` seconds (noise) and waits until
-- someone holds "Restart" (CrackDevice.restart). `step` never changes the state it gets; it returns a new one.
-- Events from step: "jammed", "beep" (also once at the jam), "done".

local CrackDevice = {}

local EPSILON = 1e-9 -- many small steps add up to 0.9999999999; count that as reached

export type State = {
	seconds: number,
	beepInterval: number,
	progress: number, -- 0 .. 1
	jammed: boolean,
	jamsHit: number, -- jam points passed so far
	done: boolean,
	beepIn: number, -- seconds until the next beep while jammed
}

function CrackDevice.new(seconds: number, beepInterval: number?): State
	return {
		seconds = math.max(seconds, 1e-3),
		beepInterval = beepInterval or 3,
		progress = 0,
		jammed = false,
		jamsHit = 0,
		done = false,
		beepIn = 0,
	}
end

function CrackDevice.step(state: State, dt: number, jamTimes: { number }): (State, { string })
	local s = table.clone(state)
	local events = {}
	if s.done or dt <= 0 then
		return s, events
	end
	if s.jammed then
		s.beepIn -= dt
		while s.beepIn <= 0 do
			table.insert(events, "beep")
			s.beepIn += s.beepInterval
		end
		return s, events
	end

	local nextProgress = s.progress + dt / s.seconds
	local jamAt = jamTimes[s.jamsHit + 1]
	if jamAt ~= nil and jamAt < 1 and nextProgress >= jamAt - EPSILON then
		s.progress = math.max(s.progress, jamAt)
		s.jammed = true
		s.jamsHit += 1
		s.beepIn = s.beepInterval
		table.insert(events, "jammed")
		table.insert(events, "beep")
		return s, events
	end
	if nextProgress >= 1 - EPSILON then
		s.progress = 1
		s.done = true
		table.insert(events, "done")
		return s, events
	end
	s.progress = nextProgress
	return s, events
end

-- Someone held "Restart": the jam is cleared, progress continues from where it stopped.
function CrackDevice.restart(state: State): State
	local s = table.clone(state)
	s.jammed = false
	s.beepIn = 0
	return s
end

-- Seconds of running left (jams not counted).
function CrackDevice.remaining(state: State): number
	return (1 - state.progress) * state.seconds
end

-- Jam points from random numbers in [0, 1): one per roll, spread over `window` = {from, to} in equal slices
-- (so two jams never bunch up). Returns sorted fractions. RoundPlan feeds it rolls from Logic/Rng.
function CrackDevice.jamPoints(rolls: { number }, window: { number }): { number }
	local from, to = window[1], window[2]
	local count = #rolls
	local points = {}
	if count == 0 then
		return points
	end
	local slice = (to - from) / count
	for index, roll in rolls do
		local r = math.clamp(roll, 0, 1)
		table.insert(points, from + slice * (index - 1) + slice * r)
	end
	return points
end

return CrackDevice
