--!strict
-- The Garage: the crew's permanent hideout (beta-spec-maps §4). An old brick viaduct over a canal, with the
-- crew's rooms in its arches: workshop (gadget rack, workbench, mirror), van bay (job board, departure van, spawn),
-- lounge (trophy wall, TV, collection book) and a practice yard. MapService:BuildGarage() builds it once at
-- Config.World.GarageOrigin into workspace.Garage.
--
-- All coordinates in this folder are LOCAL to the Garage origin (studs; floor y 0; north = −X, the canal side).

local Builder = require(script.Parent.Common.Builder)
local Kit = require(script.Kit)
local Lounge = require(script.Lounge)
local Structure = require(script.Structure)
local VanBay = require(script.VanBay)
local Workshop = require(script.Workshop)
local Yard = require(script.Yard)

-- Meta's tag for the whole Garage area (funnel step 8); not in MetaTags yet.
local GARAGE_ZONE_TAG = "GarageZone"

-- Key positions (local; Garage.worldPoints turns them into world positions). Character positions are at root
-- height (floor + 3), like a heist's Points.Spawn.
export type Points = {
	Spawn: Vector3, -- SpawnLocation; players face SpawnFacing (the job board, 6 studs ahead)
	SpawnFacing: Vector3,
	Arrivals: { Vector3 }, -- where the crew lands after a job (outside the van zone)
	VanZone: Vector3, -- bottom centre of the GarageVan zone
	DrivePoint: Vector3, -- where the van drives to (out through the roller door)
	JobBoard: Vector3,
	GadgetRack: Vector3,
	Workbench: Vector3,
	Mirror: Vector3,
	TrophyWall: Vector3,
	CollectionBook: Vector3,
	GarageTV: Vector3,
	YardDoor: Vector3,
	ThrowLine: Vector3,
}

export type LootEntry = { Type: string, Count: number, Group: string? }

-- A walking lane (local floor points): kept free of props so players and pathfinding get through. Reach = a
-- station tag whose prompt must be in range at the lane's end. Checked by tests/map and the tester.
export type Lane = { Name: string, Width: number, Points: { Vector3 }, Reach: string? }

local V = Vector3.new
local LANES: { Lane } = {
	{ Name = "SpawnToJobBoard", Width = 4, Points = { V(13.5, 0, 0), V(16.5, 0, 0) }, Reach = "JobBoard" },
	{
		Name = "SpawnToGadgetRack",
		Width = 4,
		Points = { V(13.5, 0, 0), V(1, 0, -6), V(1, 0, -17), V(14, 0, -27) },
		Reach = "GadgetRack",
	},
	{
		Name = "SpawnToWorkbench",
		Width = 4,
		Points = { V(13.5, 0, 0), V(1, 0, -6), V(1, 0, -17), V(11.5, 0, -19) },
		Reach = "Workbench",
	},
	{
		Name = "SpawnToMirror",
		Width = 4,
		Points = { V(13.5, 0, 0), V(1, 0, -6), V(1, 0, -17), V(-8, 0, -29) },
		Reach = "Mirror",
	},
	{
		Name = "SpawnToTrophyWall",
		Width = 4,
		Points = { V(13.5, 0, 0), V(1, 0, 6), V(1, 0, 17), V(14, 0, 24) },
		Reach = "TrophyWall",
	},
	{
		Name = "SpawnToCollectionBook",
		Width = 4,
		Points = { V(13.5, 0, 0), V(1, 0, 6), V(1, 0, 17), V(-9.5, 0, 18) },
		Reach = "CollectionBook",
	},
	{
		Name = "SpawnToTV",
		Width = 4,
		Points = { V(13.5, 0, 0), V(1, 0, 6), V(1, 0, 17), V(8, 0, 20), V(6, 0, 27.5), V(2, 0, 29.3) },
		Reach = "GarageTV",
	},
	{
		Name = "SpawnToYard",
		Width = 4,
		Points = {
			V(13.5, 0, 0),
			V(1, 0, 6),
			V(1, 0, 17),
			V(-7, 0, 19),
			V(-11, 0, 30),
			V(-11, 0, 40),
			V(-15, 0, 47),
		},
	},
	{
		Name = "YardToPracticeBank",
		Width = 4,
		Points = { V(-14, 0, 50), V(-6, 0, 48.5), V(4, 0, 48.7), V(8, 0, 48.7) },
	},
	{
		Name = "ForecourtToVanBay",
		Width = 3.6,
		Points = { V(-28, 0, 0), V(-17.2, 0, 0), V(-17.2, 0, 6.5), V(-3, 0, 7), V(8, 0, 3) },
	},
	{ Name = "WorkshopDoor", Width = 4, Points = { V(-28, 0, -19), V(-10, 0, -19) } },
	{ Name = "LoungeDoor", Width = 4, Points = { V(-28, 0, 29), V(-10, 0, 29) } },
}

local POINTS: Points = {
	Spawn = Vector3.new(13.5, 3, 0),
	SpawnFacing = Vector3.new(1, 0, 0),
	Arrivals = {
		Vector3.new(-8, 3, 8),
		Vector3.new(-12, 3, 8),
		Vector3.new(-8, 3, -8),
		Vector3.new(-12, 3, -8),
	},
	VanZone = Vector3.new(4, 0, 0),
	DrivePoint = Vector3.new(-18, 0, 0),
	JobBoard = Vector3.new(19.6, 6.5, 0),
	GadgetRack = Vector3.new(19.6, 4.5, -27),
	Workbench = Vector3.new(16.5, 4, -19),
	Mirror = Vector3.new(-8, 3.5, -33.4),
	TrophyWall = Vector3.new(19.6, 6, 24),
	CollectionBook = Vector3.new(-12, 3.6, 18),
	GarageTV = Vector3.new(0, 2.6, 32.6),
	YardDoor = Vector3.new(-11, 0, 36),
	ThrowLine = Vector3.new(-10, 0, 52),
}

local Garage = {
	Id = "Garage",
	DisplayName = "The Garage",
	Seed = 3107, -- fixed: every build looks the same
	Points = POINTS,
	Lanes = LANES,
	-- Practice yard loot (fixed anchors, Session = "Practice": never banks, returns home after a drop).
	Session = "Practice",
	Loot = {
		{ Type = "CheeseWheel", Count = 2 },
		{ Type = "BigWheel", Count = 1 },
	} :: { LootEntry },
	-- beta-spec-maps §12.
	Budget = { Parts = 1200, Lights = 10, Shadowed = 3 },
	-- Local box around everything that is built.
	Bounds = { Min = Vector3.new(-80, -12, -56), Max = Vector3.new(24, 30, 76) },
}

-- The Points in world space for a Garage built at `origin`.
function Garage.worldPoints(origin: CFrame): Points
	local arrivals = {}
	for _, p in POINTS.Arrivals do
		table.insert(arrivals, origin * p)
	end
	return {
		Spawn = origin * POINTS.Spawn,
		SpawnFacing = origin:VectorToWorldSpace(POINTS.SpawnFacing),
		Arrivals = arrivals,
		VanZone = origin * POINTS.VanZone,
		DrivePoint = origin * POINTS.DrivePoint,
		JobBoard = origin * POINTS.JobBoard,
		GadgetRack = origin * POINTS.GadgetRack,
		Workbench = origin * POINTS.Workbench,
		Mirror = origin * POINTS.Mirror,
		TrophyWall = origin * POINTS.TrophyWall,
		CollectionBook = origin * POINTS.CollectionBook,
		GarageTV = origin * POINTS.GarageTV,
		YardDoor = origin * POINTS.YardDoor,
		ThrowLine = origin * POINTS.ThrowLine,
	}
end

-- Builds the Garage into `folder` at `origin` (≤ 1,200 parts, ≤ 10 lights of which 3 cast shadows).
function Garage.Build(folder: Folder, origin: CFrame, rng: Random)
	local k = Kit.new(origin)
	Structure.build(k, folder, rng)
	local anchors = Builder.folder(folder, "Anchors")
	Workshop.build(k, folder)
	VanBay.build(k, folder)
	Lounge.build(k, folder)
	Yard.build(k, folder, anchors)
	k.zone(folder, "GarageZone", Vector3.new(-36, -4, -50), Vector3.new(20, 30, 64), nil, GARAGE_ZONE_TAG)
end

return Garage
