--!strict
-- Doors for every heist (docs/contracts.md §2.5, beta-spec §6.1): door leaves that the Crowbar can pry, entrances with
-- a `LockedBlocker`, roller doors, keycard gates, and lockdown shutters. Geometry and tags only: the behaviour
-- (prying, locking, keycards, lockdown) belongs to the mechanics services.
--
-- Openings are given as two floor points `a`, `b` on the wall's centre line plus a height. A swinging leaf turns
-- 100° around its hinge into the side `swing` points at (GadgetService: the hinge is the leaf's local -Z end and it
-- opens towards local +X). Keep that quarter circle (radius = width) free of props. Engine rules: doors on loot
-- routes are 6 wide × 9 high, never under 5 × 8; roller doors 8 wide.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Builder = require(script.Parent.Builder)

local C = Builder.Colors

local Doors = {}

Doors.Red = Color3.fromRGB(255, 50, 40)

export type LeafOpts = {
	thickness: number?,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	bottom: number?, -- gap under the leaf (default 0)
}

-- The CFrame of a leaf filling the opening a → b (floor points), height h, opening towards `swing`.
-- Local Z runs along the opening (the hinge is the -Z end), local X points into the swing side.
function Doors.leafCFrame(a: Vector3, b: Vector3, height: number, swing: Vector3): CFrame
	local along = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local dir = along.Unit
	local n = Vector3.new(swing.X, 0, swing.Z)
	n = (n - dir * n:Dot(dir)).Unit
	local center = (a + b) / 2 + Vector3.new(0, height / 2, 0)
	return CFrame.fromMatrix(center, n, Vector3.yAxis)
end

-- A door leaf (one part) in the opening a → b. Not pryable on its own: see Doors.pryable.
function Doors.leaf(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	height: number,
	swing: Vector3,
	opts: LeafOpts?
): Part
	local o: LeafOpts = opts or {}
	local width = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
	local bottom = o.bottom or 0
	local cf =
		Doors.leafCFrame(a + Vector3.new(0, bottom, 0), b + Vector3.new(0, bottom, 0), height - bottom, swing)
	return Builder.block(
		parent,
		name,
		Vector3.new(o.thickness or 0.4, height - bottom, width),
		cf,
		o.color or C.DoorGreen,
		{ material = o.material or Enum.Material.Wood, transparency = o.transparency }
	)
end

-- Makes a part pryable with the Crowbar (contract: PrySeconds, DoorState, ClosedCFrame, optional LoudOnly).
function Doors.pryable(part: BasePart, seconds: number, loudOnly: boolean?)
	part:SetAttribute("PrySeconds", seconds)
	part:SetAttribute(Tags.SpotKind, "lock")
	part:SetAttribute(Tags.DoorState, "Closed")
	part:SetAttribute(Tags.ClosedCFrame, part.CFrame)
	if loudOnly then
		part:SetAttribute(Tags.LoudOnly, true)
	end
	CollectionService:AddTag(part, Tags.Pryable)
	CollectionService:AddTag(part, Tags.Spottable)
end

-- A red "secure" lamp above a door: neon only (no light), so it costs nothing from the light budget.
function Doors.redLamp(parent: Instance, pos: Vector3): Part
	return Builder.block(parent, "SecureLamp", Vector3.new(0.7, 0.5, 0.7), CFrame.new(pos), Doors.Red, {
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
end

-- A yellow-striped threshold strip (staff ring border) on the floor along a → b, `depth` studs deep.
function Doors.threshold(parent: Instance, a: Vector3, b: Vector3, depth: number?)
	local along = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local width = along.Magnitude
	local center = (a + b) / 2
	local cf = CFrame.lookAt(center, center + along.Unit) -- local Z along the opening
	local d = depth or 1
	local stripes = math.max(2, math.floor(width / 1.2))
	for i = 0, stripes - 1 do
		local z = -width / 2 + (i + 0.5) * width / stripes
		Builder.block(
			parent,
			"StaffStripe",
			Vector3.new(d, 0.04, width / stripes),
			cf * CFrame.new(0, 0.02, z),
			if i % 2 == 0 then C.Safety else Color3.fromRGB(30, 30, 30),
			{ collide = false, shadow = false, query = false }
		)
	end
end

export type EntranceSpec = {
	id: string, -- EntranceId, e.g. "E1"
	a: Vector3, -- opening (floor points on the wall line)
	b: Vector3,
	height: number,
	approach: Vector3, -- direction towards the side people come from (the CLOSED board faces it)
	offset: number?, -- how far the blocker stands in front of the wall line, towards `approach` (default 0.7)
	label: string?, -- board text (default "CLOSED")
}

-- An entrance (contract: Model tagged Entrance, attribute EntranceId, child `LockedBlocker`). The blocker is built
-- solid and visible (= locked); SetupService destroys it when the round plan leaves the entrance open. Put the
-- entrance's doors and gates inside the returned model, so a locked entrance disables its Pryables.
function Doors.entrance(parent: Instance, spec: EntranceSpec): Model
	local model = Instance.new("Model")
	model.Name = `Entrance_{spec.id}`
	model:SetAttribute(Tags.EntranceId, spec.id)
	CollectionService:AddTag(model, Tags.Entrance)

	local blocker = Instance.new("Model")
	blocker.Name = "LockedBlocker"
	local along = Vector3.new(spec.b.X - spec.a.X, 0, spec.b.Z - spec.a.Z)
	local width = along.Magnitude
	local dir = along.Unit
	local out = Vector3.new(spec.approach.X, 0, spec.approach.Z)
	out = (out - dir * out:Dot(dir)).Unit
	local offset = spec.offset or 0.7
	local center = (spec.a + spec.b) / 2 + out * offset
	-- Local X runs along the opening; the front (-Z) faces `out`.
	local face = CFrame.lookAt(center, center + out)
	-- Solid collider over the whole opening (the planks have gaps).
	local wall = Builder.block(
		blocker,
		"BlockerWall",
		Vector3.new(width, spec.height, 0.3),
		face * CFrame.new(0, spec.height / 2, 0),
		C.WoodDark,
		{ transparency = 1, shadow = false }
	)
	wall.CanQuery = false
	-- Planks: two crossed boards and three across.
	for i, y in { 1.6, 3.6, 6.6 } do
		Builder.block(
			blocker,
			"Plank",
			Vector3.new(width + 0.4, 0.7, 0.25),
			face * CFrame.new(0, y, -0.05 * i),
			C.Wood,
			{ material = Enum.Material.WoodPlanks, collide = false }
		)
	end
	local diag = math.sqrt(width * width + 36)
	local angle = math.atan2(6, width)
	for _, s in { -1, 1 } do
		Builder.block(
			blocker,
			"Plank",
			Vector3.new(diag, 0.6, 0.2),
			face * CFrame.new(0, 4, 0.2) * CFrame.Angles(0, 0, s * angle),
			C.WoodDark,
			{ material = Enum.Material.WoodPlanks, collide = false }
		)
	end
	-- Chain with a padlock, and the CLOSED board.
	Builder.block(
		blocker,
		"Chain",
		Vector3.new(width * 0.8, 0.2, 0.2),
		face * CFrame.new(0, 6.1, -0.35),
		C.Metal,
		{ material = Enum.Material.Metal, collide = false }
	)
	Builder.block(
		blocker,
		"Padlock",
		Vector3.new(0.6, 0.8, 0.3),
		face * CFrame.new(0, 5.75, -0.45),
		C.Gold,
		{ material = Enum.Material.Foil, collide = false }
	)
	local boardCf = face * CFrame.new(0, 4.5, -0.45)
	Builder.sign(
		blocker,
		boardCf,
		Vector3.new(4, 1.2, 0.2),
		spec.label or "CLOSED",
		Color3.fromRGB(190, 40, 36),
		C.Trim,
		Enum.Font.GothamBold,
		{ viewFrom = boardCf.Position + out * 8 + Vector3.new(0, 0.5, 0) }
	)
	blocker.PrimaryPart = wall
	blocker.Parent = model
	model.Parent = parent
	return model
end

export type RollerOpts = {
	swing: Vector3, -- when pried it swings like a door (GadgetService); point it at the side with free floor
	seconds: number?, -- PrySeconds (default 3)
	color: Color3?,
	inset: number?, -- housing and rails sit this far towards `swing`, on the wall face (default 0.85)
}

-- A roller door: one panel (pryable) under a housing box, with side rails.
function Doors.roller(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	height: number,
	opts: RollerOpts
): Part
	local panel = Doors.leaf(parent, name, a, b, height, opts.swing, {
		thickness = 0.35,
		color = opts.color or Color3.fromRGB(96, 104, 112),
		material = Enum.Material.CorrodedMetal,
	})
	Doors.pryable(panel, opts.seconds or 3)
	local cf = panel.CFrame
	local width = panel.Size.Z
	local inset = opts.inset or 0.85
	Builder.block(
		parent,
		"RollerHousing",
		Vector3.new(1, 1, width + 0.6),
		cf * CFrame.new(inset, height / 2 + 0.5, 0),
		C.Metal,
		{ material = Enum.Material.Metal }
	)
	for _, s in { -1, 1 } do
		Builder.block(
			parent,
			"RollerRail",
			Vector3.new(0.7, height, 0.3),
			cf * CFrame.new(inset - 0.2, 0, s * (width / 2 + 0.15)),
			C.Metal,
			{ material = Enum.Material.Metal }
		)
	end
	return panel
end

export type KeycardSpec = {
	card: string, -- Card attribute (keycard objective id)
	a: Vector3,
	b: Vector3,
	height: number,
	front: Vector3, -- side the main reader faces (where players come from)
	lamp: boolean?, -- a red PointLight above the gate (default true)
	readerEnd: number?, -- 1 = readers beside the leaf's local +Z end, -1 = beside the -Z end (default 1)
}

-- A keycard gate (contract: tag KeycardDoor, attribute Card). Children: `Door` (PrimaryPart; attributes DoorState,
-- ClosedCFrame and OpenCFrame = slid sideways beside the opening), `Reader` on both sides, a red lamp.
function Doors.keycardGate(parent: Instance, name: string, spec: KeycardSpec): Model
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute(Tags.Card, spec.card)
	CollectionService:AddTag(model, Tags.KeycardDoor)
	local door = Doors.leaf(model, "Door", spec.a, spec.b, spec.height, spec.front, {
		thickness = 0.4,
		color = Color3.fromRGB(150, 36, 32),
		material = Enum.Material.DiamondPlate,
	})
	local width = door.Size.Z
	door:SetAttribute(Tags.DoorState, "Closed")
	door:SetAttribute(Tags.ClosedCFrame, door.CFrame)
	door:SetAttribute("OpenCFrame", door.CFrame * CFrame.new(0, 0, -width))
	-- A yellow stripe across the gate: "orange = usable".
	Builder.block(
		model,
		"GateStripe",
		Vector3.new(0.45, 0.5, width),
		door.CFrame * CFrame.new(0, 0.5, 0),
		C.Safety,
		{ collide = false, shadow = false }
	)
	-- Card readers on both sides, beside the opening, at hand height.
	for _, s in { 1, -1 } do
		local readerCf = door.CFrame
			* CFrame.new(s * 0.45, 4 - spec.height / 2, (spec.readerEnd or 1) * (width / 2 + 0.6))
		local reader =
			Builder.block(model, "Reader", Vector3.new(0.3, 1, 0.7), readerCf, Color3.fromRGB(40, 42, 48), {
				material = Enum.Material.Metal,
			})
		Builder.block(
			model,
			"ReaderLed",
			Vector3.new(0.08, 0.15, 0.4),
			readerCf * CFrame.new(s * 0.18, 0.3, 0),
			Doors.Red,
			{ material = Enum.Material.Neon, collide = false, shadow = false }
		)
		local _ = reader
	end
	local lampPos = (door.CFrame * CFrame.new(
		0.7,
		spec.height / 2 + 1.9,
		(spec.readerEnd or 1) * (width / 2 - 0.4)
	)).Position
	local lamp = Doors.redLamp(model, lampPos)
	if spec.lamp ~= false then
		Builder.pointLight(lamp, 10, 1.2, Doors.Red, false)
	end
	model.PrimaryPart = door
	model.Parent = parent
	return model
end

-- A fire shutter for maps 2–3 (tag LockdownSwitch, Action "Close"). Built OPEN: the panel is parked in its housing
-- above the opening (no collision, invisible). At LOCKDOWN the mechanics move it to `ClosedCFrame`, make it solid
-- and visible; `OpenCFrame` is where it starts.
function Doors.shutter(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	height: number,
	action: string?
): Part
	local swing = Vector3.new(-(b.Z - a.Z), 0, b.X - a.X) -- any normal works: shutters do not swing
	local closedCf = Doors.leafCFrame(a, b, height, swing)
	local width = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
	local openCf = closedCf * CFrame.new(0, height, 0)
	local panel =
		Builder.block(parent, name, Vector3.new(0.3, height, width), openCf, Color3.fromRGB(176, 60, 44), {
			material = Enum.Material.CorrodedMetal,
			collide = false,
			transparency = 1,
		})
	panel:SetAttribute(Tags.Action, action or "Close")
	panel:SetAttribute(Tags.ClosedCFrame, closedCf)
	panel:SetAttribute("OpenCFrame", openCf)
	CollectionService:AddTag(panel, Tags.LockdownSwitch)
	Builder.block(
		parent,
		"ShutterHousing",
		Vector3.new(1, 1.2, width + 0.4),
		closedCf * CFrame.new(0, height / 2 + 0.6, 0),
		Color3.fromRGB(150, 50, 40),
		{ material = Enum.Material.Metal }
	)
	return panel
end

return Doors
