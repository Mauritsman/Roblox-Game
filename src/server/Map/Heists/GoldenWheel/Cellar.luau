--!strict
-- The cold cellar under the shop (Secure, main loot spot G3): x -22..0, z -46..-20, floor y -9.8, ceiling y -0.5.
-- Exit 1: the cellar door (x 0, z -46..-40, Pryable 3, red lamp) onto the ramp trench to the Back Yard.
-- Exit 2: the stairwell up into Karel's closet (x -7..-0.6, z -38.5..-26.5; built in Shop.luau).
-- Inside: an aging rack along the west wall, a low ripening shelf, the cheese press, frost-blue light.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Common = script.Parent.Parent.Parent.Common
local Builder = require(Common.Builder)
local Doors = require(Common.Doors)

local Layout = require(script.Parent.Layout)

local C = Builder.Colors

local Cellar = {}

local FROST = Color3.fromRGB(150, 200, 255)
local FLOOR = Layout.CellarFloor
local BRICK: Builder.PartOpts = { material = Enum.Material.Brick, variant = "CC_Brick" }
local METAL: Builder.PartOpts = { material = Enum.Material.Metal }

-- Medium/small loot anchors on the aging rack: decor leaves these spots free.
local RACK_ANCHORS = { Vector3.new(-18, -7, -28), Vector3.new(-21, -7, -36) }

local function frostLamp(parent: Instance, name: string, pos: Vector3, shadows: boolean)
	local bulb = Builder.block(parent, name, Vector3.new(1, 0.5, 1), CFrame.new(pos), FROST, {
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	Builder.pointLight(bulb, 20, 1.4, FROST, shadows)
	bulb:SetAttribute(Tags.Disabled, false)
	CollectionService:AddTag(bulb, Tags.Lamp)
	CollectionService:AddTag(bulb, Tags.Electronic)
	Builder.block(
		parent,
		"Cord",
		Vector3.new(0.1, -0.5 - pos.Y, 0.1),
		CFrame.new(pos.X, (pos.Y - 0.5) / 2, pos.Z),
		C.StoneDark,
		{
			collide = false,
			shadow = false,
		}
	)
end

local function cheese(parent: Instance, ground: Vector3, rotY: number)
	Builder.prop(parent, "CheeseWheel", ground, rotY, {
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
	})
end

function Cellar.build(level: Folder, rng: Random)
	local cellar = Builder.folder(level, "Cellar")
	-- Ceiling slab (also the floor under the shop and the Back Lane), cut open for the stairwell.
	local slab: Builder.PartOpts = { material = Enum.Material.Concrete }
	Builder.box(
		cellar,
		"CellarCeilingW",
		Vector3.new(-22, -0.5, -46),
		Vector3.new(-7.5, 0, -20),
		C.Concrete,
		slab
	)
	Builder.box(
		cellar,
		"CellarCeilingS",
		Vector3.new(-7.5, -0.5, -46),
		Vector3.new(0, 0, -40),
		C.Concrete,
		slab
	)
	Builder.box(
		cellar,
		"CellarCeilingN",
		Vector3.new(-7.5, -0.5, -26),
		Vector3.new(0, 0, -20),
		C.Concrete,
		slab
	)
	-- Floor and brick walls.
	Builder.box(
		cellar,
		"CellarFloor",
		Vector3.new(-22, FLOOR - 0.5, -46),
		Vector3.new(0, FLOOR, -20),
		C.StoneDark,
		{
			material = Enum.Material.Slate,
		}
	)
	Builder.box(
		cellar,
		"CellarWallW",
		Vector3.new(-22.5, -10.3, -46.5),
		Vector3.new(-22, 0, -19.5),
		C.BrickDark,
		BRICK
	)
	Builder.box(
		cellar,
		"CellarWallS",
		Vector3.new(-22.5, -10.3, -46.5),
		Vector3.new(0, 0, -46),
		C.BrickDark,
		BRICK
	)
	Builder.box(
		cellar,
		"CellarWallN",
		Vector3.new(-22.5, -10.3, -20),
		Vector3.new(0, 0, -19.5),
		C.BrickDark,
		BRICK
	)
	Builder.box(
		cellar,
		"CellarWallE",
		Vector3.new(-0.5, -10.3, -40),
		Vector3.new(0, -0.5, -20),
		C.BrickDark,
		BRICK
	)
	Builder.box(
		cellar,
		"CellarLintel",
		Vector3.new(-0.5, -1, -46),
		Vector3.new(0, -0.5, -40),
		C.BrickDark,
		BRICK
	)
	-- The cellar door (Secure: red lamp outside), swinging into the cellar.
	local door = Doors.leaf(
		cellar,
		"CellarDoor",
		Vector3.new(-0.25, FLOOR, -46),
		Vector3.new(-0.25, FLOOR, -40),
		8.8,
		-Vector3.xAxis,
		{
			thickness = 0.4,
			color = Color3.fromRGB(70, 96, 120),
			material = Enum.Material.DiamondPlate,
		}
	)
	Doors.pryable(door, Config.Gadgets.Crowbar.CageSeconds)
	Doors.redLamp(cellar, Vector3.new(0.45, -0.75, -43))

	-- Aging rack along the west wall (x -21.6..-17.9, z -38..-22): back panel, uprights, three shelves.
	Builder.box(
		cellar,
		"RackBack",
		Vector3.new(-21.9, FLOOR, -38),
		Vector3.new(-21.6, -2.5, -22),
		C.WoodDark,
		{
			material = Enum.Material.Wood,
		}
	)
		:SetAttribute("Cover", true)
	for _, z in { -38, -30, -22 } do
		Builder.box(
			cellar,
			"Upright",
			Vector3.new(-18.1, FLOOR, z - 0.2),
			Vector3.new(-17.7, -2.5, z + 0.2),
			C.RackBlue,
			METAL
		)
	end
	for _, top in { -9.2, -7, -4.8 } do
		Builder.box(
			cellar,
			"Shelf",
			Vector3.new(-21.6, top - 0.2, -38),
			Vector3.new(-17.9, top, -22),
			C.Wood,
			{
				material = Enum.Material.WoodPlanks,
			}
		)
		for _, z in { -35.5, -31.5, -27.5, -24 } do
			local pos = Vector3.new(-19.7, top, z)
			local blocked = false
			for _, a in RACK_ANCHORS do
				if math.abs(a.Y - top) < 0.3 and math.abs(a.Z - z) < 2.2 then
					blocked = true
				end
			end
			if not blocked and rng:NextNumber() < 0.8 then
				cheese(cellar, pos, rng:NextInteger(0, 359))
			end
		end
	end
	-- Low ripening shelf in the middle (crouch cover) with wheels on top.
	Builder.box(
		cellar,
		"RipeningShelf",
		Vector3.new(-12, FLOOR, -34),
		Vector3.new(-9, FLOOR + 3.6, -26),
		C.WoodDark,
		{
			material = Enum.Material.Wood,
		}
	)
		:SetAttribute("Cover", true)
	for _, z in { -32.5, -29.8, -27.4 } do
		cheese(cellar, Vector3.new(-10.5, FLOOR + 3.6, z), rng:NextInteger(0, 359))
	end
	-- The cheese press by the south wall; the Gouda spot G3 is right in front of it.
	Builder.prop(cellar, "CheesePress", Vector3.new(-16, FLOOR, -44), 0, {
		fallback = function(p, g)
			local model = Instance.new("Model")
			model.Name = "CheesePressStub"
			Builder.box(
				model,
				"PressBase",
				g + Vector3.new(-2, 0, -2),
				g + Vector3.new(2, 1.2, 2),
				C.WoodDark,
				{
					material = Enum.Material.Wood,
				}
			)
			for _, x in { -1.6, 1.6 } do
				Builder.box(
					model,
					"PressPost",
					g + Vector3.new(x - 0.3, 1.2, -0.3),
					g + Vector3.new(x + 0.3, 6, 0.3),
					C.WoodDark,
					{
						material = Enum.Material.Wood,
					}
				)
			end
			Builder.box(
				model,
				"PressBeam",
				g + Vector3.new(-2, 5.4, -0.4),
				g + Vector3.new(2, 6, 0.4),
				C.WoodDark,
				{
					material = Enum.Material.Wood,
				}
			)
			Builder.cylinder(model, "PressScrew", 0.5, 4, g + Vector3.new(0, 3.4, 0), C.Metal, METAL)
			model.Parent = p
			return model
		end,
	})
	-- Frost-blue lamps (one with shadows).
	frostLamp(cellar, "CellarLamp1", Vector3.new(-14, -2.2, -30), true)
	frostLamp(cellar, "CellarLamp2", Vector3.new(-6, -2.2, -42), false)
end

return Cellar
