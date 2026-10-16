--!strict
-- The Garage: the crew's permanent hideout (beta-spec-maps §4). An old brick viaduct over a canal, with the
-- crew's rooms in its arches: workshop (gadget rack, workbench, mirror), van bay (job board, departure van, spawn),
-- lounge (trophy wall, TV, collection book) and a practice yard. MapService:BuildGarage() builds it once at
-- Config.World.GarageOrigin into workspace.Garage.
--
-- All coordinates in this folder are LOCAL to the Garage origin (studs; floor y 0; north = −X, the canal side).

local Kit = require(script.Kit)

-- Key positions (local; Garage.worldPoints turns them into world positions). Character positions are at root
-- height (floor + 3), like a heist's Points.Spawn.
export type Points = {
	Spawn: Vector3, -- SpawnLocation; players face SpawnFacing (the job board, 8 studs ahead)
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

local POINTS: Points = {
	Spawn = Vector3.new(12, 3, 0),
	SpawnFacing = Vector3.new(1, 0, 0),
	Arrivals = {
		Vector3.new(-8, 3, 8),
		Vector3.new(-12, 3, 8),
		Vector3.new(-8, 3, -8),
		Vector3.new(-12, 3, -8),
	},
	VanZone = Vector3.new(3, 0, 0),
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

-- Builds the Garage into `folder` at `origin`.
function Garage.Build(folder: Folder, origin: CFrame, rng: Random)
	local k = Kit.new(origin)
	local _ = rng
	k.box(folder, "Floor", Vector3.new(-36, -1, -50), Vector3.new(20, 0, 70), Color3.fromRGB(150, 150, 146))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GarageSpawn"
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = CFrame.lookAt(k.at(12, 0.2, 0), k.at(13, 0.2, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder
end

return Garage
