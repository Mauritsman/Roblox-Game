--!strict
-- Timed motions of map set pieces (rising plinths, an arriving balloon, a departing barge): progress and easing.

local Motion = {}

-- 0 before `startAt`, 1 after startAt + duration, linear in between.
function Motion.progress(now: number, startAt: number, duration: number): number
	if duration <= 0 then
		return if now >= startAt then 1 else 0
	end
	return math.clamp((now - startAt) / duration, 0, 1)
end

-- Fast start, gentle stop (arrivals, plinths).
function Motion.easeOut(t: number): number
	local x = math.clamp(t, 0, 1)
	return 1 - (1 - x) ^ 3
end

-- Gentle start and stop.
function Motion.easeInOut(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Gentle start, fast end (departures).
function Motion.easeIn(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x
end

-- When an exit that arrives `arrivesAfter` s into LOCKDOWN starts its approach (it travels `travel` s, never
-- starting before the lockdown).
function Motion.approachStart(lockdownAt: number, arrivesAfter: number, travel: number): number
	return lockdownAt + math.max(0, arrivesAfter - travel)
end

return Motion
