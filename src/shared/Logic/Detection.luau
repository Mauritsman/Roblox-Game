--!strict
-- Seeing and being seen (beta-spec §3.1). Pure maths for GuardService, CameraService and snitches.
-- The meter fills in `fillSeconds`: 0.8 s right in front of the guard up to 2.0 s at the edge of the range.
-- Factors are fill RATES and multiply: crouch ×0.5 · medium ×1.25 · heavy ×1.5 · Sleepy Guards ×0.7 ·
-- Lockdown ×1.33 · difficulty tier. A rate of 2 halves the time.

local Detection = {}

Detection.DEFAULT_NEAR = 0.8 -- = Config.Guard.FillSecondsNear
Detection.DEFAULT_FAR = 2.0 -- = Config.Guard.FillSecondsFar

export type Vec3 = { x: number, y: number, z: number }

export type FactorFlags = {
	crouching: boolean?,
	carryClass: string?, -- "Small" | "Medium" | "Heavy" | "Main" | nil
	sleepyGuards: boolean?,
	lockdown: boolean?,
	tierFillRate: number?, -- Config.DifficultyTiers.Tiers[tier].FillRate
	extra: number?, -- any other factor, e.g. a snitch's fill (Karel ×0.5)
}

export type Rates = {
	CrouchFillRate: number,
	CarryFillRate: { Medium: number, Heavy: number },
	LockdownFillRate: number,
	SleepyFillRate: number,
}

export type Ranges = {
	RangeLit: number,
	RangeDark: number,
	FlashlightRange: number,
}

export type Target = {
	activity: string?, -- player attribute Activity; only "Crew" can be seen
	caught: boolean?,
	hidden: boolean?,
	immuneUntil: number?,
	masked: boolean?, -- false = unmasked (Mask Up): ignored. nil = treated as masked
}

-- Product of all factors (an empty or missing table = 1).
function Detection.multiply(factors: { [any]: number }?): number
	local product = 1
	if factors then
		for _, factor in factors do
			product *= factor
		end
	end
	return product
end

-- Seconds to fill the meter from 0 to 1. Outside the range (or a zero rate) it never fills: math.huge.
function Detection.fillSeconds(
	distance: number,
	range: number,
	factors: { [any]: number }?,
	near: number?,
	far: number?
): number
	if range <= 0 or distance > range then
		return math.huge
	end
	local nearSeconds = near or Detection.DEFAULT_NEAR
	local farSeconds = far or Detection.DEFAULT_FAR
	local t = math.clamp(distance / range, 0, 1)
	local seconds = nearSeconds + (farSeconds - nearSeconds) * t
	local rate = Detection.multiply(factors)
	if rate <= 0 then
		return math.huge
	end
	return seconds / rate
end

-- Meter gained per second (0 when it never fills).
function Detection.fillRate(
	distance: number,
	range: number,
	factors: { [any]: number }?,
	near: number?,
	far: number?
): number
	local seconds = Detection.fillSeconds(distance, range, factors, near, far)
	if seconds == math.huge then
		return 0
	end
	return 1 / seconds
end

-- The list of factors for one viewer looking at one player.
function Detection.factorsFor(flags: FactorFlags, rates: Rates): { number }
	local factors = {}
	local class = flags.carryClass
	local handsFull = class == "Medium" or class == "Heavy" or class == "Main"
	if flags.crouching and not handsFull then
		table.insert(factors, rates.CrouchFillRate)
	end
	if class == "Medium" then
		table.insert(factors, rates.CarryFillRate.Medium)
	elseif class == "Heavy" or class == "Main" then
		table.insert(factors, rates.CarryFillRate.Heavy)
	end
	if flags.sleepyGuards then
		table.insert(factors, rates.SleepyFillRate)
	end
	if flags.lockdown then
		table.insert(factors, rates.LockdownFillRate)
	end
	if flags.tierFillRate then
		table.insert(factors, flags.tierFillRate)
	end
	if flags.extra then
		table.insert(factors, flags.extra)
	end
	return factors
end

-- Alarm tier for a number of points: how many thresholds are reached (0 .. #thresholds).
function Detection.levelFor(points: number, thresholds: { number }): number
	local level = 0
	for index, threshold in thresholds do
		if points >= threshold then
			level = index
		end
	end
	return level
end

-- Vision range: lit 35, dark 18; during a Power Cut every lamp is off but the flashlight reaches 22.
function Detection.rangeFor(lit: boolean, powerCut: boolean, ranges: Ranges): number
	if powerCut then
		return ranges.FlashlightRange
	end
	return if lit then ranges.RangeLit else ranges.RangeDark
end

-- Is `target` inside the cone (half angle in degrees) and range? `forward` need not be normalised.
-- Line of sight (walls) is the caller's job (raycast).
function Detection.inCone(
	eye: Vec3,
	forward: Vec3,
	target: Vec3,
	halfAngleDegrees: number,
	range: number
): boolean
	local dx, dy, dz = target.x - eye.x, target.y - eye.y, target.z - eye.z
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
	if distance > range then
		return false
	end
	if distance < 1e-6 then
		return true
	end
	local flen = math.sqrt(forward.x * forward.x + forward.y * forward.y + forward.z * forward.z)
	if flen < 1e-6 then
		return false
	end
	local cos = (dx * forward.x + dy * forward.y + dz * forward.z) / (distance * flen)
	return cos >= math.cos(math.rad(halfAngleDegrees))
end

-- Players guards, cameras and snitches ignore. Returns (ignored, reason).
function Detection.isIgnored(target: Target, now: number): (boolean, string?)
	if target.caught then
		return true, "Caught"
	elseif target.hidden then
		return true, "Hidden"
	elseif target.activity ~= "Crew" then
		return true, "NotCrew"
	elseif target.immuneUntil and now < target.immuneUntil then
		return true, "Immune"
	elseif target.masked == false then
		return true, "Unmasked"
	end
	return false, nil
end

return Detection
