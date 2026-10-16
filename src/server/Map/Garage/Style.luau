--!strict
-- Shared dimensions, colours and small builders of the Garage (beta-spec-maps §4, §9: brick, concrete, crew
-- orange, tungsten lamps (255, 180, 110)). Local coordinates; north = −X (canal), the viaduct runs along Z.

local Builder = require(script.Parent.Parent.Common.Builder)
local Kit = require(script.Parent.Kit)

local C = Builder.Colors

local Style = {}

-- The viaduct (x −20..20, z −50..70).
Style.FRONT = -20 -- facade line
Style.BACK = 20 -- inner face of the back wall
Style.SPRING = 10 -- the arches spring from the piers here
Style.CROWN = 16 -- arch crown (interior clear height ≥ 12 under it)
Style.DECK = 18 -- underside of the deck
Style.TOP = 24 -- top of the deck (railway level)

-- Bays between the piers (z ranges) and the piers themselves.
Style.Bays = {
	Workshop = { -34, -14 },
	VanBay = { -10, 10 },
	Lounge = { 14, 34 },
	Yard = { 38, 64 },
} :: { [string]: { number } }
Style.Piers = { { -38, -34 }, { -14, -10 }, { 10, 14 }, { 34, 38 } } :: { { number } }
Style.PASSAGE = { -2, 4 } -- 6-wide arched passage (x) through the piers between the rooms
Style.YARD_DOOR = { -14, -8 } -- 6-wide door (x) from the lounge into the yard
Style.DOOR_HEIGHT = 9

Style.Colors = {
	Brick = C.BrickRed,
	BrickDark = C.BrickDark,
	BrickWarm = C.BrickWarm,
	Concrete = C.Concrete,
	Floor = Color3.fromRGB(122, 120, 116),
	Asphalt = Color3.fromRGB(58, 60, 64),
	Steel = C.Metal,
	Orange = C.CrewOrange,
	Tungsten = Color3.fromRGB(255, 180, 110),
	Wood = C.Wood,
	WoodDark = C.WoodDark,
	Cork = Color3.fromRGB(176, 136, 92),
	Enamel = Color3.fromRGB(46, 74, 62),
	Glass = Color3.fromRGB(255, 206, 150),
	Rust = Color3.fromRGB(132, 70, 42),
	Water = Color3.fromRGB(28, 54, 62),
}

-- Fresh option tables (Builder.cylinder writes into the table it gets, so never share one).
function Style.brick(): Builder.PartOpts
	return { material = Enum.Material.Brick, variant = "CC_Brick" }
end
function Style.concrete(): Builder.PartOpts
	return { material = Enum.Material.Concrete }
end
function Style.metal(): Builder.PartOpts
	return { material = Enum.Material.Metal }
end
function Style.wood(): Builder.PartOpts
	return { material = Enum.Material.Wood }
end
function Style.decal(): Builder.PartOpts
	-- Paint on the floor: no collision, no shadow, not hit by raycasts.
	return { collide = false, shadow = false, query = false }
end

-- A hanging workshop lamp: cable from the vault, enamel shade and a tungsten bulb with a PointLight.
-- bulb = local position of the bulb.
function Style.pendant(
	k: Kit.Kit,
	parent: Instance,
	bulb: Vector3,
	ceilingY: number,
	range: number,
	brightness: number,
	shadows: boolean
): Part
	local model = Instance.new("Model")
	model.Name = "Pendant"
	model.Parent = parent
	k.box(
		model,
		"Cable",
		bulb + Vector3.new(-0.06, 0.8, -0.06),
		Vector3.new(bulb.X + 0.06, ceilingY, bulb.Z + 0.06),
		C.Metal,
		{ shadow = false }
	)
	k.cylinder(
		model,
		"Shade",
		2.4,
		0.9,
		bulb + Vector3.new(0, 0.55, 0),
		Style.Colors.Enamel,
		{ material = Enum.Material.Metal, shadow = false }
	)
	local glow = k.block(model, "Bulb", Vector3.new(0.8, 0.8, 0.8), CFrame.new(bulb), Style.Colors.Tungsten, {
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		collide = false,
		shadow = false,
	})
	Builder.pointLight(glow, range, brightness, Style.Colors.Tungsten, shadows)
	return glow
end

-- A canal street lamp (StreetLamp prop, glass at 9.1–10.2) with a warm PointLight. ground = local floor point.
function Style.streetLamp(
	k: Kit.Kit,
	parent: Instance,
	ground: Vector3,
	range: number,
	shadows: boolean?
): Part
	k.prop(parent, "StreetLamp", ground, 0, {
		fallback = function(p, g)
			local post = Builder.cylinder(p, "LampPost", 0.5, 9, g + Vector3.new(0, 4.5, 0), C.Metal, {})
			Builder.block(
				p,
				"LampHead",
				Vector3.new(1.6, 0.4, 1.6),
				CFrame.new(g + Vector3.new(0, 10.4, 0)),
				C.Metal,
				{ shadow = false }
			)
			return post
		end,
	})
	local glass = k.block(
		parent,
		"LampGlass",
		Vector3.new(1.1, 1.1, 1.1),
		CFrame.new(ground + Vector3.new(0, 9.65, 0)),
		C.LampWarm,
		{ material = Enum.Material.Neon, shape = Enum.PartType.Cylinder, collide = false, shadow = false }
	)
	Builder.pointLight(glass, range, 1.4, C.LampWarm, shadows == true)
	return glass
end

-- A hide spot (contract: Model tagged HideSpot with HideKind, PrimaryPart with Attachments Inside and Exit).
-- The PrimaryPart "Body" is an invisible marker volume; the prop (or a cask/barrel fallback) is the collider.
-- exitDir (local) points to where a player tumbles out.
function Style.hideSpot(
	k: Kit.Kit,
	parent: Instance,
	kind: string,
	ground: Vector3,
	size: Vector3,
	exitDir: Vector3,
	propName: string,
	propScale: number?,
	hideSpotTag: string
): Model
	local model = Kit.model(parent, "HideSpot", hideSpotTag, { HideKind = kind })
	local center = ground + Vector3.new(0, size.Y / 2, 0)
	local body = k.block(model, "Body", size, CFrame.new(center), C.Wood, {
		transparency = 1,
		collide = false,
		shadow = false,
	})
	model.PrimaryPart = body
	Kit.attachment(body, "Inside", k.world(center))
	local reach = math.max(size.X, size.Z) / 2 + 2
	Kit.attachment(body, "Exit", k.world(ground + exitDir.Unit * reach + Vector3.new(0, 3, 0)))
	k.prop(model, propName, ground, 0, {
		scale = propScale,
		fallback = function(p, g)
			local stave = Builder.cylinder(
				p,
				"Cask",
				size.X,
				size.Y,
				g + Vector3.new(0, size.Y / 2, 0),
				Style.Colors.Wood,
				{ material = Enum.Material.Wood }
			)
			for _, y in { size.Y * 0.2, size.Y * 0.8 } do
				Builder.cylinder(
					p,
					"Hoop",
					size.X + 0.12,
					0.3,
					g + Vector3.new(0, y, 0),
					C.Metal,
					{ material = Enum.Material.Metal, collide = false, shadow = false }
				)
			end
			Builder.cylinder(
				p,
				"Lid",
				size.X - 0.3,
				0.12,
				g + Vector3.new(0, size.Y + 0.06, 0),
				Style.Colors.WoodDark,
				{ material = Enum.Material.Wood, collide = false }
			)
			return stave
		end,
	})
	return model
end

return Style
