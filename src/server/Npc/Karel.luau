--!strict
-- Karel, the fussy shop assistant (beta-spec §4.3, advisor §13). Catches nobody, immune to Bubble and EMP.
--   Rest     at `KarelHome` 60 s ±15 (alarm tier 1+: half as long)
--   Walk     along `Points.KarelRoute` at 7, then back home
--   Detour   a `Trace` within 25 studs in line of sight → walks there with pathfinding
--              OpenDoor    closes it ("WHO LEFT THIS OPEN?!" +20) and leaves a silent 0.5 s "Open" prompt
--              DroppedLoot (dropped ≥ 30 s ago) picks it up and carries it home (`LootService:SetReturning`,
--                          `ReturnHome`); players may snatch it back
--              Noisemaker  pockets it (the ring ends) +20
--            Each trace scores once. Lines go out as `KarelShout`.
--   Snitch   sees crew like a guard (range 25, fill ×0.5): "I'M TELLING!" +20, the 2 nearest guards investigate,
--            once per player per 30 s; his own meter shows above his head.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Mover = require(script.Parent.Mover)
local Peers = require(script.Parent.Peers)
local Rig = require(script.Parent.Rig)
local SnitchEye = require(script.Parent.SnitchEye)
local Targets = require(script.Parent.Targets)

local K = Config.Karel

local Karel = {}
Karel.__index = Karel

export type Hooks = {
	addAlarm: (reason: string, points: number?, player: Player?) -> (),
	alertNearest: (position: Vector3, count: number) -> (),
	endDistraction: (position: Vector3) -> (),
	alarmLevel: () -> number,
}

type State = "Rest" | "Walk" | "Home" | "Detour" | "Carry"

type Data = {
	kind: string,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	mover: Mover.Mover,
	board: Rig.Billboard,
	eye: SnitchEye.SnitchEye,
	hooks: Hooks,
	home: Vector3,
	route: { Vector3 },
	routeIndex: number,
	state: State,
	until_: number,
	trace: Instance?,
	traceSince: number,
	carrying: Instance?,
	carryHome: Vector3?,
	nextScan: number,
	visionTimer: number,
	ignored: { [Instance]: number },
}

export type Karel = typeof(setmetatable({} :: Data, Karel))

-- Traces that already cost the crew points (a re-opened door scores no second time).
local scored: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function shout(line: string, position: Vector3)
	Net.broadcast("KarelShout", line, position)
end

local function restSeconds(level: number): number
	local seconds = K.Rest + (math.random() * 2 - 1) * K.RestJitter
	if level >= 1 then
		seconds *= K.Tier1RestFactor
	end
	return seconds
end

function Karel.new(parent: Instance, home: Vector3, route: { Vector3 }?, hooks: Hooks): Karel
	local model = Rig.humanoid("Karel", {
		skin = Color3.fromRGB(240, 200, 170),
		shirt = Color3.fromRGB(196, 170, 120),
		pants = Color3.fromRGB(90, 70, 50),
	})
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = K.Speed
	Rig.attach(
		model,
		"Head",
		Vector3.new(1.4, 0.3, 1.4),
		CFrame.new(0, 0.75, 0),
		Color3.fromRGB(120, 40, 40),
		"Beret"
	)
	local board = Rig.billboard(model)
	model:SetAttribute(Tags.NpcKind, "Karel")
	model:SetAttribute("NpcState", "Rest")
	Rig.place(model, parent, CFrame.new(home + Vector3.new(0, 3, 0)), { Tags.Npc })

	local self: Data = {
		kind = "Karel",
		model = model,
		humanoid = humanoid,
		root = root,
		mover = Mover.new(humanoid, root),
		board = board,
		eye = nil :: any,
		hooks = hooks,
		home = home,
		route = route or {},
		routeIndex = 1,
		state = "Rest",
		until_ = os.clock() + restSeconds(hooks.alarmLevel()),
		trace = nil,
		traceSince = 0,
		carrying = nil,
		carryHome = nil,
		nextScan = 0,
		visionTimer = 0,
		ignored = {},
	}
	local karel = setmetatable(self, Karel)
	karel.eye = SnitchEye.new(model, root, board, Config.Snitch.KarelFill, function(player, position)
		shout("I'M TELLING!", root.Position)
		Net.broadcast("Spotted", player.UserId, "snitch")
		hooks.addAlarm("Snitch", Config.Snitch.Points, player)
		hooks.alertNearest(position, Config.Snitch.GuardsAlerted)
	end)
	return karel
end

function Karel.setState(self: Karel, state: State)
	self.state = state
	self.model:SetAttribute("NpcState", state)
end

--------------------------------------------------------------------------------------------------------------
-- Doors
--------------------------------------------------------------------------------------------------------------

local function doorCFrame(door: Instance): CFrame?
	return Targets.cframeOf(door)
end

local function setDoorCollide(door: Instance, on: boolean)
	local parts: { BasePart } = {}
	if door:IsA("BasePart") then
		table.insert(parts, door)
	end
	for _, child in door:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	for _, part in parts do
		part.CanCollide = on
		part.CanQuery = on
	end
end

local function moveDoor(door: Instance, target: CFrame)
	if door:IsA("BasePart") then
		TweenService:Create(door, TweenInfo.new(0.35, Enum.EasingStyle.Back), { CFrame = target }):Play()
	elseif door:IsA("Model") then
		door:PivotTo(target)
	end
end

local function openPromptHolder(door: Instance): BasePart?
	if door:IsA("BasePart") then
		return door
	elseif door:IsA("Model") then
		return door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- A door Karel closed can be opened again silently (0.5 s, no CRACK). It becomes a trace again (no new points).
local function ensureOpenPrompt(door: Instance)
	local holder = openPromptHolder(door)
	if not holder then
		return
	end
	local prompt = holder:FindFirstChild("OpenPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = true
		return
	end
	local newPrompt = Instance.new("ProximityPrompt")
	newPrompt.Name = "OpenPrompt"
	newPrompt.ActionText = "Open"
	newPrompt.ObjectText = "Door"
	newPrompt.HoldDuration = K.OpenHold
	newPrompt.MaxActivationDistance = 7
	newPrompt.RequiresLineOfSight = false
	newPrompt.Style = Enum.ProximityPromptStyle.Custom
	newPrompt.KeyboardKeyCode = Enum.KeyCode.E
	newPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	newPrompt:SetAttribute("ContextIcon", "Open")
	newPrompt.Parent = holder
	newPrompt.Triggered:Connect(function(player)
		if door:GetAttribute(Tags.DoorState) ~= "Closed" or not Targets.isCrew(player) then
			return
		end
		local openCFrame = door:GetAttribute("OpenCFrame")
		if typeof(openCFrame) ~= "CFrame" then
			return
		end
		newPrompt.Enabled = false
		setDoorCollide(door, false)
		moveDoor(door, openCFrame)
		door:SetAttribute(Tags.DoorState, "Open")
		door:SetAttribute(Tags.TraceKind, "OpenDoor")
		door:SetAttribute(Tags.TraceBy, player.UserId)
		CollectionService:AddTag(door, Tags.Trace)
	end)
end

local function closeDoor(door: Instance): boolean
	local closed = door:GetAttribute(Tags.ClosedCFrame)
	local current = doorCFrame(door)
	if typeof(closed) ~= "CFrame" or not current then
		return false
	end
	door:SetAttribute("OpenCFrame", current)
	moveDoor(door, closed)
	setDoorCollide(door, true)
	door:SetAttribute(Tags.DoorState, "Closed")
	CollectionService:RemoveTag(door, Tags.Trace)
	Rig.sound(openPromptHolder(door) or workspace, "rbxasset://sounds/clickfast.wav", 0.4, 0.9)
	ensureOpenPrompt(door)
	return true
end

--------------------------------------------------------------------------------------------------------------
-- Traces
--------------------------------------------------------------------------------------------------------------

local function traceBy(trace: Instance): Player?
	local userId = trace:GetAttribute(Tags.TraceBy)
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function wanted(trace: Instance, now: number): boolean
	local kind = trace:GetAttribute(Tags.TraceKind)
	if kind == "OpenDoor" then
		return trace:GetAttribute(Tags.DoorState) ~= "Closed"
	elseif kind == "DroppedLoot" then
		local droppedAt = trace:GetAttribute(Tags.DroppedAt)
		return trace:GetAttribute(Tags.LootState) == "Dropped"
			and typeof(droppedAt) == "number"
			and now - droppedAt >= Config.Loot.ReturnDelay
	elseif kind == "Noisemaker" then
		return true
	end
	return false
end

local function scanParams(self: Karel): RaycastParams
	local ignore: { Instance } = { self.model }
	for _, tag in { Tags.SeeThrough, Tags.Npc, Tags.Guard, Tags.Drone } do
		for _, inst in CollectionService:GetTagged(tag) do
			table.insert(ignore, inst)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

function Karel.scan(self: Karel): Instance?
	local now = Targets.now()
	local clock = os.clock()
	local eye = self.root.Position + Vector3.new(0, 2.5, 0)
	local best: Instance? = nil
	local bestDistance = K.Notice
	local params: RaycastParams? = nil
	for _, trace in CollectionService:GetTagged(Tags.Trace) do
		if (self.ignored[trace] or 0) > clock or not trace:IsDescendantOf(workspace) then
			continue
		end
		local position = Targets.positionOf(trace)
		if not position or not wanted(trace, now) then
			continue
		end
		local distance = (position - eye).Magnitude
		if distance > bestDistance then
			continue
		end
		params = params or scanParams(self)
		local hit = workspace:Raycast(eye, position - eye, params :: RaycastParams)
		if hit == nil or hit.Instance:IsDescendantOf(trace) or (hit.Position - position).Magnitude < 2 then
			best, bestDistance = trace, distance
		end
	end
	return best
end

function Karel.handle(self: Karel, trace: Instance)
	local kind = trace:GetAttribute(Tags.TraceKind)
	local by = traceBy(trace)
	local position = Targets.positionOf(trace) or self.root.Position
	if kind == "OpenDoor" then
		if closeDoor(trace) then
			shout("WHO LEFT THIS OPEN?!", self.root.Position)
			if not scored[trace] then
				scored[trace] = true
				self.hooks.addAlarm("TraceFound", nil, by)
				Peers.event("TraceCleaned", by)
			end
		end
		self:goHome()
	elseif kind == "DroppedLoot" then
		local called, ok = Peers.call("LootService", "SetReturning", trace, self.root)
		if called and ok then
			local record = Peers.get("LootService"):Get(trace)
			local home: CFrame? = if record then record.home else nil
			self.carrying = trace
			self.carryHome = if home then home.Position else self.home
			self:setState("Carry")
			shout("THIS GOES BACK ON THE SHELF!", self.root.Position)
			if not scored[trace] then
				scored[trace] = true
				Peers.event("TraceCleaned", by)
			end
		else
			self:goHome()
		end
	elseif kind == "Noisemaker" then
		CollectionService:RemoveTag(trace, Tags.Trace)
		local holder = if trace:IsA("BasePart") or trace:IsA("Model") then trace else trace.Parent
		if holder and holder ~= workspace then
			holder:Destroy()
		end
		self.hooks.endDistraction(position)
		shout("WHO PUTS AN ALARM CLOCK HERE?!", self.root.Position)
		if not scored[trace] then
			scored[trace] = true
			self.hooks.addAlarm("TraceFound", nil, by)
			Peers.event("TraceCleaned", by)
		end
		self:goHome()
	else
		self:goHome()
	end
end

function Karel.goHome(self: Karel)
	self.trace = nil
	self:setState("Home")
end

--------------------------------------------------------------------------------------------------------------
-- Loop
--------------------------------------------------------------------------------------------------------------

function Karel.step(self: Karel, dt: number)
	local now = os.clock()
	self.visionTimer += dt
	if self.visionTimer >= 0.1 then
		self.eye:step(self.visionTimer)
		self.visionTimer = 0
	end

	-- Traces interrupt resting and walking.
	if (self.state == "Rest" or self.state == "Walk" or self.state == "Home") and now >= self.nextScan then
		self.nextScan = now + K.ScanInterval
		local trace = self:scan()
		if trace then
			self.trace = trace
			self.traceSince = now
			self:setState("Detour")
		end
	end

	local state = self.state
	if state == "Rest" then
		self.mover:stop()
		if now >= self.until_ then
			if #self.route > 0 then
				self.routeIndex = 1
				self:setState("Walk")
			else
				self.until_ = now + restSeconds(self.hooks.alarmLevel())
			end
		end
	elseif state == "Walk" then
		local goal = self.route[self.routeIndex]
		self.mover:moveTo(goal, math.abs(goal.Y - (self.root.Position.Y - 3)) > Config.Guard.FloorStep)
		if self.mover:flatDistance(goal) < 2.5 or self.mover:stuck() then
			self.routeIndex += 1
			if self.routeIndex > #self.route then
				self:setState("Home")
			end
		end
	elseif state == "Home" then
		self.mover:moveTo(self.home, true)
		if self.mover:flatDistance(self.home) < 3 or self.mover:stuck() then
			self:setState("Rest")
			self.until_ = now + restSeconds(self.hooks.alarmLevel())
		end
	elseif state == "Detour" then
		local trace = self.trace
		local position = if trace then Targets.positionOf(trace) else nil
		if
			not trace
			or not position
			or not trace:IsDescendantOf(workspace)
			or not wanted(trace, Targets.now())
		then
			self:goHome()
		elseif now - self.traceSince > K.TraceTimeout then
			self.ignored[trace] = now + 30 -- can't reach it: forget it for a while
			self:goHome()
		else
			self.mover:moveTo(position, true)
			if self.mover:flatDistance(position) <= K.ReachDistance then
				self.mover:stop()
				self:handle(trace)
			end
		end
	elseif state == "Carry" then
		local loot = self.carrying
		local target = self.carryHome or self.home
		if not loot or loot:GetAttribute(Tags.LootState) ~= "Returning" then
			-- Snatched back by a player (or gone).
			self.carrying = nil
			shout("HEY! THAT'S NOT YOURS!", self.root.Position)
			self:goHome()
		else
			self.mover:moveTo(target, true)
			if self.mover:flatDistance(target) <= K.ReachDistance + 1 or now - self.traceSince > 40 then
				self.mover:stop()
				Peers.call("LootService", "ReturnHome", loot)
				self.carrying = nil
				self:goHome()
			end
		end
	end
	self.mover:step()
end

-- "Karel has seen worse": bubbles do nothing.
function Karel.bubble(self: Karel, _seconds: number, by: Player?): boolean
	if by then
		Net.send(by, "Toast", 'Karel: "I have seen worse."')
	end
	shout("REALLY?", self.root.Position)
	return false
end

function Karel.destroy(self: Karel)
	self.mover:stop()
	if self.carrying then
		Peers.call("LootService", "ReturnHome", self.carrying)
		self.carrying = nil
	end
	if self.model.Parent then
		self.model:Destroy()
	end
end

return Karel
