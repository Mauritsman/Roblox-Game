--!strict
-- Smooths the map runtime's moving things on this client (visuals only; the server stays authoritative and ux owns
-- every input):
--   * ride cars (src/server/MapRuntime/Rides): each frame a car is put where its replicated state says
--     (S0 + Rate × (serverNow − T0) along the ride's path), instead of jumping at the server's network rate.
--     Riders and loot are welded to the car, so they move smoothly too.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)
local RidePath = require(ReplicatedStorage.Shared.Logic.RidePath)

local RideController = {}

type CachedPath = { text: string, loop: boolean, path: RidePath.Path }
type CarEntry = { model: Instance, folder: Instance }

local paths: { [Instance]: { [string]: CachedPath } } = setmetatable({}, { __mode = "k" }) :: any
local cars: { CarEntry } = {}
local rescanIn = 0

local function pathOf(folder: Instance, key: string): RidePath.Path?
	local text = folder:GetAttribute("Path_" .. key)
	if type(text) ~= "string" then
		return nil
	end
	local loop = folder:GetAttribute("Loop_" .. key) == true
	local byKey = paths[folder]
	if not byKey then
		byKey = {}
		paths[folder] = byKey
	end
	local cached = byKey[key]
	if cached and cached.text == text and cached.loop == loop then
		return cached.path
	end
	local path = RidePath.build(RidePath.parse(text), loop)
	byKey[key] = { text = text, loop = loop, path = path }
	return path
end

local function rescan()
	table.clear(cars)
	for _, folder in CollectionService:GetTagged(Tags.Ride) do
		for _, d in folder:GetDescendants() do
			if d:GetAttribute(Tags.RideCar) == true then
				table.insert(cars, { model = d, folder = folder })
			end
		end
	end
end

local function rootOf(model: Instance): BasePart?
	if model:IsA("BasePart") then
		return model
	elseif model:IsA("Model") then
		return model.PrimaryPart
	end
	return nil
end

local function num(inst: Instance, name: string, default: number): number
	local value = inst:GetAttribute(name)
	return if type(value) == "number" then value else default
end

local function stepCars(now: number)
	for _, entry in cars do
		local model = entry.model
		local root = rootOf(model)
		if not root or not root:IsDescendantOf(workspace) then
			continue
		end
		local key = model:GetAttribute("PathKey")
		local path = pathOf(entry.folder, if type(key) == "string" then key else "Normal")
		if not path or path.length <= 0 then
			continue
		end
		local s = RidePath.distanceAt(num(model, "S0", 0), num(model, "Rate", 0), num(model, "T0", now), now)
		local p = RidePath.pointAt(path, s)
		local d = RidePath.heading(path, s, num(entry.folder, "CornerBlend", 1.5))
		local dir = Vector3.new(d.x, d.y, d.z)
		if math.abs(dir.Y) > 0.9 then
			dir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if dir.Magnitude < 1e-3 then
				dir = Vector3.new(0, 0, -1)
			end
		end
		local origin = Vector3.new(p.x, p.y + num(model, "Height", 1.5), p.z)
		root.CFrame = CFrame.lookAt(origin, origin + dir.Unit)
	end
end

function RideController:Start()
	rescan()
	RunService.RenderStepped:Connect(function(dt: number)
		rescanIn -= dt
		if rescanIn <= 0 then
			rescanIn = 1
			rescan()
		end
		local now = workspace:GetServerTimeNow()
		stepCars(now)
	end)
end

return RideController
