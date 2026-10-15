--!strict
-- De drone besturen (§4.1). De speler is netwerkeigenaar van de drone, dus vliegen voelt direct.
-- De camera volgt de drone; WASD/joystick vliegt in de kijkrichting, spatie/Ctrl of ▲/▼ voor hoogte.
-- Bewakers en camera's die de drone 0,5 s ziet, worden automatisch gemarkeerd voor de crew.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local ClientState = require(Lib.ClientState)
local Hud = require(Lib.Hud)

local DroneController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local D = Config.Gadgets.Drone

local controls: any = nil
local seenSince: { [Instance]: number } = {}
local lastAutoSpot: { [Instance]: number } = {}
local wasDisabled = false

local function getControls(): any
	if controls then
		return controls
	end
	local ok, module = pcall(function()
		local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
		return (require :: any)(playerModule):GetControls()
	end)
	if ok then
		controls = module
	end
	return controls
end

local function characterRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function spottablePosition(inst: Instance): Vector3?
	if inst:IsA("Model") then
		return inst:GetPivot().Position
	elseif inst:IsA("BasePart") then
		return inst.Position
	end
	return nil
end

local function autoSpot(drone: BasePart)
	local now = os.clock()
	local look = camera.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { drone, player.Character :: Instance }
	for _, target in CollectionService:GetTagged(Tags.Spottable) do
		local kind = target:GetAttribute(Tags.SpotKind)
		if kind == "guard" or kind == "camera" then
			local position = spottablePosition(target)
			local visible = false
			if position then
				local offset = position - drone.Position
				if offset.Magnitude < 60 and look:Dot(offset.Unit) > math.cos(math.rad(40)) then
					local result = workspace:Raycast(drone.Position, offset, params)
					visible = result == nil or result.Instance:IsDescendantOf(target)
				end
			end
			if visible then
				seenSince[target] = seenSince[target] or now
				local longEnough = now - (seenSince[target] :: number) >= D.AutoSpotSeconds
				local cooledDown = now - (lastAutoSpot[target] or 0) > 3
				if longEnough and cooledDown then
					lastAutoSpot[target] = now
					Net.request("DroneSpot", target)
				end
			else
				seenSince[target] = nil
			end
		end
	end
end

local function stopDrone(reason: string?)
	local drone = ClientState.drone
	ClientState.set("drone", nil)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
		humanoid.CameraOffset = Vector3.zero
	end
	Hud.setCrosshair(Actions.preferredInput() ~= "KeyboardAndMouse")
	table.clear(seenSince)
	table.clear(lastAutoSpot)
	if reason and reason ~= "" then
		Hud.toast(reason, Hud.Colors.Warn)
	end
	local _ = drone
end

local function flyStep(dt: number)
	local drone = ClientState.drone
	if not drone then
		return
	end
	if drone.Parent == nil then
		stopDrone("Drone lost")
		return
	end
	local velocity = drone:FindFirstChildOfClass("LinearVelocity")
	local orientation = drone:FindFirstChildOfClass("AlignOrientation")
	local disabled = drone:GetAttribute(Tags.Disabled) == true
	if disabled and not wasDisabled then
		Hud.banner("BZZT! DRONE DOWN", Hud.Colors.Danger, 2)
	end
	wasDisabled = disabled
	if disabled or not velocity then
		return
	end

	local move = Vector3.zero
	local c = getControls()
	if c then
		move = c:GetMoveVector() -- x = links/rechts, z = vooruit/achteruit (camera-relatief)
	end
	local camCF = camera.CFrame
	local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
	forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.zAxis
	local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
	right = if right.Magnitude > 0.01 then right.Unit else Vector3.xAxis
	local vertical = 0
	if Actions.isHeld("DroneUp") then
		vertical += 1
	end
	if Actions.isHeld("DroneDown") then
		vertical -= 1
	end
	local desired = (forward * -move.Z + right * move.X) * D.Speed + Vector3.yAxis * vertical * D.Speed * 0.6

	-- De LAN-kabel: niet verder dan het bereik van je lichaam (de server controleert dit ook).
	local root = characterRoot()
	if root then
		local offset = drone.Position - root.Position
		if offset.Magnitude > D.Range and desired:Dot(offset) > 0 then
			desired -= offset.Unit * desired:Dot(offset.Unit)
			desired -= offset.Unit * 4
		end
	end
	velocity.VectorVelocity = desired
	if orientation then
		orientation.CFrame = CFrame.lookAt(Vector3.zero, forward)
	end
	local _ = dt
end

local function spotFromDrone()
	local drone = ClientState.drone
	if not drone then
		return
	end
	local size = camera.ViewportSize
	local ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { drone, player.Character :: Instance }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if result then
		Net.request("Spot", result.Instance, result.Position)
	end
end

function DroneController:Start()
	Net.on("DroneStarted", function(drone: BasePart?)
		if not drone then
			-- Kan gebeuren met StreamingEnabled: land meteen, anders staat de speler vast.
			Net.request("Drone", "recall")
			return
		end
		ClientState.set("aiming", false)
		ClientState.set("drone", drone)
		camera.CameraSubject = drone
		Hud.setCrosshair(true)
		Hud.toast("Drone up. Look at guards to mark them. F / BACK to land.", Hud.Colors.Eyes)
	end)
	Net.on("DroneEnded", function(reason: string)
		stopDrone(reason)
	end)

	Actions.on("DroneRecall", function(phase)
		local operating = player.Character ~= nil and player.Character:GetAttribute(Tags.Operating) == true
		if phase == "Begin" and (ClientState.drone or operating) then
			Net.request("Drone", "recall")
		end
	end)
	-- In dronemodus is klikken/R2/SPOT = markeren wat in het midden van het beeld staat.
	Actions.on("MouseAim", function(phase)
		if phase == "Begin" and ClientState.drone then
			spotFromDrone()
		end
	end)
	Actions.on("Fire", function(phase)
		if phase == "Begin" and ClientState.drone then
			spotFromDrone()
		end
	end)
	Actions.on("Spot", function(phase)
		if phase == "Begin" and ClientState.drone then
			spotFromDrone()
		end
	end)

	player.CharacterAdded:Connect(function()
		if ClientState.drone then
			stopDrone(nil)
		end
	end)

	local spotTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		flyStep(dt)
		local drone = ClientState.drone
		if drone and drone:GetAttribute(Tags.Disabled) ~= true then
			spotTimer += dt
			if spotTimer >= 0.2 then
				spotTimer = 0
				autoSpot(drone)
			end
		end
	end)
end

return DroneController
