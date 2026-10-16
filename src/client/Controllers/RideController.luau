--!strict
-- Smooths the map runtime's moving things on this client (visuals only; the server stays authoritative and ux owns
-- every input):
--   * ride cars (src/server/MapRuntime/Rides): each frame a car is put where its replicated state says
--     (S0 + Rate × (serverNow − T0) along the ride's path), instead of jumping at the server's network rate.
--     Riders and loot are welded to the car, so they move smoothly too.
--   * `Spinner`-tagged landmarks (the Golden Wheel sign) turn once per SpinSeconds around SpinAxis (local), on the
--     client only; every client shows the same angle (server time). Skipped when far from the camera.
--   * the Tulip auction clock's light beam (a part with attribute ClockBeam in Level.MapRuntime) sweeps every
--     frame from its replicated Center/RadiusX/RadiusZ/Width/Period/T0, like the server computes it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local RidePath = require(ReplicatedStorage.Shared.Logic.RidePath)
local Rhythm = require(ReplicatedStorage.Shared.Logic.Rhythm)

local RideController = {}

type CachedPath = { text: string, loop: boolean, path: RidePath.Path }
type CarEntry = { model: Instance, folder: Instance }

local paths: { [Instance]: { [string]: CachedPath } } = setmetatable({}, { __mode = "k" }) :: any
local cars: { CarEntry } = {}
local beams: { BasePart } = {}
local rescanIn = 0
local spinBase: { [Instance]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local SPIN_RANGE = 600

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
	table.clear(beams)
	local level = workspace:FindFirstChild("Level")
	local runtime = level and level:FindFirstChild("MapRuntime")
	if runtime then
		for _, child in runtime:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute("ClockBeam") == true then
				table.insert(beams, child)
			end
		end
	end
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

local function stepBeams(now: number)
	for _, beam in beams do
		local center = beam:GetAttribute("Center")
		local period = num(beam, "Period", 0)
		if typeof(center) ~= "Vector3" or period <= 0 or not beam:IsDescendantOf(workspace) then
			continue
		end
		local timer = Rhythm.new(period, period, num(beam, "T0", 0))
		local angle = Rhythm.fraction(timer, now) * math.pi * 2
		local ex, ez =
			Rhythm.ellipse(center.X, center.Z, num(beam, "RadiusX", 18), num(beam, "RadiusZ", 30), angle)
		local base = center + Vector3.new(0, 0.08, 0)
		local tip = Vector3.new(ex, base.Y, ez)
		local length = math.max(0.5, (tip - base).Magnitude)
		beam.Size = Vector3.new(num(beam, "Width", 5) * 2, 0.1, length)
		beam.CFrame = CFrame.lookAt((base + tip) / 2, tip)
	end
end

local function stepSpinners(now: number)
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for _, inst in CollectionService:GetTagged(Tags.Spinner) do
		if not inst:IsDescendantOf(workspace) then
			continue
		end
		local base = spinBase[inst]
		if not base then
			if inst:IsA("Model") then
				base = inst:GetPivot()
			elseif inst:IsA("BasePart") then
				base = inst.CFrame
			end
			if not base then
				continue
			end
			spinBase[inst] = base
		end
		local pivot = base :: CFrame
		if (pivot.Position - eye).Magnitude > SPIN_RANGE then
			continue
		end
		local seconds = num(inst, Tags.SpinSeconds, Config.MapRuntime.Spinner.SpinSeconds)
		if seconds <= 0 then
			continue
		end
		local axisValue = inst:GetAttribute(Tags.SpinAxis)
		local axis = if typeof(axisValue) == "Vector3" and axisValue.Magnitude > 0
			then axisValue.Unit
			else Vector3.yAxis
		local angle = ((now / seconds) % 1) * math.pi * 2
		local cf = pivot * CFrame.fromAxisAngle(axis, angle)
		if inst:IsA("Model") then
			inst:PivotTo(cf)
		elseif inst:IsA("BasePart") then
			inst.CFrame = cf
		end
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
		stepSpinners(now)
		stepBeams(now)
	end)
end

return RideController
