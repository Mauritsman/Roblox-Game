--!strict
-- Bouwt map 1 "The Golden Wheel" (Polderdam, §10.1–10.2) uit code, zodat het level als tekst in Git staat.
-- De onderdelen staan in src/server/Map/: Quay (kade + gracht), GoldenWheel (winkel, beveiliging, binnenkoer),
-- Warehouse (rijpingshal, kooi, camera's, kantoor) en Atmosphere (nachtlicht).
-- Props (AI-modellen) staan in ServerStorage.Props; ontbreken ze, dan bouwt Builder eenvoudige vervangers.
--
-- Assen (studs, grond = y 0): noord = -X. Gracht x -72..-54, kade x -54..-22, winkel/koer x -22..0, hal x 0..60.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Map = script.Parent.Parent:WaitForChild("Map")
local Atmosphere = require(Map.Atmosphere)
local GoldenWheel = require(Map.GoldenWheel)
local Quay = require(Map.Quay)
local Warehouse = require(Map.Warehouse)

local MapService = {}
MapService.LevelBuilt = Signal.new() :: Signal.Signal<Folder>
MapService.Level = nil :: Folder?
MapService.GadgetColors = Quay.GadgetColors

-- Belangrijke posities die andere services gebruiken.
MapService.Points = {
	Spawn = Vector3.new(-36, 3, -10),
	GuardStart = Vector3.new(8, 3, -18),
	GuardRoute = {
		Vector3.new(8, 0, -18),
		Vector3.new(48, 0, -18),
		Vector3.new(48, 0, 18),
		Vector3.new(8, 0, 18),
	},
}

-- Vaste seed: elke build ziet er hetzelfde uit (gevelkleuren, verlichte ramen).
local SEED = 1854

-- Bouwt (of herbouwt) het hele level in Workspace.Level.
function MapService:Build(): Folder
	local old = workspace:FindFirstChild("Level")
	if old then
		old:Destroy()
	end
	local level = Instance.new("Folder")
	level.Name = "Level"
	local rng = Random.new(SEED)
	Quay.build(level, rng)
	GoldenWheel.build(level, rng)
	Warehouse.build(level, rng)
	level.Parent = workspace
	MapService.Level = level
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
	Atmosphere.apply()
	self:Build()
end

return MapService
