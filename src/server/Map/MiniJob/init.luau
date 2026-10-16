--!strict
-- Mini-job "Corner Cheese" (beta-spec-maps §5, ux §3.1): the solo tutorial, its own tiny canal-side map. It runs
-- in parallel slots (Config.World.MiniJobOrigins) while the crew uses the heist at the world origin.
-- MapService:BuildMiniJob(slot) builds it into workspace.MiniJob_<slot>; TutorialService places the player at
-- Points.Spawn (MapService returns the slot's Points in world space).
--
-- All coordinates in this folder are LOCAL to the slot origin (studs; floor y 0; north = −X, the canal side).
-- Flow: spawn by the van → grab the wheel at the market stall (15 studs) → bank it at the van → sneak past the
-- sleeping guard into the shop → pocket the cubes → lift the Golden Gouda → roll it back past the guard (front
-- door) or through the side door and the alley → hold to drive.

local Kit = require(script.Parent.Garage.Kit)

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

local POINTS: Points = {
	Spawn = Vector3.new(-18, 3, -13.1),
	SpawnFacing = Vector3.new(-4, 0, 14.5).Unit,
	Wheel = Vector3.new(-22, 2.6, 1.4),
	Van = Vector3.new(-27, 0, -13),
	BankZone = Vector3.new(-27, 0, -4),
	DrivePoint = Vector3.new(-27, 0, -30),
	SleepingGuard = Vector3.new(-14.5, 0.3, 3.4),
	SleepingGuardFacing = Vector3.new(-1, 0, 0),
	FrontDoor = Vector3.new(-12, 0, 8.4),
	SideDoor = Vector3.new(3, 0, 12),
	Gouda = Vector3.new(4, 1.4, 2),
	Barrel = Vector3.new(-6, 0, 20),
}

local MiniJob = {
	Id = "MiniJob",
	DisplayName = "Corner Cheese",
	Seed = 2604, -- fixed: every slot looks the same
	Points = POINTS,
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
	Bounds = { Min = Vector3.new(-70, -10, -50), Max = Vector3.new(14, 40, 50) },
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

-- Builds slot `slot` into `folder` at `origin`.
function MiniJob.Build(folder: Folder, origin: CFrame, slot: number, rng: Random)
	local k = Kit.new(origin)
	local _ = rng
	local _slot = slot
	k.box(folder, "Ground", Vector3.new(-34, -8, -46), Vector3.new(12, 0, 46), Color3.fromRGB(92, 96, 104))
end

return MiniJob
