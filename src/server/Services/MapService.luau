--!strict
-- Builds a heist (map) from code, so the level lives in Git as text.
-- The list of heists is in src/server/Map/Registry; each heist has its own folder in Map/Heists/
-- (map 1: Heists/GoldenWheel). Shared building blocks (Builder, CanalHouse, Atmosphere) live in Map/Common/.
-- Props (AI models) live in ServerStorage.Props; if they are missing, Builder builds simple stand-ins.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Map = script.Parent.Parent:WaitForChild("Map")
local Atmosphere = require(Map.Common.Atmosphere)
local Builder = require(Map.Common.Builder)
local Registry = require(Map.Registry)

local defaultHeist = Registry.get(Registry.DefaultHeist)
assert(defaultHeist, `[MapService] DefaultHeist "{Registry.DefaultHeist}" is not in the Registry`)

local MapService = {}
MapService.LevelBuilt = Signal.new() :: Signal.Signal<Folder>
MapService.Level = nil :: Folder?
-- The definition of the heist that is currently built (nil until the first Build).
MapService.CurrentHeist = nil :: Registry.Heist?
MapService.GadgetColors = Builder.GadgetColors

-- Key positions that other services use (Spawn, GuardStart, GuardRoute).
-- Before the first Build these are the default heist's; Build sets them to those of the built heist.
MapService.Points = defaultHeist.Points

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
		-- Different heist: remove the previous one's water (Terrain). Each heist fills its own Terrain.
		workspace.Terrain:Clear()
	end
	Atmosphere.apply(heist.Atmosphere)

	local level = Instance.new("Folder")
	level.Name = "Level"
	heist.Build(level, Random.new(heist.Seed))
	level.Parent = workspace
	MapService.Level = level
	MapService.CurrentHeist = heist
	MapService.Points = heist.Points
	MapService.LevelBuilt:Fire(level)
	return level
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
	self:Build()
end

return MapService
