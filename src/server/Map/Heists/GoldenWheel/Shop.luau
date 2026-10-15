--!strict
-- De winkel "The Golden Wheel" aan de kade (§10.1): kaaswinkel (A), beveiligingsruimte (B) en binnenkoer (C).
-- A: x -22..0, z -40..-14   B: x -22..0, z -14..4   C: x -22..0, z 4..40 (buiten)
-- De gevels staan op x = -22 en kijken naar de gracht (-X).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Common = script.Parent.Parent.Parent.Common
local Builder = require(Common.Builder)

local C = Builder.Colors

local Shop = {}

local GROUND_H = 14 -- hoogte van de benedenverdieping (plafond)

local function lamp(parent: Instance, name: string, pos: Vector3, range: number, color: Color3?)
	local bulb =
		Builder.block(parent, name, Vector3.new(1.2, 0.6, 1.2), CFrame.new(pos), color or C.LampWarm, {
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
	Builder.pointLight(bulb, range, 1.3, color or C.LampWarm, true)
	bulb:SetAttribute(Tags.Disabled, false)
	CollectionService:AddTag(bulb, Tags.Lamp)
	CollectionService:AddTag(bulb, Tags.Electronic)
	-- Ophangsnoer.
	Builder.block(
		parent,
		"Cord",
		Vector3.new(0.1, GROUND_H - pos.Y, 0.1),
		CFrame.new(pos.X, (GROUND_H + pos.Y) / 2, pos.Z),
		C.StoneDark,
		{
			collide = false,
			shadow = false,
		}
	)
end

local function pryable(part: BasePart, seconds: number)
	part:SetAttribute("PrySeconds", seconds)
	part:SetAttribute(Tags.SpotKind, "lock")
	CollectionService:AddTag(part, Tags.Pryable)
	CollectionService:AddTag(part, Tags.Spottable)
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
	-- Bovenverdiepingen (decor, massief) boven de benedenverdieping.
	local width = zMax - zMin
	local zMid = (zMin + zMax) / 2
	local top = GROUND_H + 14
	local opts: Builder.PartOpts = if brick
		then { material = Enum.Material.Brick, variant = "CC_Brick" }
		else { material = Enum.Material.Plaster }
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
			local cf = CFrame.lookAt(
				Vector3.new(-22.2, GROUND_H + 3.6 + floor * 7, z),
				Vector3.new(-40, GROUND_H + 3.6 + floor * 7, z)
			)
			Builder.window(parent, cf, 2.6, 4, rng:NextNumber() < 0.5)
		end
	end
	-- Topgevel: trap- of halsgevel, uitgelijnd met de gevel.
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
			true
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

local function buildShop(parent: Instance, rng: Random)
	local shop = Builder.folder(parent, "Shop")
	local floorOpts: Builder.PartOpts = { material = Enum.Material.WoodPlanks, variant = "CC_Planks" }
	Builder.box(shop, "ShopFloor", Vector3.new(-22, 0, -40), Vector3.new(0, 0.2, -14), C.Wood, floorOpts)
	-- Gevel benedenverdieping: grote etalage, deur, tweede raam.
	local wallOpts: Builder.PartOpts = { material = Enum.Material.Brick, variant = "CC_Brick" }
	Builder.box(
		shop,
		"FrontPier1",
		Vector3.new(-22.6, 0, -40),
		Vector3.new(-21.4, GROUND_H, -38.5),
		C.BrickRed,
		wallOpts
	)
	Builder.box(
		shop,
		"FrontBelowWindow",
		Vector3.new(-22.6, 0, -38.5),
		Vector3.new(-21.4, 2.4, -29),
		C.BrickRed,
		wallOpts
	)
	Builder.box(
		shop,
		"FrontAboveWindow",
		Vector3.new(-22.6, 10.5, -38.5),
		Vector3.new(-21.4, GROUND_H, -29),
		C.BrickRed,
		wallOpts
	)
	Builder.box(
		shop,
		"FrontPier2",
		Vector3.new(-22.6, 0, -29),
		Vector3.new(-21.4, GROUND_H, -28.5),
		C.BrickRed,
		wallOpts
	)
	Builder.box(
		shop,
		"FrontAboveDoor",
		Vector3.new(-22.6, 9, -28.5),
		Vector3.new(-21.4, GROUND_H, -23.5),
		C.BrickRed,
		wallOpts
	)
	Builder.box(
		shop,
		"FrontPier3",
		Vector3.new(-22.6, 0, -23.5),
		Vector3.new(-21.4, GROUND_H, -23),
		C.BrickRed,
		wallOpts
	)
	Builder.box(
		shop,
		"FrontBelowWindow2",
		Vector3.new(-22.6, 0, -23),
		Vector3.new(-21.4, 2.4, -16),
		C.BrickRed,
		wallOpts
	)
	Builder.box(
		shop,
		"FrontAboveWindow2",
		Vector3.new(-22.6, 10.5, -23),
		Vector3.new(-21.4, GROUND_H, -16),
		C.BrickRed,
		wallOpts
	)
	Builder.box(
		shop,
		"FrontPier4",
		Vector3.new(-22.6, 0, -16),
		Vector3.new(-21.4, GROUND_H, -14),
		C.BrickRed,
		wallOpts
	)
	for _, w in { { -38.5, -29 }, { -23, -16 } } do
		local zMid = (w[1] + w[2]) / 2
		Builder.block(
			shop,
			"DisplayGlass",
			Vector3.new(0.3, 8.1, w[2] - w[1]),
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
			Vector3.new(0.5, 0.4, w[2] - w[1]),
			CFrame.new(-22.1, 10.4, zMid),
			C.DoorGreen
		)
		Builder.block(
			shop,
			"DisplaySill",
			Vector3.new(1.2, 0.4, w[2] - w[1] + 0.4),
			CFrame.new(-22.6, 2.5, zMid),
			C.Stone
		)
		-- Tulpenbak onder de etalage.
		Builder.prop(shop, "TulipBox", Vector3.new(-23.4, Builder.SIDEWALK, zMid), 90, { collide = false })
	end
	-- Luifel in crew-oranje en wit (gestreept): schuine banen die van de gevel naar de straat zakken.
	for i = 0, 9 do
		local z = -39 + i * 2.5 + 1.25
		local stripe = if i % 2 == 0 then C.CrewOrange else C.Trim
		Builder.block(
			shop,
			"Awning",
			Vector3.new(4, 0.15, 2.5),
			CFrame.new(-24.4, 11.7, z) * CFrame.Angles(0, 0, math.rad(25)),
			stripe,
			{ material = Enum.Material.Fabric, collide = false }
		)
		Builder.block(
			shop,
			"AwningValance",
			Vector3.new(0.12, 0.7, 2.5),
			CFrame.new(-26.2, 10.5, z),
			stripe,
			{ material = Enum.Material.Fabric, collide = false }
		)
	end
	-- Uithangbord.
	Builder.sign(
		shop,
		CFrame.lookAt(Vector3.new(-22.8, 12.6, -27), Vector3.new(-40, 12.6, -27)),
		Vector3.new(16, 2.4, 0.4),
		"THE GOLDEN WHEEL",
		C.DoorGreen,
		C.Gold
	)
	Builder.sign(
		shop,
		CFrame.lookAt(Vector3.new(-22.8, 9.6, -26), Vector3.new(-40, 9.6, -26)),
		Vector3.new(3.6, 0.9, 0.2),
		"KAAS · CHEESE",
		C.Trim,
		C.DoorGreen,
		Enum.Font.GothamBold
	)

	-- Zijmuren en achtermuur van de winkel (met personeelsdeur naar de hal).
	Builder.box(
		shop,
		"ShopWallSouth",
		Vector3.new(-22, 0, -40.6),
		Vector3.new(0, GROUND_H, -40),
		C.Cream,
		{ material = Enum.Material.Plaster }
	)
	Builder.box(
		shop,
		"ShopWallNorth",
		Vector3.new(-22, 0, -14.6),
		Vector3.new(0, GROUND_H, -14),
		C.Cream,
		{ material = Enum.Material.Plaster }
	)
	Builder.box(
		shop,
		"ShopBackA",
		Vector3.new(-0.6, 0, -40),
		Vector3.new(0, GROUND_H, -22.5),
		C.Cream,
		{ material = Enum.Material.Plaster }
	)
	Builder.box(
		shop,
		"ShopBackB",
		Vector3.new(-0.6, 0, -17.5),
		Vector3.new(0, GROUND_H, -14),
		C.Cream,
		{ material = Enum.Material.Plaster }
	)
	Builder.box(
		shop,
		"ShopBackLintel",
		Vector3.new(-0.6, 8, -22.5),
		Vector3.new(0, GROUND_H, -17.5),
		C.Cream,
		{ material = Enum.Material.Plaster }
	)
	local staffDoor =
		Builder.box(shop, "StaffDoor", Vector3.new(-0.5, 0, -22.5), Vector3.new(0, 8, -17.5), C.DoorGreen, {
			material = Enum.Material.Wood,
		})
	pryable(staffDoor, Config.Gadgets.Crowbar.DoorSeconds)
	Builder.sign(
		shop,
		CFrame.lookAt(Vector3.new(-0.7, 9, -20), Vector3.new(-10, 9, -20)),
		Vector3.new(3.4, 0.8, 0.2),
		"STAFF ONLY",
		Color3.fromRGB(200, 40, 40),
		C.Trim,
		Enum.Font.GothamBold
	)

	-- Inrichting: toonbank, kassa, kaasrekken, kaaspiramide.
	Builder.box(
		shop,
		"Counter",
		Vector3.new(-12, 0.2, -36),
		Vector3.new(-9, 3.6, -28),
		C.WoodDark,
		{ material = Enum.Material.Wood }
	)
	Builder.box(
		shop,
		"CounterTop",
		Vector3.new(-12.3, 3.6, -36.3),
		Vector3.new(-8.7, 3.9, -27.7),
		C.Wood,
		floorOpts
	)
	Builder.box(
		shop,
		"Register",
		Vector3.new(-11.4, 3.9, -30),
		Vector3.new(-9.6, 5, -28.6),
		C.Metal,
		{ material = Enum.Material.Metal }
	)
	for row = 0, 2 do
		local y = 1 + row * 3.2
		Builder.box(
			shop,
			"WallShelf",
			Vector3.new(-20, y, -39.8),
			Vector3.new(-2, y + 0.3, -37.6),
			C.Wood,
			floorOpts
		)
		for i = 0, 5 do
			Builder.prop(
				shop,
				"CheeseWheel",
				Vector3.new(-18.5 + i * 3, y + 0.3, -38.7),
				rng:NextInteger(0, 359),
				{
					scale = 0.8,
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
				}
			)
		end
	end
	Builder.box(
		shop,
		"DisplayTable",
		Vector3.new(-19, 0.2, -36),
		Vector3.new(-15, 2.6, -31),
		C.WoodDark,
		{ material = Enum.Material.Wood }
	)
	-- Kaaspiramide: drie onderaan, één erbovenop (precies op de bovenkant gestapeld).
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
	-- Etalagetrap met kazen, zichtbaar vanaf de straat.
	Builder.box(
		shop,
		"WindowStand",
		Vector3.new(-21.4, 0.2, -37.5),
		Vector3.new(-19.8, 2.2, -30),
		C.WoodDark,
		{
			material = Enum.Material.Wood,
		}
	)
	for i = 0, 2 do
		Builder.prop(shop, "CheeseWheel", Vector3.new(-20.6, 2.2, -36 + i * 2.6), i * 50, { collide = false })
	end
	-- Krijtbord met het aanbod.
	Builder.sign(
		shop,
		CFrame.lookAt(Vector3.new(-12, 6.8, -14.75), Vector3.new(-12, 6.8, -30)),
		Vector3.new(7, 3.4, 0.2),
		"GOUDA\nYoung · Aged · Extra old",
		Color3.fromRGB(30, 34, 32),
		Color3.fromRGB(235, 235, 225),
		Enum.Font.PatrickHand
	)
	lamp(shop, "ShopLamp1", Vector3.new(-11, 11, -32), 22)
	lamp(shop, "ShopLamp2", Vector3.new(-11, 11, -20), 22)
	-- Karels hok achterin (bezem en emmer).
	Builder.box(
		shop,
		"ClosetWall",
		Vector3.new(-6.5, 0, -40),
		Vector3.new(-6, 9, -33),
		C.Plaster,
		{ material = Enum.Material.Plaster }
	)
	Builder.box(
		shop,
		"ClosetFront",
		Vector3.new(-6, 0, -33.5),
		Vector3.new(-0.6, 9, -33),
		C.Plaster,
		{ material = Enum.Material.Plaster }
	)
	Builder.box(shop, "Broom", Vector3.new(-3, 0.2, -38), Vector3.new(-2.7, 5, -37.7), C.Wood)
	Builder.cylinder(shop, "Bucket", 1.4, 1.4, Vector3.new(-4, 0.9, -38), Color3.fromRGB(60, 110, 170))
	Builder.box(
		shop,
		"ClosetDoor",
		Vector3.new(-4.6, 0.2, -32.98),
		Vector3.new(-2, 7.2, -32.9),
		C.DoorGreen,
		{
			material = Enum.Material.Wood,
		}
	)
	Builder.sign(
		shop,
		CFrame.lookAt(Vector3.new(-3.3, 7.8, -32.85), Vector3.new(-3.3, 7.8, -20)),
		Vector3.new(2.4, 0.6, 0.1),
		"KAREL",
		C.Trim,
		C.DoorGreen,
		Enum.Font.GothamBold
	)

	upperFacade(parent, -40, -14, C.BrickRed, true, "step", rng)
end

local function buildSecurityRoom(parent: Instance, rng: Random)
	local room = Builder.folder(parent, "SecurityRoom")
	Builder.box(
		room,
		"SecurityFloor",
		Vector3.new(-22, 0, -14),
		Vector3.new(0, 0.2, 4),
		C.StoneDark,
		{ material = Enum.Material.Slate }
	)
	-- Gevel met getralied raam.
	Builder.box(
		room,
		"Front",
		Vector3.new(-22.6, 0, -14),
		Vector3.new(-21.4, GROUND_H, -7),
		C.PaintNavy,
		{ material = Enum.Material.Plaster }
	)
	Builder.box(
		room,
		"FrontB",
		Vector3.new(-22.6, 0, -2),
		Vector3.new(-21.4, GROUND_H, 4),
		C.PaintNavy,
		{ material = Enum.Material.Plaster }
	)
	Builder.box(
		room,
		"FrontBelow",
		Vector3.new(-22.6, 0, -7),
		Vector3.new(-21.4, 4, -2),
		C.PaintNavy,
		{ material = Enum.Material.Plaster }
	)
	Builder.box(
		room,
		"FrontAbove",
		Vector3.new(-22.6, 9, -7),
		Vector3.new(-21.4, GROUND_H, -2),
		C.PaintNavy,
		{ material = Enum.Material.Plaster }
	)
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
			{ material = Enum.Material.Metal }
		)
	end
	Builder.box(
		room,
		"WallNorth",
		Vector3.new(-22, 0, 3.4),
		Vector3.new(0, GROUND_H, 4),
		C.Plaster,
		{ material = Enum.Material.Plaster }
	)
	-- Bureau met monitoren (koud blauw licht).
	Builder.box(
		room,
		"Desk",
		Vector3.new(-12, 0.2, 0),
		Vector3.new(-4, 3.2, 3),
		C.Metal,
		{ material = Enum.Material.Metal }
	)
	for i = 0, 2 do
		local screen = Builder.block(
			room,
			"Monitor",
			Vector3.new(2.4, 1.6, 0.25),
			CFrame.new(-10.5 + i * 2.6, 4.4, 2.3) * CFrame.Angles(0, math.rad(180), 0),
			Color3.fromRGB(110, 200, 255),
			{
				material = Enum.Material.Neon,
			}
		)
		local _ = screen
	end
	Builder.box(
		room,
		"Chair",
		Vector3.new(-9, 0.2, -2.5),
		Vector3.new(-7, 2.4, -0.5),
		Color3.fromRGB(30, 30, 34)
	)
	Builder.box(
		room,
		"ChairBack",
		Vector3.new(-9, 2.4, -2.6),
		Vector3.new(-7, 4.6, -2.2),
		Color3.fromRGB(30, 30, 34)
	)
	Builder.box(
		room,
		"EvidenceLocker",
		Vector3.new(-21, 0.2, 0),
		Vector3.new(-17, 7, 3),
		Color3.fromRGB(90, 96, 110),
		{ material = Enum.Material.DiamondPlate }
	)
	lamp(room, "SecurityLamp", Vector3.new(-10, 12, -5), 20, Color3.fromRGB(200, 225, 255))

	upperFacade(parent, -14, 4, C.PaintNavy, false, "spout", rng)
end

local function buildCourtyard(parent: Instance, rng: Random)
	local yard = Builder.folder(parent, "Courtyard")
	local wallOpts: Builder.PartOpts = { material = Enum.Material.Brick, variant = "CC_Brick" }
	Builder.box(yard, "YardGround", Vector3.new(-22, 0, 4), Vector3.new(0, 0.15, 40), C.StoneDark, {
		material = Enum.Material.Cobblestone,
		variant = "CC_Cobble",
	})
	-- Muur aan de kade met de leveringspoort (ketenpunt 1).
	Builder.box(
		yard,
		"YardWallA",
		Vector3.new(-22.6, 0, 4),
		Vector3.new(-21.4, 10, 16),
		C.BrickDark,
		wallOpts
	)
	Builder.box(
		yard,
		"YardWallB",
		Vector3.new(-22.6, 0, 24),
		Vector3.new(-21.4, 10, 40.6),
		C.BrickDark,
		wallOpts
	)
	Builder.box(
		yard,
		"GatePostA",
		Vector3.new(-23, 0, 15.2),
		Vector3.new(-21, 11, 16.2),
		C.Stone,
		{ material = Enum.Material.Granite }
	)
	Builder.box(
		yard,
		"GatePostB",
		Vector3.new(-23, 0, 23.8),
		Vector3.new(-21, 11, 24.8),
		C.Stone,
		{ material = Enum.Material.Granite }
	)
	local gate = Builder.box(
		yard,
		"DeliveryGate",
		Vector3.new(-22.3, 0, 16.2),
		Vector3.new(-21.7, 9, 23.8),
		Color3.fromRGB(40, 44, 50),
		{
			material = Enum.Material.DiamondPlate,
			transparency = 0.25,
		}
	)
	pryable(gate, Config.Gadgets.Crowbar.CageSeconds)
	Builder.block(
		yard,
		"Padlock",
		Vector3.new(0.4, 0.8, 0.6),
		CFrame.new(-22.7, 4.5, 20),
		C.Gold,
		{ material = Enum.Material.Foil, collide = false }
	)
	Builder.sign(
		yard,
		CFrame.lookAt(Vector3.new(-22.8, 10.6, 20), Vector3.new(-40, 10.6, 20)),
		Vector3.new(7, 1.2, 0.3),
		"DELIVERIES",
		C.Trim,
		C.DoorGreen,
		Enum.Font.GothamBold
	)
	Builder.box(
		yard,
		"YardWallNorth",
		Vector3.new(-22, 0, 40),
		Vector3.new(0, 10, 40.6),
		C.BrickDark,
		wallOpts
	)
	Builder.box(yard, "YardWallEast", Vector3.new(-0.6, 0, 25), Vector3.new(0, 10, 40), C.BrickDark, wallOpts)
	Builder.box(
		yard,
		"WallCap",
		Vector3.new(-23, 10, 4),
		Vector3.new(-21, 10.4, 40.6),
		C.Stone,
		{ material = Enum.Material.Granite }
	)

	-- Inrichting: hondenhok, kratten, vaten, pallets, modderplas.
	Builder.prop(yard, "Kennel", Vector3.new(-4, 0.15, 35), 180, {
		fallback = function(p, g)
			return Builder.block(
				p,
				"KennelStub",
				Vector3.new(4, 4, 4),
				CFrame.new(g + Vector3.new(0, 2, 0)),
				C.Wood,
				{ material = Enum.Material.WoodPlanks }
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
					{ material = Enum.Material.WoodPlanks }
				)
			end,
		})
	end
	for i = 0, 2 do
		Builder.prop(yard, "Barrel", Vector3.new(-5 + i * 2.8, 0.15, 8), i * 33, {
			fallback = function(p, g)
				return Builder.cylinder(p, "BarrelStub", 2.6, 3.6, g + Vector3.new(0, 1.8, 0), C.WoodDark)
			end,
		})
	end
	Builder.box(
		yard,
		"Pallet",
		Vector3.new(-12, 0.15, 6),
		Vector3.new(-8, 0.7, 10),
		C.Wood,
		{ material = Enum.Material.WoodPlanks }
	)
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
	-- Lamp boven de achterdeur van de hal.
	lamp(yard, "YardLamp", Vector3.new(-1.5, 9.5, 17), 24)
	-- Muurlantaarn bij de poort en een slinger lampjes boven de koer: gezellig, en je ziet waar je loopt.
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
	Builder.pointLight(gateLamp, 18, 1.2, C.LampWarm, true)
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
		if i % 3 == 1 then
			Builder.pointLight(bulb, 10, 0.5, Color3.fromRGB(255, 200, 140))
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
	-- Klimop op de koermuren.
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
	-- Wasrek, fiets en plantenbakken: de koer is van mensen, niet van een fabriek.
	Builder.prop(yard, "Bicycle", Vector3.new(-19.5, 0.15, 9), 0, { collide = false })
	Builder.prop(yard, "TulipBoxTall", Vector3.new(-20.2, 0.15, 27), 90, { collide = false })
	Builder.prop(yard, "TulipBoxTall", Vector3.new(-20.2, 0.15, 33), 90, { collide = false })
end

function Shop.build(level: Folder, rng: Random)
	-- De Folder in Workspace.Level heet (zoals vroeger) "GoldenWheel".
	local building = Builder.folder(level, "GoldenWheel")
	buildShop(building, rng)
	buildSecurityRoom(building, rng)
	buildCourtyard(building, rng)
end

return Shop
