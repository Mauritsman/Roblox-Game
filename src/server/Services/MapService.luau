--!strict
-- Builds the world from code, so every level lives in Git as text (beta-spec-maps §1):
-- - Heists at the world origin in workspace.Level: `Build(heistId)` (list in src/server/Map/Registry, one folder per
--   heist in Map/Heists/). Only one heist exists at a time.
-- - The Garage (permanent hideout) at Config.World.GarageOrigin in workspace.Garage: `BuildGarage()`, once in Init.
-- - Mini-job ("Corner Cheese") slots at Config.World.MiniJobOrigins in workspace.MiniJob_<slot>:
--   `BuildMiniJob(slot)` / `DestroyMiniJob(slot)` (TutorialService).
-- Areas are ≥ 2,000 studs apart, so with StreamingEnabled a phone only holds the area its player is in.
-- Shared building blocks live in Map/Common; props (AI models) in ServerStorage.Props, with simple stand-ins.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Map = script.Parent.Parent:WaitForChild("Map")
local Atmosphere = require(Map.Common.Atmosphere)
local Builder = require(Map.Common.Builder)
local Garage = require(Map.Garage)
local MiniJob = require(Map.MiniJob)
local Registry = require(Map.Registry)

local defaultHeist = Registry.get(Registry.DefaultHeist)
assert(defaultHeist, `[MapService] DefaultHeist "{Registry.DefaultHeist}" is not in the Registry`)

-- One built mini-job slot.
export type MiniJobSlot = {
	Slot: number,
	Session: string, -- "Tutorial<slot>": the Session attribute of its loot anchors and BankZone
	Folder: Folder,
	Origin: CFrame,
	Points: MiniJob.Points, -- world positions
}

local MapService = {}
MapService.LevelBuilt = Signal.new() :: Signal.Signal<Folder>
MapService.Level = nil :: Folder?
-- The definition of the heist that is currently built (nil until the first Build).
MapService.CurrentHeist = nil :: Registry.Heist?
MapService.GadgetColors = Builder.GadgetColors

-- Key positions that other services use (Spawn, GuardStart, GuardRoute).
-- Before the first Build these are the default heist's; Build sets them to those of the built heist.
MapService.Points = defaultHeist.Points

-- The Garage: its folder, its definition (local Points, practice Loot) and its Points in world space.
MapService.Garage = nil :: Folder?
MapService.GarageDef = Garage
MapService.GaragePoints = nil :: Garage.Points?

-- The mini-job: its definition (local Points, Loot) and the built slots.
MapService.MiniJobDef = MiniJob
MapService.MiniJobs = {} :: { [number]: MiniJobSlot }

local function toVector(p: Config.WorldPoint): Vector3
	return Vector3.new(p.X, p.Y, p.Z)
end

local function defaultBounds(): { Min: Vector3, Max: Vector3 }
	local b = Config.World.DefaultHeistBounds
	return { Min = toVector(b.Min), Max = toVector(b.Max) }
end

-- Clears a heist's Terrain (its canal water) inside its Bounds only, so nothing else in the world is touched.
local function clearTerrain(bounds: { Min: Vector3, Max: Vector3 })
	local minV = bounds.Min:Min(bounds.Max)
	local maxV = bounds.Min:Max(bounds.Max)
	workspace.Terrain:FillBlock(CFrame.new((minV + maxV) / 2), maxV - minV, Enum.Material.Air)
end

-- With Config.World.GarageIsSpawn the Garage SpawnLocation is the only one: heist spawns are switched off.
local function disableHeistSpawns(level: Folder)
	if not Config.World.GarageIsSpawn or MapService.Garage == nil then
		return
	end
	for _, d in level:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d.Enabled = false
		end
	end
end

-- Builds (or rebuilds) a heist in Workspace.Level and applies that heist's atmosphere.
-- Without heistId: the same heist again (the first time, the default heist from the Registry).
function MapService:Build(heistId: string?): Folder
	local current = MapService.CurrentHeist
	local id = heistId or (if current then current.Id else Registry.DefaultHeist)
	local heist = Registry.get(id)
	assert(heist, `[MapService] Unknown heist "{id}"`)

	local old = workspace:FindFirstChild("Level")
	if old then
		old:Destroy()
	end
	if current and current.Id ~= heist.Id then
		-- Different heist: remove the previous one's water inside its Bounds. Each heist fills its own Terrain.
		clearTerrain(current.Bounds or defaultBounds())
	end
	Atmosphere.apply(heist.Atmosphere)

	local level = Instance.new("Folder")
	level.Name = "Level"
	level:SetAttribute("Area", "Heist")
	level:SetAttribute("HeistId", heist.Id)
	level:SetAttribute("LightingPreset", heist.Id)
	heist.Build(level, Random.new(heist.Seed))
	disableHeistSpawns(level)
	level.Parent = workspace
	MapService.Level = level
	MapService.CurrentHeist = heist
	MapService.Points = heist.Points
	MapService.LevelBuilt:Fire(level)
	return level
end

-- Builds the Garage once (workspace.Garage); later calls return the existing folder.
function MapService:BuildGarage(): Folder
	local existing = MapService.Garage
	if existing and existing.Parent then
		return existing
	end
	local origin = CFrame.new(toVector(Config.World.GarageOrigin))
	local folder = Instance.new("Folder")
	folder.Name = "Garage"
	folder:SetAttribute("Area", "Garage")
	folder:SetAttribute("LightingPreset", "Garage")
	Garage.Build(folder, origin, Random.new(Garage.Seed))
	folder.Parent = workspace
	MapService.Garage = folder
	MapService.GaragePoints = Garage.worldPoints(origin)
	return folder
end

-- Number of mini-job slots (Config.World.MiniJobOrigins).
function MapService:MiniJobSlotCount(): number
	return #Config.World.MiniJobOrigins
end

-- The Session attribute value of a slot's loot and BankZone: "Tutorial1", "Tutorial2".
function MapService:MiniJobSession(slot: number): string
	return MiniJob.sessionFor(slot)
end

-- Builds mini-job slot `slot` (a previous build of that slot is destroyed first).
-- Returns the folder and the slot's Points in world space (Spawn, SpawnFacing, SleepingGuard, Gouda, …).
function MapService:BuildMiniJob(slot: number): (Folder, MiniJob.Points)
	local originPoint = Config.World.MiniJobOrigins[slot]
	assert(originPoint, `[MapService] No mini-job slot {slot} (Config.World.MiniJobOrigins)`)
	self:DestroyMiniJob(slot)

	local origin = CFrame.new(toVector(originPoint))
	local session = MiniJob.sessionFor(slot)
	local folder = Instance.new("Folder")
	folder.Name = `MiniJob_{slot}`
	folder:SetAttribute("Area", "MiniJob")
	folder:SetAttribute("Slot", slot)
	folder:SetAttribute("Session", session)
	folder:SetAttribute("LightingPreset", "MiniJob")
	MiniJob.Build(folder, origin, slot, Random.new(MiniJob.Seed))
	folder.Parent = workspace

	local points = MiniJob.worldPoints(origin)
	MapService.MiniJobs[slot] = {
		Slot = slot,
		Session = session,
		Folder = folder,
		Origin = origin,
		Points = points,
	}
	return folder, points
end

-- Removes mini-job slot `slot` (no-op when it is not built).
function MapService:DestroyMiniJob(slot: number)
	local record = MapService.MiniJobs[slot]
	MapService.MiniJobs[slot] = nil
	if record then
		record.Folder:Destroy()
	end
	local stray = workspace:FindFirstChild(`MiniJob_{slot}`)
	if stray then
		stray:Destroy()
	end
end

-- The built slot, or nil.
function MapService:GetMiniJob(slot: number): MiniJobSlot?
	return MapService.MiniJobs[slot]
end

local function setupCollisionGroups()
	-- The drone collides with walls, but not with players or guards (it must not push anyone away).
	for _, group in { "Players", "Guards", "Drone" } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("Drone", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Drone", "Guards", false)
end

-- The baseplate sinks below the canal (y -12): the quay, the street and the hall have their own floor.
local function placeBaseplate()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.CFrame = CFrame.new(0, -12 - baseplate.Size.Y / 2, 0)
		baseplate.Color = Color3.fromRGB(36, 40, 44)
		baseplate.Material = Enum.Material.Ground
	end
end

function MapService:Init()
	setupCollisionGroups()
	placeBaseplate()
	self:BuildGarage()
	self:Build()
end

return MapService
