--!strict
-- Ride geometry for every heist (docs/contracts.md §2.5 "Ride"): chutes, rails and trolley trains whose seats the
-- server moves along a fixed path (never free physics). This module builds the track, the cars and the stations
-- and returns the path for `Points.Rides[RideId]`; mechanics package D moves the cars.
--
-- Contract: a Folder tagged `Ride` with attributes RideId, Seats (riders or loot per car), Speed, LockdownSpeed?.
-- Stations: an Attachment named `Station` (attributes Boarding, Stop, LockdownOnly?) under each station's part
-- (`Station<n>`, a visible platform or an invisible anchor). Cars: Models `Car<n>` (PrimaryPart `Base`, a `Seat` part
-- with Attachment `SeatPoint`), all anchored and non-colliding, parked at the first station; move them with PivotTo.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Builder = require(script.Parent.Builder)

local C = Builder.Colors

local Rides = {}

export type TrackKind = "Trough" | "Rail" | "None"

export type StationSpec = {
	at: Vector3, -- the stop point on the path (floor of the car)
	boarding: boolean, -- riders/loot can get on here
	stop: boolean?, -- STOP window: guards here can grab riders
	lockdownOnly: boolean?,
	platform: boolean?, -- draw a platform pad (default false: invisible anchor)
}

export type RideSpec = {
	id: string,
	path: { Vector3 }, -- car floor positions, in order
	seats: number,
	speed: number,
	lockdownSpeed: number?,
	cars: number?, -- default 1
	carSize: Vector3?, -- default 3 × 0.6 × 3.4
	carColor: Color3?,
	stations: { StationSpec },
	track: TrackKind?, -- default "Trough"
	trackWidth: number?, -- default 4
	trackColor: Color3?,
	supports: { number }?, -- path indices whose point gets a support post down to `floorY`
	floorY: number?,
	attrs: { [string]: any }?, -- extra ride data (e.g. LootDelay, ExitNoise)
}

local function segment(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	kind: TrackKind,
	width: number,
	color: Color3
)
	local length = (to - from).Magnitude
	if length < 0.05 or kind == "None" then
		return
	end
	-- The track runs just under the car floor; local Z along the segment.
	local cf = CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, -0.35, 0)
	if kind == "Rail" then
		Builder.block(
			parent,
			"Rail",
			Vector3.new(0.6, 0.5, length),
			cf,
			color,
			{ material = Enum.Material.Metal }
		)
		return
	end
	Builder.block(parent, "TroughBed", Vector3.new(width, 0.3, length + 0.3), cf, color, {
		material = Enum.Material.Metal,
	})
	for _, s in { -1, 1 } do
		Builder.block(
			parent,
			"TroughSide",
			Vector3.new(0.3, 1.4, length + 0.3),
			cf * CFrame.new(s * (width / 2 + 0.15), 0.55, 0),
			color:Lerp(Color3.new(0, 0, 0), 0.25),
			{ material = Enum.Material.Metal }
		)
	end
end

-- Builds a ride and returns its folder and its path (for Points.Rides[spec.id]).
function Rides.build(parent: Instance, spec: RideSpec): (Folder, { Vector3 })
	assert(#spec.path >= 2, `ride {spec.id}: the path needs at least 2 points`)
	local folder = Builder.folder(parent, `Ride_{spec.id}`)
	folder:SetAttribute(Tags.RideId, spec.id)
	folder:SetAttribute(Tags.Seats, spec.seats)
	folder:SetAttribute(Tags.Speed, spec.speed)
	if spec.lockdownSpeed then
		folder:SetAttribute(Tags.LockdownSpeed, spec.lockdownSpeed)
	end
	if spec.attrs then
		for key, value in spec.attrs do
			folder:SetAttribute(key, value)
		end
	end
	CollectionService:AddTag(folder, Tags.Ride)

	-- Track.
	local kind: TrackKind = spec.track or "Trough"
	local width = spec.trackWidth or 4
	local trackColor = spec.trackColor or Color3.fromRGB(150, 156, 164)
	local track = Builder.folder(folder, "Track")
	for i = 1, #spec.path - 1 do
		segment(track, spec.path[i], spec.path[i + 1], kind, width, trackColor)
	end
	local floorY = spec.floorY or 0
	local supports: { number } = spec.supports or {}
	for _, index in supports do
		local p = spec.path[index]
		if p and p.Y - 0.6 > floorY + 0.2 then
			Builder.box(
				track,
				"Support",
				Vector3.new(p.X - 0.25, floorY, p.Z - 0.25),
				Vector3.new(p.X + 0.25, p.Y - 0.6, p.Z + 0.25),
				C.Metal,
				{ material = Enum.Material.Metal, collide = false }
			)
		end
	end

	-- Stations.
	for index, station in spec.stations do
		local pad = Builder.block(
			folder,
			`Station{index}`,
			Vector3.new(width, 0.2, width),
			CFrame.new(station.at - Vector3.new(0, 0.1, 0)),
			C.CrewOrange,
			{ material = Enum.Material.SmoothPlastic, collide = false, shadow = false }
		)
		if not station.platform then
			pad.Transparency = 1
			pad.CanQuery = false
			pad.CanTouch = false
		end
		local att = Instance.new("Attachment")
		att.Name = "Station"
		att.CFrame = CFrame.new(0, 0.1, 0)
		att:SetAttribute(Tags.Boarding, station.boarding)
		att:SetAttribute(Tags.Stop, station.stop == true)
		if station.lockdownOnly then
			att:SetAttribute(Tags.LockdownOnly, true)
		end
		att.Parent = pad
	end

	-- Cars, parked one behind the other at the first station, facing along the path.
	local carSize = spec.carSize or Vector3.new(3, 0.6, 3.4)
	local start, nextPoint = spec.path[1], spec.path[2]
	local look = Vector3.new(nextPoint.X - start.X, 0, nextPoint.Z - start.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	for n = 1, spec.cars or 1 do
		local car = Instance.new("Model")
		car.Name = `Car{n}`
		local pos = start - look * (n - 1) * (carSize.Z + 0.6) + Vector3.new(0, carSize.Y / 2, 0)
		local cf = CFrame.lookAt(pos, pos + look)
		local base = Builder.block(car, "Base", carSize, cf, spec.carColor or C.Wood, {
			material = Enum.Material.WoodPlanks,
		})
		for _, s in { -1, 1 } do
			Builder.block(
				car,
				"Rim",
				Vector3.new(0.25, 0.6, carSize.Z),
				cf * CFrame.new(s * (carSize.X / 2 - 0.125), carSize.Y / 2 + 0.3, 0),
				C.WoodDark,
				{ material = Enum.Material.Wood }
			)
		end
		local seat = Builder.block(
			car,
			"Seat",
			Vector3.new(carSize.X - 0.6, 0.2, carSize.Z - 0.6),
			cf * CFrame.new(0, carSize.Y / 2 + 0.1, 0),
			C.CrewOrange,
			{ collide = false, shadow = false }
		)
		local seatPoint = Instance.new("Attachment")
		seatPoint.Name = "SeatPoint"
		seatPoint.CFrame = CFrame.new(0, 0.1, 0)
		seatPoint.Parent = seat
		car.PrimaryPart = base
		car.Parent = folder
	end
	-- Nothing on a ride collides: riders are welded to a seat the server moves, and nobody can walk up a chute.
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return folder, table.clone(spec.path)
end

return Rides
