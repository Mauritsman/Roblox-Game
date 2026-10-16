--!strict
-- Mini-job "Corner Cheese" (beta-spec-maps §5, ux §3.1): the solo tutorial, its own tiny canal-side map. It runs
-- in parallel slots (Config.World.MiniJobOrigins) while the crew uses the heist at the world origin.
-- MapService:BuildMiniJob(slot) builds it into workspace.MiniJob_<slot>; TutorialService places the player at
-- Points.Spawn (MapService returns the slot's Points in world space).
--
-- All coordinates in this folder are LOCAL to the slot origin (studs; floor y 0; north = −X, the canal side).
-- Flow: spawn by the van → grab the wheel at the market stall (15 studs) → bank it at the van → sneak past the
-- sleeping guard into the shop → pocket the cubes → lift the Golden Gouda → roll it back past the guard (front
-- door, ≈ 40 studs) or through the side door and the alley (≈ 55 studs) → hold to drive.
--
--   x −46..−34 canal · −34..−12 quay (van −28,−13 · stall −25,3 · guard −13.6,3.4) · −12..8 Corner Cheese
--   (z −8..12, front door z 5.4..11.4, side door x 0..6) · alley z 12..22 · road barriers at z −22 and 28

local Builder = require(script.Parent.Common.Builder)
local Kit = require(script.Parent.Garage.Kit)
local Shop = require(script.Shop)
local Street = require(script.Street)

-- Key positions (local). Character positions are at root height (floor + 3).
export type Points = {
	Spawn: Vector3,
	SpawnFacing: Vector3, -- towards the market stall's wheel
	Wheel: Vector3, -- first loot (Medium, Opener) on the stall counter
	Van: Vector3, -- the van exit (prop position)
	BankZone: Vector3, -- bottom centre of the van's rear BankZone
	DrivePoint: Vector3,
	SleepingGuard: Vector3, -- the guard's seat (bottom centre); he faces SleepingGuardFacing
	SleepingGuardFacing: Vector3,
	FrontDoor: Vector3,
	SideDoor: Vector3,
	Gouda: Vector3, -- main loot on its pedestal
	Barrel: Vector3, -- the hide spot in the alley
}

export type LootEntry = { Type: string, Count: number, Group: string? }

-- A walking/rolling lane (local floor points), kept free of props. Checked by tests/map and the tester.
export type Lane = { Name: string, Width: number, Points: { Vector3 } }

local V = Vector3.new

local POINTS: Points = {
	Spawn = V(-19, 3, -13.1),
	SpawnFacing = V(-6, 0, 14.5).Unit,
	Wheel = V(-25, 2.6, 1.4),
	Van = V(-28, 0, -13),
	BankZone = V(-28, 0, -4),
	DrivePoint = V(-28, 0, -30),
	SleepingGuard = V(-13.6, 0.3, 3.4),
	SleepingGuardFacing = V(-1, 0, 0),
	FrontDoor = V(-12, 0, 8.4),
	SideDoor = V(3, 0, 12),
	Gouda = V(4, 1.4, 2),
	Barrel = V(-6, 0, 20),
}

local LANES: { Lane } = {
	{ Name = "SpawnToStall", Width = 4, Points = { V(-19, 0, -13.1), V(-24.5, 0, -0.8) } },
	{ Name = "StallToVan", Width = 4, Points = { V(-24.5, 0, -1.8), V(-28, 0, -4) } },
	{
		Name = "QuayToFrontDoor",
		Width = 5,
		Points = { V(-19, 0, -9), V(-17.8, 0, -2.5), V(-17.8, 0, 8.4), V(-9, 0, 8.4) },
	},
	-- Rolling the Golden Gouda back (beta-spec-maps §5: two flat routes).
	{
		Name = "RollPastGuard",
		Width = 5,
		Points = {
			V(1.5, 0, 5),
			V(-7, 0, 4.5),
			V(-9, 0, 8.4),
			V(-17.8, 0, 8.4),
			V(-17.8, 0, -2.5),
			V(-26, 0, -4),
		},
	},
	{
		Name = "RollThroughAlley",
		Width = 5,
		Points = {
			V(3, 0, 5),
			V(3, 0, 15),
			V(-14, 0, 15),
			V(-17.8, 0, 9),
			V(-17.8, 0, -2.5),
			V(-26, 0, -4),
		},
	},
}

local MiniJob = {
	Id = "MiniJob",
	DisplayName = "Corner Cheese",
	Seed = 2604, -- fixed: every slot looks the same
	Points = POINTS,
	Lanes = LANES,
	-- Every anchor is Fixed, so this loot always spawns (RoundPlan fills Fixed anchors).
	Loot = {
		{ Type = "CheeseWheel", Count = 2 }, -- stall (Opener) + display table
		{ Type = "CheeseCube", Count = 3 }, -- shop counter
		{ Type = "CashDrawer", Count = 1, Group = "Drawer" }, -- the till on the counter
		{ Type = "GoldenGouda", Count = 1 }, -- pedestal (anchor attribute Scale = 0.6)
	} :: { LootEntry },
	-- beta-spec-maps §12.
	Budget = { Parts = 1500, Lights = 10, Shadowed = 2 },
	-- Local box around everything that is built.
	Bounds = { Min = V(-70, -10, -50), Max = V(14, 40, 50) },
}

-- Session attribute of a slot's loot anchors, BankZone and triggers ("Tutorial1", "Tutorial2").
function MiniJob.sessionFor(slot: number): string
	return `Tutorial{slot}`
end

-- The Points in world space for a slot built at `origin`.
function MiniJob.worldPoints(origin: CFrame): Points
	return {
		Spawn = origin * POINTS.Spawn,
		SpawnFacing = origin:VectorToWorldSpace(POINTS.SpawnFacing),
		Wheel = origin * POINTS.Wheel,
		Van = origin * POINTS.Van,
		BankZone = origin * POINTS.BankZone,
		DrivePoint = origin * POINTS.DrivePoint,
		SleepingGuard = origin * POINTS.SleepingGuard,
		SleepingGuardFacing = origin:VectorToWorldSpace(POINTS.SleepingGuardFacing),
		FrontDoor = origin * POINTS.FrontDoor,
		SideDoor = origin * POINTS.SideDoor,
		Gouda = origin * POINTS.Gouda,
		Barrel = origin * POINTS.Barrel,
	}
end

-- Builds slot `slot` into `folder` at `origin` (≤ 1,500 parts, ≤ 10 lights of which 2 cast shadows).
function MiniJob.Build(folder: Folder, origin: CFrame, slot: number, rng: Random)
	local k = Kit.new(origin)
	local session = MiniJob.sessionFor(slot)
	local anchors = Builder.folder(folder, "Anchors")
	local ctx: Street.Context = {
		k = k,
		folder = folder,
		anchors = anchors,
		slot = slot,
		session = session,
		points = POINTS,
	}
	Street.build(ctx, rng)
	Shop.build(ctx)
end

return MiniJob
