--!strict
-- Bewakers (§9.1): vier toestanden met een icoon boven het hoofd.
--   Patrol      vaste route
--   Suspicious  loopt naar iets wat hij zag of hoorde en zoekt even ("?")
--   Alert       achtervolgt een speler en pakt hem bij aanraking ("!")
--   Search      zoekt rond de laatste plek na een achtervolging ("?!")
-- Bewakers hebben geen wapens: een zaklamp en een radio.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local AlarmService = require(script.Parent.AlarmService)
local MapService = require(script.Parent.MapService)

local GuardService = {}

type GuardState = "Patrol" | "Suspicious" | "Alert" | "Search"

type Guard = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	state: GuardState,
	routeIndex: number,
	meters: { [Player]: number },
	target: Player?,
	targetPos: Vector3?,
	arrived: boolean,
	stateUntil: number,
	lastSeenAt: number,
	droneSeenFor: number,
	distractedUntil: number,
	icon: TextLabel,
	meterFill: Frame,
	walkTrack: AnimationTrack?,
}

local guards: { Guard } = {}
local captureCallback: ((player: Player, guard: Model) -> ())? = nil

local G = Config.Guard
local COS_HALF = math.cos(math.rad(G.ConeHalfAngle))

local STATE_ICONS: { [GuardState]: { text: string, color: Color3 } } = {
	Patrol = { text = "", color = Color3.new(1, 1, 1) },
	Suspicious = { text = "?", color = Color3.fromRGB(255, 220, 60) },
	Alert = { text = "!", color = Color3.fromRGB(255, 60, 60) },
	Search = { text = "?!", color = Color3.fromRGB(255, 150, 40) },
}

-- Wordt door RoundService ingevuld: wat er gebeurt als een bewaker iemand pakt.
function GuardService:OnCapture(callback: (player: Player, guard: Model) -> ())
	captureCallback = callback
end

local function createRig(): Model
	-- Probeer een echt Roblox-personage; lukt dat niet, dan een eenvoudig blok met Humanoid.
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local navy = Color3.fromRGB(40, 52, 90)
		local skin = Color3.fromRGB(234, 184, 146)
		description.HeadColor = skin
		description.LeftArmColor = navy
		description.RightArmColor = navy
		description.TorsoColor = navy
		description.LeftLegColor = Color3.fromRGB(30, 30, 40)
		description.RightLegColor = Color3.fromRGB(30, 30, 40)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		return model
	end
	warn("[GuardService] CreateHumanoidModelFromDescription faalde, gebruik blok-bewaker:", model)
	local fallback = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 4.5, 1.5)
	root.Color = Color3.fromRGB(40, 52, 90)
	root.Parent = fallback
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Color = Color3.fromRGB(234, 184, 146)
	head.Parent = fallback
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	head.CFrame = root.CFrame * CFrame.new(0, 2.95, 0)
	weld.Parent = root
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 0.75
	humanoid.Parent = fallback
	fallback.PrimaryPart = root
	return fallback
end

local function addFlashlight(model: Model)
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("HumanoidRootPart")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local torch = Instance.new("Part")
	torch.Name = "Flashlight"
	torch.Size = Vector3.new(0.4, 0.4, 1.2)
	torch.Color = Color3.fromRGB(20, 20, 20)
	torch.Massless = true
	torch.CanCollide = false
	torch.CFrame = hand.CFrame * CFrame.new(0, -0.3, -0.6)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = torch
	weld.Parent = torch
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = G.ConeHalfAngle * 2
	light.Range = 26
	light.Brightness = 2.5
	light.Color = Color3.fromRGB(255, 244, 214)
	light.Shadows = true
	light.Parent = torch
	torch.Parent = model
end

local function addBillboard(model: Model): (TextLabel, Frame)
	local head = model:FindFirstChild("Head") :: BasePart?
	local gui = Instance.new("BillboardGui")
	gui.Name = "GuardState"
	gui.Size = UDim2.fromOffset(60, 70)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	if head then
		gui.Adornee = head
	end
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 0, 52)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBlack
	icon.TextScaled = true
	icon.TextStrokeTransparency = 0
	icon.Text = ""
	icon.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "Meter"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 56)
	bar.Size = UDim2.new(0.8, 0, 0, 8)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bar.BackgroundTransparency = 0.3
	bar.Visible = false
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	gui.Parent = model
	return icon, fill
end

local function setState(guard: Guard, state: GuardState)
	if guard.state == state then
		return
	end
	guard.state = state
	guard.model:SetAttribute(Tags.GuardState, state)
	local style = STATE_ICONS[state]
	guard.icon.Text = style.text
	guard.icon.TextColor3 = style.color
	guard.humanoid.WalkSpeed = if state == "Alert"
		then G.ChaseSpeed
		elseif state == "Patrol" then G.PatrolSpeed
		else G.InvestigateSpeed
	if state == "Alert" then
		AlarmService:Add("GuardAlert")
		Net.broadcast("GuardAlert", guard.target and guard.target.Name or "")
	end
end

local function spawnGuard(level: Folder, position: Vector3)
	local model = createRig()
	model.Name = "Guard"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = G.PatrolSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	model:PivotTo(CFrame.new(position))
	addFlashlight(model)
	local icon, fill = addBillboard(model)
	model:SetAttribute(Tags.SpotKind, "guard")
	model:SetAttribute(Tags.GuardState, "Patrol")
	model.Parent = level
	CollectionService:AddTag(model, Tags.Guard)
	CollectionService:AddTag(model, Tags.Spottable)
	-- Servereigendom: alle spelers zien dezelfde bewaker op dezelfde plek.
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local walkTrack: AnimationTrack? = nil
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator and humanoid.RigType == Enum.HumanoidRigType.R15 and model:FindFirstChild("UpperTorso") then
		local walk = Instance.new("Animation")
		walk.AnimationId = "rbxassetid://507777826" -- standaard R15-loopanimatie van Roblox
		local okTrack, track = pcall(function()
			return animator:LoadAnimation(walk)
		end)
		if okTrack then
			walkTrack = track
		end
	end

	local guard: Guard = {
		model = model,
		humanoid = humanoid,
		root = root,
		state = "Patrol",
		routeIndex = 1,
		meters = {},
		target = nil,
		targetPos = nil,
		arrived = false,
		stateUntil = 0,
		lastSeenAt = 0,
		droneSeenFor = 0,
		distractedUntil = 0,
		icon = icon,
		meterFill = fill,
		walkTrack = walkTrack,
	}
	table.insert(guards, guard)
end

local function isLit(position: Vector3): boolean
	for _, lamp in CollectionService:GetTagged(Tags.Lamp) do
		if lamp:IsA("BasePart") and lamp:GetAttribute(Tags.Disabled) ~= true then
			local light = lamp:FindFirstChildOfClass("PointLight")
			local range = if light then light.Range else 18
			if (lamp.Position - position).Magnitude <= range then
				return true
			end
		end
	end
	return false
end

local function visionParams(guard: Guard, extra: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { guard.model }
	local level = MapService.Level
	if level then
		local cage = level:FindFirstChild("Cage")
		if cage then
			table.insert(ignore, cage) -- door het hekwerk van de kooi kan je kijken
		end
	end
	for _, other in guards do
		table.insert(ignore, other.model)
	end
	for _, inst in extra do
		table.insert(ignore, inst)
	end
	params.FilterDescendantsInstances = ignore
	return params
end

-- Ziet deze bewaker dit punt? Geeft ook de afstand terug.
local function canSee(guard: Guard, point: Vector3, targetModel: Instance?, range: number): (boolean, number)
	local eye = guard.root.Position + Vector3.new(0, G.HeadHeight, 0)
	local offset = point - eye
	local distance = offset.Magnitude
	if distance > range or distance < 0.01 then
		return distance < 0.01, distance
	end
	local look = guard.root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	local dir = offset.Unit
	local flatDir = Vector3.new(dir.X, dir.Y * 0.5, dir.Z).Unit
	if flatLook:Dot(flatDir) < COS_HALF then
		return false, distance
	end
	local result = workspace:Raycast(eye, offset, visionParams(guard, {}))
	if result == nil then
		return true, distance
	end
	if targetModel and result.Instance:IsDescendantOf(targetModel) then
		return true, distance
	end
	return false, distance
end

local function goTo(guard: Guard, position: Vector3)
	guard.humanoid:MoveTo(position)
end

local function investigate(guard: Guard, position: Vector3, searchSeconds: number)
	if guard.state == "Alert" then
		return
	end
	setState(guard, "Suspicious")
	guard.targetPos = position
	guard.arrived = false
	guard.stateUntil = searchSeconds
end

-- Geluid (Noisemaker, CRACK, BZZT). Geeft het aantal bewakers terug dat het hoorde.
-- Een bewaker die door een Noisemaker is afgeleid, hoort tijdens dat venster geen CRACK of BZZT:
-- precies daarom moet de Crowbar tijdens de afleiding (§3.1).
function GuardService:HearNoise(
	position: Vector3,
	radius: number,
	searchSeconds: number?,
	kind: string?
): number
	local heard = 0
	local now = os.clock()
	for _, guard in guards do
		if guard.state ~= "Alert" and (guard.root.Position - position).Magnitude <= radius then
			local distracted = guard.distractedUntil > now
			if distracted and kind ~= "noisemaker" then
				continue
			end
			investigate(guard, position, searchSeconds or G.SearchSeconds)
			if kind == "noisemaker" then
				guard.distractedUntil = now + (searchSeconds or G.SearchSeconds)
			end
			heard += 1
		end
	end
	return heard
end

-- Een camera zag iemand: de bewakers komen kijken.
function GuardService:ReportPosition(position: Vector3)
	for _, guard in guards do
		if guard.state ~= "Alert" then
			investigate(guard, position, G.SearchSeconds)
		end
	end
end

local function nearestRouteIndex(guard: Guard): number
	local best, bestDistance = 1, math.huge
	for index, point in MapService.Points.GuardRoute do
		local d = (point - guard.root.Position).Magnitude
		if d < bestDistance then
			best, bestDistance = index, d
		end
	end
	return best
end

local function updateVision(guard: Guard, dt: number)
	local maxMeter = 0
	local bestPlayer: Player? = nil
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local meter = guard.meters[player] or 0
		if
			character
			and hrp
			and humanoid
			and humanoid.Health > 0
			and not character:GetAttribute("Caught")
		then
			local range = if isLit(hrp.Position) then G.RangeLit else G.RangeDark
			local seen, distance = canSee(guard, hrp.Position, character, range)
			if seen then
				local t = math.clamp(distance / range, 0, 1)
				local fillSeconds = G.FillSecondsNear + (G.FillSecondsFar - G.FillSecondsNear) * t
				if character:GetAttribute(Tags.Crouching) == true then
					fillSeconds *= G.CrouchFillMultiplier
				end
				meter = math.min(1, meter + dt / fillSeconds)
				if guard.state == "Alert" and guard.target == player then
					guard.lastSeenAt = os.clock()
					guard.targetPos = hrp.Position
				end
			else
				meter = math.max(0, meter - G.DecayPerSecond * dt)
			end
			if meter > maxMeter then
				maxMeter = meter
				bestPlayer = player
			end
			local currentState: string = guard.state
			local alreadyAlert = currentState == "Alert"
			if meter >= 1 and not alreadyAlert then
				guard.target = player
				guard.targetPos = hrp.Position
				guard.lastSeenAt = os.clock()
				setState(guard, "Alert")
			elseif meter >= G.SuspiciousAt then
				if currentState == "Patrol" then
					investigate(guard, hrp.Position, G.SearchSeconds)
				elseif currentState == "Suspicious" then
					guard.targetPos = hrp.Position
					guard.arrived = false
				end
			end
		else
			meter = 0
		end
		guard.meters[player] = meter
	end

	-- Drone gezien? (§4.1: na 1,5 s "What's that?" en hij komt kijken)
	local sawDrone = false
	for _, drone in CollectionService:GetTagged(Tags.Drone) do
		if drone:IsA("BasePart") and guard.state ~= "Alert" then
			local seen = canSee(guard, drone.Position, drone, G.RangeLit)
			if seen then
				sawDrone = true
				guard.droneSeenFor += dt
				if guard.droneSeenFor >= 1.5 and guard.state == "Patrol" then
					investigate(guard, drone.Position, G.SearchSeconds)
					Net.broadcast("Toast", 'Guard: "What\'s that?"')
				end
			end
		end
	end
	if not sawDrone then
		guard.droneSeenFor = 0
	end

	local bar = guard.meterFill.Parent :: Frame
	bar.Visible = maxMeter > 0.02 and guard.state ~= "Alert"
	guard.meterFill.Size = UDim2.fromScale(maxMeter, 1)
	guard.meterFill.BackgroundColor3 = if maxMeter >= G.SuspiciousAt
		then Color3.fromRGB(255, 120, 40)
		else Color3.fromRGB(255, 220, 60)
	local _ = bestPlayer
end

local function updateBehaviour(guard: Guard, dt: number)
	local state = guard.state
	if state == "Patrol" then
		local route = MapService.Points.GuardRoute
		local point = route[guard.routeIndex]
		local flat = Vector3.new(guard.root.Position.X, 0, guard.root.Position.Z)
		if (flat - point).Magnitude < 2 then
			guard.routeIndex = guard.routeIndex % #route + 1
			point = route[guard.routeIndex]
		end
		goTo(guard, point)
	elseif state == "Suspicious" or state == "Search" then
		local targetPos = guard.targetPos
		if targetPos and not guard.arrived then
			goTo(guard, targetPos)
			local flat = Vector3.new(guard.root.Position.X, targetPos.Y, guard.root.Position.Z)
			if (flat - targetPos).Magnitude < 3 then
				guard.arrived = true
			end
		else
			-- Rondkijken: langzaam draaien terwijl de zoektijd afloopt.
			guard.root.CFrame = guard.root.CFrame * CFrame.Angles(0, math.rad(70) * dt, 0)
			guard.stateUntil -= dt
			if guard.stateUntil <= 0 then
				guard.targetPos = nil
				guard.routeIndex = nearestRouteIndex(guard)
				setState(guard, "Patrol")
			end
		end
	elseif state == "Alert" then
		local target = guard.target
		local character = target and target.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not target or not character or not hrp or character:GetAttribute("Caught") then
			guard.target = nil
			guard.stateUntil = G.AlertSearchSeconds
			guard.arrived = false
			setState(guard, "Search")
			return
		end
		goTo(guard, guard.targetPos or hrp.Position)
		if (hrp.Position - guard.root.Position).Magnitude <= G.CaptureDistance then
			guard.meters[target] = 0
			guard.target = nil
			guard.stateUntil = 3
			guard.arrived = true
			setState(guard, "Search")
			if captureCallback then
				captureCallback(target, guard.model)
			end
		elseif os.clock() - guard.lastSeenAt > 3 then
			-- Speler kwijt: zoek rond de laatste plek.
			guard.target = nil
			guard.stateUntil = G.AlertSearchSeconds
			guard.arrived = false
			setState(guard, "Search")
		end
	end

	if guard.walkTrack then
		local moving = guard.root.AssemblyLinearVelocity.Magnitude > 0.5
		if moving and not guard.walkTrack.IsPlaying then
			guard.walkTrack:Play()
		elseif not moving and guard.walkTrack.IsPlaying then
			guard.walkTrack:Stop()
		end
	end
end

local function clearGuards()
	for _, guard in guards do
		if guard.model.Parent then
			guard.model:Destroy()
		end
	end
	table.clear(guards)
end

local function onLevelBuilt(level: Folder)
	clearGuards()
	spawnGuard(level, MapService.Points.GuardStart)
end

function GuardService:Start()
	MapService.LevelBuilt:Connect(onLevelBuilt)
	if MapService.Level then
		onLevelBuilt(MapService.Level)
	end

	local visionTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		visionTimer += dt
		local doVision = visionTimer >= G.VisionInterval
		local visionDt = visionTimer
		if doVision then
			visionTimer = 0
		end
		for _, guard in guards do
			if guard.model.Parent then
				if doVision then
					updateVision(guard, visionDt)
				end
				updateBehaviour(guard, dt)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, guard in guards do
			guard.meters[player] = nil
			if guard.target == player then
				guard.target = nil
			end
		end
	end)
end

return GuardService
