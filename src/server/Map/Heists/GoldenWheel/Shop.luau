--!strict
-- The shop "The Golden Wheel" on the quay (§10.1): cheese shop (A, Public), security room (B) with the holding cell,
-- courtyard (C) and the rotating Golden Wheel on the roof (landmark).
-- A: x -22..0, z -40..-14   B: x -22..0, z -14..4   C: x -22..0, z 4..40.6 (outdoors)
-- The facades stand at x = -22 and face the canal (-X).
-- Karel's closet (x -7.5..-0.6, z -40..-26) is the stairwell down to the cold cellar.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Common = script.Parent.Parent.Parent.Common
local Anchors = require(Common.Anchors)
local Builder = require(Common.Builder)
local Doors = require(Common.Doors)

local Layout = require(script.Parent.Layout)

local C = Builder.Colors

local Shop = {}

local GROUND_H = 14 -- height of the ground floor (ceiling)
local BRICK: Builder.PartOpts = { material = Enum.Material.Brick, variant = "CC_Brick" }
local PLASTER: Builder.PartOpts = { material = Enum.Material.Plaster }
local PLANKS: Builder.PartOpts = { material = Enum.Material.WoodPlanks, variant = "CC_Planks" }

-- A ceiling lamp (tag Lamp + Electronic) on a cord up to the ceiling.
local function lamp(
	parent: Instance,
	name: string,
	pos: Vector3,
	range: number,
	color: Color3?,
	shadows: boolean?
)
	local bulb =
		Builder.block(parent, name, Vector3.new(1.2, 0.6, 1.2), CFrame.new(pos), color or C.LampWarm, {
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
	Builder.pointLight(bulb, range, 1.3, color or C.LampWarm, shadows)
	bulb:SetAttribute(Tags.Disabled, false)
	CollectionService:AddTag(bulb, Tags.Lamp)
	CollectionService:AddTag(bulb, Tags.Electronic)
	Builder.block(
		parent,
		"Cord",
		Vector3.new(0.1, GROUND_H - pos.Y, 0.1),
		CFrame.new(pos.X, (GROUND_H + pos.Y) / 2, pos.Z),
		C.StoneDark,
		{ collide = false, shadow = false }
	)
end

local function cheese(parent: Instance, ground: Vector3, rotY: number, scale: number?)
	Builder.prop(parent, "CheeseWheel", ground, rotY, {
		scale = scale or 0.8,
		collide = false,
		fallback = function(p, g)
			return Builder.cylinder(
				p,
				"CheeseStub",
				2.4,
				1.2,
				g + Vector3.new(0, 0.6, 0),
				C.Cheese,
				{ collide = false }
			)
		end,
	})
end

local function upperFacade(
	parent: Instance,
	zMin: number,
	zMax: number,
	color: Color3,
	brick: boolean,
	gableStyle: string,
	rng: Random
)
	-- Upper floors (scenery, solid) above the ground floor.
	local width = zMax - zMin
	local zMid = (zMin + zMax) / 2
	local top = GROUND_H + 14
	local opts: Builder.PartOpts = if brick then BRICK else PLASTER
	Builder.box(
		parent,
		"UpperFloors",
		Vector3.new(-22, GROUND_H, zMin),
		Vector3.new(0, top, zMax),
		color,
		opts
	)
	Builder.block(
		parent,
		"Cornice",
		Vector3.new(1.2, 0.8, width + 0.6),
		CFrame.new(-22.3, top - 0.4, zMid),
		C.Trim
	)
	Builder.block(
		parent,
		"FloorBand",
		Vector3.new(0.8, 0.6, width + 0.2),
		CFrame.new(-22.2, GROUND_H + 0.3, zMid),
		C.Trim
	)
	local cols = if width >= 20 then 4 elseif width >= 14 then 3 else 2
	for floor = 0, 1 do
		for col = 1, cols do
			local z = zMin + width / cols * (col - 0.5)
			local y = GROUND_H + 3.6 + floor * 7
			local cf = CFrame.lookAt(Vector3.new(-22.2, y, z), Vector3.new(-40, y, z))
			Builder.window(parent, cf, 2.6, 4, rng:NextNumber() < 0.5, nil, rng)
		end
	end
	-- Gable: step or neck gable, aligned with the facade.
	if gableStyle == "step" then
		for i = 1, 3 do
			local w = width - (i - 1) * width * 0.27
			Builder.block(
				parent,
				"GableStep",
				Vector3.new(1.2, 3, w),
				CFrame.new(-21.6, top + (i - 0.5) * 3, zMid),
				color,
				opts
			)
			Builder.block(
				parent,
				"GableCap",
				Vector3.new(1.6, 0.4, w + 0.4),
				CFrame.new(-21.6, top + i * 3, zMid),
				C.Trim
			)
		end
	else
		local neck = width * 0.45
		Builder.block(
			parent,
			"GableNeck",
			Vector3.new(1.2, 8, neck),
			CFrame.new(-21.6, top + 4, zMid),
			color,
			opts
		)
		Builder.block(
			parent,
			"GableCap",
			Vector3.new(1.6, 0.5, neck + 0.6),
			CFrame.new(-21.6, top + 8, zMid),
			C.Trim
		)
		Builder.window(
			parent,
			CFrame.lookAt(Vector3.new(-22.3, top + 4, zMid), Vector3.new(-40, top + 4, zMid)),
			2,
			3,
			true,
			nil,
			rng
		)
	end
	Builder.box(
		parent,
		"Roof",
		Vector3.new(-21, top, zMin + 0.3),
		Vector3.new(-1, top + 1, zMax - 0.3),
		C.StoneDark,
		{
			material = Enum.Material.Slate,
			variant = "CC_Roof",
		}
	)
end

-- Karel's closet = the stairwell to the cold cellar (exit 2 of the cellar). Door z -26 (x -6..-1), Pryable 1.5,
-- red lamp; 16 steps down to the cellar floor with an invisible ramp over the step noses.
local function closetStairwell(shop: Instance)
	local x0, x1 = -7, -0.6
	local topZ, bottomZ = -26.5, -38.5
	Builder.box(
		shop,
		"ClosetWallW",
		Vector3.new(-7.5, 0, -40),
		Vector3.new(-7, 10.5, -26),
		C.Plaster,
		PLASTER
	)
	Builder.box(
		shop,
		"ClosetFrontW",
		Vector3.new(-7.5, 0, -26.5),
		Vector3.new(-6, 10.5, -26),
		C.Plaster,
		PLASTER
	)
	Builder.box(
		shop,
		"ClosetFrontE",
		Vector3.new(-1, 0, -26.5),
		Vector3.new(-0.6, 10.5, -26),
		C.Plaster,
		PLASTER
	)
	Builder.box(
		shop,
		"ClosetLintel",
		Vector3.new(-6, 8.2, -26.5),
		Vector3.new(-1, 10.5, -26),
		C.Plaster,
		PLASTER
	)
	Builder.box(
		shop,
		"ClosetSill",
		Vector3.new(x0, -0.3, -26.5),
		Vector3.new(x1, 0.2, -26),
		C.WoodDark,
		PLANKS
	)
	local door = Doors.leaf(
		shop,
		"ClosetDoor",
		Vector3.new(-6, 0.2, -26.25),
		Vector3.new(-1, 0.2, -26.25),
		8,
		-Vector3.zAxis,
		{
			thickness = 0.3,
			color = C.DoorGreen,
		}
	)
	Doors.pryable(door, Config.Gadgets.Crowbar.DoorSeconds)
	Doors.redLamp(shop, Vector3.new(-6.6, 9.3, -25.75))
	Builder.sign(
		shop,
		CFrame.lookAt(Vector3.new(-3.5, 9.35, -25.85), Vector3.new(-3.5, 9.35, -10)),
		Vector3.new(3, 0.9, 0.2),
		"KAREL",
		C.Trim,
		C.DoorGreen,
		Enum.Font.GothamBold,
		{ viewFrom = Vector3.new(-4, 5, -17) }
	)
	-- Steps (floating treads, so the space under the stair stays open) and the walking ramp.
	local steps = 16
	local run = (topZ - bottomZ) / steps
	local rise = (0.2 - Layout.CellarFloor) / steps
	for i = 0, steps - 1 do
		local top = 0.2 - (i + 1) * rise
		Builder.box(
			shop,
			"CellarStep",
			Vector3.new(x0, top - 0.5, topZ - (i + 1) * run),
			Vector3.new(x1, top, topZ - i * run),
			C.WoodDark,
			PLANKS
		)
	end
	local topP = Vector3.new((x0 + x1) / 2, 0.2, topZ)
	local bottomP = Vector3.new((x0 + x1) / 2, Layout.CellarFloor, bottomZ)
	local ramp = Builder.block(
		shop,
		"CellarStairRamp",
		Vector3.new(x1 - x0, 0.4, (topP - bottomP).Magnitude),
		CFrame.lookAt((topP + bottomP) / 2, bottomP) * CFrame.new(0, -0.2, 0),
		C.Metal,
		{ transparency = 1, shadow = false }
	)
	ramp.CanQuery = false
	-- Rail along the open west side of the stair (inside the cellar).
	Builder.box(
		shop,
		"StairRail",
		Vector3.new(x0 - 0.2, -9.8, -38.4),
		Vector3.new(x0, -6.5, -37.6),
		C.Metal,
		{
			material = Enum.Material.Metal,
		}
	)
end

local function buildShop(parent: Instance, rng: Random)
	local shop = Builder.folder(parent, "Shop")
	-- Floor with the stairwell cut out.
	Builder.box(shop, "ShopFloorW", Vector3.new(-22, 0, -40), Vector3.new(-7.5, 0.2, -14), C.Wood, PLANKS)
	Builder.box(shop, "ShopFloorE", Vector3.new(-7.5, 0, -26), Vector3.new(0, 0.2, -14), C.Wood, PLANKS)

	-- Ground-floor facade: display window, a 6-wide doorway (B-002), second window.
	local function front(name: string, z0: number, z1: number, y0: number, y1: number)
		Builder.box(shop, name, Vector3.new(-22.6, y0, z0), Vector3.new(-21.4, y1, z1), C.BrickRed, BRICK)
	end
	front("FrontPier1", -40, -38.5, 0, GROUND_H)
	front("FrontBelowWindow", -38.5, -30, 0, 2.4)
	front("FrontAboveWindow", -38.5, -30, 10.5, GROUND_H)
	front("FrontPier2", -30, -29.5, 0, GROUND_H)
	front("FrontAboveDoor", -29.5, -23.5, 9, GROUND_H)
	front("FrontPier3", -23.5, -23, 0, GROUND_H)
	front("FrontBelowWindow2", -23, -16, 0, 2.4)
	front("FrontAboveWindow2", -23, -16, 10.5, GROUND_H)
	front("FrontPier4", -16, -14, 0, GROUND_H)
	for _, w in { { -38.5, -30 }, { -23, -16 } } do
		local zMid = (w[1] + w[2]) / 2
		local width = w[2] - w[1]
		Builder.block(
			shop,
			"DisplayGlass",
			Vector3.new(0.3, 8.1, width),
			CFrame.new(-22, 6.45, zMid),
			Color3.fromRGB(180, 210, 230),
			{
				material = Enum.Material.Glass,
				transparency = 0.65,
			}
		)
		Builder.block(
			shop,
			"DisplayFrame",
			Vector3.new(0.5, 0.4, width),
			CFrame.new(-22.1, 10.4, zMid),
			C.DoorGreen
		)
		Builder.block(
			shop,
			"DisplaySill",
			Vector3.new(1.2, 0.4, width + 0.4),
			CFrame.new(-22.6, 2.5, zMid),
			C.Stone
		)
		Builder.prop(shop, "TulipBox", Vector3.new(-23.4, Builder.SIDEWALK, zMid), 90, { collide = false })
	end
	-- The front door: two leaves propped open against the inside (the shop is public, the door is on the latch).
	for _, z in { -29.3, -23.7 } do
		Builder.box(
			shop,
			"FrontDoor",
			Vector3.new(-21.4, 0.2, z - 0.15),
			Vector3.new(-18.4, 8.8, z + 0.15),
			C.DoorGreen,
			{
				material = Enum.Material.Wood,
			}
		)
		Builder.box(
			shop,
			"FrontDoorGlass",
			Vector3.new(-21, 4.5, z - 0.17),
			Vector3.new(-18.8, 8, z + 0.17),
			C.WindowLit,
			{
				material = Enum.Material.Glass,
				transparency = 0.4,
				collide = false,
			}
		)
	end
	-- Awning in crew orange and white (striped): sloping strips that drop from the facade towards the street.
	for i = 0, 9 do
		local z = -39 + i * 2.5 + 1.25
		local stripe = if i % 2 == 0 then C.CrewOrange else C.Trim
		Builder.block(
			shop,
			"Awning",
			Vector3.new(4, 0.15, 2.5),
			CFrame.new(-24.4, 10.45, z) * CFrame.Angles(0, 0, math.rad(25)),
			stripe,
			{ material = Enum.Material.Fabric, collide = false }
		)
		Builder.block(shop, "AwningValance", Vector3.new(0.12, 0.7, 2.5), CFrame.new(-26.2, 9.3, z), stripe, {
			material = Enum.Material.Fabric,
			collide = false,
		})
	end
	Builder.sign(
		shop,
		CFrame.lookAt(Vector3.new(-22.8, 12.9, -27), Vector3.new(-40, 12.9, -27)),
		Vector3.new(16, 2.2, 0.4),
		"THE GOLDEN WHEEL",
		C.DoorGreen,
		C.Gold,
		Enum.Font.FredokaOne,
		{ frame = C.Gold, viewFrom = Vector3.new(-40, 5, -27) }
	)
	-- Hanging sign at right angles to the facade (north side of the shop): readable from along the street.
	Builder.box(
		shop,
		"BladeBracket",
		Vector3.new(-25.9, 13.85, -15.3),
		Vector3.new(-22.6, 14.05, -15.1),
		C.Metal,
		{
			material = Enum.Material.Metal,
		}
	)
	Builder.sign(
		shop,
		CFrame.lookAt(Vector3.new(-24.5, 12.9, -15.2), Vector3.new(-24.5, 12.9, 0)),
		Vector3.new(2.6, 1.6, 0.2),
		"CHEESE",
		C.Gold,
		C.DoorGreen,
		Enum.Font.FredokaOne,
		{ doubleSided = true, frame = C.DoorGreen, viewFrom = Vector3.new(-32, 5, -2) }
	)

	-- Side walls and back wall (the staff door E1 to the hall is 6 wide, 9 high).
	Builder.box(
		shop,
		"ShopWallSouth",
		Vector3.new(-22, 0, -40.6),
		Vector3.new(0, GROUND_H, -40),
		C.Cream,
		PLASTER
	)
	Builder.box(
		shop,
		"ShopWallNorth",
		Vector3.new(-22, 0, -14.6),
		Vector3.new(0, GROUND_H, -14),
		C.Cream,
		PLASTER
	)
	Builder.box(shop, "ShopBackA", Vector3.new(-0.6, 0, -40), Vector3.new(0, GROUND_H, -23), C.Cream, PLASTER)
	Builder.box(shop, "ShopBackB", Vector3.new(-0.6, 0, -17), Vector3.new(0, GROUND_H, -14), C.Cream, PLASTER)
	Builder.box(
		shop,
		"ShopBackLintel",
		Vector3.new(-0.6, 9, -23),
		Vector3.new(0, GROUND_H, -17),
		C.Cream,
		PLASTER
	)
	local e1 = Doors.entrance(shop, {
		id = "E1",
		a = Vector3.new(-0.5, 0.2, -23),
		b = Vector3.new(-0.5, 0.2, -17),
		height = 9,
		approach = -Vector3.xAxis,
		offset = 0.8,
	})
	local staffDoor = Doors.leaf(
		e1,
		"StaffDoor",
		Vector3.new(-0.5, 0.2, -23),
		Vector3.new(-0.5, 0.2, -17),
		8.8,
		Vector3.xAxis
	)
	Doors.pryable(staffDoor, Config.Gadgets.Crowbar.DoorSeconds)
	Doors.threshold(shop, Vector3.new(-2, 0.2, -23), Vector3.new(-2, 0.2, -17), 1)
	Builder.sign(
		shop,
		CFrame.lookAt(Vector3.new(-1.2, 10.1, -20), Vector3.new(-10, 10.1, -20)),
		Vector3.new(4.4, 1, 0.2),
		"STAFF ONLY",
		Color3.fromRGB(200, 40, 40),
		C.Trim,
		Enum.Font.GothamBold,
		{ viewFrom = Vector3.new(-11, 5, -20) }
	)

	-- Furnishing: counter with the till, cheese shelves, display table, two window stands.
	Builder.box(shop, "Counter", Vector3.new(-12, 0.2, -36), Vector3.new(-9, 3.6, -28), C.WoodDark, {
		material = Enum.Material.Wood,
	})
	Builder.box(
		shop,
		"CounterTop",
		Vector3.new(-12.3, 3.6, -36.3),
		Vector3.new(-8.7, 3.9, -27.7),
		C.Wood,
		PLANKS
	)
	Builder.box(shop, "Register", Vector3.new(-11.4, 3.9, -30.2), Vector3.new(-9.6, 5, -28.6), C.Metal, {
		material = Enum.Material.Metal,
	})
	for row = 0, 2 do
		local y = 1 + row * 3.2
		Builder.box(
			shop,
			"WallShelf",
			Vector3.new(-20, y, -39.8),
			Vector3.new(-8, y + 0.3, -37.6),
			C.Wood,
			PLANKS
		)
		for i = 0, 3 do
			-- The middle shelf's last slot is a loot anchor (x -9.5).
			if not (row == 1 and i == 3) then
				cheese(shop, Vector3.new(-18.5 + i * 3, y + 0.3, -38.7), rng:NextInteger(0, 359))
			end
		end
	end
	Builder.box(shop, "DisplayTable", Vector3.new(-19, 0.2, -36), Vector3.new(-15, 2.6, -31), C.WoodDark, {
		material = Enum.Material.Wood,
	})
	-- Cheese pyramid (props only): three at the bottom, one on top.
	local stackTop = 2.6
	for i, offset in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(0, 0, 1) } do
		local wheel = Builder.prop(shop, "CheeseWheel", Vector3.new(-17, 2.6, -33.5) + offset, i * 40, {
			scale = 0.75,
			collide = false,
		})
		stackTop = math.max(stackTop, Builder.topOf(wheel) or 2.6)
	end
	Builder.prop(
		shop,
		"CheeseWheel",
		Vector3.new(-17, stackTop, -33.6),
		20,
		{ scale = 0.75, collide = false }
	)
	local function windowStand(z0: number, z1: number, cheeses: { number })
		Builder.box(
			shop,
			"WindowStand",
			Vector3.new(-21.4, 0.2, z0),
			Vector3.new(-19.8, 2.2, z1),
			C.WoodDark,
			{
				material = Enum.Material.Wood,
			}
		)
		for i, z in cheeses do
			cheese(shop, Vector3.new(-20.6, 2.2, z), i * 50, 1)
		end
	end
	windowStand(-37.5, -30, { -36.5, -30.8 })
	windowStand(-22.5, -16.5, { -21.6, -17.4 })
	Builder.sign(
		shop,
		CFrame.lookAt(Vector3.new(-12, 6.8, -14.75), Vector3.new(-12, 6.8, -30)),
		Vector3.new(7, 3.4, 0.2),
		"FRESH GOUDA\nYOUNG AND OLD",
		Color3.fromRGB(30, 34, 32),
		Color3.fromRGB(235, 235, 225),
		Enum.Font.PatrickHand,
		{ viewFrom = Vector3.new(-12, 5, -24) }
	)
	lamp(shop, "ShopLamp1", Vector3.new(-12, 11, -32), 22, nil, true)
	lamp(shop, "ShopLamp2", Vector3.new(-12, 11, -20), 22)
	closetStairwell(shop)

	upperFacade(parent, -40, -14, C.BrickRed, true, "step", rng)
end

-- The holding cell in the security room's west half (beta-spec §3.4 cell contract): bars on x -12 and z -4
-- (10 high, top rail), a sliding CellDoor (x -12, z -10.5..-5.5), 4 CellSpots, CellDropoff, CellExit, and the
-- CellGrate (a drain on the quay, 20 studs away). Bars, rails and door carry the SeeThrough tag.
local function holdingCell(level: Folder)
	local cell = Builder.folder(level, "Cell")
	CollectionService:AddTag(cell, Tags.Cell)
	local steel = Color3.fromRGB(110, 116, 128)
	local barOpts: Builder.PartOpts = { material = Enum.Material.Metal }
	local function seeThrough(part: BasePart)
		CollectionService:AddTag(part, Tags.SeeThrough)
	end
	local function bar(x: number, z: number)
		seeThrough(
			Builder.box(
				cell,
				"CellBar",
				Vector3.new(x - 0.12, 0.2, z - 0.12),
				Vector3.new(x + 0.12, 9.7, z + 0.12),
				steel,
				barOpts
			)
		)
	end
	-- Bars along x = -12 (door gap z -10.5..-5.5) and along z = -4.
	for _, z in { -13.2, -12.3, -11.4, -10.6, -5.4, -4.6 } do
		bar(-12, z)
	end
	for x = -21.2, -12.4, 0.88 do
		bar(x, -4)
	end
	bar(-12, -4)
	for _, y in { 0.2, 9.7 } do
		local h = if y > 1 then 0.4 else 0.3
		seeThrough(
			Builder.box(
				cell,
				"CellRail",
				Vector3.new(-12.2, y, -13.4),
				Vector3.new(-11.8, y + h, -4),
				steel,
				barOpts
			)
		)
		seeThrough(
			Builder.box(
				cell,
				"CellRail",
				Vector3.new(-21.4, y, -4.2),
				Vector3.new(-12, y + h, -3.8),
				steel,
				barOpts
			)
		)
	end
	local door = Builder.box(
		cell,
		"CellDoor",
		Vector3.new(-12.15, 0.2, -10.5),
		Vector3.new(-11.85, 9.6, -5.5),
		steel,
		{ material = Enum.Material.DiamondPlate, transparency = 0.35 }
	)
	door:SetAttribute(Tags.ClosedCFrame, door.CFrame)
	door:SetAttribute("OpenCFrame", door.CFrame * CFrame.new(0.4, 0, -5))
	CollectionService:AddTag(door, Tags.CellDoor)
	seeThrough(door)
	Builder.box(cell, "CellBench", Vector3.new(-21.2, 0.2, -13.4), Vector3.new(-13, 1.6, -12.4), C.WoodDark, {
		material = Enum.Material.Wood,
	})
	Builder.sign(
		cell,
		CFrame.lookAt(Vector3.new(-11.6, 10.6, -8), Vector3.new(0, 10.6, -8)),
		Vector3.new(5, 1, 0.2),
		"HOLDING CELL",
		Color3.fromRGB(38, 52, 84),
		C.Trim,
		Enum.Font.GothamBold,
		{ viewFrom = Vector3.new(-2, 5, -8) }
	)
	for _, p in
		{
			Vector3.new(-19, 0.2, -11),
			Vector3.new(-15, 0.2, -11),
			Vector3.new(-19, 0.2, -7),
			Vector3.new(-15, 0.2, -7),
		}
	do
		Anchors.point(cell, "CellSpot", Tags.CellSpot, p)
	end
	Anchors.point(cell, "CellDropoff", Tags.CellDropoff, Vector3.new(-9.5, 0.2, -8))
	Anchors.point(cell, "CellExit", Tags.CellExit, Vector3.new(-8, 0.2, -10))
	-- Self-escape: out through a drain on the quay (another area, 20 studs from the cell).
	Builder.box(
		cell,
		"QuayDrain",
		Vector3.new(-33, 0, -23),
		Vector3.new(-31, 0.06, -21),
		Color3.fromRGB(28, 30, 34),
		{
			material = Enum.Material.DiamondPlate,
			collide = false,
		}
	)
	Anchors.point(cell, "CellGrate", Tags.CellGrate, Vector3.new(-32, 0.2, -22))
end

local function buildSecurityRoom(parent: Instance, level: Folder, rng: Random)
	local room = Builder.folder(parent, "SecurityRoom")
	Builder.box(room, "SecurityFloor", Vector3.new(-22, 0, -14), Vector3.new(0, 0.2, 4), C.StoneDark, {
		material = Enum.Material.Slate,
	})
	-- Facade with a barred window.
	local function front(name: string, z0: number, z1: number, y0: number, y1: number)
		Builder.box(room, name, Vector3.new(-22.6, y0, z0), Vector3.new(-21.4, y1, z1), C.PaintNavy, PLASTER)
	end
	front("Front", -14, -7, 0, GROUND_H)
	front("FrontB", -2, 4, 0, GROUND_H)
	front("FrontBelow", -7, -2, 0, 4)
	front("FrontAbove", -7, -2, 9, GROUND_H)
	Builder.block(
		room,
		"BarredGlass",
		Vector3.new(0.2, 5, 5),
		CFrame.new(-22, 6.5, -4.5),
		Color3.fromRGB(120, 170, 220),
		{
			material = Enum.Material.Glass,
			transparency = 0.5,
		}
	)
	for i = 0, 4 do
		Builder.block(
			room,
			"Bar",
			Vector3.new(0.25, 5, 0.25),
			CFrame.new(-22.5, 6.5, -6.6 + i * 1.05),
			C.Metal,
			{
				material = Enum.Material.Metal,
			}
		)
	end
	Builder.box(room, "WallNorth", Vector3.new(-22, 0, 3.4), Vector3.new(0, GROUND_H, 4), C.Plaster, PLASTER)
	-- Desk with monitors (cold blue light) against the north wall, 6 studs clear of the hall opening; chair, locker.
	Builder.box(
		room,
		"Desk",
		Vector3.new(-15, 0.2, 0.4),
		Vector3.new(-7, 3.2, 3.4),
		C.Metal,
		{ material = Enum.Material.Metal }
	)
	for i = 0, 2 do
		Builder.block(
			room,
			"Monitor",
			Vector3.new(2.4, 1.6, 0.25),
			CFrame.new(-13.5 + i * 2.6, 4.4, 2.7) * CFrame.Angles(0, math.rad(180), 0),
			Color3.fromRGB(110, 200, 255),
			{ material = Enum.Material.Neon }
		)
	end
	Builder.box(
		room,
		"Chair",
		Vector3.new(-12, 0.2, -2.1),
		Vector3.new(-10, 2.4, -0.1),
		Color3.fromRGB(30, 30, 34)
	)
	Builder.box(
		room,
		"ChairBack",
		Vector3.new(-12, 2.4, -2.2),
		Vector3.new(-10, 4.6, -1.8),
		Color3.fromRGB(30, 30, 34)
	)
	Builder.box(
		room,
		"EvidenceLocker",
		Vector3.new(-21, 0.2, 0),
		Vector3.new(-17, 7, 3),
		Color3.fromRGB(90, 96, 110),
		{
			material = Enum.Material.DiamondPlate,
		}
	)
	lamp(room, "SecurityLamp", Vector3.new(-6, 12, -5), 20, Color3.fromRGB(200, 225, 255))
	holdingCell(level)

	upperFacade(parent, -14, 4, C.PaintNavy, false, "spout", rng)
end

local function buildCourtyard(parent: Instance, rng: Random)
	local yard = Builder.folder(parent, "Courtyard")
	Builder.box(yard, "YardGround", Vector3.new(-22, 0, 4), Vector3.new(0, 0.15, 40), C.StoneDark, {
		material = Enum.Material.Cobblestone,
		variant = "CC_Cobble",
	})
	-- Wall on the quay with the Delivery Gate (entrance E2, padlock: pry 3 s, noisy).
	Builder.box(yard, "YardWallA", Vector3.new(-22.6, 0, 4), Vector3.new(-21.4, 10, 16), C.BrickDark, BRICK)
	Builder.box(
		yard,
		"YardWallB",
		Vector3.new(-22.6, 0, 24),
		Vector3.new(-21.4, 10, 40.6),
		C.BrickDark,
		BRICK
	)
	Builder.box(yard, "GatePostA", Vector3.new(-23, 0, 15.2), Vector3.new(-21, 11, 16.2), C.Stone, {
		material = Enum.Material.Granite,
	})
	Builder.box(yard, "GatePostB", Vector3.new(-23, 0, 23.8), Vector3.new(-21, 11, 24.8), C.Stone, {
		material = Enum.Material.Granite,
	})
	local e2 = Doors.entrance(yard, {
		id = "E2",
		a = Vector3.new(-22, 0.3, 16.2),
		b = Vector3.new(-22, 0.3, 23.8),
		height = 9,
		approach = -Vector3.xAxis,
		offset = 1.1,
	})
	local gate = Builder.box(
		e2,
		"DeliveryGate",
		Vector3.new(-22.3, 0, 16.2),
		Vector3.new(-21.7, 9, 23.8),
		Color3.fromRGB(40, 44, 50),
		{
			material = Enum.Material.DiamondPlate,
			transparency = 0.25,
		}
	)
	Doors.pryable(gate, Config.Gadgets.Crowbar.CageSeconds)
	Builder.block(yard, "Padlock", Vector3.new(0.4, 0.8, 0.6), CFrame.new(-22.55, 4.5, 21.5), C.Gold, {
		material = Enum.Material.Foil,
		collide = false,
	})
	Doors.threshold(yard, Vector3.new(-20.9, 0.15, 16.2), Vector3.new(-20.9, 0.15, 23.8), 1)
	-- Beam between the gate posts that holds the sign (not against the wall cap: half the text would vanish).
	Builder.box(yard, "GateBeam", Vector3.new(-22.6, 11, 15.2), Vector3.new(-21.4, 11.4, 24.8), C.Stone, {
		material = Enum.Material.Granite,
	})
	Builder.sign(
		yard,
		CFrame.lookAt(Vector3.new(-22.9, 12, 20), Vector3.new(-40, 12, 20)),
		Vector3.new(7, 1.2, 0.3),
		"DELIVERIES",
		C.Trim,
		C.DoorGreen,
		Enum.Font.GothamBold,
		{ viewFrom = Vector3.new(-34, 5, 20) }
	)
	Builder.sign(
		yard,
		CFrame.lookAt(Vector3.new(-22.8, 6.5, 10), Vector3.new(-40, 6.5, 10)),
		Vector3.new(4.4, 2, 0.2),
		"BEWARE OF\nTHE DOG",
		Color3.fromRGB(240, 200, 40),
		Color3.fromRGB(30, 30, 30),
		Enum.Font.GothamBold,
		{ viewFrom = Vector3.new(-36, 5, 10) }
	)
	Builder.box(yard, "YardWallNorth", Vector3.new(-22, 0, 40), Vector3.new(0, 10, 40.6), C.BrickDark, BRICK)
	-- East wall towards the Back Alley, with a 6-wide gap (z 27..33): a loop hall ↔ courtyard ↔ Back Alley.
	Builder.box(yard, "YardWallEastA", Vector3.new(-0.6, 0, 25), Vector3.new(0, 10, 27), C.BrickDark, BRICK)
	Builder.box(yard, "YardWallEastB", Vector3.new(-0.6, 0, 33), Vector3.new(0, 10, 40), C.BrickDark, BRICK)
	Builder.box(yard, "WallCap", Vector3.new(-23, 10, 4), Vector3.new(-21, 10.4, 40.6), C.Stone, {
		material = Enum.Material.Granite,
	})

	-- Furnishing: dog kennel, crates, pallet, mud puddle.
	Builder.prop(yard, "Kennel", Vector3.new(-4, 0.15, 35), 180, {
		fallback = function(p, g)
			return Builder.block(
				p,
				"KennelStub",
				Vector3.new(4, 4, 4),
				CFrame.new(g + Vector3.new(0, 2, 0)),
				C.Wood,
				{
					material = Enum.Material.WoodPlanks,
				}
			)
		end,
	})
	for i, pos in
		{
			Vector3.new(-18, 0.15, 36),
			Vector3.new(-14, 0.15, 36),
			Vector3.new(-18, 4.15, 36),
			Vector3.new(-18, 0.15, 32),
		}
	do
		Builder.prop(yard, "Crate", pos, i * 7, {
			fallback = function(p, g)
				return Builder.block(
					p,
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
	Builder.box(yard, "Pallet", Vector3.new(-12, 0.15, 6), Vector3.new(-8, 0.7, 10), C.Wood, PLANKS)
	Builder.box(
		yard,
		"MudPuddle",
		Vector3.new(-20, 0.15, 17),
		Vector3.new(-14, 0.22, 23),
		Color3.fromRGB(70, 52, 36),
		{
			material = Enum.Material.Mud,
			collide = false,
		}
	)
	-- Lamp above the back door of the hall, a wall lantern by the gate and a string of lights.
	lamp(yard, "YardLamp", Vector3.new(-1.5, 9.5, 17), 24, nil, true)
	local gateLamp = Builder.block(
		yard,
		"GateLantern",
		Vector3.new(0.8, 1.2, 0.8),
		CFrame.new(-20.8, 8.6, 13.6),
		C.LampWarm,
		{
			material = Enum.Material.Neon,
			collide = false,
		}
	)
	Builder.pointLight(gateLamp, 18, 1.2, C.LampWarm)
	gateLamp:SetAttribute(Tags.Disabled, false)
	CollectionService:AddTag(gateLamp, Tags.Lamp)
	CollectionService:AddTag(gateLamp, Tags.Electronic)
	for i = 0, 7 do
		local t = i / 7
		local pos = Vector3.new(-20 + t * 18, 9.4 - math.sin(t * math.pi) * 1.4, 30)
		local bulb = Builder.block(
			yard,
			"StringLight",
			Vector3.new(0.35, 0.35, 0.35),
			CFrame.new(pos),
			Color3.fromRGB(255, 214, 150),
			{
				material = Enum.Material.Neon,
				shape = Enum.PartType.Ball,
				collide = false,
				shadow = false,
			}
		)
		if i == 2 or i == 5 then
			Builder.pointLight(bulb, 12, 0.6, Color3.fromRGB(255, 200, 140))
		end
	end
	Builder.box(
		yard,
		"StringWire",
		Vector3.new(-20, 9.38, 29.97),
		Vector3.new(-2, 9.42, 30.03),
		C.StoneDark,
		{
			collide = false,
			shadow = false,
		}
	)
	-- Ivy on the yard walls.
	local ivy = { Color3.fromRGB(44, 82, 46), Color3.fromRGB(56, 96, 52), Color3.fromRGB(36, 70, 42) }
	for i = 0, 9 do
		local z = 25 + rng:NextNumber(0, 14)
		local h = rng:NextNumber(3, 8)
		Builder.block(
			yard,
			"Ivy",
			Vector3.new(0.5, h, rng:NextNumber(1.6, 3.2)),
			CFrame.new(-21.15, h / 2, z),
			ivy[i % 3 + 1],
			{
				material = Enum.Material.LeafyGrass,
				collide = false,
			}
		)
	end
	for i = 0, 7 do
		local x = -20 + rng:NextNumber(0, 18)
		local h = rng:NextNumber(3, 9)
		Builder.block(
			yard,
			"Ivy",
			Vector3.new(rng:NextNumber(1.6, 3.2), h, 0.5),
			CFrame.new(x, h / 2, 39.75),
			ivy[i % 3 + 1],
			{
				material = Enum.Material.LeafyGrass,
				collide = false,
			}
		)
	end
	-- A bike and planters: the yard belongs to people, not to a factory.
	Builder.prop(yard, "Bicycle", Vector3.new(-9, 0.15, 38.4), 90, { collide = false })
	Builder.prop(yard, "TulipBoxTall", Vector3.new(-20.2, 0.15, 27), 90, { collide = false })
	Builder.prop(yard, "TulipBoxTall", Vector3.new(-20.2, 0.15, 33), 90, { collide = false })
end

-- Landmark: the Golden Wheel (Ø 10, gold neon rim) on a mast above the shop roof, high enough to be seen from the
-- quay, the yard and the alleys. Tagged Spinner: a client turns it once per SpinSeconds around SpinAxis.
local function landmark(parent: Instance)
	local center = Vector3.new(-9, 45, -27)
	Builder.box(
		parent,
		"WheelMast",
		Vector3.new(-9.5, 29, -27.5),
		Vector3.new(-8.5, center.Y - 1, -26.5),
		C.Metal,
		{
			material = Enum.Material.Metal,
		}
	)
	for _, s in { -1, 1 } do
		Builder.block(
			parent,
			"WheelBrace",
			Vector3.new(0.4, 9, 0.4),
			CFrame.new(-9, 33, -27 + s * 2.5) * CFrame.Angles(math.rad(s * 18), 0, 0),
			C.Metal,
			{ material = Enum.Material.Metal }
		)
	end
	local model = Instance.new("Model")
	model.Name = "GoldenWheelSign"
	local hub = Builder.block(model, "Hub", Vector3.new(1.4, 2, 2), CFrame.new(center), C.Gold, {
		material = Enum.Material.Foil,
		shape = Enum.PartType.Cylinder,
	})
	Builder.block(
		model,
		"CheeseFace",
		Vector3.new(0.3, 9, 9),
		CFrame.new(center + Vector3.new(0.2, 0, 0)),
		C.Cheese,
		{
			shape = Enum.PartType.Cylinder,
		}
	)
	local radius = 5
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local p = center + Vector3.new(0, radius * math.cos(a), radius * math.sin(a))
		Builder.block(
			model,
			"Rim",
			Vector3.new(0.7, 0.7, 2 * radius * math.tan(math.rad(15)) + 0.1),
			CFrame.new(p) * CFrame.Angles(a, 0, 0),
			C.Gold,
			{ material = Enum.Material.Neon, shadow = false }
		)
	end
	for i = 0, 5 do
		local a = math.rad(i * 60)
		local p = center + Vector3.new(0, radius / 2 * math.cos(a), radius / 2 * math.sin(a))
		Builder.block(
			model,
			"Spoke",
			Vector3.new(0.6, radius - 0.6, 0.45),
			CFrame.new(p) * CFrame.Angles(a, 0, 0),
			C.Gold,
			{
				material = Enum.Material.Foil,
			}
		)
	end
	model.PrimaryPart = hub
	model:SetAttribute("SpinSeconds", 10)
	model:SetAttribute("SpinAxis", Vector3.xAxis)
	CollectionService:AddTag(model, Tags.Spinner)
	model.Parent = parent
end

function Shop.build(level: Folder, rng: Random)
	-- The Folder in Workspace.Level is called "GoldenWheel" (as before).
	local building = Builder.folder(level, "GoldenWheel")
	buildShop(building, rng)
	buildSecurityRoom(building, level, rng)
	buildCourtyard(building, rng)
	landmark(building)
end

return Shop
