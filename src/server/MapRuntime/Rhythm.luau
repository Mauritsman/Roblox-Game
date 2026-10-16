--!strict
-- Rhythm machines (beta-spec-maps §7–8; tag RhythmMachine with Kind, Period, Active, Radius). Each machine runs in
-- cycles (Logic/Rhythm): a cycle starts every Period s and its first Active s are the active window.
--   Fountain   each cycle the nearest patrolling guard within Radius comes to taste (GuardService:HearNoise with a
--              radius that only reaches him), for the Active seconds.
--   Mixer      thumps at each cycle start; for Active s a noise within Radius is masked: IsNoiseMasked(pos) (the
--              Crowbar's CRACK is not heard: callers check it before GuardService:HearNoise).
--   Wrapper    during the window, an empty-handed crew member within Radius is gold-wrapped for WrapSeconds:
--              `Wrapped` + `WrappedUntil`, and guards/cameras ignore him (ImmuneUntil is extended); grabbing medium or
--              heavy loot ends it.
--   Mist/Steam during the window, crew inside the cloud (the machine's parts, or within Radius) get `InMist` and a
--              rolling ImmuneUntil, so guards and cameras cannot see them.
--   Sprinkler  always on while running: running (> SlipSpeed) with medium loot inside → slip, SQUEAK, loot drops.
--   Clock      the Tulip auction clock: a light beam sweeps from Center out to an ellipse (RadiusX × RadiusZ) once per
--              Period; standing in it (in sight of the clock) fills a meter; full = spotted (+Points alarm, nearest
--              guards come). Clients smooth the beam (RideController).
-- `Active` may also be a boolean: false = the machine starts switched off. Tagged LockdownSwitch with Action "On" /
-- "Off" it switches at LOCKDOWN; Action "Speed" (or attribute LockdownPeriod) speeds it up at LOCKDOWN.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Timing = require(ReplicatedStorage.Shared.Logic.Rhythm)

local Util = require(script.Parent.Util)
local Effects = require(script.Parent.Effects)
local Optional = require(script.Parent.Parent.Lib.Optional)

local Rhythm = {}

local R = Config.MapRuntime.Rhythm

local STYLE: { [string]: string } = {
	Fountain = "Fountain",
	Mixer = "Dust",
	Wrapper = "Sparkle",
	Mist = "Mist",
	Steam = "Steam",
	Sprinkler = "Sprinkler",
}

type Machine = {
	inst: Instance,
	kind: string,
	timer: Timing.Timer,
	basePeriod: number,
	active: number,
	radius: number,
	offset: number,
	lockdownPeriod: number?,
	speedsUp: boolean,
	running: boolean,
	switchAtLockdown: string?, -- "On" | "Off"
	lastCycle: number,
	pulse: boolean,
	position: Vector3,
	volume: Util.Volume,
	emitters: { ParticleEmitter },
	wrapSeconds: number,
	-- clock
	beam: BasePart?,
	center: Vector3,
	rx: number,
	rz: number,
	meters: { [Player]: number },
	cooldown: { [Player]: number },
}

type Wrap = { character: Model, untilTime: number, written: number }

local ctx: Util.Context? = nil
local machines: { Machine } = {}
local wraps: { [Player]: Wrap } = {}
local misted: { [Player]: Model } = {}
local slipAt: { [Player]: number } = {}
local lockdownApplied = false
local started = false

local function inRound(): boolean
	local c = ctx
	return c ~= nil and (c.phase == "Heist" or c.phase == "Lockdown")
end

local function handsFull(character: Model): boolean
	local class = character:GetAttribute(Tags.CarryClass)
	return class == "Medium" or class == "Heavy" or class == "Main"
end

-- Inside the machine's parts, or within Radius (horizontally, ±8 high) of it.
local function inZone(m: Machine, position: Vector3): boolean
	local d = position - m.position
	if Vector3.new(d.X, 0, d.Z).Magnitude <= m.radius and math.abs(d.Y) <= 8 then
		return true
	end
	return Util.inVolume(m.volume, position)
end

local function setRunning(m: Machine, on: boolean)
	m.running = on
	Util.set(m.inst, Tags.Running, on)
	if m.kind == "Fountain" then
		Effects.set(m.emitters, on)
	end
	if m.beam then
		m.beam.Transparency = if on then 0.72 else 1
	end
end

--------------------------------------------------------------------------------------------------------------
-- Wrapper
--------------------------------------------------------------------------------------------------------------

local function unwrap(player: Player, early: boolean)
	local wrap = wraps[player]
	if not wrap then
		return
	end
	wraps[player] = nil
	if wrap.character.Parent then
		wrap.character:SetAttribute(Tags.Wrapped, nil)
		wrap.character:SetAttribute(Tags.WrappedUntil, nil)
		if early then
			Util.endImmunity(wrap.character, wrap.written)
		end
	end
end

local function wrap(view: Util.View, m: Machine, now: number)
	local untilTime = now + m.wrapSeconds
	local written = Util.extendImmunity(view.character, untilTime)
	view.character:SetAttribute(Tags.Wrapped, true)
	view.character:SetAttribute(Tags.WrappedUntil, untilTime)
	wraps[view.player] = { character = view.character, untilTime = untilTime, written = written }
	Net.send(view.player, "Toast", "Gold-wrapped! Guards ignore you.")
	Util.event("Wrapped", view.player)
end

local function stepWraps(now: number)
	for player, w in table.clone(wraps) do
		local character = w.character
		if character.Parent == nil or player.Character ~= character then
			wraps[player] = nil
		elseif now >= w.untilTime then
			unwrap(player, false)
		elseif handsFull(character) or not Util.isFree(character) then
			unwrap(player, true)
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Machines
--------------------------------------------------------------------------------------------------------------

local function guardRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

-- The fountain: the nearest patrolling guard within Radius walks over to taste it.
local function drawGuard(m: Machine)
	local best: number? = nil
	for _, guard in Util.guards() do
		local state = guard:GetAttribute(Tags.GuardState)
		local root = guardRoot(guard)
		if root and (state == nil or state == "Patrol") then
			local d = (root.Position - m.position).Magnitude
			if d <= m.radius and (best == nil or d < (best :: number)) then
				best = d
			end
		end
	end
	if best then
		Util.hearNoise(m.position, (best :: number) + 0.5, m.active, "fountain")
	end
end

local function onCycle(m: Machine)
	if m.kind == "Fountain" then
		Effects.burst(m.emitters, 20)
		drawGuard(m)
	elseif m.kind == "Mixer" then
		Effects.burst(m.emitters, 12)
	end
end

local function slip(view: Util.View, m: Machine, now: number)
	local player, character = view.player, view.character
	slipAt[player] = now + R.Sprinkler.SlipEvery
	character:SetAttribute(Tags.Slipping, true)
	Util.refresh(player)
	Optional.call("CarryService", "DropHands", player, "slip")
	Util.hearNoise(view.root.Position, R.Sprinkler.SqueakRadius, nil, "squeak", player)
	task.delay(Config.Movement.SlipSeconds, function()
		if player.Character == character then
			character:SetAttribute(Tags.Slipping, nil)
			Util.refresh(player)
		end
	end)
	local _ = m
end

local function stepSprinkler(m: Machine, views: { Util.View }, now: number)
	for _, view in views do
		local character = view.character
		if
			character:GetAttribute(Tags.CarryClass) == "Medium"
			and character:GetAttribute(Tags.Crouching) ~= true
			and Util.isFree(character)
			and now >= (slipAt[view.player] or 0)
			and inZone(m, view.root.Position)
		then
			local v = view.root.AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > R.Sprinkler.SlipSpeed then
				slip(view, m, now)
			end
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Clock
--------------------------------------------------------------------------------------------------------------

local function clockAngle(m: Machine, now: number): number
	return Timing.fraction(m.timer, now) * math.pi * 2
end

local function placeBeam(m: Machine, now: number)
	local beam = m.beam
	if not beam then
		return
	end
	local ex, ez = Timing.ellipse(m.center.X, m.center.Z, m.rx, m.rz, clockAngle(m, now))
	local tip = Vector3.new(ex, m.center.Y + 0.08, ez)
	local base = Vector3.new(m.center.X, m.center.Y + 0.08, m.center.Z)
	local length = math.max(0.5, (tip - base).Magnitude)
	beam.Size = Vector3.new(m.radius * 2, 0.1, length)
	beam.CFrame = CFrame.lookAt((base + tip) / 2, tip)
end

local function writeClock(m: Machine)
	local beam = m.beam
	if beam then
		beam:SetAttribute("Period", m.timer.period)
		beam:SetAttribute("T0", m.timer.t0)
	end
end

local function visionParams(m: Machine): RaycastParams
	local ignore: { Instance } = { m.inst }
	local c = ctx
	if c then
		table.insert(ignore, c.folder)
	end
	for _, view in Util.crewViews() do
		table.insert(ignore, view.character)
	end
	for _, tag in { Tags.SeeThrough, Tags.Npc, Tags.Guard, Tags.Loot, Tags.Drone, Tags.RideCar } do
		for _, inst in CollectionService:GetTagged(tag) do
			table.insert(ignore, inst)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

local function spotted(m: Machine, view: Util.View, now: number)
	local c = R.Clock
	m.cooldown[view.player] = now + c.Cooldown
	m.meters[view.player] = 0
	Util.alarm("ClockSpotlight", Util.num(m.inst, "Points", c.Points), view.player)
	Optional.call("GuardService", "ReportPosition", view.root.Position)
	Net.broadcast("Spotted", view.player.UserId, "camera")
	Util.event("Seen", view.player)
end

local function stepClock(m: Machine, views: { Util.View }, now: number, dt: number)
	placeBeam(m, now)
	local c = R.Clock
	local angle = clockAngle(m, now)
	local params: RaycastParams? = nil
	for _, view in views do
		local player = view.player
		local position = view.root.Position
		local lit = false
		if not Util.ignored(view.character, now) and now >= (m.cooldown[player] or 0) then
			if
				Timing.beamHit(position.X, position.Z, m.center.X, m.center.Z, m.rx, m.rz, angle, m.radius)
			then
				params = params or visionParams(m)
				local head = position + Vector3.new(0, 1.5, 0)
				lit = workspace:Raycast(m.position, head - m.position, params) == nil
			end
		end
		local rate = if view.character:GetAttribute(Tags.Crouching) == true
			then Config.Guard.CrouchFillRate
			else 1
		local meter = Timing.meter(m.meters[player] or 0, dt, lit, c.FillSeconds, rate, c.Decay)
		m.meters[player] = meter
		if meter >= 1 then
			spotted(m, view, now)
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Setup and stepping
--------------------------------------------------------------------------------------------------------------

local function floorBelow(position: Vector3, ignore: Instance): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	local hit = workspace:Raycast(position, Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else position.Y
end

local function setupMachine(c: Util.Context, inst: Instance, now: number): Machine?
	local kind = Util.str(inst, Tags.Kind)
	local d = if kind then (R :: any)[kind] else nil
	if not kind or type(d) ~= "table" or d.Period == nil then
		warn(`[MapRuntime] RhythmMachine {inst:GetFullName()}: unknown Kind {kind}`)
		return nil
	end
	local position = Util.positionOf(inst)
	if not position then
		local cf = Util.box(inst)
		position = if cf then cf.Position else nil
	end
	if not position then
		return nil
	end
	local period = Util.num(inst, Tags.Period, d.Period)
	local activeAttr = inst:GetAttribute(Tags.Active)
	local active = if type(activeAttr) == "number"
		then activeAttr
		else Util.num(inst, "ActiveSeconds", d.Active)
	if kind == "Clock" then
		active = period
	end
	local action = if CollectionService:HasTag(inst, Tags.LockdownSwitch)
		then Util.str(inst, Tags.Action)
		else nil
	local running = if type(activeAttr) == "boolean" then activeAttr else true
	local switchAtLockdown: string? = nil
	if action == "On" then
		running, switchAtLockdown = false, "On"
	elseif action == "Off" then
		switchAtLockdown = "Off"
	end
	local offset = Util.num(inst, Tags.Offset, 0)
	local m: Machine = {
		inst = inst,
		kind = kind :: string,
		timer = Timing.new(period, active, now + offset),
		basePeriod = period,
		active = active,
		radius = Util.num(inst, Tags.Radius, d.Radius),
		offset = offset,
		lockdownPeriod = Util.optNum(inst, Tags.LockdownPeriod),
		speedsUp = action == "Speed" or d.SpeedsUp == true,
		running = running,
		switchAtLockdown = switchAtLockdown,
		lastCycle = 0,
		pulse = false,
		position = position :: Vector3,
		volume = Util.volume(inst),
		emitters = {},
		wrapSeconds = Util.num(inst, "WrapSeconds", R.Wrapper.WrapSeconds),
		beam = nil,
		center = position :: Vector3,
		rx = 0,
		rz = 0,
		meters = {},
		cooldown = {},
	}
	m.lastCycle = Timing.cycle(m.timer, now)
	local style = STYLE[m.kind]
	if style then
		m.emitters = Effects.emitters(inst, style, c.folder)
	end
	if m.kind == "Clock" then
		local center = Util.vec(inst, "Center")
		m.center = center or Vector3.new(m.position.X, floorBelow(m.position, inst), m.position.Z)
		m.rx = Util.num(inst, "RadiusX", R.Clock.RadiusX)
		m.rz = Util.num(inst, "RadiusZ", R.Clock.RadiusZ)
		local beam = Util.part("ClockBeam", Vector3.new(1, 0.1, 1), CFrame.new(m.center), c.folder)
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(255, 236, 190)
		beam.Transparency = 0.72
		beam:SetAttribute("ClockBeam", true)
		beam:SetAttribute("Center", m.center)
		beam:SetAttribute("RadiusX", m.rx)
		beam:SetAttribute("RadiusZ", m.rz)
		beam:SetAttribute("Width", m.radius)
		m.beam = beam
		writeClock(m)
		placeBeam(m, now)
	end
	setRunning(m, running)
	Util.set(inst, Tags.Pulse, false)
	return m
end

-- New cycle origin (round start): every machine's first cycle begins now (+ its Offset).
local function restart(now: number)
	for _, m in machines do
		m.timer = Timing.new(m.timer.period, m.timer.active, now + m.offset)
		m.lastCycle = Timing.cycle(m.timer, now)
		writeClock(m)
	end
end

local function applyLockdown(now: number)
	for _, m in machines do
		local period = Timing.periodFor(m.basePeriod, true, m.lockdownPeriod, m.speedsUp, R.LockdownFactor)
		if period ~= m.timer.period and period > 0 then
			local active = if m.kind == "Clock" then period else math.min(m.active, period)
			m.timer = Timing.retime(m.timer, now, period, active)
			m.lastCycle = Timing.cycle(m.timer, now)
			writeClock(m)
		end
		if m.switchAtLockdown == "On" then
			setRunning(m, true)
			Effects.power(m.inst, true)
		elseif m.switchAtLockdown == "Off" then
			setRunning(m, false)
			Effects.power(m.inst, false)
		end
	end
end

function Rhythm.setup(c: Util.Context)
	Rhythm.clear()
	ctx = c
	local now = Util.now()
	for _, inst in Util.tagged(Tags.RhythmMachine, c.level) do
		local ok, result = pcall(setupMachine, c, inst, now)
		if not ok then
			warn(`[MapRuntime] RhythmMachine {inst:GetFullName()} failed: {result}`)
		elseif result then
			table.insert(machines, result)
		end
	end
end

function Rhythm.phase(c: Util.Context)
	ctx = c
	local now = Util.now()
	if (c.phase == "Heist" or c.phase == "Lockdown") and not started then
		started = true
		restart(now)
	end
	if c.lockdown and not lockdownApplied then
		lockdownApplied = true
		applyLockdown(now)
	end
	if not inRound() then
		for _, m in machines do
			m.pulse = false
			Util.set(m.inst, Tags.Pulse, false)
			if m.kind ~= "Fountain" then
				Effects.set(m.emitters, false)
			end
		end
	end
end

function Rhythm.step(now: number, dt: number)
	if not ctx then
		return
	end
	local round = inRound()
	local views: { Util.View } = if round then Util.crewViews() else {}
	local inMist: { [Player]: Util.View } = {}
	for _, m in machines do
		local pulse = round and m.running and Timing.isActive(m.timer, now)
		if round and m.running then
			local cycle = Timing.cycle(m.timer, now)
			if cycle ~= m.lastCycle then
				m.lastCycle = cycle
				onCycle(m)
			end
		end
		if pulse ~= m.pulse then
			m.pulse = pulse
			Util.set(m.inst, Tags.Pulse, pulse)
			if m.kind ~= "Fountain" and m.kind ~= "Mixer" then
				Effects.set(m.emitters, pulse)
			end
		end
		if not pulse then
			continue
		end
		if m.kind == "Wrapper" then
			for _, view in views do
				local d = view.root.Position - m.position
				if
					wraps[view.player] == nil
					and Vector3.new(d.X, 0, d.Z).Magnitude <= m.radius
					and math.abs(d.Y) <= 6
					and not handsFull(view.character)
					and Util.isFree(view.character)
				then
					wrap(view, m, now)
				end
			end
		elseif m.kind == "Mist" or m.kind == "Steam" then
			for _, view in views do
				if inMist[view.player] == nil and inZone(m, view.root.Position) then
					inMist[view.player] = view
				end
			end
		elseif m.kind == "Sprinkler" then
			stepSprinkler(m, views, now)
		elseif m.kind == "Clock" then
			stepClock(m, views, now, dt)
		end
	end
	-- Mist: a short rolling immunity while inside (it runs out on its own a moment after you leave).
	for player, view in inMist do
		Util.extendImmunity(view.character, now + 0.35)
		Util.set(view.character, Tags.InMist, true)
		misted[player] = view.character
	end
	for player, character in table.clone(misted) do
		if inMist[player] == nil then
			misted[player] = nil
			if character.Parent then
				character:SetAttribute(Tags.InMist, nil)
			end
		end
	end
	stepWraps(now)
end

-- Is a noise at `position` drowned out right now (Big Mixer thump window)?
function Rhythm.isNoiseMasked(position: Vector3): boolean
	if not inRound() then
		return false
	end
	local now = Util.now()
	for _, m in machines do
		if
			m.kind == "Mixer"
			and m.running
			and (position - m.position).Magnitude <= m.radius
			and Timing.isActive(m.timer, now)
		then
			return true
		end
	end
	return false
end

function Rhythm.clear()
	for player in table.clone(wraps) do
		unwrap(player, true)
	end
	for _, character in misted do
		if character.Parent then
			character:SetAttribute(Tags.InMist, nil)
		end
	end
	table.clear(misted)
	table.clear(slipAt)
	for _, m in machines do
		Effects.set(m.emitters, false)
		if m.inst.Parent then
			m.inst:SetAttribute(Tags.Running, nil)
			m.inst:SetAttribute(Tags.Pulse, nil)
		end
	end
	table.clear(machines)
	lockdownApplied = false
	started = false
	ctx = nil
end

return Rhythm
