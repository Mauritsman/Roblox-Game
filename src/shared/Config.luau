--!strict
-- Alle afstelbare getallen op één plek (bron: docs/gameplan-roblox.md).
-- Pas waarden hier aan na speeltests, niet verspreid door de code.
-- Afstanden in studs, tijden in seconden.

local Config = {}

Config.Version = "0.2.0-fase1"

-- Het venster (§3.3): gedeelde toestand op de server, voor iedereen even lang.
Config.Difficulty = "Normal" -- "Rookie" | "Normal" | "Pro"
Config.WindowSeconds = {
	Rookie = 12,
	Normal = 10,
	Pro = 8,
}
Config.SoloExtraWindow = 2

-- Gadgetvakken per crewgrootte (§3.7).
Config.SlotsByCrewSize = { 3, 2, 2, 1 }

-- Gadgets (§4). Step = welke stap van de keten.
Config.Gadgets = {
	Drone = {
		Step = "EYES",
		Charges = 1,
		Range = 45, -- maximale afstand tot het lichaam van de bestuurder
		BatterySeconds = 40,
		RechargeSeconds = 20,
		Speed = 18,
		AutoSpotSeconds = 0.5,
		DogGrabHeight = 5,
	},
	Noisemaker = {
		Step = "CLEAR",
		Charges = 3,
		ThrowRange = 40,
		RingSeconds = 6,
		HearRadius = 20,
		RepeatWindow = 30, -- tweede worp op dezelfde plek binnen deze tijd = verdacht
		RepeatDistance = 8,
	},
	EMP = {
		Step = "CLEAR",
		Charges = 2,
		ThrowRange = 40,
		Radius = 14,
		Cooldown = 30,
		BzztRadius = 10,
	},
	Crowbar = {
		Step = "OPEN",
		Charges = math.huge,
		DoorSeconds = 1.5,
		CageSeconds = 3,
		CrackRadius = 25,
	},
}
Config.GadgetOrder = { "Drone", "Noisemaker", "EMP", "Crowbar" }

-- Bewakers (§9.1).
Config.Guard = {
	ConeHalfAngle = 35, -- graden (kegel van 70°)
	RangeLit = 35,
	RangeDark = 18,
	FillSecondsNear = 0.6,
	FillSecondsFar = 1.9,
	CrouchFillMultiplier = 2,
	DecayPerSecond = 0.5,
	SuspiciousAt = 0.35,
	SearchSeconds = 8,
	AlertSearchSeconds = 15,
	CaptureDistance = 3.5,
	PatrolSpeed = 6,
	InvestigateSpeed = 9,
	ChaseSpeed = 14,
	VisionInterval = 0.1,
	HeadHeight = 2.5,
}

-- Beveiligingscamera's (§9.3).
Config.SecurityCamera = {
	SweepDegrees = 90,
	SweepSeconds = 6,
	ConeHalfAngle = 25,
	Range = 38,
	FillSeconds = { Rookie = 3, Normal = 2, Pro = 2 },
}

-- Alarmladder (§9.5).
Config.Alarm = {
	Points = {
		CameraSpotted = 40,
		GuardAlert = 40,
		CrackHeard = 20,
		NoisemakerRepeat = 15,
		TraceFound = 20,
	},
	LevelThresholds = { 100, 200, 300 }, -- trede 1, 2, 3
	LevelNames = { [0] = "QUIET", [1] = "SUSPICIOUS", [2] = "SEARCHING", [3] = "LOCKDOWN" },
	LockdownSeconds = 90,
	RookieMultiplier = 0.5,
}

-- Spelers.
Config.Player = {
	WalkSpeed = 16,
	CrouchSpeed = 8,
}

-- Pings en Chain Call (§3.4–3.5).
Config.Ping = {
	SpotMaxPerWindow = 3,
	SpotWindowSeconds = 2,
	SpotDurationDefault = 8,
	SpotDurationTracked = 5,
	QuickCooldown = 2, -- verhoog naar 10 als Roblox dit als preset-bericht beschouwt
	QuickPresets = { "NOW", "WAIT" },
	MaxRange = 300,
}
Config.ChainCall = {
	JoinSeconds = 6,
	Cooldown = 5,
	CountdownSeconds = 3,
	Steps = { "EYES", "CLEAR", "OPEN" },
}

function Config.windowSeconds(crewSize: number): number
	local base = Config.WindowSeconds[Config.Difficulty] or 10
	if crewSize <= 1 then
		base += Config.SoloExtraWindow
	end
	return base
end

function Config.slotsFor(crewSize: number): number
	local clamped = math.clamp(crewSize, 1, #Config.SlotsByCrewSize)
	return Config.SlotsByCrewSize[clamped]
end

return Config
