--!strict
-- Boef, the shop's dog (beta-spec §4.2; map 1, outdoors). Never bites, immune to Bubble and EMP.
--   Wander   walks `Points.DogRoute` (or random spots) at 6 inside the `DogZone` parts; no pathfinding
--   Follow   smells a crew member with smelly loot (pocket included) within 15 → follows 4 studs behind at 12 and
--            barks every 2 s (`BoefBark`; guards within 30 investigate). A smelly player hiding: barks at the spot
--   Edge     the carrier left the zone: 3 s of barking at the edge, then he gives up
--   Eating   "Give cheese" (a smelly pocket item): busy for 12 s
--   Chasing  a Noisemaker within 20: runs to it for 8 s
-- The model's `NpcState` attribute mirrors the state for the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Mover = require(script.Parent.Mover)
local Peers = require(script.Parent.Peers)
local Rig = require(script.Parent.Rig)
local Targets = require(script.Parent.Targets)

local D = Config.Dog

local Boef = {}
Boef.__index = Boef

export type Hooks = {
	hearNoise: (position: Vector3, radius: number, kind: string, by: Player?) -> (),
	hiddenPlayers: () -> { [Player]: Vector3 },
}

type State = "Wander" | "Follow" | "Edge" | "Eating" | "Chasing"

type Data = {
	kind: string,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	mover: Mover.Mover,
	zones: { BasePart },
	route: { Vector3 },
	routeIndex: number,
	hooks: Hooks,
	state: State,
	target: Player?,
	until_: number,
	nextBark: number,
	nextSmell: number,
	prompt: ProximityPrompt,
	chasePos: Vector3?,
}

export type Boef = typeof(setmetatable({} :: Data, Boef))

local function insideAny(zones: { BasePart }, point: Vector3): boolean
	for _, zone in zones do
		if Targets.insidePart(zone, Vector3.new(point.X, zone.Position.Y, point.Z)) then
			return true
		end
	end
	return false
end

-- The nearest point inside the zones (keeps Boef in his yard).
local function clampToZones(zones: { BasePart }, point: Vector3): Vector3
	if #zones == 0 or insideAny(zones, point) then
		return point
	end
	local best = point
	local bestDistance = math.huge
	for _, zone in zones do
		local localPoint = zone.CFrame:PointToObjectSpace(point)
		local half = zone.Size / 2 - Vector3.new(1, 0, 1)
		local clamped = Vector3.new(
			math.clamp(localPoint.X, -math.max(half.X, 0), math.max(half.X, 0)),
			localPoint.Y,
			math.clamp(localPoint.Z, -math.max(half.Z, 0), math.max(half.Z, 0))
		)
		local world = zone.CFrame:PointToWorldSpace(clamped)
		local distance = (world - point).Magnitude
		if distance < bestDistance then
			best, bestDistance = Vector3.new(world.X, point.Y, world.Z), distance
		end
	end
	return best
end

local function randomPointIn(zones: { BasePart }, fallback: Vector3): Vector3
	local zone = zones[math.random(1, math.max(1, #zones))]
	if not zone then
		return fallback
	end
	local half = zone.Size / 2
	local localPoint =
		Vector3.new((math.random() * 2 - 1) * half.X * 0.8, 0, (math.random() * 2 - 1) * half.Z * 0.8)
	local world = zone.CFrame:PointToWorldSpace(localPoint)
	return Vector3.new(world.X, fallback.Y, world.Z)
end

function Boef.new(parent: Instance, zones: { BasePart }, route: { Vector3 }?, hooks: Hooks): Boef
	local model = Rig.dog()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = D.WanderSpeed
	model:SetAttribute(Tags.NpcKind, "Boef")
	model:SetAttribute("NpcState", "Wander")
	model:SetAttribute(Tags.SpotKind, "dog")
	local start = if route and route[1]
		then route[1] + Vector3.new(0, 2, 0)
		else randomPointIn(
			zones,
			(zones[1] and zones[1].Position or Vector3.zero) + Vector3.new(0, 2, 0)
		)
	Rig.place(model, parent, CFrame.new(start), { Tags.Npc, Tags.Spottable })

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TreatPrompt"
	prompt.ActionText = "Give cheese"
	prompt.ObjectText = "Boef"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = D.TreatRange
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("ContextIcon", "Treat")
	prompt.Parent = root

	local self: Data = {
		kind = "Boef",
		model = model,
		humanoid = humanoid,
		root = root,
		mover = Mover.new(humanoid, root),
		zones = zones,
		route = route or {},
		routeIndex = 1,
		hooks = hooks,
		state = "Wander",
		target = nil,
		until_ = 0,
		nextBark = 0,
		nextSmell = 0,
		prompt = prompt,
		chasePos = nil,
	}
	local boef = setmetatable(self, Boef)
	prompt.Triggered:Connect(function(player)
		boef:treat(player)
	end)
	return boef
end

function Boef.setState(self: Boef, state: State)
	if self.state == state then
		return
	end
	self.state = state
	self.model:SetAttribute("NpcState", state)
	self.humanoid.WalkSpeed = if state == "Wander"
		then D.WanderSpeed
		elseif state == "Eating" then 0
		else D.FollowSpeed
	self.prompt.Enabled = state ~= "Eating"
	if state == "Wander" or state == "Eating" then
		self.target = nil
	end
end

function Boef.bark(self: Boef, player: Player?)
	local now = os.clock()
	if now < self.nextBark then
		return
	end
	self.nextBark = now + D.BarkInterval
	local position = self.root.Position
	Net.broadcast("BoefBark", if player then player.UserId else nil, position)
	self.hooks.hearNoise(position, D.BarkRadius, "bark", nil)
end

function Boef.treat(self: Boef, player: Player)
	if self.state == "Eating" or not Targets.isCrew(player) then
		return
	end
	local called, consumed = Peers.call("CarryService", "ConsumePocket", player, nil)
	if not called or consumed == nil then
		Net.send(player, "Toast", "Boef wants cheese!")
		return
	end
	self:setState("Eating")
	self.until_ = os.clock() + D.TreatSeconds
	self.mover:stop()
	Peers.event("BoefFed", player)
end

-- A Noisemaker landed: he runs after it for 8 s (when it is close enough).
function Boef.noise(self: Boef, position: Vector3, kind: string, by: Player?)
	if kind ~= "noisemaker" or self.state == "Eating" then
		return
	end
	if (position - self.root.Position).Magnitude > D.NoisemakerRadius then
		return
	end
	self:setState("Chasing")
	self.chasePos = clampToZones(self.zones, position)
	self.until_ = os.clock() + D.NoisemakerSeconds
	if by then
		Peers.event("BoefDistracted", by)
	end
end

local function smellTarget(self: Boef): (Player?, Vector3?)
	local best: Player? = nil
	local bestPos: Vector3? = nil
	local bestDistance = D.Smell
	local now = Targets.now()
	for _, view in Targets.crewViews() do
		local character = view.character
		if
			character:GetAttribute(Tags.Caught) ~= true and not Targets.ignored(view.player, character, now)
		then
			local distance = (view.root.Position - self.root.Position).Magnitude
			if distance <= bestDistance and Targets.smelly(view.player, character) then
				best, bestPos, bestDistance = view.player, view.root.Position, distance
			end
		end
	end
	if best == nil and D.HideBark then
		for player, spot in self.hooks.hiddenPlayers() do
			local character = player.Character
			if
				character
				and Targets.isCrew(player)
				and (spot - self.root.Position).Magnitude <= bestDistance
				and Targets.smelly(player, character)
			then
				best, bestPos, bestDistance = player, spot, (spot - self.root.Position).Magnitude
			end
		end
	end
	return best, bestPos
end

local function targetPosition(self: Boef, player: Player): Vector3?
	local hidden = self.hooks.hiddenPlayers()[player]
	if hidden then
		return hidden
	end
	local view = Targets.view(player)
	if not view or view.character:GetAttribute(Tags.Caught) == true then
		return nil
	end
	if not Targets.smelly(player, view.character) then
		return nil
	end
	return view.root.Position
end

function Boef.step(self: Boef, _dt: number)
	local now = os.clock()
	local state = self.state
	if state == "Eating" then
		self.mover:stop()
		if now >= self.until_ then
			self:setState("Wander")
		end
	elseif state == "Chasing" then
		if self.chasePos then
			self.mover:moveTo(self.chasePos, false)
		end
		if now >= self.until_ then
			self:setState("Wander")
		end
	elseif state == "Follow" or state == "Edge" then
		local target = self.target
		local position = if target then targetPosition(self, target) else nil
		if not target or not position or (position - self.root.Position).Magnitude > D.GiveUpDistance then
			self:setState("Wander")
		else
			local inside = #self.zones == 0 or insideAny(self.zones, position)
			if inside then
				if state == "Edge" then
					self:setState("Follow")
				end
				local away = self.root.Position - position
				local flatAway = Vector3.new(away.X, 0, away.Z)
				local goal = if flatAway.Magnitude > 0.1
					then position + flatAway.Unit * D.FollowDistance
					else position
				self.mover:moveTo(clampToZones(self.zones, goal), false)
				self:bark(target)
			else
				if state ~= "Edge" then
					self:setState("Edge")
					self.until_ = now + D.EdgeBark
				end
				self.mover:moveTo(clampToZones(self.zones, position), false)
				self:bark(target)
				if now >= self.until_ then
					self:setState("Wander")
					self.nextSmell = now + 3 -- he sulks for a moment
				end
			end
		end
	else -- Wander
		if now >= self.nextSmell then
			self.nextSmell = now + 0.25
			local player = smellTarget(self)
			if player then
				self.target = player
				self:setState("Follow")
				Net.broadcast("Spotted", player.UserId, "dog")
				self.nextBark = 0
				return
			end
		end
		local goal: Vector3
		if #self.route > 0 then
			goal = self.route[self.routeIndex]
			if self.mover:flatDistance(goal) < 2 or self.mover:stuck() then
				self.routeIndex = self.routeIndex % #self.route + 1
				goal = self.route[self.routeIndex]
			end
		else
			if not self.mover:hasGoal() or self.mover:stuck() or now >= self.until_ then
				self.until_ = now + 4
				self.mover:moveTo(randomPointIn(self.zones, self.root.Position), false)
			end
			self.mover:step()
			return
		end
		self.mover:moveTo(clampToZones(self.zones, goal), false)
	end
	self.mover:step()
end

-- Bubble and EMP do nothing to Boef.
function Boef.bubble(_self: Boef, _seconds: number, _by: Player?): boolean
	return false
end

function Boef.destroy(self: Boef)
	self.mover:stop()
	if self.model.Parent then
		self.model:Destroy()
	end
end

return Boef
