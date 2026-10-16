--!strict
-- Security cameras (beta-spec §3.3, §6.2): they sweep back and forth and a meter fills while they see a crew
-- member. Full meter = alarm points, `Spotted(userId, "camera")` and the 2 nearest guards come to look.
--   * Crew only (caught, hidden, immune, unmasked or non-crew players are ignored, Logic/Detection).
--   * Meter time from the difficulty tier (Easy 3 s, Normal 2 s, Hard 1.6 s); alarm tier 2 sweeps 30% faster.
--   * Vision passes through `SeeThrough` parts (and the prototype `Cage` folder).
--   * Power Cut: every camera and Lamp is off for the whole round.
-- Camera order (ViewCam / Spot camIndex) = sorted by full name, the same order the client's cell view uses.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local AlarmService = require(script.Parent.AlarmService)
local GuardService = require(script.Parent.GuardService)
local MapService = require(script.Parent.MapService)

local Npc = script.Parent.Parent:WaitForChild("Npc")
local Peers = require(Npc.Peers)
local Targets = require(Npc.Targets)

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
local powerCutActive = false

local function isPowerCut(): boolean
	return powerCutActive or Targets.modifier() == "PowerCut"
end

local function register(model: Instance)
	if not model:IsA("Model") then
		return
	end
	for _, cam in cams do
		if cam.model == model then
			return
		end
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

local function visionParams(cam: Cam): RaycastParams
	local ignore: { Instance } = { cam.model }
	for _, tag in { Tags.SeeThrough, Tags.Loot, Tags.Drone, Tags.Guard, Tags.Npc } do
		for _, inst in CollectionService:GetTagged(tag) do
			table.insert(ignore, inst)
		end
	end
	local level = MapService.Level
	local cage = level and level:FindFirstChild("Cage")
	if cage then
		table.insert(ignore, cage)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

local function inView(
	cam: Cam,
	point: Vector3,
	target: Instance?,
	range: number,
	params: RaycastParams
): boolean
	local offset = point - cam.mount
	if offset.Magnitude > range or offset.Magnitude < 0.01 then
		return false
	end
	if cam.body.CFrame.LookVector:Dot(offset.Unit) < COS_HALF then
		return false
	end
	local result = workspace:Raycast(cam.mount, offset, params)
	return result == nil or (target ~= nil and result.Instance:IsDescendantOf(target))
end

local function isOff(cam: Cam): boolean
	return isPowerCut() or cam.model:GetAttribute(Tags.Disabled) == true
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

local function update(cam: Cam, dt: number, fillSeconds: number, now: number)
	if isOff(cam) then
		cam.clock = 0 -- after restarting it first looks back at its starting point
		table.clear(cam.meters)
		setVisual(cam, true, false)
		return
	end

	local rate = if AlarmService.Level >= 2 then C.Tier2SweepRate else 1
	cam.clock += dt * rate
	local phase = math.sin(cam.clock / C.SweepSeconds * math.pi * 2)
	local yaw = math.rad(C.SweepDegrees / 2) * phase
	local look = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(cam.baseLook)
	cam.body.CFrame = CFrame.lookAt(cam.mount, cam.mount + look)
	if cam.led then
		cam.led.CFrame = cam.body.CFrame * CFrame.new(0, 0.3, -1.25)
	end

	local tracking = false
	local params: RaycastParams? = nil
	for _, view in Targets.crewViews() do
		local player = view.player
		local meter = cam.meters[player] or 0
		local onCooldown = (cam.cooldown[player] or 0) > os.clock()
		local seen = false
		if not onCooldown and not Targets.ignored(player, view.character, now) then
			params = params or visionParams(cam)
			seen = inView(cam, view.root.Position, view.character, C.Range, params :: RaycastParams)
		end
		if seen then
			meter += dt / fillSeconds
			tracking = true
			if meter >= 1 then
				meter = 0
				cam.cooldown[player] = os.clock() + 5
				AlarmService:Add("CameraSpotted", nil, player)
				GuardService:ReportPosition(view.root.Position)
				Net.broadcast("Spotted", player.UserId, "camera")
				Peers.event("Seen", player)
			end
		else
			meter = math.max(0, meter - dt)
		end
		cam.meters[player] = meter
	end
	setVisual(cam, false, tracking)
end

-- Power Cut: every Lamp off for the round (re-applied if an EMP timer switches one back on).
local function applyPowerCutToLamp(lamp: Instance)
	if not isPowerCut() then
		return
	end
	if lamp:GetAttribute(Tags.Disabled) ~= true then
		lamp:SetAttribute(Tags.Disabled, true)
	end
	for _, light in lamp:GetDescendants() do
		if light:IsA("Light") then
			light.Enabled = false
		end
	end
	if lamp:IsA("BasePart") and lamp.Material == Enum.Material.Neon then
		lamp.Material = Enum.Material.SmoothPlastic
	end
end

local lampConnections: { RBXScriptConnection } = {}

local function hookLamp(lamp: Instance)
	table.insert(
		lampConnections,
		lamp:GetAttributeChangedSignal(Tags.Disabled):Connect(function()
			if isPowerCut() and lamp:GetAttribute(Tags.Disabled) ~= true then
				task.defer(applyPowerCutToLamp, lamp)
			end
		end)
	)
	applyPowerCutToLamp(lamp)
end

-- Switches the round's Power Cut on (SetupService/NpcService) or off. Lamps come back with the next level build.
function CameraService:SetPowerCut(on: boolean)
	powerCutActive = on
	for _, connection in lampConnections do
		connection:Disconnect()
	end
	table.clear(lampConnections)
	if on then
		for _, lamp in CollectionService:GetTagged(Tags.Lamp) do
			hookLamp(lamp)
		end
	end
end

-- Cameras in ViewCam order (sorted by full name; Models with a Body in the workspace).
function CameraService:GetCameras(): { Model }
	local list = {}
	for _, inst in CollectionService:GetTagged(Tags.SecurityCamera) do
		if inst:IsA("Model") and inst:IsDescendantOf(workspace) and inst:FindFirstChild("Body") then
			table.insert(list, inst)
		end
	end
	table.sort(list, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return list
end

function CameraService:GetCamera(index: number): Model?
	return CameraService:GetCameras()[index]
end

-- May a celled player spot `position` through camera `index`? (working camera, in range, line of sight)
function CameraService:CanSpotFrom(index: number, position: Vector3): boolean
	local model = CameraService:GetCamera(index)
	if not model or model:GetAttribute(Tags.Disabled) == true or isPowerCut() then
		return false
	end
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return false
	end
	local offset = position - body.Position
	if offset.Magnitude > C.Range * 1.5 then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { model }
	for _, inst in CollectionService:GetTagged(Tags.SeeThrough) do
		table.insert(ignore, inst)
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(body.Position, offset * 0.98, params)
	return result == nil or (result.Position - position).Magnitude < 4
end

local function rescan()
	table.clear(cams)
	for _, model in CollectionService:GetTagged(Tags.SecurityCamera) do
		register(model)
	end
end

function CameraService:Start()
	MapService.LevelBuilt:Connect(function()
		powerCutActive = false
		for _, connection in lampConnections do
			connection:Disconnect()
		end
		table.clear(lampConnections)
		rescan()
	end)
	rescan()
	CollectionService:GetInstanceAddedSignal(Tags.SecurityCamera):Connect(register)
	CollectionService:GetInstanceAddedSignal(Tags.Lamp):Connect(function(lamp)
		if isPowerCut() then
			hookLamp(lamp)
		end
	end)
	-- The Modifier attribute can arrive after the level (SetupService): follow it.
	ReplicatedStorage:GetAttributeChangedSignal(Tags.Modifier):Connect(function()
		if Targets.modifier() == "PowerCut" then
			CameraService:SetPowerCut(true)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then
			return
		end
		local step = acc
		acc = 0
		local fillSeconds = Targets.round().cameraFillSeconds
		local now = Targets.now()
		for index = #cams, 1, -1 do
			local cam = cams[index]
			if cam.model.Parent == nil then
				table.remove(cams, index)
			else
				update(cam, step, fillSeconds, now)
			end
		end
	end)
end

return CameraService
