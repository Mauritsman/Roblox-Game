--!strict
-- Walking for humanoid NPCs (guards, Karel, the Inspector, Boef). Two modes:
--   * direct: Humanoid:MoveTo straight at the goal (patrol legs, investigating on the same floor, Boef)
--   * path:   PathfindingService, computed in a separate thread (never in the Heartbeat), recomputed at most
--             every Config.Guard.PathRecompute seconds and only when the goal moved more than 3 studs
--             (chasing without line of sight, carrying a captive to the cell, floor changes, Karel's detours).
-- A failed path falls back to walking straight. `stuck()` reports no progress for Config.Guard.StuckSeconds.
-- Smoothness (bug B-010):
--   * Humanoid:MoveTo is only re-issued when the target moved meaningfully, the last MoveTo finished short of
--     it, or before Roblox's 8 s MoveTo timeout; `stop()` only touches the Humanoid when it was walking.
--   * Turning on the spot (`face`, `turnBy`) uses an AlignOrientation (physics, replicates smoothly) instead of
--     setting the root CFrame every frame; walking hands the turning back to the Humanoid (AutoRotate).
--   * The root stays server-owned: checked about once a second, because welding (bubble, captive) can hand an
--     assembly back to automatic ownership, and a nearby client then simulates the NPC (jitter).

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local G = Config.Guard

local Mover = {}
Mover.__index = Mover

type MoverData = {
	humanoid: Humanoid,
	root: BasePart,
	path: Path,
	goal: Vector3?,
	usePath: boolean,
	pathGoal: Vector3?,
	waypoints: { PathWaypoint }?,
	index: number,
	computing: boolean,
	lastCompute: number,
	issued: Vector3?,
	issuedAt: number,
	finished: boolean, -- the last MoveTo ended (reached or timed out)
	progressPos: Vector3,
	progressAt: number,
	token: number,
	align: AlignOrientation,
	turning: boolean,
	yaw: number,
	ownerCheckAt: number,
}

export type Mover = typeof(setmetatable({} :: MoverData, Mover))

local REISSUE_SECONDS = 6 -- Humanoid:MoveTo gives up after 8 s
local OWNER_CHECK_SECONDS = 1

-- Keeps the NPC's assembly simulated by the server (no-op for anchored or removed parts).
local function ensureServerOwned(root: BasePart)
	if root.Anchored or not root:IsDescendantOf(workspace) then
		return
	end
	pcall(function()
		if root:GetNetworkOwnershipAuto() or root:GetNetworkOwner() ~= nil then
			root:SetNetworkOwner(nil)
		end
	end)
end

local function makeAlign(root: BasePart): AlignOrientation
	local attachment = Instance.new("Attachment")
	attachment.Name = "MoverTurn"
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "MoverTurn"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = false
	align.MaxTorque = 100000
	align.Responsiveness = 25
	align.MaxAngularVelocity = math.rad(G.TurnSpeed)
	align.Enabled = false
	align.Parent = root
	return align
end

function Mover.new(humanoid: Humanoid, root: BasePart, agent: { [string]: any }?): Mover
	local params = agent
		or {
			AgentRadius = G.AgentRadius,
			AgentHeight = G.AgentHeight,
			AgentCanJump = false,
			WaypointSpacing = 6,
		}
	local self: MoverData = {
		humanoid = humanoid,
		root = root,
		path = PathfindingService:CreatePath(params),
		goal = nil,
		usePath = false,
		pathGoal = nil,
		waypoints = nil,
		index = 1,
		computing = false,
		lastCompute = -math.huge,
		issued = nil,
		issuedAt = 0,
		finished = false,
		progressPos = root.Position,
		progressAt = os.clock(),
		token = 0,
		align = makeAlign(root),
		turning = false,
		yaw = 0,
		ownerCheckAt = 0,
	}
	humanoid.MoveToFinished:Connect(function()
		self.finished = true
	end)
	return setmetatable(self, Mover)
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function currentYaw(root: BasePart): number
	local look = root.CFrame.LookVector
	return math.atan2(-look.X, -look.Z) -- CFrame.Angles(0, yaw, 0) looks along (-sin yaw, 0, -cos yaw)
end

-- Hands turning back to the Humanoid (it faces where it walks).
local function releaseTurn(self: Mover)
	if self.turning then
		self.turning = false
		self.align.Enabled = false
		self.humanoid.AutoRotate = true
	end
end

local function checkOwner(self: Mover, now: number)
	if now >= self.ownerCheckAt then
		self.ownerCheckAt = now + OWNER_CHECK_SECONDS
		ensureServerOwned(self.root)
	end
end

-- Sets the goal. Changing the goal by more than 3 studs (or switching mode) drops the old path.
function Mover.moveTo(self: Mover, goal: Vector3, usePath: boolean)
	releaseTurn(self)
	local previous = self.goal
	if usePath ~= self.usePath or previous == nil or (previous - goal).Magnitude > 3 then
		self.progressPos = self.root.Position
		self.progressAt = os.clock()
	end
	if usePath ~= self.usePath then
		self.waypoints = nil
		self.pathGoal = nil
	end
	self.goal = goal
	self.usePath = usePath
end

-- Stops walking. Only tells the Humanoid when it was walking (calling it every frame makes NPCs stutter).
function Mover.stop(self: Mover)
	local walking = self.goal ~= nil or self.issued ~= nil
	self.goal = nil
	self.waypoints = nil
	self.pathGoal = nil
	self.issued = nil
	self.token += 1
	if walking then
		self.humanoid:MoveTo(self.root.Position)
	end
	checkOwner(self, os.clock())
end

-- Re-checks server ownership on the next step (call after welding or unwelding something to the NPC).
function Mover.refreshOwner(self: Mover)
	self.ownerCheckAt = 0
end

function Mover.hasGoal(self: Mover): boolean
	return self.goal ~= nil
end

-- Turns on the spot to face the heading `yaw` (radians), smoothly through physics.
function Mover.faceYaw(self: Mover, yaw: number)
	self.yaw = yaw
	self.align.CFrame = CFrame.Angles(0, yaw, 0)
	if not self.turning then
		self.turning = true
		self.humanoid.AutoRotate = false
		self.align.Enabled = true
	end
end

-- Turns on the spot to face a point.
function Mover.face(self: Mover, point: Vector3)
	local position = self.root.Position
	local dx, dz = point.X - position.X, point.Z - position.Z
	if dx * dx + dz * dz < 0.01 then
		return
	end
	self:faceYaw(math.atan2(-dx, -dz))
end

-- Keeps turning on the spot (looking around): the wanted heading moves on by `radians`.
function Mover.turnBy(self: Mover, radians: number)
	local yaw = if self.turning then self.yaw else currentYaw(self.root)
	self:faceYaw((yaw + radians + math.pi) % (2 * math.pi) - math.pi)
end

-- The first waypoint still ahead of the walker. The path was computed from where he stood a moment ago, so the
-- first waypoints may already be behind him; walking back to them made NPCs turn around and jitter.
local function firstAhead(waypoints: { PathWaypoint }, position: Vector3): number
	local best, bestDistance = 1, math.huge
	for index = 1, math.min(#waypoints, 4) do
		local d = flat(waypoints[index].Position, position)
		if d < bestDistance then
			best, bestDistance = index, d
		end
	end
	return math.min(best + 1, #waypoints)
end

local function compute(self: Mover, goal: Vector3)
	self.computing = true
	self.lastCompute = os.clock()
	self.token += 1
	local token = self.token
	local from = self.root.Position
	task.spawn(function()
		local ok = pcall(function()
			self.path:ComputeAsync(from, goal)
		end)
		self.computing = false
		if token ~= self.token then
			return -- stopped or re-targeted meanwhile
		end
		if ok and self.path.Status == Enum.PathStatus.Success then
			local waypoints = self.path:GetWaypoints()
			self.waypoints = waypoints
			self.index = firstAhead(waypoints, self.root.Position)
		else
			self.waypoints = nil -- walk straight instead
		end
		self.pathGoal = goal
	end)
end

-- Call every Heartbeat.
function Mover.step(self: Mover)
	local now = os.clock()
	checkOwner(self, now)
	local goal = self.goal
	if goal == nil then
		return
	end
	local position = self.root.Position
	local target = goal
	if self.usePath then
		local pathGoal = self.pathGoal
		local needsPath = pathGoal == nil or (pathGoal - goal).Magnitude > 3
		if needsPath and not self.computing and now - self.lastCompute >= G.PathRecompute then
			compute(self, goal)
		end
		local waypoints = self.waypoints
		if waypoints then
			while self.index <= #waypoints do
				local waypoint = waypoints[self.index]
				local close = flat(waypoint.Position, position) < 2.5
					and math.abs(waypoint.Position.Y - (position.Y - 3)) < 4
				if not close then
					break
				end
				self.index += 1
			end
			if self.index <= #waypoints then
				target = waypoints[self.index].Position
			end
		end
	end
	-- Re-issue only when it matters: the target moved (further targets may move more before it counts), the last
	-- MoveTo ended short of the target, or the 8 s timeout is near.
	local issued = self.issued
	local away = flat(target, position)
	local moved = if issued then (issued - target).Magnitude else math.huge
	if
		issued == nil
		or moved > math.max(1, away * 0.15)
		or (self.finished and away > 1.5)
		or now - self.issuedAt > REISSUE_SECONDS
	then
		self.issued = target
		self.issuedAt = now
		self.finished = false
		self.humanoid:MoveTo(target)
	end
	if (position - self.progressPos).Magnitude > 1 then
		self.progressPos = position
		self.progressAt = now
	end
end

-- No progress for a while although there is a goal.
function Mover.stuck(self: Mover): boolean
	return self.goal ~= nil and os.clock() - self.progressAt > G.StuckSeconds
end

-- Horizontal distance from the walker to a point.
function Mover.flatDistance(self: Mover, point: Vector3): number
	return flat(point, self.root.Position)
end

return Mover
