--!strict
-- Corner Cheese, the shop (x −12..8, z −8..12) and the alley behind its side door (z 12..22). Inside: the counter
-- with three cheese cubes and the till (Small anchors), the display wheel (Medium) and the Golden Gouda on its
-- pedestal (Main, Scale 0.6). TutorialTriggers: "GuardAhead" on the quay before the door (crouch hint) and
-- "SneakedPastGuard" just inside the front door (onboarding step). The alley has the barrel hide spot.
-- Doors are 6 wide and 9 high; the floor inside is 0.2 higher than the street.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Builder = require(script.Parent.Parent.Common.Builder)
local Style = require(script.Parent.Parent.Garage.Style)
local Street = require(script.Parent.Street)

local C = Builder.Colors
local V = Vector3.new

type Context = Street.Context

local Shop = {}

local X0, X1, Z0, Z1 = -12, 8, -8, 12 -- outer walls
local WALL = 0.6
local FLOOR = 0.2
local CEILING = 10
local TOP = 11 -- top of the ground-floor walls
local DOOR = { 5.4, 11.4 } -- front door (z)
local SIDE_DOOR = { 0, 6 } -- side door (x) in the north wall
local SHOPFRONT = Color3.fromRGB(30, 70, 52)

local function walls(ctx: Context, f: Instance)
	local k = ctx.k
	local brick = C.BrickRed
	-- Front (shopfront, painted green): shop window z −6.4..1.4, door z 5.4..11.4.
	k.box(f, "Shopfront", V(X0, 0, Z0 + WALL), V(X0 + WALL, TOP, -6.4), SHOPFRONT, Style.wood())
	k.box(f, "Shopfront", V(X0, 0, -6.4), V(X0 + WALL, 2.5, 1.4), SHOPFRONT, Style.wood())
	k.box(f, "Shopfront", V(X0, 8, -6.4), V(X0 + WALL, TOP, 1.4), SHOPFRONT, Style.wood())
	k.box(f, "Shopfront", V(X0, 0, 1.4), V(X0 + WALL, TOP, DOOR[1]), SHOPFRONT, Style.wood())
	k.box(f, "Shopfront", V(X0, 9, DOOR[1]), V(X0 + WALL, TOP, DOOR[2]), SHOPFRONT, Style.wood())
	k.box(f, "ShopWindow", V(X0 + 0.2, 2.5, -6.4), V(X0 + 0.4, 8, 1.4), Color3.fromRGB(255, 214, 160), {
		material = Enum.Material.Glass,
		transparency = 0.5,
		shadow = false,
	})
	k.box(f, "WindowBar", V(X0 - 0.1, 5.1, -6.4), V(X0 + 0.2, 5.3, 1.4), C.Trim, { shadow = false })
	-- Door trim on the facade (outside the opening, so the doorway stays 6 wide).
	k.box(f, "DoorTrim", V(X0 - 0.2, 0, DOOR[1] - 0.4), V(X0, 9.4, DOOR[1]), C.Trim)
	k.box(f, "DoorTrim", V(X0 - 0.2, 0, DOOR[2]), V(X0, 9.4, DOOR[2] + 0.4), C.Trim)
	k.box(f, "DoorTrim", V(X0 - 0.2, 9, DOOR[1] - 0.4), V(X0, 9.4, DOOR[2] + 0.4), C.Trim)
	-- South and back walls.
	k.box(f, "Wall", V(X0, 0, Z0), V(X1, TOP, Z0 + WALL), brick, Style.brick())
	k.box(f, "Wall", V(X1 - WALL, 0, Z0 + WALL), V(X1, TOP, Z1 - WALL), brick, Style.brick())
	-- North wall: a lit window and the side door to the alley.
	local zn = Z1 - WALL
	k.box(f, "Wall", V(X0, 0, zn), V(-9, TOP, Z1), brick, Style.brick())
	k.box(f, "Wall", V(-9, 0, zn), V(-5, 4, Z1), brick, Style.brick())
	k.box(f, "Wall", V(-9, 7, zn), V(-5, TOP, Z1), brick, Style.brick())
	k.box(f, "SideWindow", V(-9, 4, zn + 0.2), V(-5, 7, zn + 0.4), C.WindowLit, {
		material = Enum.Material.Neon,
		shadow = false,
	})
	k.box(f, "Wall", V(-5, 0, zn), V(SIDE_DOOR[1], TOP, Z1), brick, Style.brick())
	k.box(f, "Wall", V(SIDE_DOOR[1], 9, zn), V(SIDE_DOOR[2], TOP, Z1), brick, Style.brick())
	k.box(f, "Wall", V(SIDE_DOOR[2], 0, zn), V(X1, TOP, Z1), brick, Style.brick())
	-- Floor and ceiling.
	k.box(f, "ShopFloor", V(X0 + WALL, 0, Z0 + WALL), V(X1 - WALL, FLOOR, Z1 - WALL), C.Wood, {
		material = Enum.Material.WoodPlanks,
	})
	k.box(f, "Ceiling", V(X0 + WALL, CEILING, Z0 + WALL), V(X1 - WALL, TOP, Z1 - WALL), C.Plaster, {
		material = Enum.Material.Plaster,
	})
end

-- The upper storey with its windows, cornice and step gable, and the shop sign.
local function upper(ctx: Context, f: Instance)
	local k = ctx.k
	k.box(f, "UpperStorey", V(X0, TOP, Z0), V(X1, 18, Z1), C.BrickWarm, Style.brick())
	for _, z in { -4, 2, 8 } do
		k.window(f, CFrame.lookAt(V(X0 - 0.05, 14.5, z), V(X0 - 1, 14.5, z)), 2.4, 3.6, true)
	end
	k.box(f, "Cornice", V(X0 - 0.5, 18, Z0 - 0.2), V(X0 + 0.4, 18.8, Z1 + 0.2), C.Trim)
	k.box(f, "Roof", V(X0 + 0.4, 18, Z0), V(X1, 18.6, Z1), C.StoneDark, { material = Enum.Material.Slate })
	for i, width in { 16, 11, 6 } do
		local y = 18.8 + (i - 1) * 2.6
		k.box(
			f,
			"GableStep",
			V(X0, y, 2 - width / 2),
			V(X0 + 1, y + 2.6, 2 + width / 2),
			C.BrickWarm,
			Style.brick()
		)
	end
	k.sign(f, "CORNER CHEESE", V(X0 - 0.35, 10.4, 2), V(-1, 0, 0), 14.4, 2, ctx.points.Spawn + V(0, 1.5, 0), {
		bg = SHOPFRONT,
		fg = C.Gold,
		frame = C.Gold,
	})
end

local function interior(ctx: Context, f: Instance)
	local k, slot, session = ctx.k, ctx.slot, ctx.session
	-- Counter along x −4 with the till and three cubes (the cubes and the till are loot).
	k.box(f, "Counter", V(-5, FLOOR, -7), V(-3, 3, 1), C.WoodDark, Style.wood())
	k.box(f, "CounterTop", V(-5.2, 3, -7.1), V(-2.8, 3.2, 1.1), C.Cream, { material = Enum.Material.Marble })
	local smalls: { { id: string, z: number, group: string? } } = {
		{ id = "Till", z = -5.8, group = "Drawer" },
		{ id = "Cube1", z = -3.8 },
		{ id = "Cube2", z = -1.8 },
		{ id = "Cube3", z = 0.2 },
	}
	for _, item in smalls do
		k.anchor(ctx.anchors, `Counter{item.id}`, CFrame.new(-4, 3.2, item.z), {
			AnchorClass = "Small",
			AnchorId = `T{slot}_Counter{item.id}`,
			Zone = "Shop",
			Fixed = true,
			Group = item.group,
			Session = session,
		}, Tags.LootAnchor)
	end
	-- Display table with the extra wheel.
	k.box(f, "DisplayTable", V(-4, FLOOR, 8), V(-1, 2.2, 11), C.Wood, Style.wood())
	k.box(f, "DisplayTop", V(-4.1, 2.2, 7.9), V(-0.9, 2.4, 11.1), C.WoodDark, Style.wood())
	k.anchor(ctx.anchors, "DisplayWheel", CFrame.new(-2.5, 2.4, 9.5), {
		AnchorClass = "Medium",
		AnchorId = `T{slot}_DisplayWheel`,
		Zone = "Shop",
		Fixed = true,
		Session = session,
	}, Tags.LootAnchor)
	-- The Golden Gouda on its pedestal, under a spotlight.
	local gouda = ctx.points.Gouda
	k.cylinder(f, "Pedestal", 3.6, gouda.Y - FLOOR, V(gouda.X, (gouda.Y + FLOOR) / 2, gouda.Z), C.Cream, {
		material = Enum.Material.Marble,
	})
	k.cylinder(f, "PedestalRim", 3.8, 0.15, V(gouda.X, gouda.Y - 0.05, gouda.Z), C.Gold, {
		material = Enum.Material.Foil,
		collide = false,
	})
	k.anchor(ctx.anchors, "Gouda", CFrame.new(gouda), {
		AnchorClass = "Main",
		AnchorId = `T{slot}_Gouda`,
		Zone = "Shop",
		Fixed = true,
		Scale = 0.6,
		Session = session,
	}, Tags.LootAnchor)
	local fixture =
		k.block(f, "GoudaSpot", V(1, 0.4, 1), CFrame.new(gouda.X, CEILING - 0.2, gouda.Z), C.Metal, {
			shadow = false,
		})
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 50
	spot.Range = 14
	spot.Brightness = 2
	spot.Color = Color3.fromRGB(255, 220, 150)
	spot.Shadows = false
	spot.Parent = fixture
	Style.pendant(k, f, V(-3, 8.4, -2), CEILING, 26, 1.1, true)
	-- Cheese racks against the back wall (scenery, no loot).
	for _, rack in { { -7, -1 }, { 7.2, 11 } } do
		k.box(f, "RackSide", V(6.2, FLOOR, rack[1]), V(7.4, 6.5, rack[1] + 0.2), C.WoodDark, Style.wood())
		k.box(f, "RackSide", V(6.2, FLOOR, rack[2] - 0.2), V(7.4, 6.5, rack[2]), C.WoodDark, Style.wood())
		for _, y in { 2, 4.2 } do
			k.box(f, "RackShelf", V(6.2, y - 0.15, rack[1]), V(7.4, y, rack[2]), C.Wood, Style.wood())
			local z = (rack[1] + rack[2]) / 2
			k.block(
				f,
				"ShelfCheese",
				V(0.8, 1.6, 1.6),
				CFrame.new(6.8, y + 0.8, z) * CFrame.Angles(0, 0, math.rad(90)),
				C.Cheese,
				{ shape = Enum.PartType.Cylinder }
			)
		end
	end
	k.sign(f, "SIDE DOOR", V(3, 9.5, Z1 - WALL - 0.2), V(0, 0, -1), 4.8, 0.9, V(gouda.X, 4.5, gouda.Z))
end

local function triggers(ctx: Context, f: Instance)
	local k = ctx.k
	k.zone(f, "GuardAheadTrigger", V(-21, 0, 2), V(X0, 8, 12), {
		Step = "GuardAhead",
		Session = ctx.session,
	}, Tags.TutorialTrigger)
	k.zone(f, "SneakedPastGuardTrigger", V(X0 + WALL, 0, DOOR[1]), V(-8, 8, DOOR[2]), {
		Step = "SneakedPastGuard",
		Session = ctx.session,
	}, Tags.TutorialTrigger)
end

local function alley(ctx: Context, f: Instance)
	local k = ctx.k
	local brick = C.BrickDark
	k.box(f, "AlleyWall", V(4, 0, 22), V(10.6, 14, 22.6), brick, Style.brick())
	k.box(f, "AlleyWall", V(10, 0, Z1 - WALL), V(10.6, 14, 22), brick, Style.brick())
	k.box(f, "AlleyWall", V(X1, 0, Z1 - WALL), V(10, 14, Z1), brick, Style.brick())
	-- The barrel to hide in (≥ 4 tall; hidden players are parked inside).
	local barrel = ctx.points.Barrel
	Style.hideSpot(k, f, "Barrel", barrel, V(3.2, 4.6, 3.2), V(0, 0, -1), "Barrel", 1.9, Tags.HideSpot)
	-- Wall lamp and the way back to the van.
	k.box(f, "LampBracket", V(4.9, 7.6, 21.2), V(5.1, 7.8, 22), C.Metal, Style.metal())
	local bulb = k.block(f, "AlleyLamp", V(0.6, 0.6, 0.6), CFrame.new(5, 7.4, 21.2), C.LampWarm, {
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		collide = false,
		shadow = false,
	})
	Builder.pointLight(bulb, 18, 1, C.LampWarm, false)
	k.sign(f, "TO THE VAN", V(-2, 6.5, 21.8), V(0, 0, -1), 6.2, 1.1, V(3, 4.5, 13))
end

function Shop.build(ctx: Context)
	local f = Builder.folder(ctx.folder, "CornerCheese")
	walls(ctx, f)
	upper(ctx, f)
	interior(ctx, f)
	triggers(ctx, f)
	alley(ctx, f)
end

return Shop
