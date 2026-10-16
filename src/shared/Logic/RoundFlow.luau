--!strict
-- Decisions of the round state machine (beta-spec §1.2–§1.4) as pure functions, so RoundService stays thin and
-- the rules are unit-tested. Times are server times in seconds (workspace:GetServerTimeNow()).
--   * Garage van countdown: 15 s when someone stands in the GarageVan zone, 3 s when every Garage player (or the
--     only one) is in it; it only ever gets shorter; an empty zone cancels it.
--   * HOLD TO DRIVE: free crew outside the van (or an empty van) → the first hold warns, a second hold within
--     DriveConfirmSeconds drives.
--   * Exits: QuietOnly exits close at LOCKDOWN; LockdownOnly exits open at LOCKDOWN once their ArrivesAt passed.
--   * Payout: ends after PayoutSeconds, or early once every crew member is ready and PayoutMinSeconds passed.
--   * NextJob: ends after NextJobSeconds, or early once every crew member answered.

local RoundFlow = {}

RoundFlow.PHASES = table.freeze({ "Garage", "Briefing", "Heist", "Lockdown", "Getaway", "Payout", "NextJob" })

-- New VanDepartAt (or nil = no countdown). `current` is the running departure time or nil.
function RoundFlow.departAt(
	now: number,
	current: number?,
	boarders: number,
	garagePlayers: number,
	countdown: number,
	allAboard: number
): number?
	if boarders <= 0 then
		return nil
	end
	local everyone = boarders >= garagePlayers
	local want = now + (if everyone then allAboard else countdown)
	if current == nil then
		return want
	end
	return math.min(current, want)
end

-- "Warn" or "Drive". `outsideFree` = free crew members outside every escape zone; `lastWarnAt` = when this driver
-- was last warned (nil = never); `vanLoot` = banked value (an empty van also asks twice).
function RoundFlow.driveDecision(
	outsideFree: number,
	vanLoot: number,
	lastWarnAt: number?,
	now: number,
	confirmSeconds: number
): string
	if outsideFree <= 0 and vanLoot > 0 then
		return "Drive"
	end
	if lastWarnAt ~= nil and now - lastWarnAt <= confirmSeconds then
		return "Drive"
	end
	return "Warn"
end

export type ExitRules = {
	quietOnly: boolean?,
	lockdownOnly: boolean?,
	arrivesAt: number?, -- server time the lockdown exit arrives (nil = at once)
}

-- Can players bank, count as "in the van" and drive at this exit right now?
function RoundFlow.exitUsable(rules: ExitRules, lockdown: boolean, now: number): boolean
	if rules.quietOnly and lockdown then
		return false
	end
	if rules.lockdownOnly then
		if not lockdown then
			return false
		end
		if rules.arrivesAt ~= nil and now < rules.arrivesAt then
			return false
		end
	end
	return true
end

-- Police time: anyone free in an escape zone means the crew escaped (the rest count as caught).
function RoundFlow.policeOutcome(freeInVan: number): string
	return if freeInVan > 0 then "Escaped" else "Busted"
end

function RoundFlow.payoutDone(
	elapsed: number,
	ready: number,
	crew: number,
	minSeconds: number,
	maxSeconds: number
): boolean
	if elapsed >= maxSeconds then
		return true
	end
	return crew > 0 and ready >= crew and elapsed >= minSeconds
end

function RoundFlow.nextJobDone(elapsed: number, answered: number, crew: number, maxSeconds: number): boolean
	if elapsed >= maxSeconds then
		return true
	end
	return crew > 0 and answered >= crew
end

-- Lockdown reasons as sent in the `Lockdown` message: "MainLoot" | "Alarm" | "Dev".
function RoundFlow.lockdownReason(raw: string?): string
	local lower = string.lower(raw or "")
	if lower == "main" or lower == "mainloot" or lower == "gouda" then
		return "MainLoot"
	elseif lower == "alarm" then
		return "Alarm"
	end
	return "Dev"
end

export type Job = {
	cardId: string?,
	heistId: string?,
	difficulty: string?,
	modifierId: string?,
	isHotJob: boolean?,
}

-- A safe job: unknown heists fall back to `defaultHeist`, unknown tiers to `defaultTier`, unknown modifiers to nil.
function RoundFlow.sanitizeJob(
	job: Job?,
	heists: { [string]: any },
	tiers: { [string]: any },
	modifiers: { [string]: any },
	defaultHeist: string,
	defaultTier: string
): Job
	local raw: Job = job or {}
	local heistId = if type(raw.heistId) == "string" and heists[raw.heistId] ~= nil
		then raw.heistId
		else defaultHeist
	local difficulty = if type(raw.difficulty) == "string" and tiers[raw.difficulty] ~= nil
		then raw.difficulty
		else defaultTier
	local modifierId = if type(raw.modifierId) == "string" and modifiers[raw.modifierId] ~= nil
		then raw.modifierId
		else nil
	return {
		cardId = if type(raw.cardId) == "string" then raw.cardId else heistId,
		heistId = heistId,
		difficulty = difficulty,
		modifierId = modifierId,
		isHotJob = raw.isHotJob == true,
	}
end

-- Round length: the heist's RoundSeconds (or the default), Rush Job overrides it.
function RoundFlow.roundSeconds(
	default: number,
	heistSeconds: number?,
	modifierId: string?,
	rushSeconds: number?
): number
	if modifierId == "RushJob" and rushSeconds then
		return rushSeconds
	end
	return heistSeconds or default
end

-- Positions around a centre for `count` players (ring of `radius`), as {x, z} offsets; the first is the centre.
function RoundFlow.ringOffsets(count: number, radius: number): { { x: number, z: number } }
	local list = {}
	for index = 1, count do
		if index == 1 then
			table.insert(list, { x = 0, z = 0 })
		else
			local angle = (index - 2) / math.max(1, count - 1) * math.pi * 2
			table.insert(list, { x = math.cos(angle) * radius, z = math.sin(angle) * radius })
		end
	end
	return list
end

return RoundFlow
