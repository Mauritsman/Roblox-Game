--!strict
-- Beveiligingscamera's (§9.3): zwaaien heen en weer, een meter loopt vol als ze je zien.
-- Volle meter = alarmpunten en de bewakers komen kijken. Een EMP zet ze een venster lang uit.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local AlarmService = require(script.Parent.AlarmService)
local GuardService = require(script.Parent.GuardService)
local MapService = require(script.Parent.MapService)

local CameraService = {}

type Cam = {
	model: Model,
	body: BasePart,
	mount: Vector3,
	baseLook: Vector3,
	clock: number,
	meters: { [Player]: number },
	cooldown: { [Player]: number },
	led: BasePart?,
	cone: SpotLight?,
}

local cams: { Cam } = {}
local C = Config.SecurityCamera
local COS_HALF = math.cos(math.rad(C.ConeHalfAngle))

local function register(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end
	local baseLook = model:GetAttribute("BaseLook")
	local led: BasePart? = nil
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("IsLed") then
			led = child
		end
	end
	table.insert(cams, {
		model = model,
		body = body,
		mount = body.Position,
		baseLook = if typeof(baseLook) == "Vector3" then baseLook else body.CFrame.LookVector,
		clock = math.random() * C.SweepSeconds,
		meters = {},
		cooldown = {},
		led = led,
		cone = body:FindFirstChildOfClass("SpotLight"),
	})
end

local function sees(cam: Cam, character: Model, point: Vector3): boolean
	local offset = point - cam.mount
	local distance = offset.Magnitude
	if distance > C.Range then
		return false
	end
	if cam.body.CFrame.LookVector:Dot(offset.Unit) < COS_HALF then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { cam.model }
	local level = MapService.Level
	local cage = level and level:FindFirstChild("Cage")
	if cage then
		table.insert(ignore, cage)
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(cam.mount, offset, params)
	return result == nil or result.Instance:IsDescendantOf(character)
end

local function setVisual(cam: Cam, disabled: boolean, tracking: boolean)
	if cam.cone then
		cam.cone.Enabled = not disabled
		cam.cone.Brightness = if tracking then 4 else 2
	end
	if cam.led then
		cam.led.Color = if disabled
			then Color3.fromRGB(40, 40, 40)
			elseif tracking then Color3.fromRGB(255, 230, 60)
			else Color3.fromRGB(255, 40, 40)
	end
end

local function update(cam: Cam, dt: number)
	local disabled = cam.model:GetAttribute(Tags.Disabled) == true
	if disabled then
		cam.clock = 0 -- na het herstarten kijkt hij eerst weer naar zijn beginpunt
		table.clear(cam.meters)
		setVisual(cam, true, false)
		return
	end

	cam.clock += dt
	local phase = math.sin(cam.clock / C.SweepSeconds * math.pi * 2)
	local yaw = math.rad(C.SweepDegrees / 2) * phase
	local look = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(cam.baseLook)
	cam.body.CFrame = CFrame.lookAt(cam.mount, cam.mount + look)

	local tracking = false
	local fillSeconds = C.FillSeconds[Config.Difficulty] or 2
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local meter = cam.meters[player] or 0
		local onCooldown = (cam.cooldown[player] or 0) > os.clock()
		if
			character
			and hrp
			and not character:GetAttribute("Caught")
			and not onCooldown
			and sees(cam, character, hrp.Position)
		then
			meter += dt / fillSeconds
			tracking = true
			if meter >= 1 then
				meter = 0
				cam.cooldown[player] = os.clock() + 5
				AlarmService:Add("CameraSpotted")
				GuardService:ReportPosition(hrp.Position)
				Net.broadcast("CameraSpotted", player.Name, cam.model.Name)
			end
		else
			meter = math.max(0, meter - dt)
		end
		cam.meters[player] = meter
	end
	setVisual(cam, false, tracking)
end

function CameraService:Start()
	MapService.LevelBuilt:Connect(function()
		table.clear(cams)
		for _, model in CollectionService:GetTagged(Tags.SecurityCamera) do
			register(model)
		end
	end)
	for _, model in CollectionService:GetTagged(Tags.SecurityCamera) do
		register(model)
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then
			return
		end
		local step = acc
		acc = 0
		for index = #cams, 1, -1 do
			local cam = cams[index]
			if cam.model.Parent == nil then
				table.remove(cams, index)
			else
				update(cam, step)
			end
		end
	end)
end

return CameraService
