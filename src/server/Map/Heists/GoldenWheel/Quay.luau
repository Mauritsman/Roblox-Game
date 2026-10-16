--!strict
-- The quay of Polderdam (§10.1): the canal street (Common/CanalStreet), our side's house rows, the neighbour blocks
-- that close the ring around the plot, boats, the van (exit), the spawn and the quay's edges.
--
-- Axes: north = -X (towards the canal). Canal x -72..-54, quay x -54..-22, facades of our row at x -22.
-- Our south row ends at z -47 and the north row starts at z 47 (depth 22): the Back Lane and the Bin Alley run
-- between them and the shop/courtyard. Neighbour blocks: z ≤ -59 and z ≥ 47 (x 0..67), warehouse x 67..115.

local Common = script.Parent.Parent.Parent.Common
local Anchors = require(Common.Anchors)
local Builder = require(Common.Builder)
local CanalHouse = require(Common.CanalHouse)
local CanalStreet = require(Common.CanalStreet)

local Layout = require(script.Parent.Layout)

local C = Builder.Colors

local Quay = {}

-- A big brick block with rows of far windows on one face (the backdrop of the ring).
local function neighbourBlock(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	color: Color3,
	face: Vector3, -- outward normal of the face that gets windows (axis-aligned)
	rng: Random
)
	local block =
		Builder.box(parent, name, a, b, color, { material = Enum.Material.Brick, variant = "CC_Brick" })
	local minV, maxV = a:Min(b), a:Max(b)
	local along = if face.X ~= 0 then "Z" else "X"
	local fixed = if face.X > 0
		then maxV.X
		elseif face.X < 0 then minV.X
		elseif face.Z > 0 then maxV.Z
		else minV.Z
	local from = (if along == "Z" then minV.Z else minV.X) + 3
	local to = (if along == "Z" then maxV.Z else maxV.X) - 3
	for _, y in { 6, 12 } do
		local t = from
		while t <= to do
			local pos = if along == "Z"
				then Vector3.new(fixed + face.X * 0.2, y, t)
				else Vector3.new(t, y, fixed + face.Z * 0.2)
			Builder.farWindow(parent, CFrame.lookAt(pos, pos + face), 2.4, 3.2, rng:NextNumber() < 0.3, rng)
			t += 6
		end
	end
	return block
end

local function handcart(parent: Instance, center: Vector3)
	-- Quay handcart: a flat bed (top y 2.4) on two wheels, handle towards the van.
	Builder.box(
		parent,
		"CartBed",
		center + Vector3.new(-1.5, 1.9, -2),
		center + Vector3.new(1.5, 2.4, 2),
		C.Wood,
		{ material = Enum.Material.WoodPlanks }
	)
	for _, x in { -1.6, 1.6 } do
		local wheel = Builder.cylinder(
			parent,
			"CartWheel",
			1.8,
			0.3,
			center + Vector3.new(x, 0.9, 0),
			C.WoodDark,
			{ material = Enum.Material.Wood }
		)
		wheel.CFrame = CFrame.new(center + Vector3.new(x, 0.9, 0)) -- axle along X
	end
	Builder.box(
		parent,
		"CartHandle",
		center + Vector3.new(-1.3, 2.4, 2),
		center + Vector3.new(1.3, 2.7, 3.6),
		C.WoodDark,
		{ material = Enum.Material.Wood }
	)
end

function Quay.build(level: Folder, rng: Random)
	local quay = Builder.folder(level, "Quay")

	-- The canal street: lit lanterns only near the plot (2 with shadows by the van and the shop).
	CanalStreet.build(quay, rng, {
		litLamps = { [-60] = true, [-36] = true, [-12] = true, [12] = true, [36] = true, [60] = true },
		shadowLamps = { [-12] = true, [12] = true },
		treeZ = { -96, -72, -48, -24, 24, 48, 72, 96 },
	})

	-- Our side: near detail next to the plot (no window lights), far LOD further away.
	local west = Vector3.new(-1, 0, 0)
	CanalHouse.row(quay, Vector3.new(-22, 0, -126), Vector3.new(-22, 0, -80), west, rng, {
		depth = 22,
		detail = "far",
	})
	CanalHouse.row(quay, Vector3.new(-22, 0, -80), Vector3.new(-22, 0, -47), west, rng, { depth = 22 })
	CanalHouse.row(quay, Vector3.new(-22, 0, 47), Vector3.new(-22, 0, 80), west, rng, { depth = 22 })
	CanalHouse.row(quay, Vector3.new(-22, 0, 80), Vector3.new(-22, 0, 126), west, rng, {
		depth = 22,
		detail = "far",
	})

	-- Neighbour blocks close the ring: south of the basin, north of the Back Alley, and the warehouse east.
	neighbourBlock(
		quay,
		"NeighbourBlockS",
		Vector3.new(0, 0, -126),
		Vector3.new(67, 18, -59),
		C.BrickRed,
		Vector3.new(0, 0, 1),
		rng
	)
	neighbourBlock(
		quay,
		"NeighbourBlockN",
		Vector3.new(0, 0, 47),
		Vector3.new(67, 18, 126),
		C.BrickRed,
		Vector3.new(0, 0, -1),
		rng
	)
	neighbourBlock(
		quay,
		"NeighbourWarehouse",
		Vector3.new(67, 0, -70),
		Vector3.new(115, 22, 70),
		C.BrickDark,
		Vector3.new(-1, 0, 0),
		rng
	)

	-- Small boats moored in the canal, and a houseboat (scenery).
	Builder.boat(quay, Vector3.new(-57.4, -2.6, -70), Color3.fromRGB(40, 90, 70))
	Builder.boat(quay, Vector3.new(-57.4, -2.6, -28), Color3.fromRGB(220, 220, 210))
	Builder.boat(quay, Vector3.new(-68.6, -2.6, -4), Color3.fromRGB(40, 60, 110))
	Builder.boat(quay, Vector3.new(-68.6, -2.6, 78), Color3.fromRGB(150, 50, 40))
	Builder.box(
		quay,
		"HouseboatHull",
		Vector3.new(-68, -3.6, 30),
		Vector3.new(-58, -1.2, 56),
		Color3.fromRGB(36, 52, 70),
		{ material = Enum.Material.Wood }
	)
	Builder.box(
		quay,
		"HouseboatCabin",
		Vector3.new(-67, -1.2, 34),
		Vector3.new(-59, 3.6, 52),
		Color3.fromRGB(120, 160, 140),
		{ material = Enum.Material.WoodPlanks }
	)
	for i = 0, 2 do
		Builder.window(
			quay,
			CFrame.lookAt(Vector3.new(-58.9, 1.4, 38 + i * 5), Vector3.new(-50, 1.4, 38 + i * 5)),
			2.4,
			2,
			i ~= 1,
			nil,
			rng
		)
	end
	Builder.box(
		quay,
		"HouseboatRoof",
		Vector3.new(-67.5, 3.6, 33.5),
		Vector3.new(-58.5, 4.2, 52.5),
		C.StoneDark
	)

	-- Bikes against the houses south of the Back Lane, a bench by the water, flower boxes.
	for i = 0, 3 do
		Builder.prop(quay, "Bicycle", Vector3.new(-25.2, Builder.SIDEWALK, -64 + i * 3.4), 90 + (i % 2) * 6, {
			fallback = function(p, g)
				return Builder.block(
					p,
					"BikeStub",
					Vector3.new(0.4, 3, 5),
					CFrame.new(g + Vector3.new(0, 1.5, 0)),
					Color3.fromRGB(20, 20, 24)
				)
			end,
		})
	end
	for _, z in { -60, 52, 70 } do
		Builder.prop(quay, "TulipBoxTall", Vector3.new(-23.4, Builder.SIDEWALK, z), 90, { collide = false })
	end
	Builder.box(
		quay,
		"BenchSeat",
		Vector3.new(-50, 1.6, 30),
		Vector3.new(-48, 1.9, 36),
		C.Wood,
		{ material = Enum.Material.WoodPlanks }
	)
	Builder.box(
		quay,
		"BenchBack",
		Vector3.new(-50, 1.9, 30),
		Vector3.new(-49.6, 3.4, 36),
		C.Wood,
		{ material = Enum.Material.WoodPlanks }
	)
	handcart(quay, Vector3.new(-30, 0, -12))

	-- The crew's van: the exit (bank zone behind the rear doors) with the van inside its model.
	local van = Anchors.exit(quay, {
		kind = "Van",
		name = "VanExit",
		bankMin = Vector3.new(-45, 0, 9),
		bankMax = Vector3.new(-35, 8, 17),
		drivePoint = Vector3.new(-44.5, 0.2, -0.5),
	})
	Builder.prop(van, "Van", Layout.VanGround, 0, {
		fallback = function(p, g)
			local body = Builder.block(
				p,
				"Van",
				Vector3.new(6, 6, 13),
				CFrame.new(g + Vector3.new(0, 3.4, 0)),
				C.CrewOrange
			)
			Builder.block(
				p,
				"VanWindshield",
				Vector3.new(5.4, 2, 0.3),
				CFrame.new(g + Vector3.new(0, 4.6, -6.55)),
				C.WindowDark,
				{ material = Enum.Material.Glass }
			)
			return body
		end,
	})
	local vanLabel =
		Builder.block(van, "VanLabel", Vector3.new(1, 1, 1), CFrame.new(-40, 8.5, 4), C.CrewOrange, {
			transparency = 1,
			collide = false,
			query = false,
		})
	Builder.label(vanLabel, "THE VAN", Color3.new(1, 1, 1), 0, 80)

	-- Spawn beside the van (outside the bank zone).
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CrewSpawn"
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = CFrame.new(Layout.Spawn.X, 0.2, Layout.Spawn.Z)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = quay

	-- Invisible boundaries at both ends of the street, with a roadblock as the visible reason.
	Builder.box(quay, "BarrierSouth", Vector3.new(-54, 0, -116), Vector3.new(-22, 14, -115), C.Stone, {
		transparency = 1,
		query = false,
	})
	Builder.box(quay, "BarrierNorth", Vector3.new(-54, 0, 115), Vector3.new(-22, 14, 116), C.Stone, {
		transparency = 1,
		query = false,
	})
	for _, z in { -114, 114 } do
		for i = 0, 3 do
			Builder.box(
				quay,
				"RoadBarrier",
				Vector3.new(-50 + i * 7, 0, z - 0.4),
				Vector3.new(-45 + i * 7, 2.2, z + 0.4),
				Color3.fromRGB(220, 60, 50)
			)
		end
	end
end

return Quay
