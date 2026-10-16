--!strict
-- Timing for rhythm machines (beta-spec-maps §7–8): the chocolate fountain, the Big Mixer, the wrapping machine,
-- mist lines, steam vents and the Tulip auction clock. A machine runs in cycles: a cycle starts every `period`
-- seconds from `t0`, and the first `active` seconds of each cycle are its active window (fountain tasting, mixer
-- mask after a thump, mist cloud). period ≤ 0 means "always active" (sprinklers).
-- The clock's light beam sweeps from a centre out to an ellipse; `beamHit` tells whether a floor point is lit.

local Rhythm = {}

export type Timer = {
	period: number,
	active: number,
	t0: number, -- server time when a cycle started
}

function Rhythm.new(period: number, active: number, t0: number): Timer
	return { period = period, active = math.max(0, active), t0 = t0 }
end

-- Seconds into the current cycle, in [0, period).
function Rhythm.phase(timer: Timer, now: number): number
	if timer.period <= 0 then
		return 0
	end
	return (now - timer.t0) % timer.period
end

-- Which cycle is running (counts up from 0 at t0; negative before t0).
function Rhythm.cycle(timer: Timer, now: number): number
	if timer.period <= 0 then
		return 0
	end
	return math.floor((now - timer.t0) / timer.period)
end

-- Fraction of the current cycle done, in [0, 1).
function Rhythm.fraction(timer: Timer, now: number): number
	if timer.period <= 0 then
		return 0
	end
	return Rhythm.phase(timer, now) / timer.period
end

function Rhythm.isActive(timer: Timer, now: number): boolean
	if timer.period <= 0 then
		return true
	end
	return Rhythm.phase(timer, now) < timer.active
end

-- Seconds until the next cycle starts.
function Rhythm.untilNext(timer: Timer, now: number): number
	if timer.period <= 0 then
		return math.huge
	end
	return timer.period - Rhythm.phase(timer, now)
end

-- The same machine at a new speed: keeps the cycle fraction (and the clock's angle) continuous at `now`.
function Rhythm.retime(timer: Timer, now: number, period: number, active: number): Timer
	if timer.period <= 0 or period <= 0 then
		return Rhythm.new(period, active, now)
	end
	local fraction = Rhythm.fraction(timer, now)
	return Rhythm.new(period, active, now - fraction * period)
end

-- The period to use: LOCKDOWN uses `lockdownPeriod` when given, else base × factor when the machine speeds up.
function Rhythm.periodFor(
	base: number,
	lockdown: boolean,
	lockdownPeriod: number?,
	speedsUp: boolean,
	factor: number
): number
	if not lockdown then
		return base
	elseif lockdownPeriod and lockdownPeriod > 0 then
		return lockdownPeriod
	elseif speedsUp then
		return base * factor
	end
	return base
end

-- The point of an ellipse (centre cx/cz, radii rx/rz) at `angle` radians (0 = +x, π/2 = +z).
function Rhythm.ellipse(cx: number, cz: number, rx: number, rz: number, angle: number): (number, number)
	return cx + math.cos(angle) * rx, cz + math.sin(angle) * rz
end

-- Shortest distance from point p to the segment a–b (2D).
function Rhythm.segmentDistance(
	px: number,
	pz: number,
	ax: number,
	az: number,
	bx: number,
	bz: number
): number
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = 0
	if len2 > 1e-12 then
		t = math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1)
	end
	local qx, qz = ax + dx * t, az + dz * t
	return math.sqrt((px - qx) ^ 2 + (pz - qz) ^ 2)
end

-- Is floor point (px, pz) inside the clock beam: within `width` of the line from the centre to the ellipse?
function Rhythm.beamHit(
	px: number,
	pz: number,
	cx: number,
	cz: number,
	rx: number,
	rz: number,
	angle: number,
	width: number
): boolean
	local ex, ez = Rhythm.ellipse(cx, cz, rx, rz, angle)
	return Rhythm.segmentDistance(px, pz, cx, cz, ex, ez) <= width
end

-- A light meter: fills to 1 in `fillSeconds` while lit (× rate), drains at `decay` per second otherwise.
function Rhythm.meter(
	value: number,
	dt: number,
	lit: boolean,
	fillSeconds: number,
	rate: number,
	decay: number
): number
	if lit then
		return math.min(1, value + dt * rate / math.max(0.05, fillSeconds))
	end
	return math.max(0, value - dt * decay)
end

return Rhythm
