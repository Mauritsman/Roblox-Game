--!strict
-- Getting caught (beta-spec §3.4): grab → carried → cell → rescue or self-escape. Pure rules for CaptureService
-- and GuardService.
--   * Grab: an Alert guard within `range` (3.5) of his target for `seconds` (1.0) without a break.
--   * Hero moment: a Bubble on the carrying guard always drops the captive; a Noisemaker only within its radius.
--   * Self-escape: once per round (Easy: twice), `after` seconds after being celled (perk Escape Artist: 12).
--   * All caught: every crew member caught (an empty crew is never "all caught").

local Capture = {}

-- One step of the grab timer. Returns (progress, grabbed). Leaving the range resets the timer.
function Capture.grabStep(
	progress: number,
	dt: number,
	distance: number,
	range: number,
	seconds: number
): (number, boolean)
	if distance > range then
		return 0, false
	end
	local next = progress + dt
	return next, next >= seconds - 1e-6 -- tolerate float sums (10 × 0.1 s)
end

-- Grab reach (bug B-007): the horizontal distance from the guard to his target, or math.huge when the height
-- difference `dy` is more than `vertical` (another floor). A 3D distance let a guard who ended up standing on a
-- player's head stay "out of reach" (4.1 > 3.5) forever.
function Capture.reach(dx: number, dy: number, dz: number, vertical: number): number
	if math.abs(dy) > vertical then
		return math.huge
	end
	return math.sqrt(dx * dx + dz * dz)
end

-- Does this make a carrying guard drop his captive? kind = "bubble" | "noisemaker".
function Capture.heroDrop(kind: string, distance: number, noisemakerRadius: number): boolean
	if kind == "bubble" then
		return true
	elseif kind == "noisemaker" then
		return distance <= noisemakerRadius
	end
	return false
end

-- When CRAWL OUT unlocks for someone celled at `celledAt`; nil when no self-escapes are left.
function Capture.selfEscapeAt(celledAt: number, after: number, used: number, allowed: number): number?
	if used >= allowed then
		return nil
	end
	return celledAt + after
end

export type CrawlCheck = {
	captured: string?, -- character attribute Captured
	selfEscapeAt: number?,
	used: number,
	allowed: number,
}

-- May this player crawl out of the cell now? Returns (ok, reason).
function Capture.canCrawlOut(check: CrawlCheck, now: number): (boolean, string?)
	if check.captured ~= "Cell" then
		return false, "NotInCell"
	elseif check.used >= check.allowed then
		return false, "NoneLeft"
	elseif check.selfEscapeAt == nil then
		return false, "NotYet"
	elseif now < check.selfEscapeAt then
		return false, "NotYet"
	end
	return true, nil
end

-- Every flag true (and at least one).
function Capture.allCaught(caught: { boolean }): boolean
	if #caught == 0 then
		return false
	end
	for _, flag in caught do
		if not flag then
			return false
		end
	end
	return true
end

-- First free index 1..count in `occupied` (a map index → anything); nil when all are taken.
function Capture.freeSpot(occupied: { [number]: any }, count: number): number?
	for index = 1, count do
		if occupied[index] == nil then
			return index
		end
	end
	return nil
end

return Capture
