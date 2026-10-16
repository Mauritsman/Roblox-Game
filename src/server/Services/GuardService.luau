--!strict
-- Guards (beta-spec §3.1–3.3). Many guards from the round plan, each on his own route.
--   Patrol      walks his route (straight legs; a leg that changes floor uses pathfinding), speed 6 (tier 2: 7.5)
--   Suspicious  walks to something he saw or heard and looks around ("?"), speed 9
--   Alert       chases at 15 ("!"): straight while he sees you, pathfinding when he lost sight; 1 s within
--               3.5 studs = grab. Lost for 3 s → Search
--   Search      searches around the last known spot for 15 s ("?!")
--   Stunned     in a bubble (8 s), sees nothing; then Search, +10 alarm
--   Carrying    carries a captive to the cell at 8 (pathfinding), sees nothing (CaptureService drives this)
-- Guards have no weapons: a flashlight and a radio. Vision ignores `SeeThrough` parts (and the `Cage` folder).
-- Detection numbers: Logic/Detection (crouch, carry, Sleepy Guards, lockdown and difficulty factors).

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Capture = require(ReplicatedStorage.Shared.Logic.Capture)
local Config = require(ReplicatedStorage.Shared.Config)
local Detection = require(ReplicatedStorage.Shared.Logic.Detection)
local Hiding = require(ReplicatedStorage.Shared.Logic.Hiding)
local Net = require(ReplicatedStorage.Shared.Net)
local Noise = require(ReplicatedStorage.Shared.Logic.Noise)
local Patrol = require(ReplicatedStorage.Shared.Logic.Patrol)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tags = require(ReplicatedStorage.Shared.Tags)

local AlarmService = require(script.Parent.AlarmService)
local MapService = require(script.Parent.MapService)

local Npc = script.Parent.Parent:WaitForChild("Npc")
local Mover = require(Npc.Mover)
local Peers = require(Npc.Peers)
local Rig = require(Npc.Rig)
local Targets = require(Npc.Targets)

local GuardService = {}

-- Signals for other services.
GuardService.Grabbed = Signal.new() :: Signal.Signal<Player, Model> -- a guard grabbed someone
GuardService.Noise = Signal.new() :: Signal.Signal<Vector3, number, string, Player?> -- every HearNoise (Boef)
GuardService.Bubbled = Signal.new() :: Signal.Signal<Model, Player?> -- a guard was bubbled (radio checks)
-- A carrying guard dropped his captive: guard, captive, "bubble" | "noisemaker", who did it (if known).
GuardService.CarryInterrupted = Signal.new() :: Signal.Signal<Model, Player, string, Player?>

type GuardState = "Patrol" | "Suspicious" | "Alert" | "Search" | "Stunned" | "Carrying"

type PullOut = {
	player: Player,
	spot: Vector3,
	onReached: () -> (),
}

type Guard = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	mover: Mover.Mover,
	index: number, -- index in plan.guards
	board: Rig.Billboard,
	walkTrack: AnimationTrack?,
	flashlight: SpotLight?,
	state: GuardState,
	route: { Patrol.Step },
	routeIndex: number,
	waitUntil: number,
	waited: boolean,
	meters: { [Player]: number },
	target: Player?,
	targetPos: Vector3?,
	lastSeenAt: number,
	grabProgress: number,
	arrived: boolean,
	hunting: boolean, -- walks to targetPos with pathfinding (lost a chase, radio call)
	stateUntil: number, -- seconds of looking around left
	walkDeadline: number,
	wanderAt: number,
	droneSeenFor: number,
	distractedUntil: number,
	stunUntil: number,
	bubble: BasePart?,
	pullOut: PullOut?,
	carrying: Player?,
	carryDest: Vector3?,
	onArrive: (() -> ())?,
}

local G = Config.Guard
local COS_HALF = math.cos(math.rad(G.ConeHalfAngle))
local RANGES = { RangeLit = G.RangeLit, RangeDark = G.RangeDark, FlashlightRange = G.FlashlightRange }
local RATES = {
	CrouchFillRate = G.CrouchFillRate,
	CarryFillRate = G.CarryFillRate,
	LockdownFillRate = G.LockdownFillRate,
	SleepyFillRate = Config.Modifiers.SleepyGuards.FillRate,
}

local STATE_ICONS: { [GuardState]: { text: string, color: Color3 } } = {
	Patrol = { text = "", color = Color3.new(1, 1, 1) },
	Suspicious = { text = "?", color = Color3.fromRGB(255, 220, 60) },
	Alert = { text = "!", color = Color3.fromRGB(255, 60, 60) },
	Search = { text = "?!", color = Color3.fromRGB(255, 150, 40) },
	Stunned = { text = "◎", color = Color3.fromRGB(150, 220, 255) },
	Carrying = { text = "", color = Color3.new(1, 1, 1) },
}

local guards: { Guard } = {}
local lockdownOn = false
local everSeen: { [Player]: boolean } = {}
local round = {
	modifier = nil :: string?,
	fillRate = 1,
}

-- Hooks set by other services (no require cycles).
local grabHandler: ((player: Player, guard: Model) -> boolean)? = nil
local captureCallback: ((player: Player, guard: Model) -> ())? = nil -- DEPRECATED: prototype RoundService
local prankPointsHandler: ((guard: Model) -> ())? = nil
local npcBubbleHandler: ((model: Instance, seconds: number, by: Player?) -> boolean)? = nil

-- CaptureService: decides what a grab does. Return true when the grab happened (it calls StartCarry).
function GuardService:SetGrabHandler(handler: (player: Player, guard: Model) -> boolean)
	grabHandler = handler
end

-- DEPRECATED (prototype RoundService): only used when no grab handler is set.
function GuardService:OnCapture(callback: (player: Player, guard: Model) -> ())
	captureCallback = callback
end

-- ObjectiveService (radio checks): takes over the +10 "PrankUsed" points when a bubble pops.
function GuardService:SetPrankPointsHandler(handler: (guard: Model) -> ())
	prankPointsHandler = handler
end

-- NpcService: bubbles that hit an NPC that is not a guard (Inspector yes, Karel/Boef no).
function GuardService:SetNpcBubbleHandler(handler: (model: Instance, seconds: number, by: Player?) -> boolean)
	npcBubbleHandler = handler
end

local function isLockdown(): boolean
	return lockdownOn or Targets.lockdown()
end

local function powerCut(): boolean
	return (round.modifier or Targets.modifier()) == "PowerCut"
end

local function patrolSpeed(): number
	return if AlarmService.Level >= 2 then G.Tier2PatrolSpeed else G.PatrolSpeed
end

local function setState(guard: Guard, state: GuardState)
	if guard.state == state then
		return
	end
	guard.state = state
	guard.model:SetAttribute(Tags.GuardState, state)
	local style = STATE_ICONS[state]
	Rig.setIcon(guard.board, style.text, style.color)
	guard.humanoid.WalkSpeed = if state == "Stunned"
		then 0
		elseif state == "Alert" then G.ChaseSpeed
		elseif state == "Patrol" then patrolSpeed()
		elseif state == "Carrying" then G.CarrySpeed
		else G.InvestigateSpeed
	if state ~= "Alert" then
		guard.pullOut = nil
		guard.grabProgress = 0
	end
end

local function findGuard(model: Instance): Guard?
	for _, guard in guards do
		if guard.model == model or model:IsDescendantOf(guard.model) then
			return guard
		end
	end
	return nil
end

local function addFlashlight(model: Model): SpotLight?
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("HumanoidRootPart")
	if not hand or not hand:IsA("BasePart") then
		return nil
	end
	local torch = Instance.new("Part")
	torch.Name = "Flashlight"
	torch.Size = Vector3.new(0.4, 0.4, 1.2)
	torch.Color = Color3.fromRGB(20, 20, 20)
	torch.Massless = true
	torch.CanCollide = false
	torch.CanQuery = false
	torch.CFrame = hand.CFrame * CFrame.new(0, -0.3, -0.6)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = torch
	weld.Parent = torch
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = G.ConeHalfAngle * 2
	light.Range = if powerCut() then G.FlashlightRange + 4 else 26
	light.Brightness = if powerCut() then 4 else 2.5
	light.Color = Color3.fromRGB(255, 244, 214)
	light.Shadows = true
	light.Parent = torch
	torch.Parent = model
	return light
end

local function spawnGuard(
	parent: Instance,
	route: { Patrol.Step },
	start: number,
	index: number,
	fallback: Vector3
)
	local model = Rig.humanoid("Guard", {
		skin = Color3.fromRGB(234, 184, 146),
		shirt = Color3.fromRGB(40, 52, 90),
		pants = Color3.fromRGB(30, 30, 40),
	})
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = patrolSpeed()
	local flashlight = addFlashlight(model)
	Rig.attach(
		model,
		"Head",
		Vector3.new(1.3, 0.35, 1.3),
		CFrame.new(0, 0.7, 0),
		Color3.fromRGB(30, 38, 70),
		"Cap"
	)
	local board = Rig.billboard(model)
	model:SetAttribute(Tags.SpotKind, "guard")
	model:SetAttribute(Tags.GuardState, "Patrol")
	model:SetAttribute("GuardIndex", index)
	local startStep = route[start]
	local position = if startStep then (startStep.pos :: Vector3) + Vector3.new(0, 3, 0) else fallback
	Rig.place(model, parent, CFrame.new(position), { Tags.Guard, Tags.Spottable })

	local guard: Guard = {
		model = model,
		humanoid = humanoid,
		root = root,
		mover = Mover.new(humanoid, root),
		index = index,
		board = board,
		walkTrack = Rig.walkTrack(humanoid),
		flashlight = flashlight,
		state = "Patrol",
		route = route,
		routeIndex = Patrol.nextIndex(start, #route),
		waitUntil = 0,
		waited = false,
		meters = {},
		target = nil,
		targetPos = nil,
		lastSeenAt = 0,
		grabProgress = 0,
		arrived = false,
		hunting = false,
		stateUntil = 0,
		walkDeadline = 0,
		wanderAt = 0,
		droneSeenFor = 0,
		distractedUntil = 0,
		stunUntil = 0,
		bubble = nil,
		pullOut = nil,
		carrying = nil,
		carryDest = nil,
		onArrive = nil,
	}
	table.insert(guards, guard)
end

--------------------------------------------------------------------------------------------------------------
-- Vision
--------------------------------------------------------------------------------------------------------------

type Seen = {
	player: Player,
	character: Model,
	root: BasePart,
	ignored: boolean,
	lit: boolean,
	factors: { number },
}

local function isLit(position: Vector3): boolean
	if powerCut() then
		return false
	end
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

-- Everything vision rays pass through: guards, NPCs, loot, drones, `SeeThrough` parts and the `Cage` folder.
local function visionParams(): RaycastParams
	local ignore: { Instance } = {}
	for _, guard in guards do
		table.insert(ignore, guard.model)
	end
	for _, tag in { Tags.SeeThrough, Tags.Npc, Tags.Loot, Tags.Drone } do
		for _, inst in CollectionService:GetTagged(tag) do
			table.insert(ignore, inst)
		end
	end
	local level = MapService.Level
	local cage = level and level:FindFirstChild("Cage")
	if cage then
		table.insert(ignore, cage) -- fallback: the prototype's see-through cage folder
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

local function eyeOf(guard: Guard): Vector3
	return guard.root.Position + Vector3.new(0, G.HeadHeight, 0)
end

local function lineOfSight(
	from: Vector3,
	point: Vector3,
	targetModel: Instance?,
	params: RaycastParams
): boolean
	local result = workspace:Raycast(from, point - from, params)
	if result == nil then
		return true
	end
	return targetModel ~= nil and result.Instance:IsDescendantOf(targetModel)
end

-- Does this guard see this point inside his cone? Also returns the distance.
local function canSee(
	guard: Guard,
	point: Vector3,
	targetModel: Instance?,
	range: number,
	params: RaycastParams
): (boolean, number)
	local eye = eyeOf(guard)
	local offset = point - eye
	local distance = offset.Magnitude
	if distance > range then
		return false, distance
	end
	if distance < 0.01 then
		return true, distance
	end
	local look = guard.root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	local dir = offset.Unit
	local flatDir = Vector3.new(dir.X, dir.Y * 0.5, dir.Z).Unit -- forgiving up and down (upper floors)
	if flatLook:Dot(flatDir) < COS_HALF then
		return false, distance
	end
	return lineOfSight(eye, point, targetModel, params), distance
end

local function snapshot(now: number): { Seen }
	local list = {}
	local sleepy = (round.modifier or Targets.modifier()) == "SleepyGuards"
	local lockdown = isLockdown()
	for _, player in Players:GetPlayers() do
		local view = Targets.view(player)
		if view then
			local character = view.character
			local ignored = Targets.ignored(player, character, now)
			table.insert(list, {
				player = player,
				character = character,
				root = view.root,
				ignored = ignored,
				lit = not ignored and isLit(view.root.Position),
				factors = Detection.factorsFor({
					crouching = character:GetAttribute(Tags.Crouching) == true,
					carryClass = Targets.carryClass(character),
					sleepyGuards = sleepy,
					lockdown = lockdown,
					tierFillRate = round.fillRate,
				}, RATES),
			})
		end
	end
	return list
end

local function investigate(guard: Guard, position: Vector3, searchSeconds: number, hunting: boolean?)
	if guard.state == "Alert" or guard.state == "Stunned" or guard.state == "Carrying" then
		return
	end
	setState(guard, "Suspicious")
	guard.targetPos = position
	guard.arrived = false
	guard.hunting = hunting == true
	guard.stateUntil = searchSeconds
	-- Can't get there (wall in between)? He gives up after this and searches where he stands.
	local travel = (position - guard.root.Position).Magnitude / G.InvestigateSpeed
	guard.walkDeadline = os.clock() + travel + (if hunting then 8 else 3)
end

local function startSearch(guard: Guard, position: Vector3?, seconds: number, hunting: boolean)
	guard.target = nil
	guard.targetPos = position
	guard.arrived = position == nil
	guard.hunting = hunting
	guard.stateUntil = seconds
	guard.walkDeadline = os.clock() + 8
	setState(guard, "Search")
end

local function becomeAlert(guard: Guard, player: Player, position: Vector3)
	guard.target = player
	guard.targetPos = position
	guard.lastSeenAt = os.clock()
	guard.grabProgress = 0
	setState(guard, "Alert")
	AlarmService:Add("GuardAlert", nil, player)
	Net.broadcast("Spotted", player.UserId, "guard")
end

local function noteSeen(player: Player)
	if not everSeen[player] then
		everSeen[player] = true
		Peers.event("Seen", player)
	end
end

local function updateVision(guard: Guard, dt: number, seen: { Seen }, params: RaycastParams)
	if guard.state == "Stunned" or guard.state == "Carrying" then
		for player, meter in guard.meters do
			guard.meters[player] = math.max(0, meter - G.DecayPerSecond * dt)
		end
		Rig.setMeter(guard.board, 0, true)
		return
	end
	local now = os.clock()
	local maxMeter = 0
	local cut = powerCut()
	for _, entry in seen do
		local player = entry.player
		local meter = guard.meters[player] or 0
		if entry.ignored then
			meter = 0
		else
			local range = Detection.rangeFor(entry.lit, cut, RANGES)
			local position = entry.root.Position
			local isTarget = guard.state == "Alert" and guard.target == player
			local visible, distance
			if isTarget then
				-- While chasing he keeps track of you in any direction, as long as he has line of sight.
				distance = (position - eyeOf(guard)).Magnitude
				visible = distance <= range and lineOfSight(eyeOf(guard), position, entry.character, params)
			else
				visible, distance = canSee(guard, position, entry.character, range, params)
			end
			if visible then
				meter = math.min(1, meter + dt * Detection.fillRate(distance, range, entry.factors))
				if isTarget then
					guard.lastSeenAt = now
					guard.targetPos = position
				end
			else
				meter = math.max(0, meter - G.DecayPerSecond * dt)
			end
			local state: string = guard.state
			local alreadyAlert = state == "Alert" -- (a separate local avoids a wrong type refinement)
			if meter >= 1 and not alreadyAlert then
				noteSeen(player)
				becomeAlert(guard, player, position)
			elseif meter >= G.SuspiciousAt and visible then
				if state == "Patrol" then
					investigate(guard, position, G.SearchSeconds)
				elseif state == "Suspicious" or state == "Search" then
					guard.targetPos = position
					guard.arrived = false
					guard.walkDeadline = now + 4
				end
			end
		end
		guard.meters[player] = meter
		if meter > maxMeter then
			maxMeter = meter
		end
	end

	-- A drone in view: after a moment "What's that?" and he comes to look.
	local sawDrone = false
	if guard.state ~= "Alert" then
		for _, drone in CollectionService:GetTagged(Tags.Drone) do
			if drone:IsA("BasePart") and canSee(guard, drone.Position, drone, G.RangeLit, params) then
				sawDrone = true
				guard.droneSeenFor += dt
				if guard.droneSeenFor >= G.DroneNoticeSeconds and guard.state == "Patrol" then
					investigate(guard, drone.Position, G.SearchSeconds)
					Net.broadcast("Toast", 'Guard: "What\'s that?"')
				end
			end
		end
	end
	if not sawDrone then
		guard.droneSeenFor = 0
	end

	Rig.setMeter(
		guard.board,
		maxMeter,
		guard.state == "Alert",
		if maxMeter >= G.SuspiciousAt then Color3.fromRGB(255, 120, 40) else Color3.fromRGB(255, 220, 60)
	)
end

--------------------------------------------------------------------------------------------------------------
-- Behaviour
--------------------------------------------------------------------------------------------------------------

local function nearestRouteIndex(guard: Guard): number
	local best, bestDistance = 1, math.huge
	for index, step in guard.route do
		local d = ((step.pos :: Vector3) - guard.root.Position).Magnitude
		if d < bestDistance then
			best, bestDistance = index, d
		end
	end
	return best
end

local function floorY(guard: Guard): number
	return guard.root.Position.Y - 3
end

local function changesFloor(guard: Guard, point: Vector3): boolean
	return math.abs(point.Y - floorY(guard)) > G.FloorStep
end

local function backToPatrol(guard: Guard)
	guard.targetPos = nil
	guard.hunting = false
	guard.routeIndex = if #guard.route > 0 then nearestRouteIndex(guard) else 1
	guard.waited = false
	setState(guard, "Patrol")
end

local function popBubble(guard: Guard)
	if guard.bubble then
		guard.bubble:Destroy()
		guard.bubble = nil
	end
	guard.model:SetAttribute(Tags.Bubbled, nil)
	Rig.sound(guard.root, "rbxasset://sounds/swoosh.wav")
	-- Angry out of the bubble: searches right where he stands, and the alarm rises a little (§4.8).
	startSearch(guard, nil, G.AlertSearchSeconds, false)
	if prankPointsHandler then
		task.spawn(prankPointsHandler, guard.model)
	else
		AlarmService:Add("PrankUsed")
	end
	Net.broadcast("Toast", 'Guard: "Who did that?!"')
end

local function attemptGrab(guard: Guard, player: Player)
	guard.grabProgress = 0
	if grabHandler then
		local ok, grabbed = pcall(grabHandler, player, guard.model)
		if not ok then
			warn("[GuardService] grab handler failed:", grabbed)
			return
		end
		if grabbed then
			guard.meters[player] = 0
			GuardService.Grabbed:Fire(player, guard.model)
		end
		return
	end
	-- Prototype fallback (no CaptureService): the old RoundService callback.
	guard.meters[player] = 0
	startSearch(guard, guard.root.Position, 3, false)
	GuardService.Grabbed:Fire(player, guard.model)
	if captureCallback then
		task.spawn(captureCallback, player, guard.model)
	end
end

local function updatePatrol(guard: Guard)
	local route = guard.route
	if #route == 0 then
		guard.mover:stop()
		return
	end
	local now = os.clock()
	if guard.waitUntil > now then
		return
	end
	local step = route[guard.routeIndex]
	local point = step.pos :: Vector3
	local previous = route[if guard.routeIndex == 1 then #route else guard.routeIndex - 1].pos :: Vector3
	local usePath = Patrol.changesFloor(previous, point, G.FloorStep) or changesFloor(guard, point)
	local flatDistance = guard.mover:flatDistance(point)
	if
		Patrol.arrived(flatDistance, floorY(guard), point, G.ArriveDistance, G.FloorStep)
		or guard.mover:stuck()
	then
		if step.wait > 0 and not guard.waited then
			guard.waited = true
			guard.waitUntil = now + step.wait
			guard.mover:stop()
			return
		end
		guard.waited = false
		guard.routeIndex = Patrol.nextIndex(guard.routeIndex, #route)
		step = route[guard.routeIndex]
		point = step.pos :: Vector3
		usePath = Patrol.changesFloor(previous, point, G.FloorStep) or changesFloor(guard, point)
	end
	guard.mover:moveTo(point + Vector3.new(0, 0, 0), usePath)
end

local function lookAround(guard: Guard, dt: number)
	guard.root.CFrame = guard.root.CFrame * CFrame.Angles(0, math.rad(70) * dt, 0)
end

local function updateInvestigate(guard: Guard, dt: number)
	local targetPos = guard.targetPos
	local now = os.clock()
	if targetPos and not guard.arrived then
		guard.mover:moveTo(targetPos, guard.hunting or changesFloor(guard, targetPos))
		local flatDistance = guard.mover:flatDistance(targetPos)
		if flatDistance < 3 or now > guard.walkDeadline or guard.mover:stuck() then
			guard.arrived = true
			guard.mover:stop()
			guard.wanderAt = now + 2
		end
		return
	end
	-- Look around while the search time runs out; while searching he also wanders around the spot.
	guard.stateUntil -= dt
	if guard.state == "Search" and now >= guard.wanderAt then
		guard.wanderAt = now + 3
		local angle = math.random() * math.pi * 2
		local radius = math.random() * G.SearchWander
		local base = targetPos or guard.root.Position
		guard.mover:moveTo(base + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), false)
	elseif not guard.mover:hasGoal() or guard.mover:stuck() then
		guard.mover:stop()
		lookAround(guard, dt)
	end
	if guard.stateUntil <= 0 then
		backToPatrol(guard)
	end
end

local function updateAlert(guard: Guard, dt: number)
	local now = os.clock()
	local pull = guard.pullOut
	if pull then
		local character = pull.player.Character
		local stillHidden = pull.player.Parent ~= nil
			and character ~= nil
			and character:GetAttribute(Tags.Hidden) == true
		if stillHidden then
			guard.mover:moveTo(pull.spot, true)
			if guard.mover:flatDistance(pull.spot) <= Config.Hiding.PullOut then
				guard.pullOut = nil
				guard.mover:stop()
				startSearch(guard, nil, 3, false)
				task.spawn(pull.onReached)
			end
			return
		end
		-- Out of the spot before he got there: a normal chase (or a search at the spot).
		guard.pullOut = nil
		guard.lastSeenAt = now - G.LostSeconds + 0.5
		guard.targetPos = pull.spot
	end

	local target = guard.target
	local view = if target then Targets.view(target) else nil
	if not target or not view or view.character:GetAttribute(Tags.Caught) == true then
		startSearch(guard, guard.targetPos, G.AlertSearchSeconds, true)
		return
	end
	if Targets.ignored(target, view.character, Targets.now()) then
		-- Hidden or immune: he lost you; search where he last saw you.
		startSearch(guard, guard.targetPos, G.AlertSearchSeconds, true)
		return
	end
	local position = view.root.Position
	local sawRecently = now - guard.lastSeenAt < 0.3
	if sawRecently then
		guard.mover:moveTo(position, false)
	else
		guard.mover:moveTo(guard.targetPos or position, true)
	end
	local distance = (position - guard.root.Position).Magnitude
	local progress, grabbed =
		Capture.grabStep(guard.grabProgress, dt, distance, G.CaptureDistance, G.GrabSeconds)
	guard.grabProgress = progress
	if grabbed then
		attemptGrab(guard, target)
		return
	end
	if now - guard.lastSeenAt > G.LostSeconds then
		startSearch(guard, guard.targetPos, G.AlertSearchSeconds, true)
	end
end

local function updateCarrying(guard: Guard)
	local dest = guard.carryDest
	if not dest then
		guard.mover:stop()
		return
	end
	guard.mover:moveTo(dest, true)
	if guard.onArrive and guard.mover:flatDistance(dest) <= Config.Capture.DropoffRange then
		local onArrive = guard.onArrive
		guard.onArrive = nil
		guard.mover:stop()
		task.spawn(onArrive)
	end
end

local function updateBehaviour(guard: Guard, dt: number)
	local state = guard.state
	if state == "Stunned" then
		guard.mover:stop()
		lookAround(guard, dt * 0.6)
		if os.clock() >= guard.stunUntil then
			popBubble(guard)
		end
	elseif state == "Carrying" then
		updateCarrying(guard)
	elseif state == "Patrol" then
		updatePatrol(guard)
	elseif state == "Suspicious" or state == "Search" then
		updateInvestigate(guard, dt)
	elseif state == "Alert" then
		updateAlert(guard, dt)
	end
	guard.mover:step()
	Rig.updateWalk(guard.walkTrack, guard.root)
end

--------------------------------------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------------------------------------

-- Noise (Noisemaker, CRACK, BZZT, thud, rumble, bark, sneeze, squeak, beep, splosh). Returns how many guards
-- heard it. A guard distracted by a Noisemaker hears nothing else during that window (the Crowbar moment).
-- A Noisemaker within 20 studs of a carrying guard makes him drop his captive (hero moment).
function GuardService:HearNoise(
	position: Vector3,
	radius: number,
	searchSeconds: number?,
	kind: string?,
	by: Player?
): number
	GuardService.Noise:Fire(position, radius, kind or "", by)
	local now = os.clock()
	local heard = 0
	if kind == "noisemaker" then
		for _, guard in guards do
			local captive = guard.carrying
			local distance = (guard.root.Position - position).Magnitude
			if
				captive
				and guard.state == "Carrying"
				and Capture.heroDrop("noisemaker", distance, Config.Capture.HeroNoisemakerRadius)
			then
				guard.carrying = nil
				guard.carryDest = nil
				guard.onArrive = nil
				startSearch(guard, nil, 2, false)
				GuardService.CarryInterrupted:Fire(guard.model, captive, "noisemaker", by)
			end
		end
	end
	for _, guard in guards do
		if (guard.root.Position - position).Magnitude > radius then
			continue
		end
		local busy = guard.state == "Alert" or guard.state == "Stunned" or guard.state == "Carrying"
		local reaction = Noise.reaction(kind, guard.distractedUntil > now, busy)
		local seconds = Noise.searchSeconds(kind, searchSeconds, G.NoiseSearch, G.SearchSeconds)
		if reaction == "Ignore" then
			continue
		elseif reaction == "LookAround" then
			-- "Again?!": he no longer falls for it and looks around where he stands.
			investigate(guard, guard.root.Position, seconds)
			guard.arrived = true
		elseif reaction == "Distract" then
			investigate(guard, position, seconds)
			guard.distractedUntil = now + seconds
		else
			investigate(guard, position, seconds)
		end
		heard += 1
	end
	return heard
end

-- Bubble Blaster: traps this guard in a bubble. Returns true on success. `by` = the shooter (hero drop award).
-- Non-guard NPCs go to NpcService (the Inspector can be bubbled, Karel and Boef cannot).
function GuardService:Bubble(model: Instance, seconds: number, by: Player?): boolean
	local guard = findGuard(model)
	if not guard then
		if npcBubbleHandler then
			local ok, result = pcall(npcBubbleHandler, model, seconds, by)
			return ok and result == true
		end
		return false
	end
	if guard.state == "Stunned" then
		guard.stunUntil = os.clock() + seconds
		return true
	end
	local captive = guard.carrying
	guard.carrying = nil
	guard.carryDest = nil
	guard.onArrive = nil
	guard.target = nil
	guard.stunUntil = os.clock() + seconds
	guard.mover:stop()
	setState(guard, "Stunned")
	guard.model:SetAttribute(Tags.Bubbled, true)
	local bubble = Instance.new("Part")
	bubble.Name = "Bubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(7, 7, 7)
	bubble.Material = Enum.Material.Glass
	bubble.Transparency = 0.55
	bubble.Color = Color3.fromRGB(190, 230, 255)
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.Massless = true
	bubble.CFrame = guard.root.CFrame * CFrame.new(0, 0.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = guard.root
	weld.Part1 = bubble
	weld.Parent = bubble
	bubble.Parent = guard.model
	guard.bubble = bubble
	if captive then
		GuardService.CarryInterrupted:Fire(guard.model, captive, "bubble", by)
	end
	GuardService.Bubbled:Fire(guard.model, by)
	return true
end

-- The `count` nearest free guards come to look (snitches; cameras). Returns how many.
function GuardService:AlertNearest(position: Vector3, count: number, searchSeconds: number?): number
	local candidates: { Guard } = {}
	local distances: { number } = {}
	for _, guard in guards do
		if guard.state ~= "Alert" and guard.state ~= "Stunned" and guard.state ~= "Carrying" then
			table.insert(candidates, guard)
			table.insert(distances, (guard.root.Position - position).Magnitude)
		end
	end
	local picked = Noise.nearest(distances, count)
	for _, index in picked do
		investigate(candidates[index], position, searchSeconds or G.SearchSeconds, true)
	end
	return #picked
end

-- A camera saw someone: the 2 nearest guards come to look.
function GuardService:ReportPosition(position: Vector3)
	GuardService:AlertNearest(position, Config.Snitch.GuardsAlerted, G.SearchSeconds)
end

-- LOCKDOWN on/off (RoundService). Also follows the RoundPhase attribute.
function GuardService:SetLockdown(on: boolean)
	lockdownOn = on
end

-- Guards whose meter on this player is ≥ SeenEnteringMeter, or who chase them (HidingService, before hiding).
function GuardService:WitnessesOf(player: Player): { Model }
	local list = {}
	for _, guard in guards do
		local chasing = guard.state == "Alert" and guard.target == player
		if
			guard.state ~= "Stunned"
			and guard.state ~= "Carrying"
			and Hiding.isWitness(guard.meters[player] or 0, chasing, G.SeenEnteringMeter)
		then
			table.insert(list, guard.model)
		end
	end
	return list
end

-- This guard walks over to a hiding spot he saw `player` enter; `onReached` runs when he is within PullOut studs.
function GuardService:PullOut(model: Model, player: Player, spot: Vector3, onReached: () -> ()): boolean
	local guard = findGuard(model)
	if not guard or guard.state == "Stunned" or guard.state == "Carrying" then
		return false
	end
	guard.target = player
	guard.targetPos = spot
	guard.lastSeenAt = os.clock()
	setState(guard, "Alert")
	guard.pullOut = { player = player, spot = spot, onReached = onReached }
	return true
end

-- CaptureService: this guard carries `player` to `destination` (nil = holds them where he stands).
function GuardService:StartCarry(
	model: Model,
	player: Player,
	destination: Vector3?,
	onArrive: (() -> ())?
): boolean
	local guard = findGuard(model)
	if not guard or guard.state == "Stunned" then
		return false
	end
	guard.target = nil
	guard.pullOut = nil
	guard.carrying = player
	guard.carryDest = destination
	guard.onArrive = onArrive
	table.clear(guard.meters)
	setState(guard, "Carrying")
	return true
end

-- CaptureService: the carry is over (cell reached, captive left). The guard searches briefly, then patrols.
function GuardService:StopCarry(model: Model)
	local guard = findGuard(model)
	if not guard then
		return
	end
	guard.carrying = nil
	guard.carryDest = nil
	guard.onArrive = nil
	if guard.state == "Carrying" then
		startSearch(guard, nil, 3, false)
	end
end

-- Who this guard carries (nil = nobody).
function GuardService:CarriedBy(model: Model): Player?
	local guard = findGuard(model)
	return if guard then guard.carrying else nil
end

-- Karel pocketed a Noisemaker: guards distracted near it stop being distracted.
function GuardService:EndDistraction(position: Vector3, radius: number)
	for _, guard in guards do
		if guard.distractedUntil > 0 and (guard.root.Position - position).Magnitude <= radius + 10 then
			guard.distractedUntil = 0
		end
	end
end

function GuardService:GetGuards(): { Model }
	local list = {}
	for _, guard in guards do
		table.insert(list, guard.model)
	end
	return list
end

-- The guard spawned for plan.guards[index] (keycard on a guard).
function GuardService:GetGuardModel(index: number): Model?
	for _, guard in guards do
		if guard.index == index then
			return guard.model
		end
	end
	return nil
end

function GuardService:Count(): number
	return #guards
end

-- Highest guard meter on this player right now (0..1).
function GuardService:MeterOn(player: Player): number
	local best = 0
	for _, guard in guards do
		best = math.max(best, guard.meters[player] or 0)
	end
	return best
end

function GuardService:Clear()
	for _, guard in guards do
		guard.mover:stop()
		if guard.model.Parent then
			guard.model:Destroy()
		end
	end
	table.clear(guards)
	table.clear(everSeen)
	lockdownOn = false
end

-- Spawns the round's guards (SetupService). `plan` = Logic/RoundPlan's Plan, `heistInfo.routes` = the heist's
-- GuardRoutes (falls back to MapService.Points.GuardRoutes, then the old Points.GuardRoute loop).
function GuardService:Spawn(plan: any, heistInfo: any, job: any)
	GuardService:Clear()
	local tier = Targets.round()
	round.modifier = (job and job.modifierId) or (plan and plan.modifierId) or Targets.modifier()
	round.fillRate = tier.fillRate
	local points = MapService.Points
	local routes = (heistInfo and heistInfo.routes) or points.GuardRoutes
	local guardPlans = if plan and type(plan.guards) == "table" then plan.guards else {}
	local folder = Rig.folder(MapService.Level, "Guards")
	for index, guardPlan in guardPlans do
		local variant = Patrol.variant(routes, guardPlan.routeId, guardPlan.variant)
		local steps, start
		if variant and #variant > 0 then
			steps = Patrol.steps(variant, guardPlan.waits)
			start = Patrol.startIndex(guardPlan.start, #steps)
		else
			steps = Patrol.fromPositions(points.GuardRoute or {})
			start = Patrol.spreadStart(index, #guardPlans, #steps)
		end
		spawnGuard(folder, steps, start, index, points.GuardStart)
	end
	if plan and type(plan.warnings) == "table" then
		for _, warning in plan.warnings do
			if string.find(warning, "route") then
				warn("[GuardService] plan:", warning)
			end
		end
	end
end

-- The prototype (no SetupService yet): one guard on the heist's fallback route, as before.
local function spawnPrototype()
	GuardService:Spawn({ guards = { { routeId = nil, variant = 1, start = 1, waits = {} } } }, nil, nil)
end

-- GuardDoor: guards (and the other NPCs, same collision group) walk through; pathfinding ignores them.
local function setupGuardDoor(inst: Instance)
	local parts: { BasePart } = {}
	if inst:IsA("BasePart") then
		table.insert(parts, inst)
	end
	for _, child in inst:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	for _, part in parts do
		part.CollisionGroup = "GuardDoor"
		if not part:FindFirstChild("GuardDoorPass") then
			local modifier = Instance.new("PathfindingModifier")
			modifier.Name = "GuardDoorPass"
			modifier.PassThrough = true
			modifier.Parent = part
		end
	end
end

function GuardService:Init()
	for _, group in { "Guards", "GuardDoor" } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("GuardDoor", "Guards", false)
end

function GuardService:Start()
	for _, inst in CollectionService:GetTagged(Tags.GuardDoor) do
		setupGuardDoor(inst)
	end
	CollectionService:GetInstanceAddedSignal(Tags.GuardDoor):Connect(setupGuardDoor)

	MapService.LevelBuilt:Connect(function()
		-- The old guards went with the old level. SetupService spawns the new ones; without it, the prototype guard.
		for index = #guards, 1, -1 do
			if guards[index].model.Parent == nil then
				table.remove(guards, index)
			end
		end
		if not Peers.get("SetupService") then
			spawnPrototype()
		end
	end)
	if MapService.Level and not Peers.get("SetupService") then
		spawnPrototype()
	end

	-- Lockdown radio: every 8 s each patrolling guard hears where the nearest loot carrier (else anyone free) is.
	task.spawn(function()
		while true do
			task.wait(G.LockdownRadioInterval)
			if not isLockdown() then
				continue
			end
			local now = Targets.now()
			local crew = {}
			for _, view in Targets.crewViews() do
				if not Targets.ignored(view.player, view.character, now) then
					table.insert(crew, view)
				end
			end
			if #crew == 0 then
				continue
			end
			for _, guard in guards do
				if guard.state == "Patrol" then
					local best: Vector3? = nil
					local bestScore = math.huge
					for _, view in crew do
						local distance = (view.root.Position - guard.root.Position).Magnitude
						local score = distance + (if Targets.hasLoot(view.character) then 0 else 100000)
						if score < bestScore then
							best, bestScore = view.root.Position, score
						end
					end
					if best then
						investigate(guard, best, G.RadioSearchSeconds, true)
					end
				end
			end
		end
	end)

	local visionTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		visionTimer += dt
		local doVision = visionTimer >= G.VisionInterval
		local visionDt = visionTimer
		local seen: { Seen } = {}
		local params: RaycastParams? = nil
		if doVision then
			visionTimer = 0
			if #guards > 0 then
				seen = snapshot(Targets.now())
				params = visionParams()
			end
		end
		for index = #guards, 1, -1 do
			local guard = guards[index]
			if guard.model.Parent == nil then
				table.remove(guards, index)
				continue
			end
			if doVision and params then
				updateVision(guard, visionDt, seen, params)
			end
			local ok, err = pcall(function()
				updateBehaviour(guard, dt)
			end)
			if not ok then
				warn("[GuardService] guard update failed:", err)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		everSeen[player] = nil
		for _, guard in guards do
			guard.meters[player] = nil
			if guard.target == player then
				guard.target = nil
			end
			if guard.pullOut and guard.pullOut.player == player then
				guard.pullOut = nil
			end
		end
	end)
end

return GuardService
