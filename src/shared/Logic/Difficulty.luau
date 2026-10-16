--!strict
-- Difficulty tiers per job (beta-spec §7.1, advisor: Easy / Normal / Hard). A tier row comes from
-- Config.DifficultyTiers.Tiers. `base` holds the round's Normal numbers (see Difficulty.base).
--   * rates multiply:        fillRate × FillRate, alarmPointsFactor × AlarmPoints
--   * counts add:            extraGuards + ExtraGuards
--   * seconds/counts replace: cameraFillSeconds, lockdownSeconds, selfEscapes, deviceSeconds
--   * radioChecks:           only when both base and tier allow them (Easy has none)
-- Payout multipliers and unlock rules are meta's (Config.Economy.DifficultyPayout, Config.Progression).

local Difficulty = {}

export type Tier = {
	FillRate: number,
	ExtraGuards: number,
	CameraFillSeconds: number,
	AlarmPoints: number,
	LockdownSeconds: number,
	SelfEscapes: number,
	RadioChecks: boolean,
	DeviceSeconds: number,
}

export type Tiers = {
	Default: string,
	Order: { string },
	Tiers: { [string]: Tier },
}

export type Round = {
	fillRate: number,
	extraGuards: number,
	cameraFillSeconds: number,
	alarmPointsFactor: number,
	lockdownSeconds: number,
	selfEscapes: number,
	radioChecks: boolean,
	deviceSeconds: number,
}

-- The round without a tier (also the mini-job), built from the Config table.
function Difficulty.base(config: any): Round
	return {
		fillRate = 1,
		extraGuards = 0,
		cameraFillSeconds = config.SecurityCamera.BaseFillSeconds,
		alarmPointsFactor = 1,
		lockdownSeconds = config.Alarm.LockdownSeconds,
		selfEscapes = config.Capture.SelfEscapes,
		radioChecks = true,
		deviceSeconds = config.Objectives.DeviceSeconds,
	}
end

-- The tier row for a name; unknown or missing names fall back to the default tier. Returns (row, name).
function Difficulty.tier(tiers: Tiers, name: string?): (Tier, string)
	if name and tiers.Tiers[name] then
		return tiers.Tiers[name], name
	end
	return tiers.Tiers[tiers.Default], tiers.Default
end

function Difficulty.apply(base: Round, tier: Tier): Round
	return {
		fillRate = base.fillRate * tier.FillRate,
		extraGuards = base.extraGuards + tier.ExtraGuards,
		cameraFillSeconds = tier.CameraFillSeconds,
		alarmPointsFactor = base.alarmPointsFactor * tier.AlarmPoints,
		lockdownSeconds = tier.LockdownSeconds,
		selfEscapes = tier.SelfEscapes,
		radioChecks = base.radioChecks and tier.RadioChecks,
		deviceSeconds = tier.DeviceSeconds,
	}
end

-- Alarm points after the tier factor, rounded half up (Easy: 10 → 8, Hard: 10 → 13).
function Difficulty.scalePoints(points: number, factor: number): number
	return math.floor(points * factor + 0.5)
end

return Difficulty
