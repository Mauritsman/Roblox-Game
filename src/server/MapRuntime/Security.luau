--!strict
-- Security props and LOCKDOWN set pieces (contracts §2.5, §3; beta-spec-maps §6–8):
--   LaserGrid       (+ Electronic) a crew member touching a beam = +Config.MapRuntime.Laser.Points alarm, the nearest
--                   guards come; the grid flashes and rests Cooldown s. EMP (`Disabled` = true) hides the beams and
--                   switches it off until it is re-enabled. Beams = parts named "Beam"/"Laser…", else all parts.
--   LockdownSwitch  at LOCKDOWN, by Action: "Close" (shutters/roadblocks: built open per Common/Doors.shutter with
--                   ClosedCFrame/OpenCFrame, or built closed and hidden until then), "Open" (to OpenCFrame, by
--                   OpenOffset in local space, else up by its height; then no collision; OpenSeconds), "On"/"Off"
--                   (lights, sounds, particles; attributes Active/Running). Group/Pick/Exclusive choose which act
--                   (Logic/SwitchPick, seeded). RhythmMachines and Rides handle their own switches.
--   GuardDoor       slides open (OpenCFrame / OpenOffset / along its width) while a guard is near; guards walk
--                   through anyway (GuardService collision group), so this is the visible motion.
--   CellDoor        slides to OpenCFrame and back when CaptureService reports a rescue (B does not move it).
--   MorningLight    lamps (Step 1–3) light up at round end − Config.MapRuntime.MorningLight.BeforeEnd[step]
--                   ("MORNING AUCTION IN 3:00" at step 1); Lamp-tagged ones count as lit for guards only from then.
--   RisingPlinth    a plinth carrying the main loot starts RiseHeight lower and rises with it when the heist starts.
--   Exit            LockdownOnly exits with ArrivesAt arrive from ArriveOffset (default up ArriveHeight) and dock at
--                   LOCKDOWN + ArrivesAt (RoundService decides when they can be used). On an escape the exit the
--                   crew is in leaves: DepartOffset, else a Balloon rises and a Boat sails ahead; others stay.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Motion = require(ReplicatedStorage.Shared.Logic.Motion)
local SwitchPick = require(ReplicatedStorage.Shared.Logic.SwitchPick)

local Util = require(script.Parent.Util)
local Effects = require(script.Parent.Effects)
local Optional = require(script.Parent.Parent.Lib.Optional)
local LootService = require(script.Parent.Parent.Services.LootService)

local Security = {}

local MR = Config.MapRuntime

type Saved = { transparency: number, collide: boolean, query: boolean }

type Laser = {
	inst: Instance,
	beams: { BasePart },
	colors: { [BasePart]: Color3 },
	saved: { [BasePart]: number },
	disabled: boolean,
	restUntil: number,
}

type Switch = {
	inst: Instance,
	action: string,
	acts: boolean,
	saved: { [BasePart]: Saved },
}

type Door = {
	inst: Instance,
	closed: CFrame,
	open: CFrame,
	isOpen: boolean,
	lastNear: number,
}

type Plinth = { inst: Instance, home: CFrame, height: number, loot: { string }, rising: number? }

type Mover = {
	inst: Instance,
	home: CFrame,
	offset: Vector3,
	startAt: number,
	duration: number,
	ease: (number) -> number,
	from: number, -- offset fraction at the start (1 = fully away)
	to: number,
	riders: { Model },
}

local ctx: Util.Context? = nil
local bag: Util.Bag = {}
local lasers: { Laser } = {}
local switches: { Switch } = {}
local guardDoors: { Door } = {}
local cellDoors: { Door } = {}
local morning: { { inst: Instance, step: number, saved: { [Instance]: any } } } = {}
local morningStep = 0
local plinths: { Plinth } = {}
local arrivals: { Mover } = {}
local movers: { Mover } = {}
local lockdownDone = false
local heistStarted = false
local departed = false
local laserTimer = 0
local doorTimer = 0

local function inRound(): boolean
	local c = ctx
	return c ~= nil and (c.phase == "Heist" or c.phase == "Lockdown")
end

-- Moves a part or model to a CFrame over `seconds` (TweenService; a model follows a CFrameValue).
local function tweenTo(inst: Instance, target: CFrame, seconds: number, onDone: (() -> ())?)
	local info = TweenInfo.new(math.max(0.05, seconds), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween: Tween
	if inst:IsA("BasePart") then
		tween = TweenService:Create(inst, info, { CFrame = target })
	elseif inst:IsA("Model") then
		local value = Instance.new("CFrameValue")
		value.Value = inst:GetPivot()
		value.Changed:Connect(function(cf: CFrame)
			if inst.Parent then
				inst:PivotTo(cf)
			end
		end)
		tween = TweenService:Create(value, info, { Value = target })
		tween.Completed:Connect(function()
			value:Destroy()
		end)
	else
		return
	end
	if onDone then
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				onDone()
			end
		end)
	end
	tween:Play()
end

local function setSolid(inst: Instance, solid: boolean)
	for _, part in Util.parts(inst) do
		part.CanCollide = solid
		part.CanQuery = solid
	end
end

--------------------------------------------------------------------------------------------------------------
-- Laser grids
--------------------------------------------------------------------------------------------------------------

local function setupLaser(inst: Instance): Laser
	local beams: { BasePart } = {}
	for _, part in Util.parts(inst) do
		if part.Name == "Beam" or string.sub(part.Name, 1, 5) == "Laser" then
			table.insert(beams, part)
		end
	end
	if #beams == 0 then
		beams = Util.parts(inst)
	end
	local laser: Laser =
		{ inst = inst, beams = beams, colors = {}, saved = {}, disabled = false, restUntil = 0 }
	for _, beam in beams do
		laser.colors[beam] = beam.Color
		laser.saved[beam] = beam.Transparency
		beam.CanTouch = false
	end
	local function onDisabled()
		local disabled = inst:GetAttribute(Tags.Disabled) == true
		laser.disabled = disabled
		for _, beam in beams do
			beam.Transparency = if disabled then 1 else laser.saved[beam]
		end
	end
	table.insert(bag, inst:GetAttributeChangedSignal(Tags.Disabled):Connect(onDisabled))
	onDisabled()
	return laser
end

local function trip(laser: Laser, view: Util.View, now: number)
	laser.restUntil = now + MR.Laser.Cooldown
	Util.alarm("LaserGrid", MR.Laser.Points, view.player)
	if MR.Laser.ReportGuards then
		Optional.call("GuardService", "ReportPosition", view.root.Position)
	end
	Net.broadcast("Spotted", view.player.UserId, "camera")
	Util.event("Seen", view.player)
	for _, beam in laser.beams do
		beam.Color = Color3.fromRGB(255, 255, 255)
	end
	task.delay(0.4, function()
		for _, beam in laser.beams do
			if beam.Parent then
				beam.Color = laser.colors[beam]
			end
		end
	end)
end

local function stepLasers(now: number)
	if #lasers == 0 or not inRound() then
		return
	end
	local views = Util.crewViews()
	if #views == 0 then
		return
	end
	local byCharacter: { [Model]: Util.View } = {}
	local include: { Instance } = {}
	for _, view in views do
		if
			view.character:GetAttribute(Tags.Caught) ~= true
			and view.character:GetAttribute(Tags.Captured) == nil
			and view.character:GetAttribute(Tags.Hidden) ~= true
		then
			byCharacter[view.character] = view
			table.insert(include, view.character)
		end
	end
	if #include == 0 then
		return
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	for _, laser in lasers do
		if laser.disabled or now < laser.restUntil or laser.inst.Parent == nil then
			continue
		end
		for _, beam in laser.beams do
			local hit: Util.View? = nil
			for _, part in workspace:GetPartsInPart(beam, params) do
				local model = part:FindFirstAncestorOfClass("Model")
				if model and byCharacter[model] then
					hit = byCharacter[model]
					break
				end
			end
			if hit then
				trip(laser, hit, now)
				break
			end
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- LockdownSwitch
--------------------------------------------------------------------------------------------------------------

local function memberId(inst: Instance): string
	local p = Util.positionOf(inst) or Vector3.zero
	return `{inst:GetFullName()}@{math.floor(p.X + 0.5)},{math.floor(p.Y + 0.5)},{math.floor(p.Z + 0.5)}`
end

local function hide(sw: Switch)
	for _, part in Util.parts(sw.inst) do
		sw.saved[part] =
			{ transparency = part.Transparency, collide = part.CanCollide, query = part.CanQuery }
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
	end
end

local function closeSwitch(sw: Switch)
	local inst = sw.inst
	local closed = inst:GetAttribute(Tags.ClosedCFrame)
	if typeof(closed) == "CFrame" then
		-- Built open (Common/Doors.shutter): drop into the opening, then solid.
		for _, part in Util.parts(inst) do
			part.Transparency = 0
		end
		tweenTo(inst, closed, Util.num(inst, Tags.OpenSeconds, MR.Switch.CloseSeconds), function()
			setSolid(inst, true)
		end)
	else
		for part, saved in sw.saved do
			part.Transparency = saved.transparency
			part.CanCollide = saved.collide
			part.CanQuery = saved.query
		end
	end
	Util.set(inst, Tags.DoorState, "Closed")
end

local function openSwitch(sw: Switch)
	local inst = sw.inst
	local cf = Util.cframeOf(inst)
	if not cf then
		return
	end
	local target: CFrame
	local open = inst:GetAttribute(Tags.OpenCFrame)
	local offset = Util.vec(inst, Tags.OpenOffset)
	if typeof(open) == "CFrame" then
		target = open
	elseif offset then
		target = cf * CFrame.new(offset)
	else
		local _, size = Util.box(inst)
		target = cf + Vector3.new(0, if size then size.Y + 0.2 else 9, 0)
	end
	setSolid(inst, false)
	tweenTo(inst, target, Util.num(inst, Tags.OpenSeconds, MR.Switch.OpenSeconds))
	if inst:GetAttribute(Tags.DoorState) ~= nil then
		inst:SetAttribute(Tags.DoorState, "Open")
	end
end

local function setupSwitches(c: Util.Context)
	local members: { SwitchPick.Member } = {}
	local byId: { [string]: Switch } = {}
	for _, inst in Util.tagged(Tags.LockdownSwitch, c.level) do
		if
			CollectionService:HasTag(inst, Tags.RhythmMachine) or CollectionService:HasTag(inst, Tags.Ride)
		then
			continue -- they switch themselves (MapRuntime/Rhythm, MapRuntime/Rides)
		end
		local action = Util.str(inst, Tags.Action) or "On"
		local sw: Switch = { inst = inst, action = action, acts = true, saved = {} }
		local id = memberId(inst)
		byId[id] = sw
		table.insert(members, {
			id = id,
			group = Util.str(inst, Tags.Group),
			pick = Util.optNum(inst, Tags.Pick),
			exclusive = Util.str(inst, Tags.Exclusive),
		})
		table.insert(switches, sw)
		if action == "Close" and typeof(inst:GetAttribute(Tags.ClosedCFrame)) ~= "CFrame" then
			hide(sw) -- built closed: hidden until LOCKDOWN
		elseif action == "On" then
			Util.set(inst, Tags.Active, false)
			Util.set(inst, Tags.Running, false)
			Effects.power(inst, false)
		end
	end
	local chosen = SwitchPick.choose(members, c.seed)
	for id, sw in byId do
		sw.acts = chosen[id] == true
	end
end

local function lockdownSwitches()
	for _, sw in switches do
		if not sw.acts or sw.inst.Parent == nil then
			continue
		end
		if sw.action == "Close" then
			closeSwitch(sw)
		elseif sw.action == "Open" then
			openSwitch(sw)
		elseif sw.action == "On" or sw.action == "Off" then
			local on = sw.action == "On"
			Util.set(sw.inst, Tags.Active, on)
			Util.set(sw.inst, Tags.Running, on)
			Effects.power(sw.inst, on)
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Doors (GuardDoor motion, cell door on rescue)
--------------------------------------------------------------------------------------------------------------

local function doorOf(inst: Instance): Door?
	local cf = Util.cframeOf(inst)
	if not cf then
		return nil
	end
	local closedAttr = inst:GetAttribute(Tags.ClosedCFrame)
	local closed = if typeof(closedAttr) == "CFrame" then closedAttr else cf
	local openAttr = inst:GetAttribute(Tags.OpenCFrame)
	local offset = Util.vec(inst, Tags.OpenOffset)
	local open: CFrame
	if typeof(openAttr) == "CFrame" then
		open = openAttr
	elseif offset then
		open = closed * CFrame.new(offset)
	else
		local _, size = Util.box(inst)
		open = closed * CFrame.new(0, 0, -(if size then size.Z else 4)) -- slide along its width (Doors.leaf: local Z)
	end
	return { inst = inst, closed = closed, open = open, isOpen = false, lastNear = 0 }
end

local function moveDoor(door: Door, open: boolean, seconds: number)
	if door.isOpen == open or door.inst.Parent == nil then
		return
	end
	door.isOpen = open
	tweenTo(door.inst, if open then door.open else door.closed, seconds)
end

local function stepGuardDoors(now: number)
	if #guardDoors == 0 then
		return
	end
	local positions: { Vector3 } = {}
	for _, guard in Util.guards() do
		local root = guard:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	local G = MR.GuardDoor
	for _, door in guardDoors do
		if door.inst:GetAttribute(Tags.DoorState) == "Open" then
			continue -- pried open: the Crowbar owns it
		end
		local near = false
		for _, p in positions do
			if (p - door.closed.Position).Magnitude <= G.Radius then
				near = true
				break
			end
		end
		if near then
			door.lastNear = now
			moveDoor(door, true, G.OpenSeconds)
		elseif door.isOpen and now - door.lastNear >= G.HoldSeconds then
			moveDoor(door, false, G.OpenSeconds)
		end
	end
end

local function onCapture(_player: Player, stage: string)
	if stage ~= "rescued" then
		return
	end
	local C = MR.CellDoor
	for _, door in cellDoors do
		if not door.isOpen then
			moveDoor(door, true, C.OpenSeconds)
			task.delay(C.OpenSeconds + C.HoldSeconds, function()
				moveDoor(door, false, C.OpenSeconds)
			end)
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Morning light (Tulip 5:00)
--------------------------------------------------------------------------------------------------------------

local function setLamp(entry: { inst: Instance, step: number, saved: { [Instance]: any } }, on: boolean)
	local inst = entry.inst
	for _, d in inst:GetDescendants() do
		if d:IsA("Light") then
			d.Enabled = on
		end
	end
	for _, part in Util.parts(inst) do
		local saved = entry.saved[part]
		if saved == nil then
			saved = { material = part.Material }
			entry.saved[part] = saved
		end
		if saved.material == Enum.Material.Neon then
			part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	if CollectionService:HasTag(inst, Tags.Lamp) then
		Util.set(inst, Tags.Disabled, not on)
	end
	Util.set(inst, Tags.Active, on)
end

local function stepMorning()
	if #morning == 0 or not inRound() then
		return
	end
	local endsAt = ReplicatedStorage:GetAttribute(Tags.RoundEndsAt)
	if type(endsAt) ~= "number" then
		return
	end
	local now = Util.now()
	local step = 0
	for index, before in MR.MorningLight.BeforeEnd do
		if now >= endsAt - before then
			step = index
		end
	end
	if step > morningStep then
		morningStep = step
		for _, entry in morning do
			if entry.step <= step then
				setLamp(entry, true)
			end
		end
		if step == 1 then
			Util.toast(MR.MorningLight.Toast)
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Rising plinths and moving exits
--------------------------------------------------------------------------------------------------------------

local function lootOn(inst: Instance): { string }
	local cf, size = Util.box(inst)
	local list: { string } = {}
	if not cf or not size then
		return list
	end
	for id, loot in LootService:All() do
		local handle = loot.handle
		if loot.main and loot.state == "Placed" and handle then
			local p = cf:PointToObjectSpace(handle.Position)
			if
				math.abs(p.X) <= size.X / 2 + 1
				and math.abs(p.Z) <= size.Z / 2 + 1
				and p.Y >= size.Y / 2 - 1
				and p.Y <= size.Y / 2 + 8
			then
				table.insert(list, id)
			end
		end
	end
	return list
end

local function placePlinth(plinth: Plinth, down: number)
	local offset = Vector3.new(0, -down, 0)
	Util.pivot(plinth.inst, plinth.home + offset)
	for _, id in plinth.loot do
		local loot = LootService:Get(id)
		if loot and loot.state == "Placed" and loot.handle then
			LootService:PlaceAt(loot, loot.home + offset)
		end
	end
end

local function stepPlinths(now: number)
	for _, plinth in plinths do
		local start = plinth.rising
		if start then
			local t = Motion.easeOut(Motion.progress(now, start, MR.Plinth.RiseSeconds))
			placePlinth(plinth, plinth.height * (1 - t))
			if t >= 1 then
				plinth.rising = nil
			end
		end
	end
end

-- A mover offsets a part/model (and welded riders) from its home: fraction 1 = fully at `offset`.
local function moverAt(mover: Mover, fraction: number)
	local delta = mover.offset * fraction
	Util.pivot(mover.inst, mover.home + delta)
end

local function homeOf(inst: Instance): CFrame?
	if inst:IsA("Model") or inst:IsA("BasePart") then
		return Util.cframeOf(inst)
	end
	return nil
end

local function stepMovers(now: number)
	for _, list in { arrivals, movers } do
		for _, mover in list do
			if mover.startAt > now then
				continue
			end
			local t = mover.ease(Motion.progress(now, mover.startAt, mover.duration))
			moverAt(mover, mover.from + (mover.to - mover.from) * t)
		end
	end
end

local function setupExits(c: Util.Context)
	local models = c.info and c.info.exitModels
	if type(models) ~= "table" then
		return
	end
	for _, exit in models do
		if not exit.Parent or exit:GetAttribute(Tags.LockdownOnly) ~= true then
			continue
		end
		local arrives = Util.optNum(exit, Tags.ArrivesAt)
		local home = homeOf(exit)
		if arrives and home then
			local offset = Util.vec(exit, Tags.ArriveOffset) or Vector3.new(0, MR.Exit.ArriveHeight, 0)
			local mover: Mover = {
				inst = exit,
				home = home,
				offset = offset,
				startAt = math.huge,
				duration = MR.Exit.ArriveSeconds,
				ease = Motion.easeOut,
				from = 1,
				to = 0,
				riders = {},
			}
			table.insert(arrivals, mover)
			moverAt(mover, 1)
			exit:SetAttribute("Arrived", false)
		end
	end
end

local function lockdownExits(c: Util.Context)
	local lockdownAt = c.lockdownAt or Util.now()
	for _, mover in arrivals do
		local arrives = Util.num(mover.inst, Tags.ArrivesAt, 0)
		local start = Motion.approachStart(lockdownAt, arrives, MR.Exit.ArriveSeconds)
		mover.startAt = start
		mover.duration = math.max(0.1, lockdownAt + arrives - start)
		task.delay(math.max(0, lockdownAt + arrives - Util.now()), function()
			if mover.inst.Parent then
				mover.inst:SetAttribute("Arrived", true)
			end
		end)
	end
end

local function bankZoneOf(exit: Instance): BasePart?
	for _, d in exit:GetDescendants() do
		if d:IsA("BasePart") and CollectionService:HasTag(d, Tags.BankZone) then
			return d
		end
	end
	return nil
end

-- Escape: the exit the crew sits in leaves (balloon up, boat ahead, or DepartOffset).
local function depart(c: Util.Context)
	local models = c.info and c.info.exitModels
	if type(models) ~= "table" then
		return
	end
	local now = Util.now()
	for _, exit in models do
		local zone = bankZoneOf(exit)
		local home = homeOf(exit)
		if not zone or not home or not exit.Parent then
			continue
		end
		local inside: { Util.View } = {}
		for _, view in Util.crewViews() do
			if
				view.character:GetAttribute(Tags.InVan) == true
				and Util.inBox(zone.CFrame, zone.Size, view.root.Position, 1)
			then
				table.insert(inside, view)
			end
		end
		if #inside == 0 then
			continue
		end
		local kind = Util.str(exit, Tags.ExitKind)
		local offset = Util.vec(exit, Tags.DepartOffset)
		if not offset then
			if kind == "Balloon" then
				offset = Vector3.new(0, MR.Exit.DepartHeight, 0)
			elseif kind == "Boat" then
				local look = home.LookVector * Vector3.new(1, 0, 1)
				offset = if look.Magnitude > 1e-3 then look.Unit * MR.Exit.DepartDistance else nil
			end
		end
		if not offset then
			continue
		end
		-- The crew goes along: welded to the bank zone part that moves with the exit.
		local riders: { Model } = {}
		for _, view in inside do
			local weld = Instance.new("WeldConstraint")
			weld.Name = "DepartWeld"
			weld.Part0 = zone
			weld.Part1 = view.root
			weld.Parent = view.root
			table.insert(riders, view.character)
		end
		table.insert(movers, {
			inst = exit,
			home = home,
			offset = offset,
			startAt = now + 0.3,
			duration = MR.Exit.DepartSeconds,
			ease = Motion.easeIn,
			from = 0,
			to = 1,
			riders = riders,
		})
	end
end

--------------------------------------------------------------------------------------------------------------

function Security.setup(c: Util.Context)
	Security.clear()
	ctx = c
	for _, inst in Util.tagged(Tags.LaserGrid, c.level) do
		table.insert(lasers, setupLaser(inst))
	end
	setupSwitches(c)
	for _, inst in Util.tagged(Tags.GuardDoor, c.level) do
		local door = doorOf(inst)
		if door then
			table.insert(guardDoors, door)
		end
	end
	for _, inst in Util.tagged(Tags.CellDoor, c.level) do
		if typeof(inst:GetAttribute(Tags.OpenCFrame)) == "CFrame" then
			local door = doorOf(inst)
			if door then
				table.insert(cellDoors, door)
			end
		end
	end
	local capture = Optional.get("CaptureService")
	if capture and type(capture.Changed) == "table" and type(capture.Changed.Connect) == "function" then
		table.insert(bag, capture.Changed:Connect(onCapture) :: any)
	end
	for _, inst in Util.tagged(Tags.MorningLight, c.level) do
		local entry =
			{ inst = inst, step = math.clamp(math.floor(Util.num(inst, Tags.Step, 1)), 1, 3), saved = {} }
		table.insert(morning, entry)
		setLamp(entry, false)
		if CollectionService:HasTag(inst, Tags.Lamp) then
			-- An EMP wearing off would switch it back on before its step: keep it dark until then.
			table.insert(
				bag,
				inst:GetAttributeChangedSignal(Tags.Disabled):Connect(function()
					if entry.step > morningStep and inst:GetAttribute(Tags.Disabled) ~= true then
						inst:SetAttribute(Tags.Disabled, true)
					end
				end)
			)
		end
	end
	for _, inst in Util.tagged(Tags.RisingPlinth, c.level) do
		local home = homeOf(inst)
		local loot = lootOn(inst)
		if home and #loot > 0 then
			local plinth: Plinth = {
				inst = inst,
				home = home,
				height = Util.num(inst, Tags.RiseHeight, MR.Plinth.RiseHeight),
				loot = loot,
				rising = nil,
			}
			table.insert(plinths, plinth)
			placePlinth(plinth, plinth.height)
		end
	end
	setupExits(c)
end

function Security.phase(c: Util.Context)
	ctx = c
	local now = Util.now()
	if (c.phase == "Heist" or c.phase == "Lockdown") and not heistStarted then
		heistStarted = true
		for _, plinth in plinths do
			plinth.rising = now
		end
	end
	if c.lockdown and not lockdownDone then
		lockdownDone = true
		lockdownSwitches()
		lockdownExits(c)
	end
	if c.phase == "Getaway" and not departed then
		departed = true
		depart(c)
	end
end

function Security.step(now: number, dt: number)
	if not ctx then
		return
	end
	stepPlinths(now)
	stepMovers(now)
	laserTimer += dt
	if laserTimer >= 0.1 then
		laserTimer = 0
		stepLasers(now)
		stepMorning()
	end
	doorTimer += dt
	if doorTimer >= 0.25 then
		doorTimer = 0
		stepGuardDoors(now)
	end
end

function Security.clear()
	Util.disconnect(bag)
	for _, mover in movers do
		for _, character in mover.riders do
			local root = character:FindFirstChild("HumanoidRootPart")
			local weld = root and root:FindFirstChild("DepartWeld")
			if weld then
				weld:Destroy()
			end
		end
	end
	table.clear(lasers)
	table.clear(switches)
	table.clear(guardDoors)
	table.clear(cellDoors)
	table.clear(morning)
	table.clear(plinths)
	table.clear(arrivals)
	table.clear(movers)
	morningStep = 0
	lockdownDone = false
	heistStarted = false
	departed = false
	laserTimer = 0
	doorTimer = 0
	ctx = nil
end

return Security
