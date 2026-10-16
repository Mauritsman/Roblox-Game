--!strict
-- Gadgets (beta-spec §5): the Crowbar (everyone) and the picked Drone / Noisemaker / EMP / Bubble Blaster.
-- The client only asks ("throw the EMP at point X"); the server checks and carries it out. Fixed durations
-- (no shared window): Noisemaker distracts 8 s, EMP 10 s, a bubble holds a guard 8 s and a teammate 3 s.
--
-- Rules for every gadget and the Crowbar: only in a crew round, refused with full hands ("Hands full!",
-- CarryService:HandsFull) and while frozen, caught, hidden, bubbled or flying the drone (MovementService:CanGadget).
-- Speeds are MovementService's: this service only sets attributes (`Operating`, `Bubbled`, `Crouching`).
--
-- Entry points: ResetRound(players, job) (only those players: drone, battery, EMP cooldown), RecallDrone(player,
-- reason), Pry(player, target), DisableElectronic(inst, seconds). Requests: Throw, Drone.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Loadout = require(ReplicatedStorage.Shared.Logic.Loadout)

local AlarmService = require(script.Parent.AlarmService)
local CarryService = require(script.Parent.CarryService)
local GuardService = require(script.Parent.GuardService)
local LoadoutService = require(script.Parent.LoadoutService)
local MapService = require(script.Parent.MapService)
local MovementService = require(script.Parent.MovementService)
local StatsService = require(script.Parent.StatsService)

local GadgetService = {}

type DroneState = {
	part: BasePart,
	velocity: LinearVelocity,
	orientation: AlignOrientation,
	owner: Player,
}

local GADGETS = Config.Gadgets :: any
-- Package B's GuardService takes an extra `by` (the player) in HearNoise and Bubble; the prototype ignores it.
local Guards: any = GuardService
local THROWABLE = { Noisemaker = true, EMP = true, BubbleBlaster = true }

local drones: { [Player]: DroneState } = {}
local battery: { [Player]: number } = {}
local empCooldownUntil: { [Player]: number } = {}
local disableTokens: { [Instance]: number } = {}
local recentNoisemakers: { { position: Vector3, time: number } } = {}
local lastThrow: { [Player]: number } = {}

local function label(gadgetName: string): string
	return Loadout.label(gadgetName, GADGETS)
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

local function stat(name: string, player: Player)
	-- StatsService.Event is a callable Signal (not a plain function), so it is called directly, guarded.
	local ok, err = pcall(function()
		(StatsService :: any):Event(name, player)
	end)
	if not ok then
		warn(`[GadgetService] stat {name} failed: {err}`)
	end
end

-- Gadgets belong to a crew round (Activity "Crew"); without a round service (no Activity) they always work.
local function inRound(player: Player): boolean
	local activity = player:GetAttribute(Tags.Activity)
	return activity == nil or activity == "Crew"
end

-- May this player use a gadget or the Crowbar now? Tells them why not when it helps.
local function ready(player: Player): boolean
	if not inRound(player) or not characterRoot(player) then
		return false
	end
	if CarryService:HandsFull(player) then
		Net.send(player, "Toast", "Hands full!")
		return false
	end
	return MovementService:CanGadget(player)
end

-- Mask Up (beta-spec §13, proposed): using a gadget or the Crowbar puts your mask on.
local function maskUp(player: Player)
	local character = player.Character
	if character and Config.Features.MaskUp and player:GetAttribute(Tags.Activity) == "Crew" then
		character:SetAttribute(Tags.Masked, true)
	end
end

--------------------------------------------------------------------------------
-- Switching off electronics (EMP)
--------------------------------------------------------------------------------

local function setLampVisual(lamp: BasePart, disabled: boolean)
	local light = lamp:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = not disabled
	end
	-- Keep the original colour: not every lamp is equally warm (lanterns, string lights, monitors).
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
-- Throwing (Noisemaker and EMP)
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

-- The ringing clock. It is a trace for Karel (TraceKind "Noisemaker") while it rings.
local function spawnNoisemaker(player: Player, position: Vector3, seconds: number)
	local clock = Instance.new("Part")
	clock.Name = "Noisemaker"
	clock.Size = Vector3.new(1, 1, 0.6)
	clock.Color = Color3.fromRGB(255, 210, 60)
	clock.Material = Enum.Material.Neon
	clock.Anchored = true
	clock.CanCollide = false
	clock.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0))
	clock:SetAttribute(Tags.TraceKind, "Noisemaker")
	clock:SetAttribute(Tags.TraceBy, player.UserId)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Looped = true
	sound.Volume = 0.8
	sound.RollOffMaxDistance = GADGETS.Noisemaker.HearRadius * 2
	sound.Parent = clock
	clock.Parent = MapService.Level or workspace
	CollectionService:AddTag(clock, Tags.Trace)
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
	local cfg = GADGETS.Noisemaker
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

	spawnNoisemaker(player, position, cfg.RingSeconds)
	if repeated then
		-- The same trick twice: no distraction, but suspicion and alarm points.
		local noticed =
			Guards:HearNoise(position, cfg.HearRadius, Config.Guard.SearchSeconds, "repeat", player)
		if noticed > 0 then
			AlarmService:Add("NoisemakerRepeat")
			Net.broadcast("Toast", 'Guard: "Again?! Not falling for that."')
		end
		return
	end
	-- "noisemaker" also makes a carrying guard drop his captive and lures Boef (GuardService).
	local heard = Guards:HearNoise(position, cfg.HearRadius, cfg.DistractSeconds, "noisemaker", player)
	if heard > 0 then
		Net.broadcast("Window", "GUARD AWAY", cfg.DistractSeconds, position)
	else
		Net.send(player, "Toast", "No guard heard the NOISEMAKER")
	end
end

local function onEmpLanded(player: Player, position: Vector3)
	local cfg = GADGETS.EMP
	local seconds = cfg.DisableSeconds
	empPulseVisual(position, cfg.Radius)
	local hitCameras, hitLamps = 0, 0
	local hitDrones: { string } = {}
	local selfHit = false
	for _, inst in CollectionService:GetTagged(Tags.Electronic) do
		local instPosition = positionOf(inst)
		-- Horizontal distance (like the circle on the ground), up to 16 studs high: cameras hang high.
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
				if owner == player then
					selfHit = true
				end
			end
		end
	end
	if selfHit then
		stat("SelfEmp", player) -- Self-EMP Award
	end
	-- "BZZT" is audible: a guard nearby becomes briefly suspicious.
	Guards:HearNoise(position, cfg.BzztRadius, 4, "bzzt", player)
	Net.broadcast("EMP", position, cfg.Radius, hitCameras, hitLamps, hitDrones)
	if hitCameras > 0 then
		Net.broadcast("Window", "CAMS OFF", seconds, position)
	elseif hitLamps > 0 then
		Net.broadcast("Window", "LIGHTS OFF", seconds, position)
	end
end

--------------------------------------------------------------------------------
-- Bubble Blaster (funny weapon, gameplan §4.8)
--------------------------------------------------------------------------------

local function bubbleTeammate(victim: Player, shooter: Player, seconds: number)
	local character = victim.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") or character:GetAttribute(Tags.Bubbled) then
		return
	end
	character:SetAttribute(Tags.Bubbled, true)
	MovementService:Refresh(victim)
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
	stat("BubbledTeammate", shooter) -- "Oops, Bubbled"
	Net.broadcast("Toast", `{shooter.DisplayName} bubbled {victim.DisplayName}! Oops.`)
	task.delay(seconds, function()
		bubble:Destroy()
		if character.Parent then
			character:SetAttribute(Tags.Bubbled, nil)
			MovementService:Refresh(victim)
		end
	end)
end

local function bubbleGuard(player: Player, model: Model, position: Vector3): boolean
	local seconds = GADGETS.BubbleBlaster.BubbleSeconds
	if not Guards:Bubble(model, seconds, player) then
		return false
	end
	stat("BubbledGuard", player)
	Net.broadcast("Window", "GUARD BUBBLED", seconds, position)
	-- The radio check 4 s later (Normal/Hard) is ObjectiveService's: it listens to GuardService.Bubbled.
	return true
end

local function shootBubble(player: Player, from: Vector3, target: Vector3)
	local cfg = GADGETS.BubbleBlaster
	local direction = target - from
	if direction.Magnitude < 0.5 then
		return
	end
	if direction.Magnitude > cfg.ThrowRange then
		direction = direction.Unit * cfg.ThrowRange
	end
	-- What does the bubble hit? (walls stop it)
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
		-- Who is close by when it arrives? A guard, the Inspector, or (oops) a teammate.
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = shooterIgnore
		for _, part in workspace:GetPartBoundsInRadius(endPoint, cfg.HitRadius, overlap) do
			local model = part:FindFirstAncestorOfClass("Model")
			if model and CollectionService:HasTag(model, Tags.Guard) then
				-- Guards and the Inspector (also tagged Guard; GuardService passes him on to NpcService).
				if not bubbleGuard(player, model, endPoint) then
					Net.send(player, "Toast", "*pop* No effect!")
				end
				return
			end
			if model and CollectionService:HasTag(model, Tags.Npc) then
				-- Karel and Boef cannot be bubbled.
				Net.send(player, "Toast", "*boing* It bounced off!")
				return
			end
			local victim = model and Players:GetPlayerFromCharacter(model)
			if victim and victim ~= player and victim:GetAttribute(Tags.Activity) ~= "Garage" then
				bubbleTeammate(victim, player, cfg.FriendlySeconds)
				return
			end
		end
		Net.send(player, "Toast", "*pop* Missed!")
	end)
end

local function handleThrow(player: Player, gadgetName: any, target: any)
	if type(gadgetName) ~= "string" or not THROWABLE[gadgetName] then
		return
	end
	if typeof(target) ~= "Vector3" or target ~= target or target.Magnitude > 1e6 then
		return
	end
	local now = os.clock()
	if now - (lastThrow[player] or 0) < 0.25 then
		return
	end
	lastThrow[player] = now
	if not ready(player) then
		return
	end
	local root = characterRoot(player) :: BasePart
	if not LoadoutService:Has(player, gadgetName) then
		Net.send(player, "Toast", `You don't have the {label(gadgetName)}`)
		return
	end
	if gadgetName == "EMP" and (empCooldownUntil[player] or 0) > now then
		Net.send(player, "Toast", `EMP recharging: {math.ceil(empCooldownUntil[player] - now)} s`)
		return
	end
	local cfg = GADGETS[gadgetName]
	local from = root.Position + Vector3.new(0, 1.5, 0)
	local offset = target - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > cfg.ThrowRange then
		target = root.Position + flat.Unit * cfg.ThrowRange + Vector3.new(0, offset.Y, 0)
	end
	if not LoadoutService:UseCharge(player, gadgetName) then
		Net.send(player, "Toast", `No {label(gadgetName)} charges left`)
		return
	end
	maskUp(player)
	if gadgetName == "EMP" then
		empCooldownUntil[player] = now + cfg.Cooldown
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

-- Flying the drone: the pilot stands still in a crouch (MovementService reads `Operating`).
local function setOperating(player: Player, operating: boolean)
	local character = player.Character
	if character then
		character:SetAttribute(Tags.Operating, operating)
		character:SetAttribute(Tags.Crouching, operating)
		MovementService:Refresh(player)
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
	if drones[player] or not ready(player) then
		return
	end
	if not LoadoutService:Has(player, "Drone") then
		Net.send(player, "Toast", "You don't have the DRONE")
		return
	end
	local root = characterRoot(player) :: BasePart
	local cfg = GADGETS.Drone
	if (battery[player] or cfg.BatterySeconds) < cfg.BatterySeconds * 0.25 then
		Net.send(player, "Toast", "Drone battery too low, wait a moment")
		return
	end
	maskUp(player)

	local part = Instance.new("Part")
	part.Name = "Drone_" .. player.Name
	part.Size = Vector3.new(1.8, 0.5, 1.8)
	part.Color = Color3.fromRGB(70, 160, 255)
	part.Material = Enum.Material.Metal
	part.CFrame = root.CFrame * CFrame.new(0, 4, -2)
	part.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0.2)
	part.CollisionGroup = "Drone" -- does not collide with players and guards
	local attachment = Instance.new("Attachment")
	attachment.Name = "Center"
	attachment.Parent = part
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = 800 -- enough to fly, too little to push anyone away
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
		part:SetNetworkOwner(player) -- the player steers the drone directly: no lag
	end)

	drones[player] = { part = part, velocity = velocity, orientation = orientation, owner = player }
	battery[player] = battery[player] or cfg.BatterySeconds
	setOperating(player, true)
	Net.send(player, "DroneStarted", part)
end

local function updateDrones(dt: number)
	local cfg = GADGETS.Drone
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
			local character = player.Character
			local stopped = character
				and (
					character:GetAttribute(Tags.Caught)
					or character:GetAttribute(Tags.Captured)
					or character:GetAttribute(Tags.Frozen)
				)
			if not root or stopped or not inRound(player) then
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
		-- Only send it in 5% steps, otherwise the HUD rebuilds every frame.
		local rounded = math.floor(level / cfg.BatterySeconds * 20) / 20
		if player:GetAttribute(Tags.DroneBattery) ~= rounded then
			player:SetAttribute(Tags.DroneBattery, rounded)
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

-- A pried door swings open around its edge on the local −Z side. It keeps `ClosedCFrame` and becomes a trace
-- (TraceKind "OpenDoor") so Karel can close it again.
local function openPryable(target: BasePart, player: Player)
	if target:GetAttribute(Tags.ClosedCFrame) == nil then
		target:SetAttribute(Tags.ClosedCFrame, target.CFrame)
	end
	target.CanCollide = false
	target.CanQuery = false
	local hinge = target.CFrame * CFrame.new(0, 0, -target.Size.Z / 2)
	local opened = hinge * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(0, 0, target.Size.Z / 2)
	TweenService:Create(target, TweenInfo.new(0.35, Enum.EasingStyle.Back), { CFrame = opened }):Play()
	CollectionService:RemoveTag(target, Tags.Pryable)
	CollectionService:RemoveTag(target, Tags.Spottable)
	target:SetAttribute(Tags.DoorState, "Open")
	target:SetAttribute(Tags.TraceKind, "OpenDoor")
	target:SetAttribute(Tags.TraceBy, player.UserId)
	CollectionService:AddTag(target, Tags.Trace)

	local crack = Instance.new("Sound")
	crack.SoundId = "rbxasset://sounds/clickfast.wav"
	crack.Volume = 1
	crack.PlaybackSpeed = 0.6
	crack.Parent = target
	crack:Play()

	-- CRACK radius per player (Quiet Crowbar perk).
	local radius = LoadoutService:StatsOf(player).CrackRadius
	-- Loud machines (Praline mixer) drown out the CRACK: nobody hears it.
	local runtime = script.Parent:FindFirstChild("MapRuntimeService")
	local masked = false
	if runtime and runtime:IsA("ModuleScript") then
		local ok, result = pcall(function()
			return (require :: any)(runtime):IsNoiseMasked(target.Position)
		end)
		masked = ok and result == true
	end
	local heard = if masked then 0 else Guards:HearNoise(target.Position, radius, nil, "crack", player)
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
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.HoldDuration = if typeof(seconds) == "number" then seconds else GADGETS.Crowbar.DoorSeconds
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("ContextIcon", "pry")
	prompt.Parent = inst
	prompt.Triggered:Connect(function(player)
		GadgetService:Pry(player, inst)
	end)
end

-- Use the Crowbar on a Pryable object (prompt, or DevService in Studio with `dev` = true: skips the round and
-- hands checks).
function GadgetService:Pry(player: Player, target: BasePart, dev: boolean?)
	local prompt = target:FindFirstChild("PryPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
		return
	end
	if not dev and not ready(player) then
		return
	end
	if
		target:GetAttribute(Tags.LoudOnly) == true
		and ReplicatedStorage:GetAttribute(Tags.Approach) ~= "Loud"
	then
		Net.send(player, "Toast", "Too noisy! Only during a LOCKDOWN.")
		return
	end
	maskUp(player)
	-- Do not destroy it straight away: the prompt display would get stuck for the player
	-- and no other buttons would appear any more. Disable it first, clean up later.
	prompt.Enabled = false
	task.delay(1, function()
		prompt:Destroy()
	end)
	openPryable(target, player)
end

--------------------------------------------------------------------------------

-- Briefing and JUMP IN: a fresh drone battery and EMP cooldown for exactly these players.
function GadgetService:ResetRound(players: { Player }, _job: any?): boolean
	if type(players) ~= "table" then
		return false
	end
	for _, player in players do
		if typeof(player) == "Instance" and player:IsA("Player") then
			GadgetService:RecallDrone(player, "")
			battery[player] = nil
			empCooldownUntil[player] = nil
		end
	end
	return true
end

function GadgetService:Start()
	Net.onRequest("Throw", handleThrow)
	Net.onRequest("Drone", handleDrone)

	for _, inst in CollectionService:GetTagged(Tags.Pryable) do
		hookPryable(inst)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Pryable):Connect(hookPryable)

	MapService.LevelBuilt:Connect(function()
		for player in drones do
			GadgetService:RecallDrone(player, "")
		end
		table.clear(recentNoisemakers)
		for inst in disableTokens do
			if inst.Parent == nil then
				disableTokens[inst] = nil
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		GadgetService:RecallDrone(player, "")
		battery[player] = nil
		empCooldownUntil[player] = nil
		lastThrow[player] = nil
	end)

	RunService.Heartbeat:Connect(updateDrones)
end

return GadgetService
