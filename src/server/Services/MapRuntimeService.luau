--!strict
-- The map runtime (mechanics package D): the server behaviour behind the map-specific tags, so map packages only
-- build geometry and tags. Tag rules for map builders: src/server/MapRuntime/README.md.
--   Rides            MapRuntime/Rides      Ride folders: server-moved cars on Points.Rides paths, seats, loot riding
--   Rhythm machines  MapRuntime/Rhythm     fountain, mixer (noise mask), wrapper, mist/steam, sprinklers, clock beam
--
-- SetupService:Apply calls Setup(level, heistInfo, job) at Briefing; SetupService:Teardown calls Clear(). Between
-- them this service follows RoundService.PhaseChanged (Heist, Lockdown, Getaway).
--
-- Entry points: Setup(level, heistInfo, job), Clear(), RideOf(player) → RideId?,
-- IsNoiseMasked(position) → boolean (call before GuardService:HearNoise for a CRACK: the Big Mixer drowns it out).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Server = script.Parent.Parent
local MapRuntime = Server.MapRuntime
local Util = require(MapRuntime.Util)
local Rides = require(MapRuntime.Rides)
local Rhythm = require(MapRuntime.Rhythm)
local RoundService = require(script.Parent.RoundService)
local SetupService = require(script.Parent.SetupService)

local MapRuntimeService = {}

type Module = {
	setup: (ctx: Util.Context) -> (),
	phase: ((ctx: Util.Context) -> ())?,
	step: ((now: number, dt: number) -> ())?,
	clear: () -> (),
}

-- Every runtime module, in setup order; `interval` = seconds between steps (0 = every frame).
local MODULES: { { name: string, module: Module, interval: number } } = {
	{ name = "Rides", module = Rides :: any, interval = 0 },
	{ name = "Rhythm", module = Rhythm :: any, interval = 0.1 },
}

local ctx: Util.Context? = nil
local heartbeat: RBXScriptConnection? = nil
local timers: { [string]: number } = {}

local function each(method: string, ...: any)
	for _, entry in MODULES do
		local fn = (entry.module :: any)[method]
		if type(fn) == "function" then
			local ok, err = pcall(fn, ...)
			if not ok then
				warn(`[MapRuntime] {entry.name}.{method} failed: {err}`)
			end
		end
	end
end

-- Reads round timing from RoundService into the context.
local function syncState(c: Util.Context)
	local state = RoundService:GetState()
	c.phase = state.phase
	c.lockdown = state.lockdown == true
	c.lockdownAt = state.lockdownAt
	c.startedAt = state.startedAt
	local endsAt = ReplicatedStorage:GetAttribute(Tags.RoundEndsAt)
	c.roundEndsAt = if type(endsAt) == "number" then endsAt else nil
end

local function step(dt: number)
	local c = ctx
	if not c then
		return
	end
	local now = Util.now()
	for _, entry in MODULES do
		local fn = entry.module.step
		if fn then
			local due = (timers[entry.name] or 0) + dt
			if due >= entry.interval then
				timers[entry.name] = 0
				local ok, err = pcall(fn :: any, now, due)
				if not ok then
					warn(`[MapRuntime] {entry.name}.step failed: {err}`)
				end
			else
				timers[entry.name] = due
			end
		end
	end
end

-- Builds the runtime for a freshly built level (SetupService:Apply, Briefing).
function MapRuntimeService:Setup(level: Instance, heistInfo: any, job: any)
	MapRuntimeService:Clear()
	if typeof(level) ~= "Instance" or level.Parent == nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "MapRuntime"
	folder.Parent = level
	local seed = if type(job) == "table" and type(job.seed) == "number" then job.seed else 1
	local c: Util.Context = {
		level = level,
		info = heistInfo,
		job = job,
		plan = SetupService:GetPlan(),
		seed = seed,
		folder = folder,
		phase = "Briefing",
		lockdown = false,
		lockdownAt = nil,
		startedAt = nil,
		roundEndsAt = nil,
	}
	syncState(c)
	ctx = c
	table.clear(timers)
	each("setup", c)
	heartbeat = RunService.Heartbeat:Connect(step)
end

-- Stops everything and removes what the runtime created (SetupService:Teardown).
function MapRuntimeService:Clear()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	local c = ctx
	ctx = nil
	each("clear")
	if c and c.folder.Parent then
		c.folder:Destroy()
	end
end

-- The RideId this player is riding, or nil.
function MapRuntimeService:RideOf(player: Player): string?
	return Rides.rideOf(player)
end

-- True while a noise at `position` is drowned out (a Big Mixer thump window within its Radius).
function MapRuntimeService:IsNoiseMasked(position: Vector3): boolean
	if typeof(position) ~= "Vector3" then
		return false
	end
	return Rhythm.isNoiseMasked(position)
end

function MapRuntimeService:Start()
	RoundService.PhaseChanged:Connect(function(_phase: string)
		local c = ctx
		if not c then
			return
		end
		syncState(c)
		each("phase", c)
	end)
end

return MapRuntimeService
