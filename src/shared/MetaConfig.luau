--!strict
-- Meta block (owner: meta): saving, economy, progression, perks, job board, contracts, analytics, monetisation.
-- Pure data (no Roblox APIs, no requires) so the Lune tests can read it too. Cosmetics and gadgets: Catalog.luau.
-- Source: docs/beta-spec-meta.md §8.3 and docs/research/advisor-*.md. Times in seconds, money in Cash.

local MetaConfig = {}

-- Heists the meta systems know about, in job-board order. A heist only gets a playable card when the map agent
-- has added it to src/server/Map/Registry.luau; until then the card shows "Coming soon".
MetaConfig.Heists = {
	Order = { "GoldenWheel", "PralinePalace", "TulipAuction" },
	Names = {
		GoldenWheel = "The Golden Wheel",
		PralinePalace = "Praline Palace",
		TulipAuction = "Tulip Auction",
		MiniJob = "Mini-job",
	} :: { [string]: string },
	MiniJob = "MiniJob", -- heistId the tutorial uses in its RoundResult
	Default = "GoldenWheel", -- played when nobody votes
}

MetaConfig.Difficulty = {
	Order = { "Easy", "Normal", "Hard" },
	Default = "Normal",
	Labels = { Easy = "Young", Normal = "Aged", Hard = "Extra Aged" } :: { [string]: string },
	-- Hard per heist needs this many stars on Normal on that heist (advisor).
	Unlock = { Hard = { Tier = "Normal", Stars = 2 } } :: { [string]: { Tier: string, Stars: number } },
}

MetaConfig.Modifiers = {
	Names = {
		PowerCut = "Power Cut",
		HealthInspector = "Health Inspector",
		WetFloor = "Wet Floor",
		RushJob = "Rush Job",
		DoubleShift = "Double Shift",
		SleepyGuards = "Sleepy Guards",
	} :: { [string]: string },
}

MetaConfig.Data = {
	StoreName = "PlayerData", -- never rename: a new name looks like a wipe
	CorruptStoreName = "PlayerDataCorrupt",
	StudioSuffix = "_Studio", -- Studio with API access never touches live data
	KeyPrefix = "u_",
	AutosaveSeconds = 120,
	MinSecondsBetweenWrites = 7,
	LoadAttempts = 6,
	LoadRetrySeconds = 4,
	StealAfterAttempts = 5,
	StaleLockSeconds = 600,
	RetryAttempts = 5,
	RetryMaxSeconds = 16,
	ShutdownTimeoutSeconds = 25,
	ShutdownHookSeconds = 5,
	RejoinWaitSeconds = 30,
	ReceiptHistory = 100,
	RecentRounds = 10,
	TrophyLog = 30,
	RecentHeists = 2,
	UseMemoryInStudio = "auto" :: "auto" | boolean,
	Mock = { FailRate = 0, LatencySeconds = 0 }, -- Studio fault injection (MetaDevService can change it)
	SyncPerSecond = 4,
	TroubleAfterFailures = 3,
	-- Settings the client may store (ux). Numbers are clamped to Min..Max.
	SettingsKeys = {
		Music = { Kind = "number", Min = 0, Max = 10 },
		Sfx = { Kind = "number", Min = 0, Max = 10 },
		CameraSensitivity = { Kind = "number", Min = 0.5, Max = 2 },
		ReduceMotion = { Kind = "boolean", Min = 0, Max = 0 },
		Hints = { Kind = "boolean", Min = 0, Max = 0 },
	} :: { [string]: { Kind: string, Min: number, Max: number } },
	-- First-time tips (ux). Each is shown at most MaxTipShows times.
	TipIds = { "LiftTogether", "ThrowIt", "HideBarrel", "SpottedDropRun", "FreeAtCell", "DroneLook" },
	MaxTipShows = 2,
}

MetaConfig.Economy = {
	CrewBonusPerExtra = 0.15,
	BustedFactor = 0.5,
	CaughtAtEndFactor = 0.5, -- escaped round, but this player was not in the van
	QuietJobBonus = 0.20,
	QuietJobMaxTier = 1,
	NoOneLeftBehindBonus = 0.10, -- crews of 2+ only
	HotJobBonus = 0.25,
	FreshBonus = 0.20,
	FreshWindow = 2, -- Fresh needs this many rounds of history and the heist not among them
	FirstJobMultiplier = 2, -- first ESCAPED job of the UTC day
	RepPerRound = 100,
	WelcomeBonus = 500, -- mini-job
	WelcomeRep = 100,
	RankUpCashPerRank = 100,
	StarBonus = 300, -- × difficulty multiplier, per new star
	MaxPayoutPerRound = 25000,
	MostWantedDuplicateCash = 1500,
	CollectionPageCash = 2000,
	DifficultyPayout = { Easy = 0.8, Normal = 1.0, Hard = 1.4 } :: { [string]: number },
}

MetaConfig.Progression = {
	RepPerRankStep = 1000, -- rank n → n+1 costs 1,000 × n Rep
	MaxRank = 20,
	SlotRank = { Mask = 1, Hat = 2, Van = 4, Gadget = 1 } :: { [string]: number },
	HeistUnlock = {
		GoldenWheel = {},
		PralinePalace = { StarsOn = "GoldenWheel", Stars = 3, Rank = 4 },
		TulipAuction = { StarsOn = "PralinePalace", Stars = 3, Rank = 7 },
	} :: { [string]: { StarsOn: string?, Stars: number?, Rank: number? } },
	MasteryMask = {
		GoldenWheel = "GoudaVisor",
		PralinePalace = "PralineMask",
		TulipAuction = "BulbHelmet",
	} :: { [string]: string },
	MasteryTier = "Hard",
	StarMasks = { [9] = "StarShades", [27] = "AllStarMask" } :: { [number]: string },
	Titles = {
		[1] = "Rookie",
		[3] = "Pickpocket",
		[5] = "Cheese Runner",
		[8] = "Safecracker",
		[10] = "Mastermind",
		[12] = "Cheese Baron",
		[18] = "Canal Phantom",
		[20] = "Legend of Polderdam",
	} :: { [number]: string },
}

MetaConfig.PerkTree = {
	BranchOrder = { "Sneak", "Muscle", "Crew" },
	Branches = {
		Sneak = { "SoftShoes", "BarrelLungs", "QuietCrowbar" },
		Muscle = { "LongArm", "DeepPockets", "StrongBack" },
		Crew = { "QuickHands", "EscapeArtist", "SpareBatteries" },
	} :: { [string]: { string } },
	Names = {
		SoftShoes = "Soft Shoes",
		BarrelLungs = "Barrel Lungs",
		QuietCrowbar = "Quiet Crowbar",
		LongArm = "Long Arm",
		DeepPockets = "Deep Pockets",
		StrongBack = "Strong Back",
		QuickHands = "Quick Hands",
		EscapeArtist = "Escape Artist",
		SpareBatteries = "Spare Batteries",
	} :: { [string]: string },
	RowCost = { 1, 2, 3 },
	MaxEquipped = 3,
	FreeRespec = true,
}

MetaConfig.HotJob = {
	SlotSeconds = 1800,
	BonusPct = 0.25,
	-- No Sleepy Guards: a Hot Job is never easier (advisor).
	Modifiers = { "PowerCut", "HealthInspector", "WetFloor", "RushJob", "DoubleShift" },
	-- A player needs this many finished rounds before they can vote for the Hot Job (card stays visible).
	MinRoundsToVote = 2,
}

MetaConfig.Contracts = {
	Rewards = { Easy = 250, Medium = 350, Hard = 500 } :: { [string]: number },
	MaxNeedsCrew = 1,
	FreeRerollsPerDay = 1,
	-- Counter = which round fact counts (see Logic/Contracts.amountFor).
	Templates = {
		{ Id = "BankItems", Text = "Bank 5 loot items", Tier = "Easy", Counter = "lootBanked", Target = 5 },
		{
			Id = "BankValue",
			Text = "Bank 1,000 Cash of loot",
			Tier = "Easy",
			Counter = "lootValueBanked",
			Target = 1000,
		},
		{
			Id = "PocketSmall",
			Text = "Bank 6 small items",
			Tier = "Easy",
			Counter = "smallBanked",
			Target = 6,
		},
		{ Id = "FinishJobs", Text = "Finish 2 jobs", Tier = "Easy", Counter = "roundsFinished", Target = 2 },
		{
			Id = "FreeTeammate",
			Text = "Free a teammate",
			Tier = "Medium",
			Counter = "rescues",
			Target = 1,
			NeedsCrew = true,
		},
		{
			Id = "BubbleGuards",
			Text = "Bubble 3 guards",
			Tier = "Medium",
			Counter = "bubbledGuards",
			Target = 3,
		},
		{
			Id = "BankHeavy",
			Text = "Bank a heavy item",
			Tier = "Medium",
			Counter = "heavyBanked",
			Target = 1,
		},
		{
			Id = "TwoStars",
			Text = "Get 2 stars on a job",
			Tier = "Medium",
			Counter = "twoStarRounds",
			Target = 1,
		},
		{
			Id = "HideFromGuard",
			Text = "Lose a chasing guard in a hiding spot",
			Tier = "Medium",
			Counter = "hidFromChase",
			Target = 1,
		},
		{
			Id = "DistractBoef",
			Text = "Distract Boef",
			Tier = "Medium",
			Counter = "boefDistracted",
			Target = 1,
			RequiresHeist = "GoldenWheel",
		},
		{
			Id = "HotJob",
			Text = "Finish the Hot Job",
			Tier = "Medium",
			Counter = "hotJobEscapes",
			Target = 1,
		},
		{
			Id = "StealGouda",
			Text = "Escape with the main loot",
			Tier = "Hard",
			Counter = "mainLootEscapes",
			Target = 1,
		},
		{ Id = "QuietJob", Text = "Finish a Quiet Job", Tier = "Hard", Counter = "quietEscapes", Target = 1 },
		{
			Id = "HardJob",
			Text = "Escape on Hard",
			Tier = "Hard",
			Counter = "hardEscapes",
			Target = 1,
			NeedsHard = true,
		},
		{
			Id = "CarryTogether",
			Text = "Bank a heavy item carried together",
			Tier = "Hard",
			Counter = "carriedTogether",
			Target = 1,
			NeedsCrew = true,
		},
	} :: {
		{
			Id: string,
			Text: string,
			Tier: string,
			Counter: string,
			Target: number,
			NeedsCrew: boolean?,
			RequiresHeist: string?,
			NeedsHard: boolean?,
		}
	},
}

MetaConfig.MostWanted = {
	StarsNeeded = 3,
	Tiers = { Normal = true, Hard = true } :: { [string]: boolean },
	-- Weekly rotation (Monday 00:00 UTC): map 1 every other week so newcomers can join in.
	Rotation = { "GoldenWheel", "PralinePalace", "GoldenWheel", "TulipAuction" },
	RewardPool = { "BoefSnout", "NightShiftGoggles", "KarelsBucket", "SirenHat" },
}

MetaConfig.Lobby = {
	NextJobWindowSeconds = 120, -- round funnel step 6: departs again within this time
	BoardRefreshSeconds = 5,
	PrivateCrewInviteSeconds = 10,
	PrivateCrewCooldownSeconds = 60,
	StationPromptDistance = 8,
	-- Station tag → ux screen name sent with OpenScreen.
	Stations = {
		JobBoard = { Screen = "JobBoard", Action = "Jobs" },
		GadgetRack = { Screen = "Gadgets", Action = "Gadgets" },
		Workbench = { Screen = "Perks", Action = "Perks" },
		Mirror = { Screen = "Mirror", Action = "Mirror" },
		CollectionBook = { Screen = "Collection", Action = "Book" },
		TrophyWall = { Screen = "Trophies", Action = "Trophies" },
	} :: { [string]: { Screen: string, Action: string } },
}

-- Collection book: one page per heist (loot type ids from Config.Loot.Types). Keycards are not collected.
MetaConfig.Collection = {
	Pages = {
		GoldenWheel = {
			"CheeseCube",
			"TipJar",
			"CashDrawer",
			"CheeseWheel",
			"BigWheel",
			"BlueMoon",
			"GoldenGouda",
		},
		PralinePalace = {}, -- [TO BE CONFIRMED] loot types of map 2 (map agent)
		TulipAuction = {}, -- [TO BE CONFIRMED] loot types of map 3 (map agent)
	} :: { [string]: { string } },
	PageReward = { GoldenWheel = "CheeseMonocle" } :: { [string]: string }, -- other pages pay CollectionPageCash
}

-- Monetisation: off in the beta. The receipt handler is installed and testable with fake receipts in Studio.
MetaConfig.Monetization = {
	Enabled = false,
	Products = {
		-- Hidden test product (Maurits may create it as a dev product); fake receipts in Studio always work.
		BetaTestToken = { Id = 0, Enabled = false, DevOnly = true, Kind = "Consumable", Item = "" },
		CrewFireworks = { Id = 0, Enabled = false, DevOnly = false, Kind = "Consumable", Item = "" },
	} :: { [string]: { Id: number, Enabled: boolean, DevOnly: boolean, Kind: string, Item: string } },
	-- Kind "Item" grants Item into robuxOwned (never removed); "Consumable" only counts in purchases.
	Passes = {
		CrewWardrobe = { Id = 0, Enabled = false },
		PaintShop = { Id = 0, Enabled = false },
		LoadoutPresets = { Id = 0, Enabled = false },
		SupporterPack = { Id = 0, Enabled = false },
	} :: { [string]: { Id: number, Enabled: boolean } },
}

MetaConfig.Analytics = {
	StudioPrint = true,
	-- Onboarding funnel (once per player ever). Mechanics reports 1–6 by name, meta 7–8.
	OnboardingSteps = {
		"Spawned",
		"Moved",
		"FirstLootGrabbed",
		"FirstLootBanked",
		"SneakedPastGuard",
		"GoudaLifted",
		"MiniJobEscaped",
		"GarageReached",
	},
	-- Other spellings used in the ux/mechanics specs.
	StepAliases = {
		GrabbedLoot = "FirstLootGrabbed",
		BankedLoot = "FirstLootBanked",
		LiftedGouda = "GoudaLifted",
		Escaped = "MiniJobEscaped",
		ReachedGarage = "GarageReached",
	} :: { [string]: string },
	RoundSteps = {
		"VanDeparted",
		"FirstLootGrabbed",
		"FirstLootBanked",
		"MainLootLifted",
		"Escaped",
		"NextJob",
	},
	FeedbackTags = { "Fun", "TooHard", "TooEasy", "Confusing", "Bug", "Laggy" },
}

-- Every meta request: token bucket per player and request name.
MetaConfig.RateLimit = { Burst = 5, PerSecond = 2, MaxStringLength = 40 }

return MetaConfig
