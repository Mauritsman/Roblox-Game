--!strict
-- Rides (beta-spec-maps §3, §6–8; advisor rule 8: never free physics): the Praline Box Rail, the Tulip trolley train,
-- the Cheese Chute, the Bean Chute and the greenhouse vent. A `Ride` folder holds cars that the server moves along a
-- fixed path by CFrame (anchored root, everything else welded to it). Riders sit in a Seat (custom-style
-- `RidePrompt`), loot rides when it is dropped next to a halted car. Clients smooth the cars (RideController) from
-- the replicated state S0/T0/Rate/PathKey on each car, so the server only sends a few numbers per speed change.
--
-- Two modes:
--   Loop     (closed path, or Loop = true): all cars move together (a conveyor or a coupled Train). A car halts at
--            a Boarding station for Dwell s when someone waits there or the car carries riders/loot; express cars
--            (LOCKDOWN) slow to Speed through Stop stations (STOP windows: riders get `RideStop`). From LOCKDOWN the
--            ride may switch to Points.Rides[LockdownPath] where that path starts on the normal one; an open
--            lockdown path ends in a terminus where the cars queue and stay.
--   Shuttle  (open path): one car waits at the start; boarding or loading starts it, it runs to the end, riders
--            hop off and loot rolls out there (loot sent alone rumbles: noise), then it returns empty. TwoWay
--            shuttles can be boarded at both ends.
-- Riders hop off by jumping, only at a station window (loops) or while the shuttle stands; mid-ride jumps re-seat
-- them. Getting caught (Caught/Captured), hiding or freezing takes them off at once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)
local RidePath = require(ReplicatedStorage.Shared.Logic.RidePath)

local Util = require(script.Parent.Util)
local Optional = require(script.Parent.Parent.Lib.Optional)
local Services = script.Parent.Parent.Services
local LootService = require(Services.LootService)

local Rides = {}

local RC = Config.MapRuntime.Ride

type Station = {
	s: number,
	pathKey: string,
	boarding: boolean,
	stop: boolean,
	lockdownOnly: boolean,
	position: Vector3,
}

type Rider = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	seat: Seat,
	car: Car,
	resits: number,
	bag: Util.Bag,
}

type Cargo = { id: string, seat: Seat }

type Car = {
	ride: Ride,
	model: Instance,
	root: BasePart,
	seats: { Seat },
	height: number,
	index: number,
	pathKey: string,
	s0: number,
	t0: number,
	rate: number,
	lastS: number,
	parked: boolean,
	prompt: ProximityPrompt?,
	riders: { [Seat]: Rider },
	cargo: { Cargo },
	atStation: Station?,
	inStop: boolean,
	-- shuttle
	state: string, -- "Home" | "Going" | "Arrived" | "Returning"
	atEnd: boolean,
	departAt: number?,
	arrivedAt: number,
	carriedRider: boolean,
}

type Ride = {
	folder: Instance,
	id: string,
	name: string,
	paths: { [string]: RidePath.Path },
	shuttle: boolean,
	train: boolean,
	speed: number,
	lockdownSpeed: number,
	seats: number,
	emptyHands: boolean,
	twoWay: boolean,
	lockdownOnly: boolean,
	stations: { Station },
	cars: { Car },
	dwellUntil: number,
	halted: { [Station]: number },
	switchS: number?,
	spacing: number,
	trainHalf: number,
	ends: { Vector3 }, -- shuttle: positions of s = 0 and s = length
}

local ctx: Util.Context? = nil
local rides: { Ride } = {}
local riders: { [Player]: Rider } = {}
local bag: Util.Bag = {}
local created: { Instance } = {} -- default cars made by the runtime (removed on clear)

--------------------------------------------------------------------------------------------------------------
-- Paths and placement
--------------------------------------------------------------------------------------------------------------

local function toVecs(list: { any }): { RidePath.Vec }
	local out: { RidePath.Vec } = {}
	for _, p in list do
		if typeof(p) == "Vector3" then
			table.insert(out, { x = p.X, y = p.Y, z = p.Z })
		end
	end
	return out
end

local function v3(p: RidePath.Vec): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

-- Points.Rides[key] from the heist definition, or nil.
local function pointsFor(c: Util.Context, key: string): { any }?
	local points = c.info and c.info.points
	local list = points and type(points.Rides) == "table" and points.Rides[key]
	return if type(list) == "table" and #list >= 2 then list else nil
end

-- Fallback: Attachments (or parts) named "Point" inside the ride, ordered by their Order attribute, then name.
local function pointsInFolder(folder: Instance): { Vector3 }?
	local found: { Instance } = {}
	for _, d in folder:GetDescendants() do
		if d.Name == "Point" and (d:IsA("Attachment") or d:IsA("BasePart")) then
			table.insert(found, d)
		end
	end
	if #found < 2 then
		return nil
	end
	table.sort(found, function(a, b)
		local oa, ob = Util.num(a, "Order", 0), Util.num(b, "Order", 0)
		if oa ~= ob then
			return oa < ob
		end
		return a:GetFullName() < b:GetFullName()
	end)
	local list = {}
	for _, inst in found do
		table.insert(list, Util.positionOf(inst) :: Vector3)
	end
	return list
end

local function sOf(car: Car, now: number): number
	return RidePath.distanceAt(car.s0, car.rate, car.t0, now)
end

local function writeState(car: Car)
	local model = car.model
	model:SetAttribute("S0", car.s0)
	model:SetAttribute("T0", car.t0)
	model:SetAttribute("Rate", car.rate)
	model:SetAttribute("PathKey", car.pathKey)
end

-- New linear segment for a car: from distance `s` (default: where it is now) at `rate`.
local function anchor(car: Car, now: number, rate: number, s: number?)
	local at = s or sOf(car, now)
	local path = car.ride.paths[car.pathKey]
	if path and path.loop then
		at = RidePath.wrap(path, at)
	end
	car.s0, car.t0, car.rate, car.lastS = at, now, rate, at
	writeState(car)
end

local function carCFrame(car: Car, s: number): CFrame
	local path = car.ride.paths[car.pathKey]
	local p = RidePath.pointAt(path, s)
	local d = RidePath.heading(path, s, RC.CornerBlend)
	local dir = Vector3.new(d.x, d.y, d.z)
	if math.abs(dir.Y) > 0.9 then
		dir = car.root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if dir.Magnitude < 1e-3 then
			dir = Vector3.new(0, 0, -1)
		end
	end
	local origin = v3(p) + Vector3.new(0, car.height, 0)
	return CFrame.lookAt(origin, origin + dir.Unit)
end

-- Distance between two points on a path in either direction.
local function gap(path: RidePath.Path, a: number, b: number): number
	if path.loop then
		return math.min(RidePath.forward(path, a, b), RidePath.forward(path, b, a))
	end
	return math.abs(a - b)
end

--------------------------------------------------------------------------------------------------------------
-- Cars, seats, prompts
--------------------------------------------------------------------------------------------------------------

local function weldTo(root: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "RideWeld"
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function makeSeat(root: BasePart, index: number, count: number, parent: Instance): Seat
	local seat = Instance.new("Seat")
	seat.Name = `Seat{index}`
	seat.Size = Vector3.new(2, 1, 2)
	local across = (index - (count + 1) / 2) * 2.4
	seat.CFrame = root.CFrame * CFrame.new(across, root.Size.Y / 2 + 0.5, 0)
	seat.Color = Color3.fromRGB(150, 30, 40)
	seat.Material = Enum.Material.Fabric
	seat.Parent = parent
	return seat
end

local function prepareSeat(seat: Seat, root: BasePart)
	seat.Anchored = false
	seat.CanCollide = false
	seat.CanTouch = false -- no sitting by walking into it: the RidePrompt seats you
	seat.Massless = true
	if not seat:FindFirstChild("RideWeld") then
		weldTo(root, seat)
	end
end

-- A gold gift-box car built from parts (the map may give its own `Car` models instead).
local function defaultCar(ride: Ride, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Car"
	local root = Util.part("Body", Vector3.new(RC.CarWidth, RC.CarHeight, RC.CarDepth), CFrame.new(), model)
	root.Color = Color3.fromRGB(226, 178, 52)
	root.Material = Enum.Material.SmoothPlastic
	root.CanQuery = true -- moving cover: blocks guard vision
	local bow = Util.part(
		"Bow",
		Vector3.new(RC.CarWidth + 0.1, 0.4, 0.6),
		root.CFrame * CFrame.new(0, RC.CarHeight / 2 - 0.2, 0),
		model
	)
	bow.Color = Color3.fromRGB(200, 40, 50)
	bow.Anchored = false
	weldTo(root, bow)
	model.PrimaryPart = root
	model.Parent = parent
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for i = 1, ride.seats do
		makeSeat(root, i, ride.seats, model)
	end
	return model
end

-- Turns a map `Car` (Model or BasePart) into a ride car: anchored root, every other part welded to it.
local function adoptCar(inst: Instance, seats: number): (BasePart?, { Seat })
	local root: BasePart? = nil
	if inst:IsA("BasePart") then
		root = inst
	elseif inst:IsA("Model") then
		root = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
		inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	if not root then
		return nil, {}
	end
	local r = root :: BasePart
	r.Anchored = true
	r.CanCollide = false
	for _, part in Util.parts(inst) do
		if part ~= r and not part:IsA("Seat") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			if not part:FindFirstChild("RideWeld") then
				weldTo(r, part)
			end
		end
	end
	local list: { Seat } = {}
	for _, d in inst:GetDescendants() do
		if d:IsA("Seat") then
			table.insert(list, d)
		end
	end
	for i = #list + 1, seats do
		table.insert(list, makeSeat(r, i, seats, inst))
	end
	return r, list
end

local function freeSeat(car: Car): Seat?
	for _, seat in car.seats do
		if car.riders[seat] == nil and seat.Occupant == nil then
			local taken = false
			for _, cargo in car.cargo do
				if cargo.seat == seat then
					taken = true
					break
				end
			end
			if not taken then
				return seat
			end
		end
	end
	return nil
end

local function occupied(car: Car): boolean
	return next(car.riders) ~= nil or #car.cargo > 0
end

local function riderCount(car: Car): number
	local n = 0
	for _ in car.riders do
		n += 1
	end
	return n
end

--------------------------------------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------------------------------------

local function inRound(): boolean
	local c = ctx
	return c ~= nil and (c.phase == "Heist" or c.phase == "Lockdown")
end

local function rideActive(ride: Ride): boolean
	local c = ctx
	return inRound() and c ~= nil and (not ride.lockdownOnly or c.lockdown)
end

local function stationActive(station: Station): boolean
	local c = ctx
	return c ~= nil and (not station.lockdownOnly or c.lockdown)
end

local function speedOf(ride: Ride): number
	local c = ctx
	return if c and c.lockdown then ride.lockdownSpeed else ride.speed
end

-- May a rider of this car get off now?
local function canLeave(car: Car): boolean
	if car.ride.shuttle then
		return car.state == "Home" or car.state == "Arrived"
	end
	return car.atStation ~= nil or not rideActive(car.ride)
end

--------------------------------------------------------------------------------------------------------------
-- Riders
--------------------------------------------------------------------------------------------------------------

local function releaseSeat(seat: Seat, humanoid: Humanoid?)
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	if humanoid and humanoid.Parent then
		humanoid.Sit = false
	end
end

-- Takes a rider off. `to` = where to put the character (shuttle ends); nil = stays where it is.
local function dismount(rider: Rider, to: CFrame?)
	local car = rider.car
	if riders[rider.player] == rider then
		riders[rider.player] = nil
	end
	if car.riders[rider.seat] == rider then
		car.riders[rider.seat] = nil
	end
	Util.disconnect(rider.bag)
	local character = rider.character
	if character.Parent then
		character:SetAttribute(Tags.Riding, nil)
		character:SetAttribute(Tags.RideStop, nil)
	end
	if rider.seat.Occupant == rider.humanoid then
		releaseSeat(rider.seat, rider.humanoid)
	end
	if to and character.Parent then
		task.defer(function()
			if character.Parent and rider.player.Character == character then
				character:PivotTo(to)
			end
		end)
	end
end

local function validRider(rider: Rider): boolean
	return rider.character.Parent ~= nil
		and rider.player.Character == rider.character
		and rider.humanoid.Health > 0
		and Util.isFree(rider.character)
end

local function onSeatChanged(car: Car, seat: Seat)
	local rider = car.riders[seat]
	if not rider then
		return
	end
	local occupant = seat.Occupant
	if occupant == rider.humanoid then
		rider.resits = 0
		return
	elseif occupant ~= nil then
		return
	end
	-- The rider jumped out.
	if canLeave(car) or not validRider(rider) or rider.resits >= 5 then
		dismount(rider, nil)
		return
	end
	rider.resits += 1
	task.defer(function()
		if car.riders[seat] == rider and seat.Occupant == nil and validRider(rider) then
			seat:Sit(rider.humanoid)
		end
	end)
end

local function board(car: Car, player: Player)
	local ride = car.ride
	if not rideActive(ride) or riders[player] or player:GetAttribute(Tags.Activity) ~= "Crew" then
		return
	end
	local view = Util.view(player)
	if not view or not Util.isFree(view.character) then
		return
	end
	if ride.shuttle then
		if car.state ~= "Home" then
			return
		end
	elseif car.atStation == nil then
		Net.send(player, "Toast", "Wait for the station!")
		return
	end
	if ride.emptyHands then
		local ok, full = Optional.call("CarryService", "HandsFull", player)
		if ok and full == true then
			Net.send(player, "Toast", "Hands full!")
			return
		end
	end
	local seat = freeSeat(car)
	if not seat then
		Net.send(player, "Toast", "Taken!")
		return
	end
	local rider: Rider = {
		player = player,
		character = view.character,
		humanoid = view.humanoid,
		seat = seat,
		car = car,
		resits = 0,
		bag = {},
	}
	riders[player] = rider
	car.riders[seat] = rider
	view.character:SetAttribute(Tags.Riding, ride.id)
	for _, name in { Tags.Caught, Tags.Captured, Tags.Hidden, Tags.Frozen } do
		table.insert(
			rider.bag,
			view.character:GetAttributeChangedSignal(name):Connect(function()
				local value = view.character:GetAttribute(name)
				if value ~= nil and value ~= false and riders[player] == rider then
					dismount(rider, nil)
				end
			end)
		)
	end
	table.insert(
		rider.bag,
		view.humanoid.Died:Connect(function()
			if riders[player] == rider then
				dismount(rider, nil)
			end
		end)
	)
	table.insert(
		rider.bag,
		view.character.AncestryChanged:Connect(function()
			if not view.character:IsDescendantOf(workspace) and riders[player] == rider then
				dismount(rider, nil)
			end
		end)
	)
	seat:Sit(view.humanoid)
	Util.event("RideTaken", player, { ride = ride.id })
end

--------------------------------------------------------------------------------------------------------------
-- Cargo (loot riding)
--------------------------------------------------------------------------------------------------------------

local function cargoValid(car: Car, cargo: Cargo): boolean
	local loot = LootService:Get(cargo.id)
	local handle = loot and loot.handle
	if not loot or loot.state ~= "Placed" or not handle then
		return false
	end
	local weld = handle:FindFirstChild("CarryWeld")
	return weld ~= nil and weld:IsA("WeldConstraint") and weld.Part0 == car.root
end

local function load(car: Car, loot: LootService.Loot)
	local seat = freeSeat(car)
	local handle = loot.handle
	if not seat or not handle then
		return
	end
	local top = seat.CFrame * CFrame.new(0, seat.Size.Y / 2 + handle.Size.Y / 2, 0)
	LootService:WeldTo(loot, car.root, car.root.CFrame:ToObjectSpace(top))
	LootService:SetState(loot, "Placed")
	table.insert(car.cargo, { id = loot.id, seat = seat })
end

local function autoLoad(car: Car)
	if not freeSeat(car) then
		return
	end
	local here = car.root.Position
	for _, loot in LootService:All() do
		local handle = loot.handle
		if loot.state == "Dropped" and loot.session == "Crew" and handle then
			local offset = handle.Position - here
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= RC.LoadRadius and math.abs(offset.Y) <= 6 then
				load(car, loot)
				if not freeSeat(car) then
					return
				end
			end
		end
	end
end

-- Shuttle end: loot rolls out onto the floor there.
local function unload(car: Car, at: Vector3, forward: Vector3)
	for index, cargo in car.cargo do
		local loot = LootService:Get(cargo.id)
		local handle = loot and loot.handle
		if loot and handle and cargoValid(car, cargo) then
			local spot = at + forward * (2 + index * 1.5)
			LootService:PlaceAt(
				loot,
				CFrame.lookAt(spot, spot + forward) + Vector3.new(0, handle.Size.Y / 2, 0)
			)
			LootService:MarkDropped(loot, loot.lastHolderId)
			LootService:SendSession(loot.session, "LootDropped", loot.lastHolderId or 0, loot.name, spot)
			if not car.carriedRider then
				Util.hearNoise(spot, RC.RumbleRadius, RC.RumbleSearch, "rumble")
			end
		end
	end
	table.clear(car.cargo)
end

--------------------------------------------------------------------------------------------------------------
-- Stepping
--------------------------------------------------------------------------------------------------------------

local function wantsHalt(ride: Ride, station: Station, cars: { Car }, now: number): boolean
	local last = ride.halted[station]
	local dwell = if ctx and ctx.lockdown then RC.LockdownDwell else RC.Dwell
	if last and now - last < dwell + 2 then
		return false
	end
	for _, car in cars do
		if occupied(car) then
			return true
		end
	end
	for _, view in Util.crewViews() do
		if
			riders[view.player] == nil
			and Util.isFree(view.character)
			and (view.root.Position - station.position).Magnitude <= RC.WaitRadius
		then
			return true
		end
	end
	return false
end

-- The station window a car is in (boarding or stop), using the train length for coupled cars.
local function stationsNear(ride: Ride, car: Car, s: number): (Station?, boolean)
	local path = ride.paths[car.pathKey]
	local extra = if ride.train then ride.trainHalf else 0
	local boarding: Station? = nil
	local stop = false
	for _, station in ride.stations do
		if station.pathKey == car.pathKey and stationActive(station) then
			local d = gap(path, RidePath.wrap(path, s), station.s)
			if station.boarding and d <= RC.StationWindow + extra then
				boarding = station
			end
			if station.stop and d <= RC.StopWindow + extra then
				stop = true
			end
		end
	end
	return boarding, stop
end

local function stepLoop(ride: Ride, now: number)
	local halted = now < ride.dwellUntil
	local base = speedOf(ride)
	local desired = if halted then 0 else base
	if not halted and base > ride.speed then
		for _, car in ride.cars do
			if not car.parked then
				local _, stop = stationsNear(ride, car, sOf(car, now))
				if stop then
					desired = ride.speed
					break
				end
			end
		end
	end
	for _, car in ride.cars do
		if not car.parked and car.rate ~= desired then
			anchor(car, now, desired)
		end
	end
	if desired <= 0 then
		return
	end
	local c = ctx :: Util.Context
	local normal = ride.paths.Normal
	local lockdownPath = ride.paths.Lockdown
	for _, car in ride.cars do
		if car.parked then
			continue
		end
		local s = sOf(car, now)
		local travel = s - car.lastS
		if travel <= 0 then
			continue
		end
		-- LOCKDOWN: switch onto the lockdown path where it leaves the normal one.
		if
			c.lockdown
			and lockdownPath
			and ride.switchS
			and car.pathKey == "Normal"
			and RidePath.crossed(normal, car.lastS, travel, ride.switchS :: number)
		then
			local over = RidePath.forward(normal, ride.switchS :: number, RidePath.wrap(normal, s))
			car.pathKey = "Lockdown"
			anchor(car, now, car.rate, over)
			continue
		end
		local path = ride.paths[car.pathKey]
		if not path.loop then
			local parkedAhead = 0
			for _, other in ride.cars do
				if other.parked and other.pathKey == car.pathKey then
					parkedAhead += 1
				end
			end
			local limit = math.max(0, path.length - parkedAhead * ride.spacing)
			if s >= limit then
				anchor(car, now, 0, limit)
				car.parked = true
				continue
			end
		end
		-- Halts at boarding stations (the front car of a train decides).
		if not halted and (not ride.train or car.index == 1) then
			for _, station in ride.stations do
				if station.boarding and station.pathKey == car.pathKey and stationActive(station) then
					local mark = station.s + (if ride.train then ride.trainHalf else 0)
					if path.loop then
						mark = RidePath.wrap(path, mark)
					end
					local group = if ride.train then ride.cars else { car }
					if
						RidePath.crossed(path, car.lastS, travel, mark)
						and wantsHalt(ride, station, group, now)
					then
						local over = if path.loop
							then RidePath.forward(path, mark, RidePath.wrap(path, s))
							else s - mark
						ride.dwellUntil = now + (if c.lockdown then RC.LockdownDwell else RC.Dwell)
						ride.halted[station] = now
						for _, other in ride.cars do
							if not other.parked then
								anchor(other, now, 0, sOf(other, now) - over)
							end
						end
						halted = true
						break
					end
				end
			end
			if halted then
				break
			end
		end
	end
	for _, car in ride.cars do
		car.lastS = sOf(car, now)
	end
end

local function endFrame(ride: Ride, car: Car, s: number): (Vector3, Vector3)
	local path = ride.paths.Normal
	local p, d = RidePath.pointAt(path, s)
	local forward = Vector3.new(d.x, 0, d.z)
	if s <= 0 then
		forward = -forward
	end
	if forward.Magnitude < 1e-3 then
		forward = car.root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	if forward.Magnitude < 1e-3 then
		forward = Vector3.new(0, 0, -1)
	end
	return v3(p), forward.Unit
end

local function arrive(ride: Ride, car: Car, endS: number)
	local at, forward = endFrame(ride, car, endS)
	local exit =
		CFrame.lookAt(at + forward * 3 + Vector3.new(0, 3, 0), at + forward * 4 + Vector3.new(0, 3, 0))
	for _, rider in car.riders do
		dismount(rider, exit)
	end
	unload(car, at, forward)
end

local function crewNear(position: Vector3): boolean
	for _, view in Util.crewViews() do
		if riders[view.player] == nil and (view.root.Position - position).Magnitude <= RC.WaitRadius then
			return true
		end
	end
	return false
end

local function stepShuttle(ride: Ride, now: number)
	local car = ride.cars[1]
	if not car then
		return
	end
	local path = ride.paths.Normal
	local s = sOf(car, now)
	local speed = speedOf(ride)
	if car.state == "Home" then
		if occupied(car) then
			car.departAt = car.departAt or now + RC.ShuttleDepart
			if now >= (car.departAt :: number) then
				car.departAt = nil
				car.carriedRider = next(car.riders) ~= nil
				anchor(car, now, if car.atEnd then -speed else speed)
				car.state = "Going"
			end
		else
			car.departAt = nil
			-- A two-way shuttle goes to fetch someone waiting at the other end.
			if ride.twoWay then
				local here = ride.ends[if car.atEnd then 2 else 1]
				local there = ride.ends[if car.atEnd then 1 else 2]
				if crewNear(there) and not crewNear(here) then
					car.carriedRider = false
					anchor(car, now, if car.atEnd then -speed else speed)
					car.state = "Going"
				end
			end
		end
	elseif car.state == "Going" then
		if (car.rate > 0 and s >= path.length) or (car.rate < 0 and s <= 0) then
			local endS = if car.rate > 0 then path.length else 0
			anchor(car, now, 0, endS)
			car.atEnd = endS > 0
			car.arrivedAt = now
			arrive(ride, car, endS)
			car.state = if ride.twoWay then "Home" else "Arrived"
		end
	elseif car.state == "Arrived" then
		if now - car.arrivedAt >= RC.ShuttleReturn and riderCount(car) == 0 then
			anchor(car, now, -ride.speed * RC.ReturnFactor)
			car.state = "Returning"
		end
	elseif car.state == "Returning" then
		if s <= 0 then
			anchor(car, now, 0, 0)
			car.atEnd = false
			car.state = "Home"
		end
	end
end

local function refreshCar(ride: Ride, car: Car, now: number)
	local s = sOf(car, now)
	car.root.CFrame = carCFrame(car, s)
	if ride.shuttle then
		car.atStation = nil
		car.inStop = false
	else
		car.atStation, car.inStop = stationsNear(ride, car, s)
	end
	for _, rider in car.riders do
		if rider.character.Parent then
			Util.set(rider.character, Tags.RideStop, if car.inStop then true else nil)
		end
	end
	for index = #car.cargo, 1, -1 do
		if not cargoValid(car, car.cargo[index]) then
			table.remove(car.cargo, index)
		end
	end
	local active = rideActive(ride)
	local boardable = if ride.shuttle then car.state == "Home" else car.atStation ~= nil
	local prompt = car.prompt
	if prompt then
		local enabled = active and boardable and freeSeat(car) ~= nil
		if prompt.Enabled ~= enabled then
			prompt.Enabled = enabled
		end
	end
	if active and boardable and (ride.shuttle or car.rate == 0) then
		autoLoad(car)
	end
end

--------------------------------------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------------------------------------

local function makePrompt(car: Car)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RidePrompt"
	prompt.ActionText = "Ride"
	prompt.ObjectText = car.ride.name
	prompt.HoldDuration = 0.3
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = RC.PromptRange
	prompt.Enabled = false
	prompt:SetAttribute("ContextIcon", "ride")
	prompt.Parent = car.root
	prompt.Triggered:Connect(function(player: Player)
		board(car, player)
	end)
	car.prompt = prompt
end

local function newCar(
	ride: Ride,
	model: Instance,
	root: BasePart,
	seats: { Seat },
	s: number,
	index: number
): Car
	local car: Car = {
		ride = ride,
		model = model,
		root = root,
		seats = seats,
		height = RC.CarHeight / 2,
		index = index,
		pathKey = "Normal",
		s0 = s,
		t0 = Util.now(),
		rate = 0,
		lastS = s,
		parked = false,
		prompt = nil,
		riders = {},
		cargo = {},
		atStation = nil,
		inStop = false,
		state = "Home",
		atEnd = false,
		departAt = nil,
		arrivedAt = 0,
		carriedRider = false,
	}
	model:SetAttribute(Tags.RideCar, true)
	for _, seat in seats do
		prepareSeat(seat, root)
		bag[#bag + 1] = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			onSeatChanged(car, seat)
		end)
	end
	return car
end

local function setupRide(c: Util.Context, folder: Instance): Ride?
	local id = Util.str(folder, Tags.RideId) or folder.Name
	local raw = pointsFor(c, id) or pointsInFolder(folder)
	if not raw then
		warn(`[MapRuntime] ride {id} has no path (Points.Rides["{id}"]): skipped`)
		return nil
	end
	local loopAttr = folder:GetAttribute(Tags.Loop)
	local normal = RidePath.build(toVecs(raw), if type(loopAttr) == "boolean" then loopAttr else nil)
	if normal.length <= 0 then
		warn(`[MapRuntime] ride {id} has a zero-length path: skipped`)
		return nil
	end
	local paths: { [string]: RidePath.Path } = { Normal = normal }
	local lockdownKey = Util.str(folder, Tags.LockdownPath) or (id .. "Lockdown")
	local lockdownRaw = pointsFor(c, lockdownKey)
	local shuttle = not normal.loop
	if lockdownRaw and not shuttle then
		paths.Lockdown = RidePath.build(toVecs(lockdownRaw))
	end
	local speed = math.max(0.5, Util.num(folder, Tags.Speed, RC.Speed))
	local ride: Ride = {
		folder = folder,
		id = id,
		name = Util.str(folder, "DisplayName") or folder.Name,
		paths = paths,
		shuttle = shuttle,
		train = Util.bool(folder, Tags.Train, false),
		speed = speed,
		lockdownSpeed = math.max(0.5, Util.num(folder, Tags.LockdownSpeed, speed * RC.LockdownFactor)),
		seats = math.max(1, math.floor(Util.num(folder, Tags.Seats, RC.Seats))),
		emptyHands = Util.bool(folder, Tags.EmptyHands, false),
		twoWay = Util.bool(folder, Tags.TwoWay, false),
		lockdownOnly = Util.bool(folder, Tags.LockdownOnly, false),
		stations = {},
		cars = {},
		dwellUntil = 0,
		halted = {},
		switchS = nil,
		spacing = RC.CarDepth + RC.TrainGap,
		trainHalf = 0,
		ends = {},
	}
	local first = RidePath.pointAt(normal, 0)
	local last = RidePath.pointAt(normal, normal.length)
	ride.ends = { v3(first), v3(last) }

	-- Replicated path data for client smoothing (RideController).
	folder:SetAttribute("Path_Normal", RidePath.serialize(normal.points))
	folder:SetAttribute("Loop_Normal", normal.loop)
	if paths.Lockdown then
		folder:SetAttribute("Path_Lockdown", RidePath.serialize(paths.Lockdown.points))
		folder:SetAttribute("Loop_Lockdown", paths.Lockdown.loop)
		ride.switchS = (RidePath.project(normal, paths.Lockdown.points[1]))
	end
	folder:SetAttribute("CornerBlend", RC.CornerBlend)

	-- Stations: Attachments (or parts) named "Station".
	for _, d in folder:GetDescendants() do
		if d.Name == "Station" and (d:IsA("Attachment") or d:IsA("BasePart")) then
			local position = Util.positionOf(d) :: Vector3
			local p = { x = position.X, y = position.Y, z = position.Z }
			local s, distance = RidePath.project(normal, p)
			local key = "Normal"
			if paths.Lockdown then
				local s2, d2 = RidePath.project(paths.Lockdown, p)
				if d2 < distance then
					s, distance, key = s2, d2, "Lockdown"
				end
			end
			if distance > 10 then
				warn(`[MapRuntime] ride {id}: a Station is {math.floor(distance)} studs from the path`)
			end
			table.insert(ride.stations, {
				s = s,
				pathKey = key,
				boarding = Util.bool(d, Tags.Boarding, true),
				stop = Util.bool(d, Tags.Stop, false),
				lockdownOnly = Util.bool(d, Tags.LockdownOnly, false),
				position = position,
			})
		end
	end

	-- Cars: the map's `Car` models, else default ones.
	local mapCars: { Instance } = {}
	for _, d in folder:GetDescendants() do
		if d.Name == "Car" and (d:IsA("Model") or d:IsA("BasePart")) then
			local parent = d.Parent
			local nested = false
			while parent and parent ~= folder do
				if parent.Name == "Car" then
					nested = true
					break
				end
				parent = parent.Parent
			end
			if not nested then
				table.insert(mapCars, d)
			end
		end
	end
	if shuttle and #mapCars > 1 then
		mapCars = { mapCars[1] }
	end
	local now = Util.now()
	if #mapCars > 0 then
		local placed = {}
		for _, inst in mapCars do
			local root, seats = adoptCar(inst, ride.seats)
			if root then
				local pos = root.Position
				local s = RidePath.project(normal, { x = pos.X, y = pos.Y, z = pos.Z })
				table.insert(placed, { inst = inst, root = root, seats = seats, s = s })
			end
		end
		table.sort(placed, function(a, b)
			return a.s > b.s
		end)
		for index, entry in placed do
			local car = newCar(ride, entry.inst, entry.root, entry.seats, entry.s, index)
			car.height = entry.root.Position.Y - RidePath.pointAt(normal, entry.s).y
			table.insert(ride.cars, car)
		end
		if ride.train and #placed > 1 then
			ride.spacing = gap(normal, placed[1].s, placed[2].s)
		end
	else
		local count = if shuttle then 1 else math.max(1, math.floor(Util.num(folder, Tags.Cars, RC.Cars)))
		local spacing = if ride.train then ride.spacing else normal.length / count
		for index = 1, count do
			-- Inside the ride folder, so clients find the cars there (RideController).
			local model = defaultCar(ride, folder)
			model.Name = `{id}Car{index}`
			table.insert(created, model)
			local seats: { Seat } = {}
			for _, child in model:GetChildren() do
				if child:IsA("Seat") then
					table.insert(seats, child)
				end
			end
			local s = if shuttle then 0 else RidePath.wrap(normal, -(index - 1) * spacing)
			table.insert(ride.cars, newCar(ride, model, model.PrimaryPart :: BasePart, seats, s, index))
		end
	end
	if ride.train then
		ride.trainHalf = (#ride.cars - 1) * ride.spacing / 2
	end
	for _, car in ride.cars do
		car.model:SetAttribute("Height", car.height)
		anchor(car, now, 0, car.s0)
		car.root.CFrame = carCFrame(car, car.s0)
		makePrompt(car)
	end
	return ride
end

function Rides.setup(c: Util.Context)
	Rides.clear()
	ctx = c
	for _, folder in Util.tagged(Tags.Ride, c.level) do
		local ok, result = pcall(setupRide, c, folder)
		if not ok then
			warn(`[MapRuntime] ride {folder:GetFullName()} failed: {result}`)
		elseif result then
			table.insert(rides, result)
		end
	end
	bag[#bag + 1] = Players.PlayerRemoving:Connect(function(player)
		local rider = riders[player]
		if rider then
			dismount(rider, nil)
		end
	end)
end

function Rides.step(now: number)
	if not ctx then
		return
	end
	for _, ride in rides do
		if rideActive(ride) then
			if ride.shuttle then
				stepShuttle(ride, now)
			else
				stepLoop(ride, now)
			end
		else
			for _, car in ride.cars do
				if car.rate ~= 0 then
					anchor(car, now, 0)
				end
			end
		end
		for _, car in ride.cars do
			refreshCar(ride, car, now)
		end
	end
end

-- LOCKDOWN and phase changes: rides re-time at once (express speed, stations opening).
function Rides.phase(c: Util.Context)
	ctx = c
	if c.phase ~= "Heist" and c.phase ~= "Lockdown" then
		local now = Util.now()
		for _, ride in rides do
			for _, car in ride.cars do
				if car.rate ~= 0 then
					anchor(car, now, 0)
				end
			end
		end
	end
end

-- The ride this player sits on (RideId), or nil.
function Rides.rideOf(player: Player): string?
	local rider = riders[player]
	return if rider then rider.car.ride.id else nil
end

function Rides.clear()
	for _, rider in table.clone(riders) do
		dismount(rider, nil)
	end
	table.clear(riders)
	Util.disconnect(bag)
	for _, ride in rides do
		for _, car in ride.cars do
			if car.prompt then
				car.prompt:Destroy()
			end
		end
	end
	table.clear(rides)
	for _, model in created do
		model:Destroy()
	end
	table.clear(created)
	ctx = nil
end

return Rides
