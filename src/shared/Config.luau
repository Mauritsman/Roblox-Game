--!strict
-- All tunable numbers in one place. Distances in studs, times in seconds.
-- Sources: docs/beta-spec.md §9.5 with the advisor's final decisions (beta-spec §13), beta-spec-meta.md §8.3.
-- Adjust values here after playtests, not scattered through the code.
--
-- Shared file: every role edits only inside its own block (see docs/team/README.md).
-- "DEPRECATED (WP Mx)" = still read by prototype code; that mechanics work package removes it.

local Config = {}

Config.Version = "0.2.0-phase1"

-- =======================================================================================================
-- MECHANICS block (owner: mechanics)
-- =======================================================================================================

export type LootType = {
	Class: string, -- "Small" | "Medium" | "Heavy" | "Main"
	Value: number, -- base value (Cash)
	Display: string?, -- name shown to players (LootName)
	Smelly: boolean?, -- Boef smells it
	Rare: boolean?,
	RareSwap: string?, -- RareChance to become this type instead
	CanRoll: boolean?,
	Lockdown: boolean?, -- lifting it starts LOCKDOWN
	Objective: boolean?, -- keycard etc.: never banked for Cash
	Fragile: boolean?,
	FragilePenalty: number?, -- per uncaught landing, overrides Config.Loot.FragilePenalty
	Melts: boolean?, -- maps 2–3 (chocolate)
}

export type DifficultyTier = {
	Subtitle: string,
	FillRate: number, -- guard meter fill-rate factor
	ExtraGuards: number, -- within the NPC cap
	CameraFillSeconds: number,
	AlarmPoints: number, -- alarm points factor
	LockdownSeconds: number,
	SelfEscapes: number,
	RadioChecks: boolean,
	DeviceSeconds: number, -- Cheese Grater 3000 run time
}

export type PerkEffect = {
	Stat: string, -- key in Logic/Perks Stats
	Set: number?, -- absolute value
	Add: number?,
	Mul: number?,
}

-- ---------- Round flow (beta-spec §1) ----------
Config.Round = {
	RoundSeconds = 480, -- hard cap 8:00 (Rush Job: Config.Modifiers.RushJob)
	ShiftWarningSeconds = 60, -- "SHIFT CHANGE IN 60" at RoundSeconds − this
	GarageCountdown = 15, -- someone stands in the GarageVan zone
	AllAboardCountdown = 3, -- every Garage player in the zone, or solo
	BriefingSeconds = 5,
	StreamTimeout = 5, -- RequestStreamAroundAsync before teleports
	DriveHoldSeconds = 3,
	DriveConfirmSeconds = 5, -- second hold within this time drives despite free crew outside
	GetawaySeconds = 4,
	JustMadeItSeconds = 5,
	PayoutSeconds = 30,
	PayoutMinSeconds = 8,
	NextJobSeconds = 10,
	JumpInSeconds = 120,
	BustedDelay = 1.5,
	MaxCrew = 4,
}

-- ---------- Movement (only MovementService writes WalkSpeed/JumpHeight; per-player via StatsOf) ----------
Config.Movement = {
	Walk = 16,
	Crouch = 8,
	Medium = 12,
	HeavySolo = 7,
	HeavyRoll = 11,
	TwoCarry = 12,
	Jump = 7.2,
	MediumJump = 3.5,
	HeavyJump = 2, -- (proposed) a small hop over thresholds, never over obstacles
	SlipSeconds = 1,
}

-- ---------- Loot (beta-spec §2) ----------
Config.Loot = {
	GrabRange = 6, -- prompt distance and "Help carry" range
	HeavyGrabHold = 0.3,
	PocketSlots = 3,
	RareChance = 0.05,
	RareMax = 1,
	ReturnDelay = 30, -- Karel returns dropped loot after this
	BankCheckInterval = 0.2,
	FragilePenalty = 0.25, -- of base value per uncaught landing
	FragileMinFactor = 0.25, -- floor: 25% of base value
	ThudRadius = 12,
	SplashReturn = 3,
	PracticeReturn = 10,
	TeleportGuardStuds = 40, -- carrier root moves more than this in 0.5 s → loot drops
	Types = {
		CheeseCube = { Class = "Small", Value = 25, Display = "Cheese Cube", Smelly = true },
		TipJar = { Class = "Small", Value = 50, Display = "Tip Jar" },
		CashDrawer = { Class = "Small", Value = 150, Display = "Cash Drawer" },
		Keycard = { Class = "Small", Value = 0, Display = "Keycard", Objective = true },
		CheeseWheel = {
			Class = "Medium",
			Value = 150,
			Display = "Cheese Wheel",
			Smelly = true,
			RareSwap = "BlueMoon",
		},
		BlueMoon = { Class = "Medium", Value = 500, Display = "Blue Moon Cheese", Smelly = true, Rare = true },
		BigWheel = { Class = "Heavy", Value = 400, Display = "Big Wheel", Smelly = true, CanRoll = true },
		GoldenGouda = {
			Class = "Main",
			Value = 1500,
			Display = "Golden Gouda",
			Smelly = true,
			CanRoll = true,
			Lockdown = true,
		},
	} :: { [string]: LootType },
}

-- ---------- Carrying, throwing, rolling ----------
Config.Carry = {
	ThrowRange = 10,
	ThrowSpeed = 28, -- duration = distance / speed …
	ThrowMin = 0.3, -- … clamped to these seconds
	ThrowMax = 0.8,
	ThrowArc = 0.35, -- arc height = 35% of the distance …
	ThrowArcMin = 2, -- … at least this
	ThrowCooldown = 0.4,
	CatchFlight = 3.5,
	CatchLanding = 5,
	SelfCatchDelay = 0.3,
	Tether = 9, -- two-carry: further apart → helper loses grip
	RumbleRadius = 15,
	RumbleInterval = 1,
	RumbleSearch = 4,
}

-- ---------- Guards (beta-spec §3) ----------
Config.Guard = {
	ConeHalfAngle = 35, -- degrees (70° cone)
	RangeLit = 35,
	RangeDark = 18,
	FlashlightRange = 22, -- Power Cut: range inside the cone
	FillSecondsNear = 0.8, -- meter fill time right in front of the guard …
	FillSecondsFar = 2.0, -- … and at the edge of the range
	CrouchFillRate = 0.5, -- fill-rate factors multiply (Logic/Detection)
	CarryFillRate = { Medium = 1.25, Heavy = 1.5 }, -- Heavy also covers Main, rolling and two-carry
	LockdownFillRate = 1.33,
	CrouchFillMultiplier = 2, -- DEPRECATED (WP M3): use CrouchFillRate
	DecayPerSecond = 0.5,
	SuspiciousAt = 0.35,
	SeenEnteringMeter = 0.35, -- meter on you ≥ this when you hid → he walks over and pulls you out
	SearchSeconds = 8,
	AlertSearchSeconds = 15,
	LostSeconds = 3,
	CaptureDistance = 3.5, -- grab range
	GrabSeconds = 1, -- this long within grab range = grabbed
	PatrolSpeed = 6,
	Tier2PatrolSpeed = 7.5,
	InvestigateSpeed = 9,
	ChaseSpeed = 15,
	CarrySpeed = 8, -- carrying a captive to the cell
	PathRecompute = 0.5,
	LockdownRadioInterval = 8,
	CountByCrew = { 2, 3, 3, 4 }, -- base guards by crew size 1..4 (map 1)
	VisionInterval = 0.1,
	HeadHeight = 2.5,
	-- M3 (package B) additions
	NoiseSearch = { thud = 4, rumble = 4, bark = 6, sneeze = 8, squeak = 6, beep = 5, splosh = 5 }, -- search s per kind
	ArriveDistance = 2, -- horizontal distance that counts as "at the waypoint"
	FloorStep = 4, -- legs with a bigger height difference change floor (pathfinding)
	AgentRadius = 1.5, -- pathfinding (2 does not fit map 1's 5-stud doorways, bug B-002)
	AgentHeight = 5,
	SearchWander = 8, -- Search: wanders to points this far around the last known spot
	RadioSearchSeconds = 10, -- lockdown radio: search time at the radioed spot
	DroneNoticeSeconds = 1.5, -- "What's that?" after seeing a drone this long
	StuckSeconds = 3, -- not moving this long while walking → re-path or give up
}

-- ---------- Security cameras ----------
Config.SecurityCamera = {
	SweepDegrees = 90,
	SweepSeconds = 6,
	ConeHalfAngle = 25,
	Range = 38,
	BaseFillSeconds = 2, -- Normal; the difficulty tier sets CameraFillSeconds
	Tier2SweepRate = 1.3, -- (proposed) alarm tier 2: sweep 30% faster
	FillSeconds = { Rookie = 3, Normal = 2, Pro = 2 }, -- DEPRECATED (WP M3): use the difficulty tier
}

-- ---------- Alarm ladder ----------
Config.Alarm = {
	Points = {
		CameraSpotted = 40,
		GuardAlert = 40,
		CrackHeard = 20,
		NoisemakerRepeat = 15,
		PrankUsed = 10, -- a guard comes out of his bubble angry (waived when a radio check is answered)
		TraceFound = 20,
	},
	LevelThresholds = { 100, 200, 300 }, -- tier 1, 2, 3 (3 = LOCKDOWN)
	LevelNames = { [0] = "QUIET", [1] = "SUSPICIOUS", [2] = "SEARCHING", [3] = "LOCKDOWN" },
	LockdownSeconds = 60, -- Normal; the difficulty tier overrides it
	RookieMultiplier = 0.5, -- DEPRECATED (WP M3): use the difficulty tier's AlarmPoints
}

-- ---------- Gadgets (beta-spec §5): fixed durations ----------
Config.Gadgets = {
	Drone = {
		Step = "EYES", -- DEPRECATED (WP M5): Chain Call is removed
		Charges = 1,
		Range = 45, -- maximum distance from the pilot's body
		BatterySeconds = 40,
		RechargeSeconds = 20,
		Speed = 18,
		AutoSpotSeconds = 0.5,
		DogGrabHeight = 5,
	},
	Noisemaker = {
		Step = "CLEAR", -- DEPRECATED (WP M5)
		Charges = 3,
		ThrowRange = 40,
		DistractSeconds = 8,
		RingSeconds = 8,
		HearRadius = 20,
		RepeatWindow = 30, -- second throw at the same spot within this time = suspicious
		RepeatDistance = 8,
	},
	EMP = {
		Step = "CLEAR", -- DEPRECATED (WP M5)
		Charges = 2,
		ThrowRange = 40,
		Radius = 14,
		DisableSeconds = 10,
		Cooldown = 30,
		BzztRadius = 10,
	},
	-- Funny weapon (§4.8): a bubble buys time on one guard, not a solution.
	BubbleBlaster = {
		Step = "CLEAR", -- DEPRECATED (WP M5)
		Label = "BUBBLE",
		Charges = 3,
		ThrowRange = 50, -- maximum shooting distance
		ProjectileSpeed = 45,
		HitRadius = 3.5,
		BubbleSeconds = 8,
		FriendlySeconds = 3, -- if you accidentally hit a teammate
	},
	Crowbar = {
		Step = "OPEN", -- DEPRECATED (WP M5)
		Charges = math.huge,
		DoorSeconds = 1.5,
		CageSeconds = 3,
		CrackRadius = 25,
	},
}
Config.GadgetOrder = { "Drone", "Noisemaker", "EMP", "BubbleBlaster", "Crowbar" }

Config.Loadout = {
	Slots = 2, -- picks besides the Crowbar
	Pickable = { "Drone", "Noisemaker", "EMP", "BubbleBlaster" },
	Default = { "Noisemaker", "BubbleBlaster" }, -- fallback when meta has no loadout (same as meta's default)
}

-- ---------- NPCs ----------
Config.Npc = { Cap = 7 } -- guards + Karel + Boef + extras + Inspector

Config.Capture = {
	RescueHold = 2,
	SelfEscapeAfter = 15,
	SelfEscapes = 1, -- Normal; the difficulty tier overrides it
	ImmuneSeconds = 3,
	MaxCarrySeconds = 40, -- not at the cell by then → placed in the cell
	Scatter = 2, -- pocket loot scatters within this radius
	AllCaughtDelay = 1.5,
	HeroNoisemakerRadius = 20, -- a Noisemaker landing this close to a carrying guard drops the captive
	-- M3 (package B) additions
	DropoffRange = 4, -- carrying guard this close to CellDropoff → captive goes into the cell
	ViewCamCooldown = 1, -- ViewCam requests per player
	NoCellHoldSeconds = 1.2, -- map without a cell (prototype): held this long, then back to the van
}

Config.Hiding = {
	Enter = 0.5,
	Exit = 0.5,
	WarnAt = 15,
	SneezeAt = 20,
	SneezeRadius = 15,
	Reentry = 5,
	PullOut = 4, -- a guard this close pulls you out (= a normal grab, advisor)
	PromptRange = 6,
}

Config.Dog = {
	WanderSpeed = 6,
	FollowSpeed = 12,
	FollowDistance = 4,
	Smell = 15,
	BarkInterval = 2,
	BarkRadius = 30,
	EdgeBark = 3,
	TreatRange = 10,
	TreatSeconds = 12,
	NoisemakerSeconds = 8,
	NoisemakerRadius = 20,
	-- M4 (package B) additions
	GiveUpDistance = 30, -- stops following a carrier this far away
	HideBark = true, -- (proposed) barks at a hiding spot that holds smelly loot
}

Config.Karel = {
	Rest = 60,
	RestJitter = 15,
	Tier1RestFactor = 0.5,
	Speed = 7,
	Notice = 25,
	-- M4 (package B) additions
	OpenHold = 0.5, -- silent "Open" prompt on a door Karel closed
	ReachDistance = 4, -- close enough to close a door / pick up a trace
	ScanInterval = 0.5, -- looks for traces this often
	TraceTimeout = 20, -- gives up a trace he cannot reach in this time
}

Config.Snitch = {
	Range = 25,
	KarelFill = 0.5,
	InspectorFill = 0.67,
	Points = 20,
	GuardsAlerted = 2,
	Cooldown = 30, -- per player
	InspectorSpeed = 6,
}

-- ---------- Modifiers: effects only (the Hot Job pays a flat bonus: meta's Config.Economy.HotJobBonus) ----------
Config.Modifiers = {
	PowerCut = { FlashlightRange = 22 },
	HealthInspector = { Npcs = 1 },
	WetFloor = { Puddles = 6, SlipSpeed = 10, SqueakRadius = 15 },
	RushJob = { RoundSeconds = 360 },
	SleepyGuards = { FillRate = 0.7 },
	DoubleShift = { ExtraGuards = 1 },
}

-- ---------- Mini-job ----------
Config.Tutorial = {
	MaxSlots = 2,
	StirRadius = 6, -- a non-crouching player this close makes the sleeping guard stir
	WakeRange = 20,
	LockdownSeconds = 60,
	GuardChaseSpeed = 10, -- lockdown: follows but never catches (advisor)
	GuardTripDistance = 4, -- trips this far short when the player stops
}

-- ---------- §7 switches (advisor: all in the beta) ----------
Config.Features = {
	Difficulty = true,
	Objectives = true,
	LoudExtras = true, -- only the Panic Pack (+1 charge per picked gadget at LOCKDOWN)
	Perks = true,
	MaskUp = true, -- guards ignore unmasked players; the mask goes on at the first grab or StaffZone
}

-- ---------- Objectives (keycard, safe + Cheese Grater 3000, radio check) ----------
Config.Objectives = {
	BonusPct = 0.10, -- optional objective done (max 1 per heist)
	DevicePlace = 2,
	DeviceSeconds = 45, -- Normal; the difficulty tier overrides it
	DeviceJams = { 1, 2 }, -- min, max jams (seeded)
	DeviceRestart = 1.5,
	BeepInterval = 3,
	BeepRadius = 12,
	KeycardHold = 1,
	KeycardOnGuardChance = 0.5, -- else on one of the Keycard anchors
	PickpocketHold = 1.5, -- behind the guard, unseen
	RadioDelay = 4,
	RadioWindow = 6,
	RadioAnswerHold = 2,
	RadioMissPoints = 40,
	RadioMaxAnswers = 2, -- per round, whole crew
	PanicPackCharges = 1,
}

-- ---------- Round plan randomisation (Logic/RoundPlan) ----------
Config.Plan = {
	LockedEntrances = 2, -- of 4
	SecondExitChance = 0.5,
	WaitJitter = 1, -- ± seconds per guard waypoint
	MaxOptionalObjectives = 1,
	DeviceJamWindow = { 0.2, 0.85 }, -- jams fall between these fractions of the device's progress
}

-- ---------- Difficulty tiers (advisor: Easy / Normal / Hard; Big Cheese after the beta) ----------
-- Payout multipliers are meta's (Config.Economy.DifficultyPayout); unlocks too (Config.Progression).
Config.DifficultyTiers = {
	Default = "Normal",
	Order = { "Easy", "Normal", "Hard" },
	Tiers = {
		Easy = {
			Subtitle = "Young",
			FillRate = 0.8,
			ExtraGuards = 0,
			CameraFillSeconds = 3,
			AlarmPoints = 0.75,
			LockdownSeconds = 75,
			SelfEscapes = 2,
			RadioChecks = false,
			DeviceSeconds = 35,
		},
		Normal = {
			Subtitle = "Aged",
			FillRate = 1.0,
			ExtraGuards = 0,
			CameraFillSeconds = 2,
			AlarmPoints = 1,
			LockdownSeconds = 60,
			SelfEscapes = 1,
			RadioChecks = true,
			DeviceSeconds = 45,
		},
		Hard = {
			Subtitle = "Extra Aged",
			FillRate = 1.2,
			ExtraGuards = 1,
			CameraFillSeconds = 1.6,
			AlarmPoints = 1.25,
			LockdownSeconds = 50,
			SelfEscapes = 1,
			RadioChecks = true,
			DeviceSeconds = 55,
		},
	} :: { [string]: DifficultyTier },
}

-- ---------- Perk effects (tree layout, costs and max equipped: meta's Config.PerkTree) ----------
Config.Perks = {
	SoftShoes = { { Stat = "Crouch", Set = 9 } },
	BarrelLungs = { { Stat = "SneezeAt", Set = 25 }, { Stat = "WarnAt", Set = 20 } },
	QuietCrowbar = { { Stat = "CrackRadius", Set = 18 } },
	LongArm = { { Stat = "ThrowRange", Set = 12 } },
	DeepPockets = { { Stat = "PocketSlots", Set = 4 } },
	StrongBack = { { Stat = "HeavySolo", Set = 8 } },
	QuickHands = { { Stat = "RescueHold", Set = 1.5 } },
	EscapeArtist = { { Stat = "SelfEscapeAfter", Set = 12 } },
	SpareBatteries = { { Stat = "FirstGadgetBonus", Add = 1 } },
} :: { [string]: { PerkEffect } }

-- ---------- Prototype keys (still read by today's services) ----------
-- DEPRECATED (WP M3): global difficulty string; the per-job tier (Config.DifficultyTiers) replaces it.
Config.Difficulty = "Normal" -- "Rookie" | "Normal" | "Pro"
-- DEPRECATED (WP M5): the shared window is gone; gadgets use fixed durations.
Config.WindowSeconds = {
	Rookie = 12,
	Normal = 10,
	Pro = 8,
}
Config.SoloExtraWindow = 2 -- DEPRECATED (WP M5)
Config.SlotsByCrewSize = { 3, 2, 2, 1 } -- DEPRECATED (WP M5): everyone picks Config.Loadout.Slots
-- DEPRECATED (WP M1): use Config.Movement.
Config.Player = {
	WalkSpeed = 16,
	CrouchSpeed = 8,
}
-- DEPRECATED (WP M5): deleted together with ChainCallService.
Config.ChainCall = {
	JoinSeconds = 6,
	Cooldown = 5,
	CountdownSeconds = 3,
	Steps = { "EYES", "CLEAR", "OPEN" },
}

-- DEPRECATED (WP M5)
function Config.windowSeconds(crewSize: number): number
	local base = Config.WindowSeconds[Config.Difficulty] or 10
	if crewSize <= 1 then
		base += Config.SoloExtraWindow
	end
	return base
end

-- DEPRECATED (WP M5)
function Config.slotsFor(crewSize: number): number
	local clamped = math.clamp(crewSize, 1, #Config.SlotsByCrewSize)
	return Config.SlotsByCrewSize[clamped]
end

-- =======================================================================================================
-- Pings (shared: mechanics PingService + ux quick wheel). ux changes presets/cooldown in WP1.
-- =======================================================================================================
Config.Ping = {
	SpotMaxPerWindow = 3,
	SpotWindowSeconds = 2,
	SpotDurationDefault = 8,
	SpotDurationTracked = 5,
	QuickCooldown = 10, -- one shared cooldown for the whole quick wheel (advisor; Roblox preset rule)
	-- The 6 fixed quick-wheel words (ux WP1). Labels and icons: src/client/Lib/Theme.luau.
	QuickPresets = { "GO", "TO THE VAN", "THROW TO ME", "WAIT", "LIFT WITH ME", "HELP" },
	MaxRange = 300,
}

-- =======================================================================================================
-- MAP block (owner: map) — Config.World (GarageOrigin, MiniJobOrigins, …) goes here.
-- =======================================================================================================

-- =======================================================================================================
-- META block (owner: meta) — Config.Data, Economy, Progression, PerkTree, HotJob, Contracts, MostWanted,
-- Lobby, Catalog, Collection, Monetization, Analytics, MetaRateLimit go here (beta-spec-meta §8.3).
-- =======================================================================================================

-- =======================================================================================================
-- UX block (owner: ux) — Config.UX goes here.
-- =======================================================================================================

return Config
