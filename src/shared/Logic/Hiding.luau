--!strict
-- Hiding spots (beta-spec §4.1, advisor §13): barrels, crates, lockers. One player per spot, 0.5 s in and out,
-- empty hands or pocket (small) loot only. Shake at `warnAt` (15 s), ACHOO at `sneezeAt` (20 s; perk Barrel Lungs
-- 25 s), then a re-entry lockout (5 s). A guard who saw you get in (meter ≥ 0.35 or chasing you) walks over and
-- pulls you out: a normal grab.

local Hiding = {}

export type HideCheck = {
	activity: string?, -- player attribute Activity ("Crew" | "Tutorial" may hide)
	caught: boolean?,
	hidden: boolean?,
	carryClass: string?, -- character attribute CarryClass: Medium / Heavy / Main fill your hands
	operating: boolean?, -- flying a drone
	lockoutUntil: number?,
	occupied: boolean?, -- the spot already holds someone
}

-- May this player hide now? Returns (ok, reason). Reasons double as the toast key for ux.
function Hiding.canHide(check: HideCheck, now: number): (boolean, string?)
	if check.activity ~= nil and check.activity ~= "Crew" and check.activity ~= "Tutorial" then
		return false, "NotInRound"
	elseif check.caught then
		return false, "Caught"
	elseif check.hidden then
		return false, "AlreadyHidden"
	elseif check.carryClass == "Medium" or check.carryClass == "Heavy" or check.carryClass == "Main" then
		return false, "HandsFull"
	elseif check.operating then
		return false, "Busy"
	elseif check.occupied then
		return false, "Taken"
	elseif check.lockoutUntil and now < check.lockoutUntil then
		return false, "TooSoon"
	end
	return true, nil
end

export type Phase = "Hidden" | "Warn" | "Sneeze"

-- Where in the hiding timeline someone who entered at `enteredAt` is.
function Hiding.phase(enteredAt: number, now: number, warnAt: number, sneezeAt: number): Phase
	local inside = now - enteredAt
	if inside >= sneezeAt then
		return "Sneeze"
	elseif inside >= warnAt then
		return "Warn"
	end
	return "Hidden"
end

-- HideExit is accepted only after the 0.5 s entry.
function Hiding.canExit(enteredAt: number, now: number, minSeconds: number): boolean
	return now - enteredAt >= minSeconds
end

-- Did this guard see you get in?
function Hiding.isWitness(meter: number, chasing: boolean, threshold: number): boolean
	return chasing or meter >= threshold
end

-- Toast text per refusal reason (≤ 5 words).
Hiding.REFUSALS = table.freeze({
	NotInRound = "Not now",
	Caught = "You are caught",
	AlreadyHidden = "Already hiding",
	HandsFull = "Hands full!",
	Busy = "Busy",
	Taken = "Someone is inside",
	TooSoon = "Catch your breath first",
} :: { [string]: string })

return Hiding
