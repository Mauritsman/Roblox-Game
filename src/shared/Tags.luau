--!strict
-- Names of CollectionService tags and attributes, so server and client use the same spelling.
-- (A tag is a label you attach to an object, so code can find all objects with that label.)
-- Every value equals its key (except the `Charges` prefix). The full contract with value lists is in
-- docs/contracts.md. Shared file: each role edits only inside its own block.

return table.freeze({
	-- ===================================================================================================
	-- Prototype (v0.2) — tags and attributes used by today's services. Keep.
	-- ===================================================================================================
	-- Tags
	Electronic = "Electronic", -- knocked out by an EMP (cameras, lamps, drones)
	SecurityCamera = "SecurityCamera",
	Lamp = "Lamp",
	Guard = "Guard",
	Pryable = "Pryable", -- can be opened with the Crowbar
	GadgetPedestal = "GadgetPedestal", -- removed from map 1 by the map retrofit (beta-spec §5)
	Goal = "Goal", -- removed from map 1 by the map retrofit (beta-spec §5)
	Drone = "Drone",
	Spottable = "Spottable",

	-- Attributes
	Disabled = "Disabled", -- boolean on Electronic objects
	GuardState = "GuardState",
	Crouching = "Crouching",
	Operating = "Operating", -- player is flying a drone or watching camera feeds
	Gadgets = "Gadgets", -- comma-separated list of gadget names on the player
	Slots = "Slots",
	Charges = "Charges_", -- prefix: Charges_EMP etc.
	Owner = "Owner", -- UserId of the owner (drone)
	SpotKind = "SpotKind", -- kind of ping icon for this object

	-- ===================================================================================================
	-- MECHANICS block (owner: mechanics) — beta-spec §9.3–9.4. M = placed by the map agent.
	-- ===================================================================================================
	-- Tags placed by mechanics code
	Loot = "Loot", -- every loot Model in Level.Loot (PrimaryPart "Handle")
	MainLoot = "MainLoot", -- the heist's main loot (Golden Gouda, …), also tagged Loot
	Trace = "Trace", -- something Karel can find (attributes TraceKind, TraceBy)
	Npc = "Npc", -- Karel, Boef, Inspector (attribute NpcKind)

	-- Tags placed by the map (M)
	LootAnchor = "LootAnchor",
	BankZone = "BankZone", -- child of an Exit (and the Garage practice yard)
	Exit = "Exit", -- also the name of a HideSpot's exit Attachment
	Entrance = "Entrance",
	HideSpot = "HideSpot",
	Cell = "Cell",
	CellSpot = "CellSpot",
	CellDoor = "CellDoor",
	CellDropoff = "CellDropoff",
	CellExit = "CellExit",
	CellGrate = "CellGrate",
	DogZone = "DogZone",
	KarelHome = "KarelHome",
	HazardAnchor = "HazardAnchor",
	GarageVan = "GarageVan",
	TutorialTrigger = "TutorialTrigger",
	KeycardDoor = "KeycardDoor",
	Safe = "Safe",
	StaffZone = "StaffZone", -- Mask Up: entering one puts your mask on; outside = public
	SecureZone = "SecureZone", -- innermost ring (vault, office): job card and analytics
	LockdownSwitch = "LockdownSwitch", -- maps 2–3: changes at LOCKDOWN (attribute Action)
	SeeThrough = "SeeThrough", -- guards and cameras see through it (cage mesh, cell bars); vision rays ignore it
	GuardDoor = "GuardDoor", -- opens automatically for guards (e.g. Tulip cold rooms)
	Ride = "Ride", -- folder per ride: welded seats the server moves along Points.Rides[RideId]
	ColdZone = "ColdZone", -- melting loot stops melting inside
	GooZone = "GooZone", -- chocolate river: slow walk, SPLOSH noise
	RhythmMachine = "RhythmMachine", -- rhythm hazards (attributes Kind, Period, Active, Radius)
	LaserGrid = "LaserGrid", -- touch = alarm; also Electronic (EMP disables it)
	MorningLight = "MorningLight", -- Tulip 5:00 event lamps (attribute Step 1–3)
	RisingPlinth = "RisingPlinth", -- main loot rises at round start (attribute RiseHeight)
	PracticeTarget = "PracticeTarget", -- Garage practice-yard baskets

	-- ReplicatedStorage attributes (times = workspace:GetServerTimeNow())
	RoundPhase = "RoundPhase",
	RoundId = "RoundId",
	RoundStartedAt = "RoundStartedAt",
	RoundEndsAt = "RoundEndsAt",
	ShiftChangeAt = "ShiftChangeAt",
	LockdownEndsAt = "LockdownEndsAt",
	PoliceAt = "PoliceAt",
	VanDepartAt = "VanDepartAt",
	ExitArrivesAt = "ExitArrivesAt",
	JumpInUntil = "JumpInUntil",
	HeistId = "HeistId",
	JobName = "JobName",
	Difficulty = "Difficulty",
	Modifier = "Modifier",
	Approach = "Approach",
	VanLoot = "VanLoot",
	CrewSize = "CrewSize",
	AlarmLevel = "AlarmLevel",

	-- Player attributes
	Activity = "Activity",
	InRound = "InRound",
	SelfEscapeUsed = "SelfEscapeUsed",
	CrewColor = "CrewColor",
	DroneBattery = "DroneBattery",

	-- Character attributes
	Caught = "Caught",
	Captured = "Captured",
	SelfEscapeAt = "SelfEscapeAt",
	ImmuneUntil = "ImmuneUntil",
	Hidden = "Hidden",
	HideEndsAt = "HideEndsAt",
	InVan = "InVan",
	Frozen = "Frozen",
	Slipping = "Slipping",
	Masked = "Masked",
	Bubbled = "Bubbled",
	CarryClass = "CarryClass",
	CarryLoot = "CarryLoot",
	CarryLootId = "CarryLootId",
	CarryPartner = "CarryPartner",
	CarryRole = "CarryRole",
	Rolling = "Rolling",
	Pockets = "Pockets",
	PocketItems = "PocketItems",

	-- Loot attributes
	LootId = "LootId",
	LootType = "LootType",
	LootName = "LootName",
	LootClass = "LootClass",
	Value = "Value",
	BaseValue = "BaseValue",
	LootState = "LootState",
	CarrierId = "CarrierId",
	HomeAnchor = "HomeAnchor",
	DroppedAt = "DroppedAt",
	Session = "Session", -- also on BankZones

	-- Attributes on map-placed objects (M) and doors
	AnchorClass = "AnchorClass",
	AnchorId = "AnchorId",
	Zone = "Zone",
	Group = "Group",
	Fixed = "Fixed",
	Opener = "Opener",
	EntranceId = "EntranceId",
	ExitKind = "ExitKind",
	Optional = "Optional",
	QuietOnly = "QuietOnly",
	LockdownOnly = "LockdownOnly",
	ArrivesAt = "ArrivesAt",
	HideKind = "HideKind",
	Step = "Step", -- TutorialTrigger (onboarding step name), MorningLight (1–3)
	Card = "Card",
	Action = "Action",
	RideId = "RideId",
	Seats = "Seats",
	Speed = "Speed",
	LockdownSpeed = "LockdownSpeed",
	Boarding = "Boarding", -- on a ride's Station attachment
	Stop = "Stop", -- on a ride's Station attachment: STOP window where guards can grab riders
	Kind = "Kind", -- RhythmMachine: Fountain | Mixer | Wrapper | Mist | Clock
	Period = "Period",
	Active = "Active",
	Radius = "Radius",
	RiseHeight = "RiseHeight",
	TraceKind = "TraceKind",
	TraceBy = "TraceBy",
	NpcKind = "NpcKind",
	DoorState = "DoorState",
	ClosedCFrame = "ClosedCFrame",
	LoudOnly = "LoudOnly",

	-- ===================================================================================================
	-- MAP block (owner: map) — map-only tags go here.
	-- ===================================================================================================
	GarageTV = "GarageTV", -- ux: WATCH (spectate) station
	TrophyBoard = "TrophyBoard", -- meta writes the "Most Goudas" text
	Spinner = "Spinner", -- decor Model that turns (landmarks): SpinSeconds per turn, SpinAxis (local); client-side

	-- ===================================================================================================
	-- META block (owner: meta) — Garage station tags (JobBoard, GadgetRack, …) and meta attributes go here.
	-- ===================================================================================================

	-- ===================================================================================================
	-- UX block (owner: ux) — e.g. ContextIcon go here.
	-- ===================================================================================================
})
