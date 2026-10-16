--!strict
-- Walking for humanoid NPCs. Two modes:
--   * direct: Humanoid:MoveTo straight at the goal (patrol legs, investigating on the same floor, Boef)
--   * path:   PathfindingService, recomputed at most every Config.Guard.PathRecompute seconds while the goal moves
--             (chasing without line of sight, carrying a captive to the cell, floor changes, Karel's detours).
-- A failed path falls back to walking straight. `stuck()` reports no progress for Config.Guard.StuckSeconds.

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
	progressPos: Vector3,
	progressAt: number,
	token: number,
}

export type Mover = typeof(setmetatable({} :: MoverData, Mover))

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
		progressPos = root.Position,
		progressAt = os.clock(),
		token = 0,
	}
	return setmetatable(self, Mover)
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Sets the goal. Changing the goal by more than 3 studs (or switching mode) drops the old path.
function Mover.moveTo(self: Mover, goal: Vector3, usePath: boolean)
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

function Mover.stop(self: Mover)
	self.goal = nil
	self.waypoints = nil
	self.pathGoal = nil
	self.issued = nil
	self.token += 1
	self.humanoid:MoveTo(self.root.Position)
end

function Mover.hasGoal(self: Mover): boolean
	return self.goal ~= nil
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
			self.waypoints = self.path:GetWaypoints()
			self.index = 2
		else
			self.waypoints = nil -- walk straight instead
		end
		self.pathGoal = goal
	end)
end

-- Call every Heartbeat.
function Mover.step(self: Mover)
	local goal = self.goal
	if goal == nil then
		return
	end
	local now = os.clock()
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
				local close = flat(waypoint.Position, self.root.Position) < 2.5
					and math.abs(waypoint.Position.Y - (self.root.Position.Y - 3)) < 4
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
	local issued = self.issued
	if issued == nil or (issued - target).Magnitude > 0.5 or now - self.issuedAt > 2 then
		self.issued = target
		self.issuedAt = now
		self.humanoid:MoveTo(target)
	end
	if (self.root.Position - self.progressPos).Magnitude > 1 then
		self.progressPos = self.root.Position
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
