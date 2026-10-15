--!strict
-- The ripening hall (D) with cage, cameras, lamps, racks and the office on the mezzanine (E).
-- Hall: x 0..60, z -25..25, walls 16 high. Gameplay positions stay the same as in the prototype:
-- racks at z ±9 (x 12..38), cage x 50..58, cameras (44, 9, ±10), lamps in the same spots.
-- The west wall (x = 0) has three openings: shop staff door (z -22..-18), security room (z -4..4),
-- courtyard back door (z 14..20).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Common = script.Parent.Parent.Parent.Common
local Builder = require(Common.Builder)

local C = Builder.Colors

local Warehouse = {}

-- 20 high: enough clearance above and below the mezzanine, also for Roblox's pathfinder
-- (which works in 4-stud cells; with 16 or 18 it could not find the office floor).
local WALL_H = 20

local function walls(hall: Instance)
	local opts: Builder.PartOpts = { material = Enum.Material.Brick, variant = "CC_Brick" }
	Builder.box(hall, "WallNorth", Vector3.new(-0.5, 0, 25), Vector3.new(61, WALL_H, 26), C.BrickRed, opts)
	Builder.box(hall, "WallSouth", Vector3.new(-0.5, 0, -26), Vector3.new(61, WALL_H, -25), C.BrickRed, opts)
	Builder.box(hall, "WallEast", Vector3.new(60, 0, -26), Vector3.new(61, WALL_H, 26), C.BrickRed, opts)
	-- West wall in pieces around the three openings.
	local segments = { { -26, -22.5 }, { -17.5, -4 }, { 4, 14 }, { 20, 26 } }
	for i, seg in segments do
		Builder.box(
			hall,
			`WallWest{i}`,
			Vector3.new(-1, 0, seg[1]),
			Vector3.new(0, WALL_H, seg[2]),
			C.BrickRed,
			opts
		)
	end
	Builder.box(
		hall,
		"LintelStaff",
		Vector3.new(-1, 8, -22.5),
		Vector3.new(0, WALL_H, -17.5),
		C.BrickRed,
		opts
	)
	Builder.box(hall, "LintelSecurity", Vector3.new(-1, 10, -4), Vector3.new(0, WALL_H, 4), C.BrickRed, opts)
	Builder.box(hall, "LintelBack", Vector3.new(-1, 8, 14), Vector3.new(0, WALL_H, 20), C.BrickRed, opts)
	-- Office window above the back door (view of the courtyard).
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
	-- Light inner band so the hall is less gloomy.
	Builder.box(
		hall,
		"WainscotN",
		Vector3.new(0, 0, 24.7),
		Vector3.new(60, 3, 25),
		C.Cream,
		{ material = Enum.Material.Plaster }
	)
	Builder.box(
		hall,
		"WainscotS",
		Vector3.new(0, 0, -25),
		Vector3.new(60, 3, -24.7),
		C.Cream,
		{ material = Enum.Material.Plaster }
	)
	Builder.box(
		hall,
		"WainscotE",
		Vector3.new(59.7, 0, -25),
		Vector3.new(60, 3, 25),
		C.Cream,
		{ material = Enum.Material.Plaster }
	)
end

local function floorAndRoof(hall: Instance)
	Builder.box(hall, "Floor", Vector3.new(0, 0, -25), Vector3.new(60, 0.2, 25), C.Concrete, {
		material = Enum.Material.Concrete,
		variant = "CC_Concrete",
	})
	-- Yellow safety lines around the walkway and the cage.
	local lineOpts: Builder.PartOpts = { collide = false, shadow = false }
	for _, z in { -20.5, 20.5 } do
		Builder.box(
			hall,
			"SafetyLine",
			Vector3.new(4, 0.2, z - 0.15),
			Vector3.new(52, 0.24, z + 0.15),
			C.Safety,
			lineOpts
		)
	end
	Builder.box(
		hall,
		"SafetyLineCage",
		Vector3.new(46.5, 0.2, -8),
		Vector3.new(46.8, 0.24, 8),
		C.Safety,
		lineOpts
	)
	-- Roof: dark metal with a skylight strip in the middle.
	Builder.box(
		hall,
		"RoofA",
		Vector3.new(-1, WALL_H, -26),
		Vector3.new(61, WALL_H + 1, -4),
		Color3.fromRGB(58, 62, 70),
		{
			material = Enum.Material.CorrodedMetal,
		}
	)
	Builder.box(
		hall,
		"RoofB",
		Vector3.new(-1, WALL_H, 4),
		Vector3.new(61, WALL_H + 1, 26),
		Color3.fromRGB(58, 62, 70),
		{
			material = Enum.Material.CorrodedMetal,
		}
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
	-- Trusses.
	for x = 5, 55, 10 do
		Builder.box(
			hall,
			"Truss",
			Vector3.new(x - 0.4, WALL_H - 1.4, -25),
			Vector3.new(x + 0.4, WALL_H - 0.6, 25),
			Color3.fromRGB(46, 50, 58),
			{
				material = Enum.Material.Metal,
			}
		)
	end
	for _, z in { -12, 12 } do
		Builder.box(
			hall,
			"Purlin",
			Vector3.new(0, WALL_H - 0.6, z - 0.3),
			Vector3.new(60, WALL_H - 0.1, z + 0.3),
			Color3.fromRGB(46, 50, 58),
			{
				material = Enum.Material.Metal,
			}
		)
	end
end

local function racks(hall: Instance, rng: Random)
	-- Racks with cheese wheels. The solid back wall blocks the guard's view (cover).
	for _, z in { -9, 9 } do
		local rack = Builder.folder(hall, "Rack")
		local back = Builder.box(
			rack,
			"RackBack",
			Vector3.new(12, 0, z - 0.25),
			Vector3.new(38, 8, z + 0.25),
			C.Wood,
			{
				material = Enum.Material.Wood,
			}
		)
		back:SetAttribute("Cover", true)
		for x = 12, 38, 6.5 do
			for _, dz in { -1.4, 1.4 } do
				Builder.box(
					rack,
					"Upright",
					Vector3.new(x - 0.2, 0, z + dz - 0.2),
					Vector3.new(x + 0.2, 8.4, z + dz + 0.2),
					C.RackBlue,
					{
						material = Enum.Material.Metal,
					}
				)
			end
		end
		for level, y in { 0.6, 3.3, 6 } do
			for _, side in { -1, 1 } do
				Builder.box(
					rack,
					"Beam",
					Vector3.new(12, y - 0.3, z + side * 1.4 - 0.15),
					Vector3.new(38, y, z + side * 1.4 + 0.15),
					C.RackOrange,
					{
						material = Enum.Material.Metal,
					}
				)
			end
			Builder.box(
				rack,
				"Shelf",
				Vector3.new(12, y, z - 1.5),
				Vector3.new(38, y + 0.2, z + 1.5),
				C.Wood,
				{
					material = Enum.Material.WoodPlanks,
				}
			)
			for i = 0, 7 do
				if rng:NextNumber() < 0.85 then
					local side = if i % 2 == 0 then -0.75 else 0.75
					local wheel = Builder.prop(
						rack,
						"CheeseWheel",
						Vector3.new(13.6 + i * 3.2, y + 0.2, z + side),
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
					-- Sometimes a second cheese lies on top: full racks look real.
					local top = Builder.topOf(wheel)
					if top and level < 3 and rng:NextNumber() < 0.45 then
						Builder.prop(
							rack,
							"CheeseWheel",
							Vector3.new(13.6 + i * 3.2, top, z + side),
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

local function lamps(hall: Instance)
	-- Pendant lamps. The "Lamp" part is the bulb: an EMP switches it off.
	local positions = {
		Vector3.new(10, 13, 0),
		Vector3.new(26, 13, -17),
		Vector3.new(26, 13, 17),
		Vector3.new(46, 12, 0),
	}
	for index, pos in positions do
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
			Vector3.new(0.12, WALL_H - pos.Y - 1.4, 0.12),
			CFrame.new(pos.X, (WALL_H + pos.Y + 1.4) / 2 - 0.6, pos.Z),
			C.StoneDark,
			{
				collide = false,
				shadow = false,
			}
		)
		local bulb =
			Builder.block(hall, `Lamp{index}`, Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos), C.LampWarm, {
				material = Enum.Material.Neon,
				shape = Enum.PartType.Ball,
				collide = false,
				shadow = false,
			})
		Builder.pointLight(bulb, 22, 2.2, C.LampWarm, true)
		bulb:SetAttribute(Tags.Disabled, false)
		CollectionService:AddTag(bulb, Tags.Lamp)
		CollectionService:AddTag(bulb, Tags.Electronic)
	end
end

local function cage(level: Folder)
	local cageFolder = Builder.folder(level, "Cage")
	local mesh: Builder.PartOpts = { material = Enum.Material.DiamondPlate, transparency = 0.45 }
	local steel = Color3.fromRGB(120, 128, 140)
	Builder.block(cageFolder, "CageNorth", Vector3.new(8, 10, 0.3), CFrame.new(54, 5, 6), steel, mesh)
	Builder.block(cageFolder, "CageSouth", Vector3.new(8, 10, 0.3), CFrame.new(54, 5, -6), steel, mesh)
	Builder.block(cageFolder, "CageEast", Vector3.new(0.3, 10, 12), CFrame.new(58, 5, 0), steel, mesh)
	Builder.block(cageFolder, "CageWestA", Vector3.new(0.3, 10, 3.5), CFrame.new(50, 5, -4.25), steel, mesh)
	Builder.block(cageFolder, "CageWestB", Vector3.new(0.3, 10, 3.5), CFrame.new(50, 5, 4.25), steel, mesh)
	Builder.block(cageFolder, "CageTop", Vector3.new(8, 0.3, 12), CFrame.new(54, 10, 0), steel, mesh)
	for _, p in
		{
			Vector3.new(50, 5, -6),
			Vector3.new(50, 5, 6),
			Vector3.new(58, 5, -6),
			Vector3.new(58, 5, 6),
			Vector3.new(50, 5, -2.5),
			Vector3.new(50, 5, 2.5),
		}
	do
		Builder.block(
			cageFolder,
			"CagePost",
			Vector3.new(0.5, 10, 0.5),
			CFrame.new(p),
			C.Metal,
			{ material = Enum.Material.Metal }
		)
	end

	local door =
		Builder.block(cageFolder, "CageDoor", Vector3.new(0.5, 9.6, 5), CFrame.new(50, 4.8, 0), steel, {
			material = Enum.Material.DiamondPlate,
			transparency = 0.2,
		})
	door:SetAttribute("PrySeconds", Config.Gadgets.Crowbar.CageSeconds)
	door:SetAttribute(Tags.SpotKind, "lock")
	CollectionService:AddTag(door, Tags.Pryable)
	CollectionService:AddTag(door, Tags.Spottable)
	Builder.pointLight(door, 6, 0.6, Color3.fromRGB(255, 80, 80))
	Builder.block(cageFolder, "CagePadlock", Vector3.new(0.6, 1, 0.8), CFrame.new(49.6, 4.6, 1.9), C.Gold, {
		material = Enum.Material.Foil,
		collide = false,
	})

	-- The Golden Gouda on a plinth. The invisible "Goal" block is what you have to touch.
	Builder.box(
		cageFolder,
		"GoudaPlinth",
		Vector3.new(53.5, 0.2, -1.5),
		Vector3.new(56.5, 1.6, 1.5),
		C.WoodDark,
		{ material = Enum.Material.Wood }
	)
	local gouda = Builder.prop(cageFolder, "GoldenGouda", Vector3.new(55, 1.6, 0), 30, {
		collide = false,
		fallback = function(p, g)
			local w = Builder.cylinder(
				p,
				"GoudaStub",
				4,
				2,
				g + Vector3.new(0, 1, 0),
				C.Gold,
				{ material = Enum.Material.Foil, collide = false }
			)
			return w
		end,
	})
	-- The AI texture is more orange than gold: real gold foil makes the loot instantly recognisable.
	if gouda then
		for _, d in gouda:GetDescendants() do
			if d:IsA("MeshPart") then
				d.TextureID = ""
				d.Material = Enum.Material.Foil
				d.Color = C.Gold
				d.Reflectance = 0.15
			end
		end
	end
	local goal =
		Builder.block(cageFolder, "GoldenGouda", Vector3.new(4.4, 3, 4.4), CFrame.new(55, 3, 0), C.Gold, {
			transparency = 1,
			collide = false,
		})
	goal:SetAttribute(Tags.SpotKind, "loot")
	CollectionService:AddTag(goal, Tags.Goal)
	CollectionService:AddTag(goal, Tags.Spottable)
	Builder.label(goal, "GOLDEN GOUDA", C.Gold, 2.4)
	Builder.pointLight(goal, 13, 2.2, C.Gold)
	-- Golden glowing rim on the plinth: the loot must stand out from far away.
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

local function securityCamera(parent: Instance, name: string, mount: Vector3, lookAt: Vector3)
	local model = Instance.new("Model")
	model.Name = name
	Builder.box(
		model,
		"Pole",
		Vector3.new(mount.X - 0.35, 0, mount.Z - 0.35),
		Vector3.new(mount.X + 0.35, mount.Y - 0.4, mount.Z + 0.35),
		C.Metal,
		{
			material = Enum.Material.Metal,
		}
	)
	-- Body rotates (CameraService); the rest is welded to it and rotates along.
	local body = Builder.block(
		model,
		"Body",
		Vector3.new(1.3, 1.2, 2.4),
		CFrame.lookAt(mount, lookAt),
		Color3.fromRGB(230, 232, 236)
	)
	local function attach(part: BasePart)
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
	end
	local hood = Builder.block(
		model,
		"Hood",
		Vector3.new(1.5, 0.25, 2.8),
		body.CFrame * CFrame.new(0, 0.7, -0.1),
		Color3.fromRGB(60, 64, 72)
	)
	attach(hood)
	local lens = Builder.cylinder(
		model,
		"Lens",
		0.6,
		0.3,
		(body.CFrame * CFrame.new(0, -0.2, -1.3)).Position,
		Color3.fromRGB(16, 18, 24),
		{
			material = Enum.Material.Glass,
		}
	)
	lens.CFrame = body.CFrame * CFrame.new(0, -0.2, -1.3) * CFrame.Angles(0, math.rad(90), 0)
	attach(lens)
	-- CameraService puts the LED at body * (0, 0.3, -1.25) every frame; same spot here.
	local led = Builder.block(
		model,
		"Led",
		Vector3.new(0.25, 0.25, 0.2),
		body.CFrame * CFrame.new(0, 0.3, -1.25),
		Color3.fromRGB(255, 40, 40),
		{
			material = Enum.Material.Neon,
		}
	)
	led:SetAttribute("IsLed", true)
	local cone = Instance.new("SpotLight")
	cone.Name = "Cone"
	cone.Face = Enum.NormalId.Front
	cone.Angle = Config.SecurityCamera.ConeHalfAngle * 2
	cone.Range = Config.SecurityCamera.Range
	cone.Brightness = 2
	cone.Color = Color3.fromRGB(255, 60, 60)
	cone.Shadows = true
	cone.Parent = body
	model.PrimaryPart = body
	model:SetAttribute(Tags.Disabled, false)
	model:SetAttribute(Tags.SpotKind, "camera")
	model:SetAttribute("BaseLook", (lookAt - mount).Unit)
	CollectionService:AddTag(model, Tags.SecurityCamera)
	CollectionService:AddTag(model, Tags.Electronic)
	CollectionService:AddTag(model, Tags.Spottable)
	model.Parent = parent
end

local function office(hall: Instance)
	-- Mezzanine above the back door: x 0..18, z 11..25, floor at y 9.
	local o = Builder.folder(hall, "Office")
	Builder.box(o, "MezzanineFloor", Vector3.new(0, 8.6, 11), Vector3.new(18, 9.2, 25), C.Wood, {
		material = Enum.Material.WoodPlanks,
		variant = "CC_Planks",
	})
	-- Columns stand clear of the guard's route (x = 8) and leave the stairs free.
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
			{ material = Enum.Material.Metal }
		)
	end
	-- Railing.
	Builder.box(o, "RailFront", Vector3.new(0, 9.2, 11), Vector3.new(18, 12.4, 11.3), C.Metal, {
		material = Enum.Material.Metal,
		transparency = 0.3,
	})
	Builder.box(o, "RailSide", Vector3.new(17.7, 9.2, 11), Vector3.new(18, 12.4, 19.4), C.Metal, {
		material = Enum.Material.Metal,
		transparency = 0.3,
	})
	-- Stairs from the hall up (along the north wall): 16 steps from x 30 up to x 18.
	-- An invisible ramp over the step noses lets players (and pathfinders) walk smoothly.
	local steps, run, rise = 16, 0.75, 9 / 16
	for i = 0, steps - 1 do
		Builder.box(
			o,
			"Step",
			Vector3.new(18 + i * run, 0, 19.4),
			Vector3.new(18 + (i + 1) * run, 9 - i * rise, 24.6),
			C.Metal,
			{ material = Enum.Material.DiamondPlate }
		)
	end
	local ramp = Builder.wedge(
		o,
		"StairRamp",
		Vector3.new(5.2, 9, steps * run),
		CFrame.new(18 + steps * run / 2, 4.5 + rise, 22) * CFrame.Angles(0, math.rad(-90), 0),
		C.Metal
	)
	ramp.Transparency = 1
	-- Desk, filing cabinet, lamp.
	Builder.box(
		o,
		"Desk",
		Vector3.new(5, 9.2, 21),
		Vector3.new(11, 12, 24.2),
		C.WoodDark,
		{ material = Enum.Material.Wood }
	)
	Builder.box(
		o,
		"FilingCabinet",
		Vector3.new(1, 9.2, 12.5),
		Vector3.new(3.4, 14, 15),
		Color3.fromRGB(110, 116, 124),
		{
			material = Enum.Material.Metal,
		}
	)
	Builder.box(
		o,
		"Safe",
		Vector3.new(1, 9.2, 21.5),
		Vector3.new(4, 12.4, 24.5),
		Color3.fromRGB(40, 44, 50),
		{ material = Enum.Material.DiamondPlate }
	)
	local bulb =
		Builder.block(o, "OfficeLamp", Vector3.new(0.8, 0.8, 0.8), CFrame.new(8, 15, 18), C.LampWarm, {
			material = Enum.Material.Neon,
			shape = Enum.PartType.Ball,
			collide = false,
		})
	Builder.pointLight(bulb, 14, 1.2, C.LampWarm, true)
	bulb:SetAttribute(Tags.Disabled, false)
	CollectionService:AddTag(bulb, Tags.Lamp)
	CollectionService:AddTag(bulb, Tags.Electronic)
end

local function decor(hall: Instance, rng: Random)
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
	for i, pos in
		{
			Vector3.new(57, 0.2, 12),
			Vector3.new(57, 0.2, 16.5),
			Vector3.new(57, 4.2, 12),
			Vector3.new(33, 0.2, 23),
			Vector3.new(37.5, 0.2, 23),
			Vector3.new(4, 0.2, -23),
		}
	do
		Builder.prop(hall, "Crate", pos, i * 11, {
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
		Builder.prop(hall, "Barrel", Vector3.new(42 + i * 2.8, 0.2, 23), rng:NextInteger(0, 359), {
			fallback = function(p, g)
				return Builder.cylinder(p, "BarrelStub", 2.6, 3.6, g + Vector3.new(0, 1.8, 0), C.WoodDark)
			end,
		})
	end
	-- High windows (moonlight), pipes along the walls, a packing table and emergency exit signs.
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
	for _, x in { 40.5, 52 } do
		Builder.cylinder(
			hall,
			"DownPipe",
			0.5,
			14,
			Vector3.new(x, 7, 24.3),
			Color3.fromRGB(150, 60, 50),
			{ material = Enum.Material.Metal }
		)
	end
	Builder.box(
		hall,
		"PackingTable",
		Vector3.new(38, 0.2, -24.6),
		Vector3.new(45, 3, -22),
		C.Wood,
		{ material = Enum.Material.WoodPlanks }
	)
	for i, offset in
		{ Vector3.new(39.5, 3, -23.4), Vector3.new(41.8, 3, -23.2), Vector3.new(39.6, 4.6, -23.4) }
	do
		local w = if i == 2 then 2 else 1.8
		Builder.block(
			hall,
			"Box",
			Vector3.new(w, 1.6, 1.8),
			CFrame.new(offset + Vector3.new(0, 0.8, 0)),
			Color3.fromRGB(176, 138, 92),
			{
				material = Enum.Material.Cardboard,
			}
		)
	end
	Builder.prop(hall, "CheeseWheel", Vector3.new(43.6, 3, -23.3), 15, { collide = false })
	Builder.box(
		hall,
		"Pallet",
		Vector3.new(26, 0.2, -24.6),
		Vector3.new(30, 0.8, -21),
		C.Wood,
		{ material = Enum.Material.WoodPlanks }
	)
	for i = 0, 2 do
		Builder.block(
			hall,
			"Box",
			Vector3.new(1.8, 1.6, 1.8),
			CFrame.new(27 + (i % 2) * 2, 1.6 + (i // 2) * 1.6, -22.9),
			Color3.fromRGB(166, 128, 84),
			{
				material = Enum.Material.Cardboard,
			}
		)
	end
	for _, z in { -20, 17 } do
		Builder.block(
			hall,
			"ExitSign",
			Vector3.new(0.2, 0.7, 1.8),
			CFrame.new(0.15, 9, z),
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
		CFrame.lookAt(Vector3.new(30, 12, 24.6), Vector3.new(30, 12, 0)),
		Vector3.new(14, 2.2, 0.3),
		"RIPENING ROOM",
		C.DoorGreen,
		C.Gold
	)
end

function Warehouse.build(level: Folder, rng: Random)
	local hall = Builder.folder(level, "Hall")
	walls(hall)
	floorAndRoof(hall)
	racks(hall, rng)
	lamps(hall)
	office(hall)
	decor(hall, rng)
	cage(level)
	local cams = Builder.folder(level, "Cameras")
	securityCamera(cams, "CameraNorth", Vector3.new(44, 9, 10), Vector3.new(50, 0, -2))
	securityCamera(cams, "CameraSouth", Vector3.new(44, 9, -10), Vector3.new(50, 0, 2))
end

return Warehouse
