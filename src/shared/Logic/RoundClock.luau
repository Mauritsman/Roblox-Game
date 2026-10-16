--!strict
-- The round's clock (beta-spec §1.3). All times are in the same unit as `now` (server time in seconds).
-- * The round ends at startedAt + roundSeconds (hard cap, 480 s; Rush Job 360 s).
-- * LOCKDOWN (Gouda lifted or alarm tier 3) starts once: police at min(round end, lockdown + lockdownSeconds).
-- * SHIFT CHANGE at round end − shiftWarningSeconds, only if no lockdown started before it. A lockdown during the
--   shift change keeps the earlier police time.
-- A round without a cap (the mini-job) passes roundSeconds = math.huge.

local RoundClock = {}

RoundClock.DEFAULT_SHIFT_WARNING = 60 -- = Config.Round.ShiftWarningSeconds

export type Status = {
	elapsed: number,
	roundEndsAt: number,
	policeAt: number, -- the one HUD timer
	lockdownEndsAt: number?,
	shiftChangeAt: number?, -- nil when a lockdown started first, or without a cap
	shiftChange: boolean, -- the shift change is running now
	lockdown: boolean, -- a lockdown has started
	remaining: number, -- seconds until the police, ≥ 0
	over: boolean, -- police time reached
}

function RoundClock.status(
	now: number,
	startedAt: number,
	roundSeconds: number,
	lockdownAt: number?,
	lockdownSeconds: number,
	shiftWarningSeconds: number?
): Status
	local roundEndsAt = startedAt + roundSeconds
	local policeAt = roundEndsAt
	local lockdownEndsAt: number? = nil
	if lockdownAt then
		local ends = lockdownAt + lockdownSeconds
		lockdownEndsAt = ends
		policeAt = math.min(roundEndsAt, ends)
	end

	local shiftChangeAt: number? = nil
	if roundEndsAt ~= math.huge then
		local at = roundEndsAt - (shiftWarningSeconds or RoundClock.DEFAULT_SHIFT_WARNING)
		if lockdownAt == nil or lockdownAt >= at then
			shiftChangeAt = at
		end
	end

	local remaining = math.max(0, policeAt - now)
	return {
		elapsed = now - startedAt,
		roundEndsAt = roundEndsAt,
		policeAt = policeAt,
		lockdownEndsAt = lockdownEndsAt,
		shiftChangeAt = shiftChangeAt,
		shiftChange = shiftChangeAt ~= nil and now >= shiftChangeAt and now < policeAt,
		lockdown = lockdownAt ~= nil and now >= lockdownAt,
		remaining = remaining,
		over = now >= policeAt,
	}
end

-- JUMP IN (late joiners): while the round is younger than jumpInSeconds and the crew is not full.
function RoundClock.canJumpIn(
	now: number,
	startedAt: number,
	jumpInSeconds: number,
	crew: number,
	maxCrew: number
)
	return now >= startedAt and now - startedAt < jumpInSeconds and crew < maxCrew
end

-- "JUST MADE IT!": escaped with at most `seconds` left before the police.
function RoundClock.justMadeIt(now: number, policeAt: number, seconds: number): boolean
	local left = policeAt - now
	return left >= 0 and left <= seconds
end

return RoundClock
