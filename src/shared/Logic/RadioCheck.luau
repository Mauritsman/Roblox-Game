--!strict
-- Radio checks (beta-spec §7.3, advisor): 4 s after a guard is bubbled his radio squawks "Unit 3, report!". A crew
-- member holds "Answer" for 2 s within 6 s → that bubble costs no alarm points (the +10 prank points are waived).
-- Missed → +40 (instead of +10). Max 2 answers per round for the whole crew; after that every bubble costs +40.
-- Only on Normal and Hard (`enabled`); otherwise a bubble costs the usual +10 when it pops.
--
-- ObjectiveService keeps one State per round and calls these with server times; every call returns the alarm
-- points to add right now (0 when nothing is due). Guards are identified by any string id.
--   bubbled(s, id, now)  → starts a check (nil when off or one is already running for this guard)
--   due(s, now)          → the ids whose radio squawks now
--   squawk(s, id, now)   → "Window" (crew may answer until endsAt) or "NoAnswers" (+40 at once)
--   answer(s, id, now)   → true when it counted
--   expire(s, now)       → the ids that ran out of time (each +40)
--   popped(s, id)        → points when the bubble pops (+10 without a check, else 0: the check decides)

local RadioCheck = {}

export type Rules = {
	delay: number, -- RadioDelay
	window: number, -- RadioWindow
	maxAnswers: number, -- RadioMaxAnswers
	missPoints: number, -- RadioMissPoints
	prankPoints: number, -- Config.Alarm.Points.PrankUsed
}

export type Check = {
	stage: string, -- "Waiting" (before the squawk) | "Window" | "Answered" | "Missed"
	squawkAt: number,
	endsAt: number?,
	popped: boolean,
}

export type State = {
	enabled: boolean,
	rules: Rules,
	answersLeft: number,
	checks: { [string]: Check },
}

function RadioCheck.rulesFrom(config: any): Rules
	local o = config.Objectives
	return {
		delay = o.RadioDelay,
		window = o.RadioWindow,
		maxAnswers = o.RadioMaxAnswers,
		missPoints = o.RadioMissPoints,
		prankPoints = config.Alarm.Points.PrankUsed or 10,
	}
end

function RadioCheck.new(enabled: boolean, rules: Rules): State
	return { enabled = enabled, rules = rules, answersLeft = rules.maxAnswers, checks = {} }
end

local function open(check: Check?): boolean
	return check ~= nil and (check.stage == "Waiting" or check.stage == "Window")
end

-- A guard was bubbled. Returns the squawk time, or nil (radio checks off, or one already runs for him).
function RadioCheck.bubbled(s: State, id: string, now: number): number?
	if not s.enabled or open(s.checks[id]) then
		return nil
	end
	local squawkAt = now + s.rules.delay
	s.checks[id] = { stage = "Waiting", squawkAt = squawkAt, endsAt = nil, popped = false }
	return squawkAt
end

-- Ids whose radio should squawk now (sorted, so the order is stable).
function RadioCheck.due(s: State, now: number): { string }
	local list = {}
	for id, check in s.checks do
		if check.stage == "Waiting" and now >= check.squawkAt then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

-- The radio squawks. Returns (result, points): "Window" with 0 points (answer until check.endsAt), or
-- "NoAnswers" with missPoints (no answers left this round). nil when there is no waiting check.
function RadioCheck.squawk(s: State, id: string, now: number): (string?, number)
	local check = s.checks[id]
	if not check or check.stage ~= "Waiting" then
		return nil, 0
	end
	if s.answersLeft <= 0 then
		check.stage = "Missed"
		return "NoAnswers", s.rules.missPoints
	end
	check.stage = "Window"
	check.endsAt = now + s.rules.window
	return "Window", 0
end

-- Someone finished holding "Answer". True when it counted (inside the window, answers left).
function RadioCheck.answer(s: State, id: string, now: number): boolean
	local check = s.checks[id]
	if not check or check.stage ~= "Window" or s.answersLeft <= 0 then
		return false
	end
	if check.endsAt and now > check.endsAt then
		return false
	end
	check.stage = "Answered"
	s.answersLeft -= 1
	return true
end

-- Windows that ran out. Returns (ids, points): every id costs missPoints.
function RadioCheck.expire(s: State, now: number): ({ string }, number)
	local list = {}
	for id, check in s.checks do
		if check.stage == "Window" and check.endsAt and now > check.endsAt then
			check.stage = "Missed"
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list, #list * s.rules.missPoints
end

-- The bubble popped. Returns the points due now: the usual prank points when no check covers this bubble
-- (radio checks off, or a second bubble during the same check), else 0: an answered check waives them, a
-- missed one already cost missPoints or will when its window runs out.
function RadioCheck.popped(s: State, id: string): number
	local check = s.checks[id]
	if not check or check.popped then
		return s.rules.prankPoints
	end
	check.popped = true
	return 0
end

-- Forget finished checks of bubbles that popped (so a later bubble on the same guard starts a new check).
function RadioCheck.forget(s: State, id: string)
	local check = s.checks[id]
	if check and check.popped and not open(check) then
		s.checks[id] = nil
	end
end

function RadioCheck.isOpen(s: State, id: string): boolean
	return open(s.checks[id])
end

return RadioCheck
