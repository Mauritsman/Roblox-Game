--!strict
-- De vier gadgets van fase 1 (§4): Drone, Noisemaker, EMP, Crowbar.
-- De client vraagt alleen ("ik wil de EMP naar punt X gooien"); de server controleert en voert uit.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local AlarmService = require(script.Parent.AlarmService)
local GuardService = require(script.Parent.GuardService)
local LoadoutService = require(script.Parent.LoadoutService)
local MapService = require(script.Parent.MapService)

local GadgetService = {}

type DroneState = {
	part: BasePart,
	velocity: LinearVelocity,
	orientation: AlignOrientation,
	owner: Player,
}

local drones: { [Player]: DroneState } = {}
local battery: { [Player]: number } = {}
local empCooldownUntil: { [Player]: number } = {}
local disableTokens: { [Instance]: number } = {}
local recentNoisemakers: { { position: Vector3, time: number } } = {}

local function crewSize(): number
	return math.max(1, #Players:GetPlayers())
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function positionOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

--------------------------------------------------------------------------------
-- Elektronica uitzetten (EMP)
--------------------------------------------------------------------------------

local function setLampVisual(lamp: BasePart, disabled: boolean)
	local light = lamp:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = not disabled
	end
	-- De oorspronkelijke kleur bewaren: niet elke lamp is even warm (lantaarns, slingerlampjes, monitoren).
	if lamp:GetAttribute("OnColor") == nil then
		lamp:SetAttribute("OnColor", lamp.Color)
	end
	local onColor = lamp:GetAttribute("OnColor")
	lamp.Material = if disabled then Enum.Material.SmoothPlastic else Enum.Material.Neon
	lamp.Color = if disabled
		then Color3.fromRGB(50, 50, 50)
		elseif typeof(onColor) == "Color3" then onColor
		else Color3.fromRGB(255, 196, 130)
end

local function setDroneDisabled(drone: BasePart, disabled: boolean)
	for _, state in drones do
		if state.part == drone then
			state.velocity.Enabled = not disabled
			state.orientation.Enabled = not disabled
		end
	end
	local light = drone:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = not disabled
	end
end

function GadgetService:DisableElectronic(inst: Instance, seconds: number)
	local token = (disableTokens[inst] or 0) + 1
	disableTokens[inst] = token
	inst:SetAttribute(Tags.Disabled, true)
	if CollectionService:HasTag(inst, Tags.Lamp) and inst:IsA("BasePart") then
		setLampVisual(inst, true)
	elseif CollectionService:HasTag(inst, Tags.Drone) and inst:IsA("BasePart") then
		setDroneDisabled(inst, true)
	end
	task.delay(seconds, function()
		if disableTokens[inst] ~= token or inst.Parent == nil then
			return
		end
		disableTokens[inst] = nil
		inst:SetAttribute(Tags.Disabled, false)
		if CollectionService:HasTag(inst, Tags.Lamp) and inst:IsA("BasePart") then
			setLampVisual(inst, false)
		elseif CollectionService:HasTag(inst, Tags.Drone) and inst:IsA("BasePart") then
			setDroneDisabled(inst, false)
		end
	end)
end

--------------------------------------------------------------------------------
-- Werpen (Noisemaker en EMP)
--------------------------------------------------------------------------------

local function flyProjectile(from: Vector3, to: Vector3, color: Color3, onLand: (Vector3) -> ())
	local part = Instance.new("Part")
	part.Name = "Thrown"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.8, 0.8, 0.8)
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CFrame = CFrame.new(from)
	part.Parent = workspace
	local distance = (to - from).Magnitude
	local duration = math.clamp(distance / 32, 0.35, 1.1)
	local arcHeight = math.clamp(distance * 0.25, 2, 10)
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local t = math.min(1, elapsed / duration)
		local position = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * arcHeight, 0)
		part.CFrame = CFrame.new(position)
		if t >= 1 then
			connection:Disconnect()
			onLand(to)
			part:Destroy()
		end
	end)
end

local function spawnNoisemaker(position: Vector3, seconds: number)
	local clock = Instance.new("Part")
	clock.Name = "Noisemaker"
	clock.Size = Vector3.new(1, 1, 0.6)
	clock.Color = Color3.fromRGB(255, 210, 60)
	clock.Material = Enum.Material.Neon
	clock.Anchored = true
	clock.CanCollide = false
	clock.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0))
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Looped = true
	sound.Volume = 0.8
	sound.RollOffMaxDistance = Config.Gadgets.Noisemaker.HearRadius * 2
	sound.Parent = clock
	clock.Parent = workspace
	sound:Play()
	task.delay(seconds, function()
		clock:Destroy()
	end)
end

local function empPulseVisual(position: Vector3, radius: number)
	local sphere = Instance.new("Part")
	sphere.Name = "EMPPulse"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(1, 1, 1)
	sphere.CFrame = CFrame.new(position)
	sphere.Color = Color3.fromRGB(80, 220, 255)
	sphere.Material = Enum.Material.ForceField
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.Parent = workspace
	local tween = TweenService:Create(
		sphere,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * radius * 2, Transparency = 0.6 }
	)
	tween:Play()
	tween.Completed:Connect(function()
		sphere:Destroy()
	end)
end

local function onNoisemakerLanded(player: Player, position: Vector3)
	local cfg = Config.Gadgets.Noisemaker
	local now = os.clock()
	local repeated = false
	for index = #recentNoisemakers, 1, -1 do
		local entry = recentNoisemakers[index]
		if now - entry.time > cfg.RepeatWindow then
			table.remove(recentNoisemakers, index)
		elseif (entry.position - position).Magnitude <= cfg.RepeatDistance then
			repeated = true
		end
	end
	table.insert(recentNoisemakers, { position = position, time = now })

	local seconds = Config.windowSeconds(crewSize())
	spawnNoisemaker(position, cfg.RingSeconds)
	if repeated then
		-- §4.3: zelfde truc twee keer = geen afleiding, wel achterdocht en alarmpunten.
		local noticed = GuardService:HearNoise(position, cfg.HearRadius, Config.Guard.SearchSeconds, "repeat")
		if noticed > 0 then
			AlarmService:Add("NoisemakerRepeat")
			Net.broadcast("Toast", 'Guard: "Again?! Not falling for that."')
		end
		return
	end
	local heard = GuardService:HearNoise(position, cfg.HearRadius, seconds, "noisemaker")
	if heard > 0 then
		Net.broadcast("Window", "GUARD AWAY", seconds, position)
	else
		Net.send(player, "Toast", "No guard heard the Noisemaker")
	end
end

local function onEmpLanded(player: Player, position: Vector3)
	local cfg = Config.Gadgets.EMP
	local seconds = Config.windowSeconds(crewSize())
	empPulseVisual(position, cfg.Radius)
	local hitCameras, hitLamps = 0, 0
	local hitDrones: { string } = {}
	for _, inst in CollectionService:GetTagged(Tags.Electronic) do
		local instPosition = positionOf(inst)
		-- Horizontale afstand (zoals de cirkel op de grond), tot 16 studs hoog: camera's hangen hoog.
		local delta = if instPosition then instPosition - position else nil
		if delta and Vector3.new(delta.X, 0, delta.Z).Magnitude <= cfg.Radius and math.abs(delta.Y) <= 16 then
			GadgetService:DisableElectronic(inst, seconds)
			if CollectionService:HasTag(inst, Tags.SecurityCamera) then
				hitCameras += 1
			elseif CollectionService:HasTag(inst, Tags.Lamp) then
				hitLamps += 1
			elseif CollectionService:HasTag(inst, Tags.Drone) then
				local ownerId = inst:GetAttribute(Tags.Owner)
				local owner = if typeof(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
				table.insert(hitDrones, if owner then owner.Name else "?")
			end
		end
	end
	-- "BZZT" is hoorbaar: een bewaker vlakbij wordt even achterdochtig.
	GuardService:HearNoise(position, cfg.BzztRadius, 4, "bzzt")
	Net.broadcast("EMP", position, cfg.Radius, hitCameras, hitLamps, hitDrones)
	if hitCameras > 0 then
		Net.broadcast("Window", "CAMS OFF", seconds, position)
	elseif hitLamps > 0 then
		Net.broadcast("Window", "LIGHTS OFF", seconds, position)
	end
	local _ = player
end

--------------------------------------------------------------------------------
-- Bubble Blaster (grappig wapen, §4.8)
--------------------------------------------------------------------------------

local function bubbleTeammate(victim: Player, shooter: Player, seconds: number)
	local character = victim.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not character
		or not root
		or not root:IsA("BasePart")
		or not humanoid
		or character:GetAttribute("Bubbled")
	then
		return
	end
	character:SetAttribute("Bubbled", true)
	local previousSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	local bubble = Instance.new("Part")
	bubble.Name = "Bubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(6, 6, 6)
	bubble.Material = Enum.Material.Glass
	bubble.Transparency = 0.55
	bubble.Color = Color3.fromRGB(255, 190, 240)
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.Massless = true
	bubble.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bubble
	weld.Parent = bubble
	bubble.Parent = character
	Net.broadcast("Toast", `{shooter.DisplayName} bubbled {victim.DisplayName}! Oops.`)
	task.delay(seconds, function()
		bubble:Destroy()
		if character.Parent then
			character:SetAttribute("Bubbled", nil)
			if
				humanoid.WalkSpeed == 0
				and not character:GetAttribute(Tags.Operating)
				and not character:GetAttribute("Caught")
			then
				humanoid.WalkSpeed = if previousSpeed > 0 then previousSpeed else Config.Player.WalkSpeed
			end
		end
	end)
end

local function shootBubble(player: Player, from: Vector3, target: Vector3)
	local cfg = Config.Gadgets.BubbleBlaster
	local direction = target - from
	if direction.Magnitude < 0.5 then
		return
	end
	if direction.Magnitude > cfg.ThrowRange then
		direction = direction.Unit * cfg.ThrowRange
	end
	-- Waar botst de bel tegen? (muren stoppen hem)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local shooterIgnore: { Instance } = {}
	if player.Character then
		table.insert(shooterIgnore, player.Character)
	end
	params.FilterDescendantsInstances = shooterIgnore
	local hit = workspace:Raycast(from, direction, params)
	local endPoint = if hit then hit.Position else from + direction

	local ball = Instance.new("Part")
	ball.Name = "BubbleShot"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.4, 1.4, 1.4)
	ball.Material = Enum.Material.Glass
	ball.Transparency = 0.4
	ball.Color = Color3.fromRGB(255, 170, 230)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CFrame = CFrame.new(from)
	ball.Parent = workspace
	local travel = (endPoint - from).Magnitude / cfg.ProjectileSpeed
	local tween = TweenService:Create(
		ball,
		TweenInfo.new(travel, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(endPoint) }
	)
	tween:Play()
	tween.Completed:Connect(function()
		ball:Destroy()
		-- Wie staat er bij aankomst dichtbij? Een bewaker, of (oeps) een teamgenoot.
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = shooterIgnore
		local seconds = Config.windowSeconds(crewSize()) - 2
		for _, part in workspace:GetPartBoundsInRadius(endPoint, cfg.HitRadius, overlap) do
			local model = part:FindFirstAncestorOfClass("Model")
			if model and CollectionService:HasTag(model, Tags.Guard) then
				if GuardService:Bubble(model, math.max(seconds, cfg.BubbleSeconds)) then
					Net.broadcast("Window", "GUARD BUBBLED", math.max(seconds, cfg.BubbleSeconds), endPoint)
				end
				return
			end
			local victim = model and Players:GetPlayerFromCharacter(model)
			if victim and victim ~= player then
				bubbleTeammate(victim, player, cfg.FriendlySeconds)
				return
			end
		end
		Net.send(player, "Toast", "*pop* Missed!")
	end)
end

local function handleThrow(player: Player, gadgetName: any, target: any)
	if gadgetName ~= "Noisemaker" and gadgetName ~= "EMP" and gadgetName ~= "BubbleBlaster" then
		return
	end
	if typeof(target) ~= "Vector3" then
		return
	end
	local root = characterRoot(player)
	if not root or (player.Character and player.Character:GetAttribute("Caught")) then
		return
	end
	if not LoadoutService:Has(player, gadgetName) then
		Net.send(player, "Toast", `You don't have the {gadgetName:upper()}`)
		return
	end
	if gadgetName == "EMP" and (empCooldownUntil[player] or 0) > os.clock() then
		Net.send(player, "Toast", `EMP recharging: {math.ceil(empCooldownUntil[player] - os.clock())} s`)
		return
	end
	local cfg = Config.Gadgets[gadgetName]
	local from = root.Position + Vector3.new(0, 1.5, 0)
	local offset = target - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > cfg.ThrowRange then
		target = root.Position + flat.Unit * cfg.ThrowRange + Vector3.new(0, offset.Y, 0)
	end
	if not LoadoutService:UseCharge(player, gadgetName) then
		Net.send(player, "Toast", `No {gadgetName:upper()} charges left`)
		return
	end
	if gadgetName == "EMP" then
		empCooldownUntil[player] = os.clock() + cfg.Cooldown
	end
	if gadgetName == "BubbleBlaster" then
		shootBubble(player, from, target)
		return
	end
	local color = if gadgetName == "EMP" then Color3.fromRGB(80, 220, 255) else Color3.fromRGB(255, 210, 60)
	flyProjectile(from, target, color, function(landed)
		if gadgetName == "EMP" then
			onEmpLanded(player, landed)
		else
			onNoisemakerLanded(player, landed)
		end
	end)
end

--------------------------------------------------------------------------------
-- Drone
--------------------------------------------------------------------------------

local function setOperating(player: Player, operating: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character then
		character:SetAttribute(Tags.Operating, operating)
		character:SetAttribute(Tags.Crouching, operating or nil)
	end
	if humanoid then
		humanoid.WalkSpeed = if operating then 0 else Config.Player.WalkSpeed
		humanoid.JumpHeight = if operating then 0 else 7.2
	end
end

function GadgetService:RecallDrone(player: Player, reason: string?)
	local state = drones[player]
	if not state then
		return
	end
	drones[player] = nil
	if state.part.Parent then
		state.part:Destroy()
	end
	setOperating(player, false)
	Net.send(player, "DroneEnded", reason or "")
end

local function launchDrone(player: Player)
	if drones[player] then
		return
	end
	if not LoadoutService:Has(player, "Drone") then
		Net.send(player, "Toast", "You don't have the DRONE")
		return
	end
	local root = characterRoot(player)
	if not root then
		return
	end
	local cfg = Config.Gadgets.Drone
	if (battery[player] or cfg.BatterySeconds) < cfg.BatterySeconds * 0.25 then
		Net.send(player, "Toast", "Drone battery too low, wait a moment")
		return
	end

	local part = Instance.new("Part")
	part.Name = "Drone_" .. player.Name
	part.Size = Vector3.new(1.8, 0.5, 1.8)
	part.Color = Color3.fromRGB(70, 160, 255)
	part.Material = Enum.Material.Metal
	part.CFrame = root.CFrame * CFrame.new(0, 4, -2)
	part.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0.2)
	part.CollisionGroup = "Drone" -- botst niet met spelers en bewakers
	local attachment = Instance.new("Attachment")
	attachment.Name = "Center"
	attachment.Parent = part
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = 800 -- genoeg om te vliegen, te weinig om iemand weg te duwen
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = part
	local orientation = Instance.new("AlignOrientation")
	orientation.Attachment0 = attachment
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.MaxTorque = 800
	orientation.Responsiveness = 40
	orientation.CFrame = CFrame.new()
	orientation.Parent = part
	local light = Instance.new("PointLight")
	light.Range = 6
	light.Brightness = 0.8
	light.Color = Color3.fromRGB(70, 160, 255)
	light.Parent = part
	part:SetAttribute(Tags.Owner, player.UserId)
	part:SetAttribute(Tags.Disabled, false)
	part:SetAttribute(Tags.SpotKind, "drone")
	part.Parent = workspace
	CollectionService:AddTag(part, Tags.Drone)
	CollectionService:AddTag(part, Tags.Electronic)
	pcall(function()
		part:SetNetworkOwner(player) -- de speler stuurt de drone zelf: geen vertraging
	end)

	drones[player] = { part = part, velocity = velocity, orientation = orientation, owner = player }
	battery[player] = battery[player] or cfg.BatterySeconds
	setOperating(player, true)
	Net.send(player, "DroneStarted", part)
end

local function updateDrones(dt: number)
	local cfg = Config.Gadgets.Drone
	for _, player in Players:GetPlayers() do
		local state = drones[player]
		local level = battery[player] or cfg.BatterySeconds
		if state then
			if state.part.Parent == nil then
				GadgetService:RecallDrone(player, "Drone lost")
				continue
			end
			if state.part:GetAttribute(Tags.Disabled) ~= true then
				level -= dt
			end
			local root = characterRoot(player)
			if not root or (player.Character and player.Character:GetAttribute("Caught")) then
				GadgetService:RecallDrone(player, "")
			elseif level <= 0 then
				level = 0
				GadgetService:RecallDrone(player, "Battery empty")
			elseif (state.part.Position - root.Position).Magnitude > cfg.Range + 8 then
				GadgetService:RecallDrone(player, "Signal lost (cable too short)")
			end
		else
			level = math.min(cfg.BatterySeconds, level + dt * cfg.BatterySeconds / cfg.RechargeSeconds)
		end
		battery[player] = level
		-- Alleen per 5% doorsturen, anders herbouwt de HUD elke frame.
		local rounded = math.floor(level / cfg.BatterySeconds * 20) / 20
		if player:GetAttribute("DroneBattery") ~= rounded then
			player:SetAttribute("DroneBattery", rounded)
		end
	end
end

local function handleDrone(player: Player, action: any)
	if action == "launch" then
		launchDrone(player)
	elseif action == "recall" then
		GadgetService:RecallDrone(player, "")
	end
end

--------------------------------------------------------------------------------
-- Crowbar
--------------------------------------------------------------------------------

local function openPryable(target: BasePart, player: Player)
	target.CanCollide = false
	target.CanQuery = false
	local hinge = target.CFrame * CFrame.new(0, 0, -target.Size.Z / 2)
	local opened = hinge * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(0, 0, target.Size.Z / 2)
	TweenService:Create(target, TweenInfo.new(0.35, Enum.EasingStyle.Back), { CFrame = opened }):Play()
	CollectionService:RemoveTag(target, Tags.Pryable)
	CollectionService:RemoveTag(target, Tags.Spottable)

	local crack = Instance.new("Sound")
	crack.SoundId = "rbxasset://sounds/clickfast.wav"
	crack.Volume = 1
	crack.PlaybackSpeed = 0.6
	crack.Parent = target
	crack:Play()

	local heard = GuardService:HearNoise(target.Position, Config.Gadgets.Crowbar.CrackRadius, nil, "crack")
	if heard > 0 then
		AlarmService:Add("CrackHeard")
	end
	Net.broadcast("Crack", target.Position, heard, player.Name)
end

local function hookPryable(inst: Instance)
	if not inst:IsA("BasePart") or inst:FindFirstChild("PryPrompt") then
		return
	end
	local seconds = inst:GetAttribute("PrySeconds")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PryPrompt"
	prompt.ActionText = "Pry open"
	prompt.ObjectText = "Crowbar"
	prompt.HoldDuration = if typeof(seconds) == "number" then seconds else Config.Gadgets.Crowbar.DoorSeconds
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = inst
	prompt.Triggered:Connect(function(player)
		GadgetService:Pry(player, inst)
	end)
end

-- De Crowbar gebruiken op een Pryable-object (knop, of DevService in Studio).
function GadgetService:Pry(player: Player, target: BasePart)
	local prompt = target:FindFirstChild("PryPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
		return
	end
	if not LoadoutService:Has(player, "Crowbar") then
		Net.send(player, "Toast", "Needs the CROWBAR")
		return
	end
	-- Niet meteen vernietigen: dan blijft de prompt-weergave bij de speler hangen
	-- en verschijnen er geen andere knoppen meer. Eerst uitzetten, later opruimen.
	prompt.Enabled = false
	task.delay(1, function()
		prompt:Destroy()
	end)
	openPryable(target, player)
end

--------------------------------------------------------------------------------

function GadgetService:Start()
	Net.onRequest("Throw", handleThrow)
	Net.onRequest("Drone", handleDrone)
	Net.onRequest("Crouch", function(player: Player, crouching: any)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			not character
			or not humanoid
			or character:GetAttribute(Tags.Operating)
			or character:GetAttribute("Caught")
		then
			return
		end
		local on = crouching == true
		character:SetAttribute(Tags.Crouching, on)
		humanoid.WalkSpeed = if on then Config.Player.CrouchSpeed else Config.Player.WalkSpeed
	end)

	for _, inst in CollectionService:GetTagged(Tags.Pryable) do
		hookPryable(inst)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Pryable):Connect(hookPryable)

	MapService.LevelBuilt:Connect(function()
		for player in drones do
			GadgetService:RecallDrone(player, "")
		end
		table.clear(empCooldownUntil)
		table.clear(recentNoisemakers)
		table.clear(disableTokens)
		table.clear(battery)
	end)

	Players.PlayerRemoving:Connect(function(player)
		GadgetService:RecallDrone(player, "")
		battery[player] = nil
		empCooldownUntil[player] = nil
	end)

	RunService.Heartbeat:Connect(updateDrones)
end

return GadgetService
