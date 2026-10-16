--!strict
-- The ring around the hall (beta-spec-maps §6, retrofit step 1): our land east of the facades, the Back Lane (E3)
-- and Bin Alley (E4) gates, the Back Yard with the cold cellar's ramp trench, the Loading Basin with its jetty and
-- the boat exit, the Dock Apron and the Back Alley.
--   Back Lane x -22..0 z -47..-40.6 · Back Yard x 0..67 z -47..-26 · Dock Apron x 61..67 z -47..47
--   Back Alley x 0..67 z 26..47 · Bin Alley x -22..0 z 40.6..47 · Basin x 0..67 z -59..-47 (water, jetty x 38..44)
--   Trench x 0..28 z -46..-40: ramp from y 0 (x 28) down to the cellar door (x 0, floor y -9.8), 19.3°.
-- Cellar: x -22..0 z -46..-20 has no ground (see Cellar.luau).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Common = script.Parent.Parent.Parent.Common
local Anchors = require(Common.Anchors)
local Builder = require(Common.Builder)
local Doors = require(Common.Doors)

local Layout = require(script.Parent.Layout)

local C = Builder.Colors

local Grounds = {}

local BRICK: Builder.PartOpts = { material = Enum.Material.Brick, variant = "CC_Brick" }
local GRANITE: Builder.PartOpts = { material = Enum.Material.Granite }
local METAL: Builder.PartOpts = { material = Enum.Material.Metal }

local function invisibleWall(parent: Instance, name: string, a: Vector3, b: Vector3)
	Builder.box(parent, name, a, b, C.Stone, { transparency = 1, query = false, shadow = false })
end

-- A wall lamp on a short bracket (tag Lamp + Electronic). `out` = direction away from the wall.
local function wallLamp(parent: Instance, name: string, pos: Vector3, out: Vector3, range: number)
	Builder.block(
		parent,
		"LampBracket",
		Vector3.new(0.2, 0.2, 1.2),
		CFrame.lookAt(pos - out * 0.6, pos),
		C.Metal,
		METAL
	)
	local bulb = Builder.block(parent, name, Vector3.new(0.9, 0.7, 0.9), CFrame.new(pos), C.LampWarm, {
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	Builder.pointLight(bulb, range, 1.2, C.LampWarm)
	bulb:SetAttribute(Tags.Disabled, false)
	CollectionService:AddTag(bulb, Tags.Lamp)
	CollectionService:AddTag(bulb, Tags.Electronic)
end

local function ground(parent: Instance)
	local opts: Builder.PartOpts = { material = Enum.Material.Pavement }
	local function piece(name: string, a: Vector3, b: Vector3)
		Builder.box(parent, name, a, b, C.StoneDark, opts)
	end
	piece("GroundSouth", Vector3.new(-22, -8, -130), Vector3.new(160, 0, -59))
	piece("GroundEast", Vector3.new(67, -8, -59), Vector3.new(160, 0, 130))
	piece("GroundLane", Vector3.new(-22, -8, -59), Vector3.new(0, 0, -46))
	piece("GroundNorth", Vector3.new(-22, -8, -20), Vector3.new(67, 0, 130))
	piece("GroundYardSouth", Vector3.new(28, -8, -47), Vector3.new(67, 0, -39.4))
	piece("GroundYard", Vector3.new(0, -8, -39.4), Vector3.new(67, 0, -20))
end

-- An alley gate on the quay (x -22): open gate leaves inside, posts, a beam with the name sign, and the entrance's
-- LockedBlocker on the quay side. zA < zB.
local function alleyGate(parent: Instance, id: string, zA: number, zB: number, label: string)
	local cobble: Builder.PartOpts = { material = Enum.Material.Cobblestone, variant = "CC_Cobble" }
	Builder.box(parent, `AlleyFloor{id}`, Vector3.new(-22, 0, zA), Vector3.new(0, 0.15, zB), C.Cobble, cobble)
	Builder.box(
		parent,
		"GatePost",
		Vector3.new(-22.6, 0, zA - 0.4),
		Vector3.new(-21.4, 9.1, zA),
		C.Stone,
		GRANITE
	)
	Builder.box(
		parent,
		"GatePost",
		Vector3.new(-22.6, 0, zB),
		Vector3.new(-21.4, 9.1, zB + 0.4),
		C.Stone,
		GRANITE
	)
	Builder.box(
		parent,
		"GateBeam",
		Vector3.new(-22.6, 8.5, zA - 0.4),
		Vector3.new(-21.4, 9.1, zB + 0.4),
		C.Stone,
		GRANITE
	)
	-- The gate itself stands open (unlocked = the quiet way in): two leaves folded against the alley walls.
	for _, z in { zA + 0.35, zB - 0.35 } do
		Builder.box(
			parent,
			"GateLeaf",
			Vector3.new(-21.2, 0.15, z - 0.12),
			Vector3.new(-18.2, 7.5, z + 0.12),
			Color3.fromRGB(40, 44, 50),
			{ material = Enum.Material.DiamondPlate, transparency = 0.3 }
		)
	end
	Doors.entrance(parent, {
		id = id,
		a = Vector3.new(-22, 0.3, zA),
		b = Vector3.new(-22, 0.3, zB),
		height = 8.4,
		approach = -Vector3.xAxis,
		offset = 0.9,
	})
	Doors.threshold(parent, Vector3.new(-20.9, 0.15, zA), Vector3.new(-20.9, 0.15, zB), 1)
	local zMid = (zA + zB) / 2
	Builder.sign(
		parent,
		CFrame.lookAt(Vector3.new(-22.9, 9.6, zMid), Vector3.new(-40, 9.6, zMid)),
		Vector3.new(6, 1.1, 0.2),
		label,
		C.Trim,
		C.DoorGreen,
		Enum.Font.GothamBold,
		{ viewFrom = Vector3.new(-34, 5, zMid) }
	)
end

local function trench(parent: Instance)
	-- Ramp: a wedge from y 0 at x 28 down to the cellar floor at x 0 (local +Z = world +X is the high end).
	local depth = -Layout.CellarFloor
	Builder.wedge(
		parent,
		"CellarRamp",
		Vector3.new(6, depth, 28),
		CFrame.new(14, -depth / 2, -43) * CFrame.Angles(0, math.rad(90), 0),
		C.Concrete,
		{ material = Enum.Material.Concrete }
	)
	Builder.box(
		parent,
		"TrenchWallS",
		Vector3.new(0, -10.5, -47),
		Vector3.new(28, 0, -46),
		C.BrickDark,
		BRICK
	)
	Builder.box(
		parent,
		"TrenchWallN",
		Vector3.new(0, -10.5, -40),
		Vector3.new(28, 0, -39.4),
		C.BrickDark,
		BRICK
	)
	Builder.box(parent, "TrenchCapS", Vector3.new(0, 0, -47.1), Vector3.new(28, 0.3, -45.9), C.Stone, GRANITE)
	-- Railing along the yard side (posts + top rail).
	Builder.box(
		parent,
		"TrenchRail",
		Vector3.new(1, 3.2, -39.45),
		Vector3.new(27, 3.5, -39.15),
		C.Safety,
		METAL
	)
	for x = 1, 27, 4.333 do
		Builder.box(
			parent,
			"TrenchPost",
			Vector3.new(x - 0.15, 0, -39.45),
			Vector3.new(x + 0.15, 3.2, -39.15),
			C.Metal,
			METAL
		)
	end
	-- Gantry over the trench head with the COLD CELLAR sign (8.5 clear), readable from the yard.
	Builder.box(
		parent,
		"GantryPost",
		Vector3.new(28, 0, -46.9),
		Vector3.new(28.6, 10.6, -46.3),
		C.Metal,
		METAL
	)
	Builder.box(
		parent,
		"GantryPost",
		Vector3.new(28, 0, -39.7),
		Vector3.new(28.6, 10.6, -39.1),
		C.Metal,
		METAL
	)
	Builder.box(
		parent,
		"GantryBeam",
		Vector3.new(28, 8.5, -46.9),
		Vector3.new(28.6, 9, -39.1),
		C.Metal,
		METAL
	)
	Builder.sign(
		parent,
		CFrame.lookAt(Vector3.new(28.85, 9.6, -43), Vector3.new(40, 9.6, -43)),
		Vector3.new(8, 1.3, 0.2),
		"COLD CELLAR",
		Color3.fromRGB(150, 200, 255),
		Color3.fromRGB(20, 40, 70),
		Enum.Font.GothamBold,
		{ viewFrom = Vector3.new(40, 5, -38) }
	)
end

local function basin(parent: Instance)
	-- Loading Basin: brick walls, mud bed, Terrain water (top y -3), granite edge, invisible edge barrier.
	Builder.box(
		parent,
		"BasinBed",
		Vector3.new(0, -12, -59),
		Vector3.new(67, -8, -47),
		Color3.fromRGB(40, 46, 44),
		{
			material = Enum.Material.Mud,
		}
	)
	for _, wall in
		{
			{ Vector3.new(28, -12, -47.3), Vector3.new(67, 0, -47) },
			{ Vector3.new(0, -12, -47.3), Vector3.new(28, -10.5, -47) },
			{ Vector3.new(0, -12, -59), Vector3.new(0.3, 0, -47.3) },
			{ Vector3.new(0, -12, -59), Vector3.new(67, 0, -58.7) },
			{ Vector3.new(66.7, -12, -59), Vector3.new(67, 0, -47.3) },
		}
	do
		Builder.box(parent, "BasinWall", wall[1], wall[2], C.BrickDark, BRICK)
	end
	for _, edge in { { 28, 38 }, { 44, 67 } } do
		Builder.box(
			parent,
			"BasinEdge",
			Vector3.new(edge[1], 0, -47.9),
			Vector3.new(edge[2], 0.35, -46.9),
			C.Stone,
			GRANITE
		)
	end
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(33.5, -3, -53), Vector3.new(67, 10, 12), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(33.5, -5.5, -53), Vector3.new(67, 5, 12), Enum.Material.Water)
	invisibleWall(parent, "BarrierBasinW", Vector3.new(0, 0, -47.8), Vector3.new(38, 14, -47.3))
	invisibleWall(parent, "BarrierBasinE", Vector3.new(44, 0, -47.8), Vector3.new(67, 14, -47.3))

	-- Jetty (deck y -0.6) with a short slope down from the yard, barriers on three sides.
	local planks: Builder.PartOpts = { material = Enum.Material.WoodPlanks, variant = "CC_Planks" }
	Builder.box(parent, "JettyDeck", Vector3.new(38, -0.9, -52), Vector3.new(44, -0.6, -48.5), C.Wood, planks)
	Builder.wedge(
		parent,
		"JettySlope",
		Vector3.new(6, 0.6, 1.5),
		CFrame.new(41, -0.3, -47.75),
		C.Wood,
		planks
	)
	for _, p in
		{
			Vector3.new(38.4, 0, -51.6),
			Vector3.new(43.6, 0, -51.6),
			Vector3.new(38.4, 0, -48.9),
			Vector3.new(43.6, 0, -48.9),
		}
	do
		Builder.cylinder(
			parent,
			"JettyPost",
			0.6,
			9,
			p + Vector3.new(0, -4.9, 0),
			C.WoodDark,
			{ material = Enum.Material.Wood }
		)
	end
	invisibleWall(parent, "BarrierJettyW", Vector3.new(37.6, -0.6, -52.4), Vector3.new(38, 14, -47.8))
	invisibleWall(parent, "BarrierJettyE", Vector3.new(44, -0.6, -52.4), Vector3.new(44.4, 14, -47.8))
	invisibleWall(parent, "BarrierJettyS", Vector3.new(38, -0.6, -52.4), Vector3.new(44, 14, -52))

	-- The boat (optional exit, 50% of rounds): moored east of the jetty, bow to the south. The bank zone covers the
	-- jetty's end; an inactive optional exit is destroyed with its boat.
	local boat = Anchors.exit(parent, {
		kind = "Boat",
		name = "BoatExit",
		optional = true,
		bankMin = Vector3.new(39, -3, -57),
		bankMax = Vector3.new(47, 5, -48),
		drivePoint = Vector3.new(41, -0.6, -51),
	})
	Builder.boat(boat, Vector3.new(47.5, -2.6, -52.5), Color3.fromRGB(200, 120, 40), 180)
	Builder.box(boat, "MooringLine", Vector3.new(44, -0.9, -50.1), Vector3.new(45.6, -0.8, -49.9), C.Trim, {
		collide = false,
		shadow = false,
	})
end

local function yardAndAlleys(parent: Instance)
	-- Back Yard: oil drums (one carries a keycard spot), a pushcart (medium loot), a wall lamp.
	for _, p in { Vector3.new(11, 0, -37.5), Vector3.new(13.6, 0, -36.8) } do
		Builder.cylinder(
			parent,
			"OilDrum",
			2.4,
			3.2,
			p + Vector3.new(0, 1.6, 0),
			Color3.fromRGB(40, 70, 120),
			METAL
		)
	end
	Builder.box(parent, "PushcartBed", Vector3.new(20.5, 1, -38), Vector3.new(23.5, 1.4, -34), C.Wood, {
		material = Enum.Material.WoodPlanks,
	})
	for _, z in { -37.4, -34.6 } do
		Builder.box(
			parent,
			"PushcartLeg",
			Vector3.new(20.7, 0, z - 0.2),
			Vector3.new(23.3, 1, z + 0.2),
			C.Metal,
			METAL
		)
	end
	wallLamp(parent, "YardWallLamp", Vector3.new(30, 9, -26.7), -Vector3.zAxis, 26)
	-- Back Alley: crates (medium loot on top), wall lamp.
	for _, p in { Vector3.new(30, 0, 44.5), Vector3.new(34.4, 0, 44.8) } do
		Builder.prop(parent, "Crate", p, p.X * 3, {
			fallback = function(pp, g)
				return Builder.block(
					pp,
					"CrateStub",
					Vector3.new(4, 4, 4),
					CFrame.new(g + Vector3.new(0, 2, 0)),
					C.Wood,
					{
						material = Enum.Material.WoodPlanks,
					}
				)
			end,
		})
	end
	wallLamp(parent, "AlleyWallLamp", Vector3.new(30, 9, 26.7), Vector3.zAxis, 26)
	-- Dock Apron: a lamp on the warehouse wall.
	wallLamp(parent, "ApronWallLamp", Vector3.new(66.3, 9, 0), -Vector3.xAxis, 24)
end

function Grounds.build(level: Folder)
	local grounds = Builder.folder(level, "Grounds")
	ground(grounds)
	alleyGate(grounds, "E3", -47, -40.6, "BACK LANE")
	alleyGate(grounds, "E4", 40.6, 47, "BIN ALLEY")
	trench(grounds)
	basin(grounds)
	yardAndAlleys(grounds)
end

return Grounds
