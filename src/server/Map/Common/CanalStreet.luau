--!strict
-- A Polderdam canal street (extracted from map 1's Quay): the far bank, the canal with its brick quay walls and
-- water, the quay (cobbled edge, brick road, raised pavement), lanterns, bollards, elms, house rows across the canal
-- and, optionally, house rows + bridges closing both ends. It stops at the facade line (`facadeX`): the land behind
-- it belongs to the heist.
--
-- Everything is given in LOCAL coordinates (north = -X, the canal runs along Z) and placed through `origin`
-- (translation + yaw), so the mini-job can drop the same street at its own origin. Map 1 uses the identity.
--
--   x: westEdge .. canalWest   far bank (cobbles) with a far-LOD house row facing the canal
--      canalWest .. canalEast  canal (water top y -3, bed y -8)
--      canalEast .. facadeX    quay: 8 studs of cobbles, brick road, 5.7-stud pavement (y 0.3) along the facades
--
-- Lanterns: `Lamp` + `Electronic` tags only on lamps that cast light (`litLamps`); the others are neon decor, so
-- the heist stays inside its light budget (≤ 40 lights, ≤ 9 with shadows).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Builder = require(script.Parent.Builder)
local CanalHouse = require(script.Parent.CanalHouse)

local C = Builder.Colors

local CanalStreet = {}

export type Water = "Terrain" | "Part"

export type StreetOpts = {
	origin: CFrame?, -- local → world (default identity)
	zMin: number?, -- street extent along the canal (default -130 .. 130)
	zMax: number?,
	westEdge: number?, -- default -160
	canalWest: number?, -- default -72
	canalEast: number?, -- default -54
	facadeX: number?, -- default -22
	water: Water?, -- default "Terrain" (heists); the Garage and the mini-job use "Part"
	farBank: boolean?, -- far-LOD house row across the canal (default true)
	farBankDepth: number?,
	ends: boolean?, -- house rows, bridges and canal ends at both ends (default true)
	lampZ: { number }?, -- lantern positions along the quay (local z)
	litLamps: { [number]: boolean }?, -- z → lamp casts light (tagged Lamp); others are neon only
	shadowLamps: { [number]: boolean }?, -- z → that light casts shadows
	bollards: boolean?, -- default true
	treeZ: { number }?, -- elms along the quay (local z)
	barrier: boolean?, -- invisible wall along the canal edge (default true)
}

export type Street = {
	folder: Folder,
	origin: CFrame,
	-- Local helpers for the caller (same origin).
	toWorld: (v: Vector3) -> Vector3,
	box: (
		parent: Instance,
		name: string,
		a: Vector3,
		b: Vector3,
		color: Color3,
		opts: Builder.PartOpts?
	) -> Part,
}

-- A canal lantern at `ground` (world). With `light` the bulb gets a PointLight and the Lamp/Electronic tags (an EMP
-- can switch it off); without, it is only a glowing neon bulb.
function CanalStreet.lamp(
	parent: Instance,
	ground: Vector3,
	name: string,
	light: boolean?,
	shadows: boolean?,
	rotY: number?
): BasePart
	local post = Builder.prop(parent, "StreetLamp", ground, rotY or 0, {
		fallback = function(p, g)
			return Builder.cylinder(
				p,
				"LampPost",
				0.6,
				11,
				g + Vector3.new(0, 5.5, 0),
				Color3.fromRGB(34, 52, 44),
				{
					material = Enum.Material.Metal,
				}
			)
		end,
	})
	-- The light source is a separate part (an EMP switches it off). On the AI lantern the glass sits 9.1–10.2
	-- studs high, so a neon cylinder shines through the panes there.
	local isMesh = post ~= nil and post.Name == "StreetLamp"
	local bulb: BasePart = if isMesh
		then Builder.cylinder(parent, name, 1.5, 1.1, ground + Vector3.new(0, 9.65, 0), C.LampWarm, {
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
		else Builder.block(
			parent,
			name,
			Vector3.new(1, 1.2, 1),
			CFrame.new(ground + Vector3.new(0, 11.6, 0)),
			C.LampWarm,
			{
				material = Enum.Material.Neon,
				collide = false,
				shadow = false,
			}
		)
	if light then
		Builder.pointLight(bulb, 26, 1.4, C.LampWarm, shadows == true)
		bulb:SetAttribute(Tags.Disabled, false)
		CollectionService:AddTag(bulb, Tags.Lamp)
		CollectionService:AddTag(bulb, Tags.Electronic)
	end
	return bulb
end

local function defaultLampZ(): { number }
	local list = {}
	for z = -108, 108, 24 do
		table.insert(list, z)
	end
	return list
end

local function defaultTreeZ(): { number }
	local list = {}
	for z = -96, 96, 24 do
		table.insert(list, z)
	end
	return list
end

function CanalStreet.build(parent: Instance, rng: Random, opts: StreetOpts?): Street
	local o: StreetOpts = opts or {}
	local origin = o.origin or CFrame.new()
	local _, yaw, _ = origin:ToOrientation()
	local yawDeg = math.deg(yaw)
	local zMin, zMax = o.zMin or -130, o.zMax or 130
	local westEdge = o.westEdge or -160
	local canalWest, canalEast = o.canalWest or -72, o.canalEast or -54
	local facadeX = o.facadeX or -22
	local edgeX = canalEast + 8 -- cobbled strip by the water
	local sidewalkX = facadeX - 5.7
	local canalMid = (canalWest + canalEast) / 2
	local canalW = canalEast - canalWest
	local length = zMax - zMin
	local zMid = (zMin + zMax) / 2

	local folder = Builder.folder(parent, "CanalStreet")
	local function toWorld(v: Vector3): Vector3
		return origin * v
	end
	local function box(
		p: Instance,
		name: string,
		a: Vector3,
		b: Vector3,
		color: Color3,
		partOpts: Builder.PartOpts?
	): Part
		local minV, maxV = a:Min(b), a:Max(b)
		return Builder.block(p, name, maxV - minV, origin * CFrame.new((minV + maxV) / 2), color, partOpts)
	end
	local cobble: Builder.PartOpts = { material = Enum.Material.Cobblestone, variant = "CC_Cobble" }
	local brick: Builder.PartOpts = { material = Enum.Material.Brick, variant = "CC_Brick" }

	-- Ground: the far bank and the quay in three strips (cobbles by the water, a brick road, a raised pavement).
	box(
		folder,
		"GroundWest",
		Vector3.new(westEdge, -8, zMin),
		Vector3.new(canalWest, 0, zMax),
		C.Cobble,
		cobble
	)
	box(
		folder,
		"GroundQuayEdge",
		Vector3.new(canalEast, -8, zMin),
		Vector3.new(edgeX, 0, zMax),
		C.Cobble,
		cobble
	)
	box(
		folder,
		"GroundRoad",
		Vector3.new(edgeX, -8, zMin),
		Vector3.new(facadeX, 0, zMax),
		Color3.fromRGB(84, 70, 66),
		{ material = Enum.Material.Brick }
	)
	box(
		folder,
		"Sidewalk",
		Vector3.new(sidewalkX, 0, zMin),
		Vector3.new(facadeX, Builder.SIDEWALK, zMax),
		Color3.fromRGB(128, 126, 122),
		{ material = Enum.Material.Slate }
	)
	box(
		folder,
		"Curb",
		Vector3.new(sidewalkX - 0.6, 0, zMin),
		Vector3.new(sidewalkX, Builder.SIDEWALK + 0.1, zMax),
		C.Stone,
		{ material = Enum.Material.Granite }
	)
	box(
		folder,
		"EdgeCurb",
		Vector3.new(edgeX - 0.3, 0, zMin),
		Vector3.new(edgeX + 0.3, 0.12, zMax),
		C.StoneDark,
		{ material = Enum.Material.Granite }
	)
	box(
		folder,
		"CanalBed",
		Vector3.new(canalWest, -12, zMin),
		Vector3.new(canalEast, -8, zMax),
		Color3.fromRGB(40, 46, 44),
		{ material = Enum.Material.Mud }
	)
	-- Brick quay walls with a granite edge.
	for _, x in { canalEast, canalWest } do
		local inward = if x == canalEast then 0.3 else -0.3
		box(
			folder,
			"QuayWall",
			Vector3.new(x - inward, -8, zMin),
			Vector3.new(x + inward, 0, zMax),
			C.BrickDark,
			brick
		)
		box(
			folder,
			"QuayEdge",
			Vector3.new(x - 0.9, 0, zMin),
			Vector3.new(x + 0.9, 0.35, zMax),
			C.Stone,
			{ material = Enum.Material.Granite }
		)
	end
	-- Water.
	if (o.water or "Terrain") == "Terrain" then
		local terrain = workspace.Terrain
		terrain:FillBlock(
			origin * CFrame.new(canalMid, -3, zMid),
			Vector3.new(canalW, 12, length),
			Enum.Material.Air
		)
		terrain:FillBlock(
			origin * CFrame.new(canalMid, -5.5, zMid),
			Vector3.new(canalW, 5, length),
			Enum.Material.Water
		)
		terrain.WaterColor = Color3.fromRGB(28, 54, 62)
		terrain.WaterReflectance = 0.55
		terrain.WaterTransparency = 0.35
		terrain.WaterWaveSize = 0.08
		terrain.WaterWaveSpeed = 6
	else
		local water = box(
			folder,
			"CanalWater",
			Vector3.new(canalWest, -3.4, zMin),
			Vector3.new(canalEast, -3, zMax),
			Color3.fromRGB(28, 54, 62),
			{ transparency = 0.15, collide = false, shadow = false }
		)
		water:SetAttribute("Water", true)
	end

	-- Houses across the canal (background, far LOD).
	if o.farBank ~= false then
		CanalHouse.row(
			folder,
			toWorld(Vector3.new(canalWest - 3, 0, zMin + 4)),
			toWorld(Vector3.new(canalWest - 3, 0, zMax - 4)),
			origin:VectorToWorldSpace(Vector3.new(1, 0, 0)),
			rng,
			{ depth = o.farBankDepth or 18, detail = "far" }
		)
	end
	-- Houses at both ends of the street and bridges over the canal: the world does not end in nothing.
	if o.ends ~= false then
		for _, z in { zMin + 3, zMax - 3 } do
			local sign = if z > zMid then 1 else -1
			local facing = origin:VectorToWorldSpace(Vector3.new(0, 0, -sign))
			CanalHouse.row(
				folder,
				toWorld(Vector3.new(canalEast, 0, z)),
				toWorld(Vector3.new(facadeX, 0, z)),
				facing,
				rng,
				{ depth = 14, detail = "far" }
			)
			CanalHouse.row(
				folder,
				toWorld(Vector3.new(westEdge, 0, z)),
				toWorld(Vector3.new(canalWest - 3, 0, z)),
				facing,
				rng,
				{ depth = 14, detail = "far" }
			)
			CanalStreet.bridge(folder, origin, canalWest, canalEast, z - sign * 16)
			box(
				folder,
				"CanalEnd",
				Vector3.new(canalWest, -12, z),
				Vector3.new(canalEast, 0, z + sign * 3),
				C.BrickDark,
				brick
			)
		end
	end

	-- Lanterns along the canal and bollards (Amsterdammertjes).
	local lit = o.litLamps or {}
	local shadowed = o.shadowLamps or {}
	for index, z in o.lampZ or defaultLampZ() do
		CanalStreet.lamp(
			folder,
			toWorld(Vector3.new(canalEast + 2.5, 0, z)),
			`StreetBulb{index}`,
			lit[z] == true,
			shadowed[z] == true,
			yawDeg
		)
	end
	if o.bollards ~= false then
		for z = math.ceil((zMin + 16) / 6) * 6, zMax - 16, 6 do
			if math.abs(z % 24 - 12) > 2 then
				Builder.cylinder(
					folder,
					"Bollard",
					0.6,
					2.4,
					toWorld(Vector3.new(canalEast + 1.5, 1.2, z)),
					Color3.fromRGB(110, 30, 30),
					{ material = Enum.Material.Metal }
				)
			end
		end
	end
	for _, z in o.treeZ or defaultTreeZ() do
		Builder.tree(folder, toWorld(Vector3.new(canalEast + 5.4, 0, z)), rng)
	end

	-- Invisible boundary: not into the canal.
	if o.barrier ~= false then
		box(
			folder,
			"BarrierCanal",
			Vector3.new(canalEast - 1.5, 0, zMin),
			Vector3.new(canalEast - 0.5, 14, zMax),
			C.Stone,
			{ transparency = 1, query = false }
		)
	end

	return { folder = folder, origin = origin, toWorld = toWorld, box = box }
end

-- An Amsterdam canal bridge across the canal at local z: deck, arch and low railings, with a lantern (neon only)
-- and a bike.
function CanalStreet.bridge(parent: Instance, origin: CFrame, canalWest: number, canalEast: number, z: number)
	local function box(name: string, a: Vector3, b: Vector3, color: Color3, partOpts: Builder.PartOpts?)
		local minV, maxV = a:Min(b), a:Max(b)
		return Builder.block(
			parent,
			name,
			maxV - minV,
			origin * CFrame.new((minV + maxV) / 2),
			color,
			partOpts
		)
	end
	local x0, x1 = canalWest - 2, canalEast + 2
	local deckY = 0.6
	local brick: Builder.PartOpts = { material = Enum.Material.Brick, variant = "CC_Brick" }
	box(
		"BridgeDeck",
		Vector3.new(x0, deckY - 1.2, z - 5),
		Vector3.new(x1, deckY, z + 5),
		C.Stone,
		{ material = Enum.Material.Cobblestone, variant = "CC_Cobble" }
	)
	for _, side in { -1, 1 } do
		box(
			"BridgeRail",
			Vector3.new(x0, deckY, z + side * 5 - 0.5),
			Vector3.new(x1, deckY + 2.4, z + side * 5 + 0.5),
			C.BrickDark,
			brick
		)
		box(
			"BridgeRailCap",
			Vector3.new(x0, deckY + 2.4, z + side * 5 - 0.7),
			Vector3.new(x1, deckY + 2.8, z + side * 5 + 0.7),
			C.Stone,
			{ material = Enum.Material.Granite }
		)
	end
	-- Arch under the deck (blocks that get thinner towards the middle).
	local span = canalEast - canalWest
	local pieces = math.max(1, math.floor(span / 2))
	local step = span / pieces
	for i = 0, pieces - 1 do
		local x = canalWest + i * step
		local depth = 1.2 + math.abs(i - (pieces - 1) / 2) * 0.9
		box(
			"BridgeArch",
			Vector3.new(x, deckY - 1.2 - depth, z - 5),
			Vector3.new(x + step, deckY - 1.2, z + 5),
			C.BrickDark,
			brick
		)
	end
	local _, yaw, _ = origin:ToOrientation()
	CanalStreet.lamp(
		parent,
		origin * Vector3.new((canalWest + canalEast) / 2, deckY, z + 4.2),
		`BridgeLamp{z}`
	)
	Builder.prop(parent, "Bicycle", origin * Vector3.new(canalEast - 6, deckY, z + 3.6), 90 + math.deg(yaw), {
		collide = false,
	})
end

return CanalStreet
