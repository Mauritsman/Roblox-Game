--!strict
-- The ripening hall (D) with the cage (2 doors), the office on the mezzanine (E, Secure: keycard gate, safe,
-- Cheese Chute), the Loading Dock, the Fire Exit (loud-only) and all six security cameras.
-- Hall: x 0..60, z -25..25, walls 20 high. Racks at z ±9 in three sections (x 10..16.5, 22.5..29, 35..41.5) with
-- 6-wide cross-aisles. West wall openings: staff door E1 (z -23..-17), security room (z -4..4), courtyard back door
-- (z 14..20), chute opening (z 21..24, y 9.2..13). North wall: Fire Exit x 50..56. East wall: Loading Dock z 12..20.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Common = script.Parent.Parent.Parent.Common
local Builder = require(Common.Builder)
local Doors = require(Common.Doors)
local Rides = require(Common.Rides)
local Security = require(Common.Security)

local Layout = require(script.Parent.Layout)

local C = Builder.Colors

local Warehouse = {}

-- 20 high: enough clearance above and below the mezzanine for Roblox's pathfinder (4-stud cells).
local WALL_H = 20
local TRUSS_Y = WALL_H - 1.4
local BRICK: Builder.PartOpts = { material = Enum.Material.Brick, variant = "CC_Brick" }
local PLASTER: Builder.PartOpts = { material = Enum.Material.Plaster }
local METAL: Builder.PartOpts = { material = Enum.Material.Metal }

-- The medium loot anchors on the racks (aisle side): rack decor leaves these slots empty.
local RACK_ANCHORS = {
	Vector3.new(13, 0.8, -8.25),
	Vector3.new(13, 0.8, 8.25),
	Vector3.new(26, 3.5, -8.25),
	Vector3.new(26, 3.5, 8.25),
	Vector3.new(38, 0.8, -8.25),
	Vector3.new(38, 0.8, 8.25),
}

local function walls(hall: Instance)
	local box = function(name: string, a: Vector3, b: Vector3, color: Color3?, opts: Builder.PartOpts?)
		return Builder.box(hall, name, a, b, color or C.BrickRed, opts or BRICK)
	end
	-- North wall with the Fire Exit opening (x 50..56, 9 high).
	box("WallNorthA", Vector3.new(-0.5, 0, 25), Vector3.new(50, WALL_H, 26))
	box("WallNorthB", Vector3.new(56, 0, 25), Vector3.new(61, WALL_H, 26))
	box("LintelFireExit", Vector3.new(50, 9, 25), Vector3.new(56, WALL_H, 26))
	box("WallSouth", Vector3.new(-0.5, 0, -26), Vector3.new(61, WALL_H, -25))
	-- East wall with the Loading Dock opening (z 12..20, 9 high).
	box("WallEastA", Vector3.new(60, 0, -26), Vector3.new(61, WALL_H, 12))
	box("WallEastB", Vector3.new(60, 0, 20), Vector3.new(61, WALL_H, 26))
	box("LintelDock", Vector3.new(60, 9, 12), Vector3.new(61, WALL_H, 20))
	-- West wall in pieces around the openings (all doorways 6 wide).
	for i, seg in { { -26, -23 }, { -17, -4 }, { 4, 14 } } do
		box(`WallWest{i}`, Vector3.new(-1, 0, seg[1]), Vector3.new(0, WALL_H, seg[2]))
	end
	box("LintelStaff", Vector3.new(-1, 9, -23), Vector3.new(0, WALL_H, -17))
	box("LintelSecurity", Vector3.new(-1, 10, -4), Vector3.new(0, WALL_H, 4))
	box("LintelBackLow", Vector3.new(-1, 9, 14), Vector3.new(0, 11, 20))
	box("LintelBackHigh", Vector3.new(-1, 14, 14), Vector3.new(0, WALL_H, 20))
	box("OfficeWindowSill", Vector3.new(-1, 11, 14), Vector3.new(0, 14, 15))
	box("OfficeWindowJamb", Vector3.new(-1, 11, 19), Vector3.new(0, 14, 20))
	Builder.box(
		hall,
		"OfficeWindowGlass",
		Vector3.new(-0.7, 11, 15),
		Vector3.new(-0.3, 14, 19),
		Color3.fromRGB(160, 200, 230),
		{
			material = Enum.Material.Glass,
			transparency = 0.5,
		}
	)
	-- West wall beside the office, with the Cheese Chute opening (z 21..24, y 9.2..13).
	box("WallWest4", Vector3.new(-1, 0, 20), Vector3.new(0, Layout.OfficeFloor, 26))
	box("WallWest4N", Vector3.new(-1, Layout.OfficeFloor, 24), Vector3.new(0, WALL_H, 26))
	box("WallWest4S", Vector3.new(-1, Layout.OfficeFloor, 20), Vector3.new(0, WALL_H, 21))
	box("ChuteLintel", Vector3.new(-1, 13, 21), Vector3.new(0, WALL_H, 24))
	-- Light inner band so the hall is less gloomy.
	for _, w in
		{
			{ Vector3.new(0, 0, 24.7), Vector3.new(50, 3, 25) },
			{ Vector3.new(56, 0, 24.7), Vector3.new(60, 3, 25) },
			{ Vector3.new(0, 0, -25), Vector3.new(60, 3, -24.7) },
			{ Vector3.new(59.7, 0, -25), Vector3.new(60, 3, 12) },
			{ Vector3.new(59.7, 0, 20), Vector3.new(60, 3, 25) },
		}
	do
		Builder.box(hall, "Wainscot", w[1], w[2], C.Cream, PLASTER)
	end
end

local function floorAndRoof(hall: Instance)
	Builder.box(hall, "Floor", Vector3.new(0, 0, -25), Vector3.new(60, 0.2, 25), C.Concrete, {
		material = Enum.Material.Concrete,
		variant = "CC_Concrete",
	})
	-- Yellow safety lines along the walkways and in front of the cage.
	local lineOpts: Builder.PartOpts = { collide = false, shadow = false, query = false }
	Builder.box(
		hall,
		"SafetyLine",
		Vector3.new(4, 0.2, -20.65),
		Vector3.new(52, 0.24, -20.35),
		C.Safety,
		lineOpts
	)
	Builder.box(
		hall,
		"SafetyLine",
		Vector3.new(19, 0.2, 16.85),
		Vector3.new(52, 0.24, 17.15),
		C.Safety,
		lineOpts
	)
	Builder.box(
		hall,
		"SafetyLineCage",
		Vector3.new(46.5, 0.2, -8),
		Vector3.new(46.8, 0.24, 8),
		C.Safety,
		lineOpts
	)
	-- Roof: dark metal with a skylight strip in the middle.
	local roof: Builder.PartOpts = { material = Enum.Material.CorrodedMetal }
	Builder.box(
		hall,
		"RoofA",
		Vector3.new(-1, WALL_H, -26),
		Vector3.new(61, WALL_H + 1, -4),
		Color3.fromRGB(58, 62, 70),
		roof
	)
	Builder.box(
		hall,
		"RoofB",
		Vector3.new(-1, WALL_H, 4),
		Vector3.new(61, WALL_H + 1, 26),
		Color3.fromRGB(58, 62, 70),
		roof
	)
	Builder.box(
		hall,
		"Skylight",
		Vector3.new(-1, WALL_H + 0.4, -4),
		Vector3.new(61, WALL_H + 0.8, 4),
		Color3.fromRGB(120, 150, 190),
		{
			material = Enum.Material.Glass,
			transparency = 0.55,
		}
	)
	-- Trusses (the hall cameras hang from the one at x 45) and purlins.
	for x = 5, 55, 10 do
		Builder.box(
			hall,
			"Truss",
			Vector3.new(x - 0.4, TRUSS_Y, -25),
			Vector3.new(x + 0.4, WALL_H - 0.6, 25),
			Color3.fromRGB(46, 50, 58),
			METAL
		)
	end
	for _, z in { -12, 12 } do
		Builder.box(
			hall,
			"Purlin",
			Vector3.new(0, WALL_H - 0.6, z - 0.3),
			Vector3.new(60, WALL_H - 0.1, z + 0.3),
			Color3.fromRGB(46, 50, 58),
			METAL
		)
	end
end

local function nearAnchor(pos: Vector3): boolean
	for _, a in RACK_ANCHORS do
		if math.abs(a.X - pos.X) < 1.8 and math.abs(a.Y - pos.Y) < 0.5 and math.abs(a.Z - pos.Z) < 1 then
			return true
		end
	end
	return false
end

local function racks(hall: Instance, rng: Random)
	-- Each rack is three sections with 6-wide cross-aisles. The solid back wall blocks the guard's view (cover).
	for _, z in { -9, 9 } do
		for _, section in { { 10, 16.5 }, { 22.5, 29 }, { 35, 41.5 } } do
			local x0, x1 = section[1], section[2]
			local rack = Builder.folder(hall, "Rack")
			local back = Builder.box(
				rack,
				"RackBack",
				Vector3.new(x0, 0, z - 0.25),
				Vector3.new(x1, 8, z + 0.25),
				C.Wood,
				{
					material = Enum.Material.Wood,
				}
			)
			back:SetAttribute("Cover", true)
			for _, x in { x0, x1 } do
				for _, dz in { -1.4, 1.4 } do
					Builder.box(
						rack,
						"Upright",
						Vector3.new(x - 0.2, 0, z + dz - 0.2),
						Vector3.new(x + 0.2, 8.4, z + dz + 0.2),
						C.RackBlue,
						METAL
					)
				end
			end
			for level, y in { 0.6, 3.3, 6 } do
				for _, side in { -1, 1 } do
					Builder.box(
						rack,
						"Beam",
						Vector3.new(x0, y - 0.3, z + side * 1.4 - 0.15),
						Vector3.new(x1, y, z + side * 1.4 + 0.15),
						C.RackOrange,
						METAL
					)
				end
				Builder.box(
					rack,
					"Shelf",
					Vector3.new(x0, y, z - 1.5),
					Vector3.new(x1, y + 0.2, z + 1.5),
					C.Wood,
					{
						material = Enum.Material.WoodPlanks,
					}
				)
				for i = 0, 1 do
					for _, side in { -0.75, 0.75 } do
						local pos = Vector3.new(x0 + 1.6 + i * 3.3, y + 0.2, z + side)
						if not nearAnchor(pos) and rng:NextNumber() < 0.85 then
							local wheel = Builder.prop(rack, "CheeseWheel", pos, rng:NextInteger(0, 359), {
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
										{
											collide = false,
										}
									)
								end,
							})
							-- Sometimes a second cheese lies on top: full racks look real.
							local top = Builder.topOf(wheel)
							if top and level < 3 and rng:NextNumber() < 0.45 then
								Builder.prop(
									rack,
									"CheeseWheel",
									Vector3.new(pos.X, top, pos.Z),
									rng:NextInteger(0, 359),
									{
										scale = 0.8,
										collide = false,
									}
								)
							end
						end
					end
				end
			end
		end
	end
end

local function hallLamp(hall: Instance, index: number, pos: Vector3, shadows: boolean)
	-- Pendant lamp. The "Lamp" part is the bulb: an EMP switches it off.
	Builder.prop(hall, "PendantLamp", pos + Vector3.new(0, 0.2, 0), 0, {
		collide = false,
		fallback = function(p, g)
			return Builder.cylinder(
				p,
				"ShadeStub",
				2.6,
				1.2,
				g + Vector3.new(0, 0.8, 0),
				C.PaintGreen,
				{ collide = false }
			)
		end,
	})
	Builder.block(
		hall,
		"LampCord",
		Vector3.new(0.12, TRUSS_Y - pos.Y - 1.4, 0.12),
		CFrame.new(pos.X, (TRUSS_Y + pos.Y + 1.4) / 2, pos.Z),
		C.StoneDark,
		{ collide = false, shadow = false }
	)
	local bulb = Builder.block(hall, `Lamp{index}`, Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos), C.LampWarm, {
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		collide = false,
		shadow = false,
	})
	Builder.pointLight(bulb, 22, 2.2, C.LampWarm, shadows)
	bulb:SetAttribute(Tags.Disabled, false)
	CollectionService:AddTag(bulb, Tags.Lamp)
	CollectionService:AddTag(bulb, Tags.Electronic)
end

local function cage(level: Folder)
	-- Folder "Cage" (the old see-through fallback) + SeeThrough tags on the mesh. Secure ring: red lamps.
	local cageFolder = Builder.folder(level, "Cage")
	local mesh: Builder.PartOpts = { material = Enum.Material.DiamondPlate, transparency = 0.45 }
	local steel = Color3.fromRGB(120, 128, 140)
	local function meshPanel(name: string, a: Vector3, b: Vector3)
		local part = Builder.box(cageFolder, name, a, b, steel, mesh)
		CollectionService:AddTag(part, Tags.SeeThrough)
	end
	meshPanel("CageNorth", Vector3.new(50, 0.2, 5.85), Vector3.new(58, 10, 6.15))
	meshPanel("CageEast", Vector3.new(57.85, 0.2, -6), Vector3.new(58.15, 10, 6))
	meshPanel("CageWestA", Vector3.new(49.85, 0.2, -6), Vector3.new(50.15, 10, -3))
	meshPanel("CageWestB", Vector3.new(49.85, 0.2, 3), Vector3.new(50.15, 10, 6))
	meshPanel("CageWestTop", Vector3.new(49.85, 9.8, -2.5), Vector3.new(50.15, 10, 2.5))
	meshPanel("CageSouthA", Vector3.new(50, 0.2, -6.15), Vector3.new(51.5, 10, -5.85))
	meshPanel("CageSouthB", Vector3.new(57.5, 0.2, -6.15), Vector3.new(58, 10, -5.85))
	meshPanel("CageSouthTop", Vector3.new(52, 9.8, -6.15), Vector3.new(57, 10, -5.85))
	meshPanel("CageTop", Vector3.new(50, 10, -6), Vector3.new(58, 10.3, 6))
	for _, p in
		{
			Vector3.new(50, 0, -6),
			Vector3.new(50, 0, 6),
			Vector3.new(58, 0, -6),
			Vector3.new(58, 0, 6),
			Vector3.new(50, 0, -2.75),
			Vector3.new(50, 0, 2.75),
			Vector3.new(51.75, 0, -6),
			Vector3.new(57.25, 0, -6),
		}
	do
		Builder.box(
			cageFolder,
			"CagePost",
			p + Vector3.new(-0.25, 0.2, -0.25),
			p + Vector3.new(0.25, 10.3, 0.25),
			C.Metal,
			METAL
		)
	end
	-- Two doors (Pryable 3), both swinging out of the cage so the plinth never blocks them.
	local west = Doors.leaf(
		cageFolder,
		"CageDoor",
		Vector3.new(50, 0.2, -2.5),
		Vector3.new(50, 0.2, 2.5),
		9.6,
		-Vector3.xAxis,
		{
			thickness = 0.4,
			color = steel,
			material = Enum.Material.DiamondPlate,
			transparency = 0.2,
		}
	)
	local south = Doors.leaf(
		cageFolder,
		"CageDoorSouth",
		Vector3.new(52, 0.2, -6),
		Vector3.new(57, 0.2, -6),
		9.6,
		-Vector3.zAxis,
		{
			thickness = 0.4,
			color = steel,
			material = Enum.Material.DiamondPlate,
			transparency = 0.2,
		}
	)
	for _, door in { west, south } do
		Doors.pryable(door, Config.Gadgets.Crowbar.CageSeconds)
		CollectionService:AddTag(door, Tags.SeeThrough)
	end
	Doors.redLamp(cageFolder, Vector3.new(49.5, 10.6, 0))
	Doors.redLamp(cageFolder, Vector3.new(54.5, 10.6, -6.6))
	Builder.block(cageFolder, "CagePadlock", Vector3.new(0.6, 1, 0.8), CFrame.new(49.6, 4.6, 1.6), C.Gold, {
		material = Enum.Material.Foil,
		collide = false,
	})
	-- The Gouda plinth (main loot spot G1). Mechanics spawn the Golden Gouda on its LootAnchor.
	Builder.box(
		cageFolder,
		"GoudaPlinth",
		Vector3.new(53.5, 0.2, -1.5),
		Vector3.new(56.5, 1.6, 1.5),
		C.WoodDark,
		{
			material = Enum.Material.Wood,
		}
	)
	Builder.box(
		cageFolder,
		"PlinthGlow",
		Vector3.new(53.4, 1.6, -1.6),
		Vector3.new(56.6, 1.75, 1.6),
		C.Gold,
		{
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		}
	)
end

local function office(hall: Instance, level: Folder): { Vector3 }
	-- Mezzanine above the back door: x 0..18, z 11..25, floor at y 9.2. Secure: only the keycard gate at the
	-- foot of the stair (or the chute down) leads in or out.
	local o = Builder.folder(hall, "Office")
	Builder.box(
		o,
		"MezzanineFloor",
		Vector3.new(0, 8.6, 11),
		Vector3.new(18, Layout.OfficeFloor, 25),
		C.Wood,
		{
			material = Enum.Material.WoodPlanks,
			variant = "CC_Planks",
		}
	)
	for _, p in
		{
			Vector3.new(17.5, 0, 11.5),
			Vector3.new(17.5, 0, 24.5),
			Vector3.new(3, 0, 11.5),
			Vector3.new(3, 0, 24.5),
		}
	do
		Builder.box(
			o,
			"Column",
			p - Vector3.new(0.4, 0, 0.4),
			p + Vector3.new(0.4, 8.6, 0.4),
			C.RackBlue,
			METAL
		)
	end
	Builder.box(o, "RailFront", Vector3.new(0, 9.2, 11), Vector3.new(18, 12.4, 11.3), C.Metal, {
		material = Enum.Material.Metal,
		transparency = 0.3,
	})
	Builder.box(o, "RailSide", Vector3.new(17.7, 9.2, 11), Vector3.new(18, 12.4, 18.6), C.Metal, {
		material = Enum.Material.Metal,
		transparency = 0.3,
	})
	-- Stair from the hall up (along the north wall), 6 wide: 16 steps from x 30 up to x 18, with an invisible ramp
	-- over the step noses so players, rolled loot and pathfinders move smoothly.
	local steps, run, rise = 16, 0.75, 9 / 16
	for i = 0, steps - 1 do
		Builder.box(
			o,
			"Step",
			Vector3.new(18 + i * run, 0, 18.6),
			Vector3.new(18 + (i + 1) * run, 9 - i * rise, 24.6),
			C.Metal,
			{ material = Enum.Material.DiamondPlate }
		)
	end
	local ramp = Builder.wedge(
		o,
		"StairRamp",
		Vector3.new(6, 9, steps * run),
		CFrame.new(18 + steps * run / 2, 4.7, 21.6) * CFrame.Angles(0, math.rad(-90), 0),
		C.Metal
	)
	ramp.Transparency = 1
	-- Keycard gate at the stair foot (Card "Office"), with a frame, the OFFICE sign and a red lamp.
	Builder.box(o, "GatePost", Vector3.new(29.9, 0, 18.1), Vector3.new(30.6, 10.6, 18.6), C.Metal, METAL)
	Builder.box(o, "GatePostN", Vector3.new(29.9, 0, 24.6), Vector3.new(30.6, 10.6, 25), C.Metal, METAL)
	Builder.box(o, "GateBeam", Vector3.new(29.9, 9.2, 18.1), Vector3.new(30.6, 10.6, 25), C.Metal, METAL)
	Doors.keycardGate(o, "OfficeGate", {
		card = "Office",
		a = Vector3.new(30.25, 0.2, 18.6),
		b = Vector3.new(30.25, 0.2, 24.6),
		height = 9,
		front = Vector3.xAxis,
		readerEnd = -1,
	})
	Builder.sign(
		o,
		CFrame.lookAt(Vector3.new(30.75, 9.9, 21.8), Vector3.new(40, 9.9, 21.8)),
		Vector3.new(5, 1.1, 0.2),
		"OFFICE",
		Color3.fromRGB(150, 36, 32),
		C.Trim,
		Enum.Font.GothamBold,
		{ viewFrom = Vector3.new(40, 5, 18) }
	)
	-- Furniture: filing cabinet, the safe (optional objective), desk; the Gouda spot G2 stays free by the chute.
	Builder.box(
		o,
		"FilingCabinet",
		Vector3.new(1, 9.2, 12.5),
		Vector3.new(3.4, 14, 15),
		Color3.fromRGB(110, 116, 124),
		METAL
	)
	Builder.box(
		o,
		"Desk",
		Vector3.new(9.5, 9.2, 21.2),
		Vector3.new(15, 12, 24.4),
		C.WoodDark,
		{ material = Enum.Material.Wood }
	)
	local safe = Instance.new("Model")
	safe.Name = "OfficeSafe"
	safe:SetAttribute(Tags.Group, "OfficeSafe")
	CollectionService:AddTag(safe, Tags.Safe)
	local safeRoot = Builder.block(
		safe,
		"Root",
		Vector3.new(3, 3.2, 3),
		CFrame.new(2.5, Layout.OfficeFloor + 1.6, 17.3),
		C.Metal
	)
	safeRoot.Transparency = 1
	safeRoot.CanCollide = false
	safeRoot.CanQuery = false
	local deviceSpot = Instance.new("Attachment")
	deviceSpot.Name = "DeviceSpot"
	deviceSpot.CFrame = CFrame.new(2.5, -1.6, 0) -- floor in front of the safe door (x 5)
	deviceSpot.Parent = safeRoot
	Builder.prop(safe, "Safe", Vector3.new(2.5, Layout.OfficeFloor, 17.3), -90, {
		fallback = function(p, g)
			local body = Builder.block(
				p,
				"SafeBody",
				Vector3.new(3, 3.2, 3),
				CFrame.new(g + Vector3.new(0, 1.6, 0)),
				Color3.fromRGB(46, 84, 60),
				{
					material = Enum.Material.DiamondPlate,
				}
			)
			Builder.cylinder(
				p,
				"SafeDial",
				1,
				0.2,
				g + Vector3.new(1.6, 1.9, 0),
				C.Gold,
				{ material = Enum.Material.Foil }
			).CFrame =
				CFrame.new(g + Vector3.new(1.6, 1.9, 0))
			return body
		end,
	})
	safe.PrimaryPart = safeRoot
	safe.Parent = o
	-- Office lamp and the chute sign.
	local bulb =
		Builder.block(o, "OfficeLamp", Vector3.new(0.8, 0.8, 0.8), CFrame.new(8, 15, 18), C.LampWarm, {
			material = Enum.Material.Neon,
			shape = Enum.PartType.Ball,
			collide = false,
			shadow = false,
		})
	Builder.pointLight(bulb, 16, 1.2, C.LampWarm)
	bulb:SetAttribute(Tags.Disabled, false)
	CollectionService:AddTag(bulb, Tags.Lamp)
	CollectionService:AddTag(bulb, Tags.Electronic)
	Builder.sign(
		o,
		CFrame.lookAt(Vector3.new(0.2, 14, 22.5), Vector3.new(10, 14, 22.5)),
		Vector3.new(4.4, 0.9, 0.2),
		"CHEESE CHUTE",
		C.CrewOrange,
		C.Trim,
		Enum.Font.GothamBold,
		{ viewFrom = Vector3.new(9, 12, 22.5) }
	)
	-- Cheese Chute (ride): office → courtyard in 2.5 s. Heavy loot sent alone rumbles out after LootDelay seconds
	-- (noise ExitNoise; Boef chases it). The trough does not collide (nobody walks up it); the server moves the car.
	local _, path = Rides.build(level, {
		id = "CheeseChute",
		path = Layout.ChutePath,
		seats = 1,
		speed = 6,
		stations = {
			{ at = Layout.ChutePath[1], boarding = true, platform = true },
			{ at = Layout.ChutePath[#Layout.ChutePath], boarding = false },
		},
		track = "Trough",
		trackWidth = 3.4,
		trackColor = Color3.fromRGB(160, 120, 70),
		supports = { 3, 4 },
		floorY = 0.15,
		attrs = { LootDelay = 3, ExitNoise = 20 },
	})
	return path
end

local function dockAndFireExit(hall: Instance)
	-- Loading Dock: roller door (Pryable 3) swinging into the hall; the crates moved beside the forklift.
	Doors.roller(hall, "LoadingDock", Vector3.new(60.5, 0.2, 12), Vector3.new(60.5, 0.2, 20), 8.8, {
		swing = -Vector3.xAxis,
		seconds = Config.Gadgets.Crowbar.CageSeconds,
	})
	for _, spec in
		{
			{ Vector3.new(61.2, 10.4, 16), Vector3.xAxis, Vector3.new(65.5, 5, 6) },
			{ Vector3.new(59.8, 11, 16), -Vector3.xAxis, Vector3.new(48, 5, 16) },
		}
	do
		Builder.sign(
			hall,
			CFrame.lookAt(spec[1], spec[1] + spec[2]),
			Vector3.new(8, 1.3, 0.2),
			"LOADING DOCK",
			C.Safety,
			Color3.fromRGB(30, 30, 30),
			Enum.Font.GothamBold,
			{ viewFrom = spec[3] }
		)
	end
	-- Fire Exit: the loud-only shortcut to the Back Alley (push bar, swings out).
	local fireExit = Doors.leaf(
		hall,
		"FireExit",
		Vector3.new(50, 0.2, 25.5),
		Vector3.new(56, 0.2, 25.5),
		8.8,
		Vector3.zAxis,
		{
			thickness = 0.35,
			color = Color3.fromRGB(170, 40, 36),
			material = Enum.Material.Metal,
		}
	)
	Doors.pryable(fireExit, Config.Gadgets.Crowbar.DoorSeconds, true)
	Builder.sign(
		hall,
		CFrame.lookAt(Vector3.new(53, 10, 24.8), Vector3.new(53, 10, 0)),
		Vector3.new(6, 1.1, 0.2),
		"FIRE EXIT",
		Color3.fromRGB(40, 160, 80),
		C.Trim,
		Enum.Font.GothamBold,
		{ viewFrom = Vector3.new(53, 5, 13) }
	)
end

local function decor(hall: Instance)
	Builder.prop(hall, "Forklift", Vector3.new(54.5, 0.2, -19), 90, {
		fallback = function(p, g)
			return Builder.block(
				p,
				"ForkliftStub",
				Vector3.new(4, 5, 7),
				CFrame.new(g + Vector3.new(0, 2.5, 0)),
				C.Safety
			)
		end,
	})
	-- Crate stack beside the forklift (small loot on top).
	for i, pos in { Vector3.new(57, 0.2, -14), Vector3.new(57, 4.2, -14) } do
		Builder.prop(hall, "Crate", pos, i * 11, {
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
	-- High windows (moonlight), pipes along the walls, a packing table and emergency exit lights.
	for _, x in { 8, 16, 44, 52 } do
		Builder.window(
			hall,
			CFrame.lookAt(Vector3.new(x, 14.5, 24.75), Vector3.new(x, 14.5, 0)),
			4,
			2.6,
			false,
			C.Metal
		)
	end
	for _, x in { 8, 18, 28, 38, 48 } do
		Builder.window(
			hall,
			CFrame.lookAt(Vector3.new(x, 14.5, -24.75), Vector3.new(x, 14.5, 0)),
			4,
			2.6,
			false,
			C.Metal
		)
	end
	for _, z in { -24.2, 24.2 } do
		Builder.block(
			hall,
			"Pipe",
			Vector3.new(59, 0.6, 0.6),
			CFrame.new(30, 17.2, z),
			Color3.fromRGB(150, 60, 50),
			{
				material = Enum.Material.Metal,
				shape = Enum.PartType.Cylinder,
			}
		)
		Builder.block(hall, "PipeThin", Vector3.new(59, 0.3, 0.3), CFrame.new(30, 16.6, z), C.Metal, {
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		})
	end
	for _, x in { 33, 58 } do
		Builder.cylinder(
			hall,
			"DownPipe",
			0.5,
			14,
			Vector3.new(x, 7, 24.3),
			Color3.fromRGB(150, 60, 50),
			METAL
		)
	end
	Builder.box(hall, "PackingTable", Vector3.new(38, 0.2, -24.6), Vector3.new(45, 3, -22), C.Wood, {
		material = Enum.Material.WoodPlanks,
	})
	for _, y in { 3, 4.6 } do
		Builder.block(
			hall,
			"Box",
			Vector3.new(1.8, 1.6, 1.8),
			CFrame.new(44, y + 0.8, -23.4),
			Color3.fromRGB(176, 138, 92),
			{
				material = Enum.Material.Cardboard,
			}
		)
	end
	Builder.box(hall, "Pallet", Vector3.new(26, 0.2, -24.6), Vector3.new(30, 0.8, -21), C.Wood, {
		material = Enum.Material.WoodPlanks,
	})
	for i = 0, 2 do
		Builder.block(
			hall,
			"Box",
			Vector3.new(1.8, 1.6, 1.8),
			CFrame.new(27 + (i % 2) * 2, 1.6 + (i // 2) * 1.6, -22.9),
			Color3.fromRGB(166, 128, 84),
			{ material = Enum.Material.Cardboard }
		)
	end
	for _, z in { -20, 17 } do
		Builder.block(
			hall,
			"ExitSign",
			Vector3.new(0.2, 0.7, 1.8),
			CFrame.new(0.15, 9.8, z),
			Color3.fromRGB(40, 200, 90),
			{
				material = Enum.Material.Neon,
				collide = false,
				shadow = false,
			}
		)
	end
	Builder.sign(
		hall,
		CFrame.lookAt(Vector3.new(42.5, 11.8, 24.6), Vector3.new(42.5, 11.8, 0)),
		Vector3.new(14, 2.2, 0.3),
		"RIPENING ROOM",
		C.DoorGreen,
		C.Gold,
		nil,
		{ viewFrom = Vector3.new(42.5, 5, 12) }
	)
	Builder.sign(
		hall,
		CFrame.lookAt(Vector3.new(0.2, 11.2, 0), Vector3.new(10, 11.2, 0)),
		Vector3.new(6, 1.2, 0.2),
		"SECURITY",
		Color3.fromRGB(38, 52, 84),
		C.Trim,
		Enum.Font.GothamBold,
		{ viewFrom = Vector3.new(12, 5, 0) }
	)
end

-- All six cameras (beta-spec-maps §6): hall N/S hang from the truss at x 45; shop, yard, cellar, Dock Apron.
local function cameras(level: Folder)
	local cams = Builder.folder(level, "Cameras")
	Security.camera(
		cams,
		"CameraNorth",
		Vector3.new(45, 9, 10),
		Vector3.new(50, 0, -2),
		{ mount = "ceiling", ceilingY = TRUSS_Y }
	)
	Security.camera(
		cams,
		"CameraSouth",
		Vector3.new(45, 9, -10),
		Vector3.new(50, 0, 2),
		{ mount = "ceiling", ceilingY = TRUSS_Y }
	)
	Security.camera(
		cams,
		"CameraShop",
		Vector3.new(-20.5, 11, -15.5),
		Vector3.new(-10, 0, -30),
		{ mount = "ceiling", ceilingY = 14 }
	)
	Security.camera(cams, "CameraYard", Vector3.new(-2, 9, 5.5), Vector3.new(-18, 0, 20), {
		mount = "wall",
		wallPoint = Vector3.new(-1, 9, 5.5),
	})
	Security.camera(
		cams,
		"CameraCellar",
		Vector3.new(-2, -2, -22),
		Vector3.new(-16, -10, -36),
		{ mount = "ceiling", ceilingY = -0.5 }
	)
	Security.camera(
		cams,
		"CameraDock",
		Vector3.new(61.8, 9, -45.6),
		Vector3.new(64, 0, 0),
		{ mount = "pole", floorY = 0 }
	)
end

-- Builds the hall and returns the Cheese Chute path (for Points.Rides).
function Warehouse.build(level: Folder, rng: Random): { Vector3 }
	local hall = Builder.folder(level, "Hall")
	walls(hall)
	floorAndRoof(hall)
	racks(hall, rng)
	hallLamp(hall, 1, Vector3.new(10, 13, 0), false)
	hallLamp(hall, 2, Vector3.new(26, 13, -17), true)
	hallLamp(hall, 3, Vector3.new(26, 13, 16), true)
	hallLamp(hall, 4, Vector3.new(46, 12, 0), false)
	local path = office(hall, level)
	dockAndFireExit(hall)
	decor(hall)
	cage(level)
	cameras(level)
	return path
end

return Warehouse
