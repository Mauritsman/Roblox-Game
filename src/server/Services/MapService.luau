--!strict
-- Bouwt een heist (map) uit code, zodat het level als tekst in Git staat.
-- Welke heists er zijn, staat in src/server/Map/Registry; elke heist heeft een eigen map in Map/Heists/
-- (map 1: Heists/GoldenWheel). Gedeelde bouwstenen (Builder, CanalHouse, Atmosphere) staan in Map/Common/.
-- Props (AI-modellen) staan in ServerStorage.Props; ontbreken ze, dan bouwt Builder eenvoudige vervangers.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Map = script.Parent.Parent:WaitForChild("Map")
local Atmosphere = require(Map.Common.Atmosphere)
local Builder = require(Map.Common.Builder)
local Registry = require(Map.Registry)

local defaultHeist = Registry.get(Registry.DefaultHeist)
assert(defaultHeist, `[MapService] DefaultHeist "{Registry.DefaultHeist}" staat niet in de Registry`)

local MapService = {}
MapService.LevelBuilt = Signal.new() :: Signal.Signal<Folder>
MapService.Level = nil :: Folder?
-- De definitie van de heist die nu gebouwd is (nil tot de eerste Build).
MapService.CurrentHeist = nil :: Registry.Heist?
MapService.GadgetColors = Builder.GadgetColors

-- Belangrijke posities die andere services gebruiken (Spawn, GuardStart, GuardRoute).
-- Vóór de eerste Build die van de standaard-heist; Build zet ze op die van de gebouwde heist.
MapService.Points = defaultHeist.Points

-- Bouwt (of herbouwt) een heist in Workspace.Level en zet de sfeer van die heist.
-- Zonder heistId: dezelfde heist opnieuw (de eerste keer de standaard-heist uit de Registry).
function MapService:Build(heistId: string?): Folder
	local current = MapService.CurrentHeist
	local id = heistId or (if current then current.Id else Registry.DefaultHeist)
	local heist = Registry.get(id)
	assert(heist, `[MapService] Onbekende heist "{id}"`)

	local old = workspace:FindFirstChild("Level")
	if old then
		old:Destroy()
	end
	if current and current.Id ~= heist.Id then
		-- Andere heist: het water (Terrain) van de vorige weghalen. Elke heist vult zijn eigen Terrain.
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
	-- De drone botst met muren, maar niet met spelers of bewakers (hij mag niemand wegduwen).
	for _, group in { "Players", "Guards", "Drone" } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("Drone", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Drone", "Guards", false)
end

-- De grondplaat zakt onder de gracht (y -12): de kade, de straat en de hal hebben hun eigen vloer.
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
