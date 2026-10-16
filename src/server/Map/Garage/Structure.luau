--!strict
-- The Garage's shell (beta-spec-maps §4): the brick viaduct with four arches (workshop, van bay, lounge, yard),
-- the room fronts, the cobbled forecourt, the canal (part water), the far bank and the invisible edges.
--
-- local, x: −80..−56 far bank · −56..−36 canal · −36..−20 forecourt · −20..20 viaduct · 20 back wall
--        z: −50..−38 abutment · workshop −34..−14 · van bay −10..10 · lounge 14..34 · yard 38..64 · 64..70 abutment

local Builder = require(script.Parent.Parent.Common.Builder)
local Kit = require(script.Parent.Kit)
local Style = require(script.Parent.Style)

local C = Builder.Colors
local S = Style.Colors
local V = Vector3.new

local FRONT, SPRING, CROWN, DECK, TOP = Style.FRONT, Style.SPRING, Style.CROWN, Style.DECK, Style.TOP

local Structure = {}

-- One arch bay: a barrel vault (axis along X) from z0 to z1, springing at SPRING with its crown at CROWN, and the
-- brick spandrels on the facade above it. The vault's front edge stands 0.4 proud of the facade (the arch ring).
local function archBay(k: Kit.Kit, parent: Instance, z0: number, z1: number)
	local zc, a, b = (z0 + z1) / 2, (z1 - z0) / 2, CROWN - SPRING
	local segments = 8
	local thickness = 1.2
	local points: { Vector2 } = {}
	for i = 0, segments do
		local angle = math.pi * i / segments
		table.insert(points, Vector2.new(zc - a * math.cos(angle), SPRING + b * math.sin(angle)))
	end
	for i = 1, segments do
		local p, q = points[i], points[i + 1]
		local d = q - p
		local mid = (p + q) / 2
		-- Rotate about X so the block's local Z follows the chord; shift up so its underside lies on the chord.
		local cf = CFrame.new(-0.2, mid.Y, mid.X)
			* CFrame.Angles(-math.atan2(d.Y, d.X), 0, 0)
			* CFrame.new(0, thickness / 2, 0)
		k.block(parent, "Vault", V(40.4, thickness, d.Magnitude + 0.25), cf, S.BrickDark, Style.brick())

		-- Spandrel on the facade: everything above the segment's top line up to the deck.
		local za, zb = p.X, q.X
		local ya, yb = p.Y + thickness, q.Y + thickness
		local top = math.max(ya, yb)
		k.box(parent, "Spandrel", V(FRONT, top, za), V(FRONT + 0.6, DECK, zb), S.Brick, Style.brick())
		local rise = math.abs(yb - ya)
		if rise > 0.05 then
			-- WedgePart: solid under the slope from its bottom-front (−Z) edge to its top-back edge. Flipped so the
			-- solid sits above the arch line on either half.
			local flip = if yb > ya then CFrame.Angles(math.pi, 0, 0) else CFrame.Angles(0, 0, math.pi)
			k.wedge(
				parent,
				"SpandrelWedge",
				V(0.6, rise, zb - za),
				CFrame.new(FRONT + 0.3, (ya + yb) / 2, (za + zb) / 2) * flip,
				S.Brick,
				Style.brick()
			)
		end
	end
end

-- A pier between two bays, optionally with a 9-high opening (x range) through it.
local function pier(k: Kit.Kit, parent: Instance, z0: number, z1: number, opening: { number }?)
	if not opening then
		k.box(parent, "Pier", V(FRONT, 0, z0), V(Style.BACK, DECK, z1), S.Brick, Style.brick())
		return
	end
	local x0, x1 = opening[1], opening[2]
	k.box(parent, "Pier", V(FRONT, 0, z0), V(x0, DECK, z1), S.Brick, Style.brick())
	k.box(parent, "Pier", V(x1, 0, z0), V(Style.BACK, DECK, z1), S.Brick, Style.brick())
	k.box(parent, "PierLintel", V(x0, Style.DOOR_HEIGHT, z0), V(x1, DECK, z1), S.Brick, Style.brick())
	-- Dark brick trim around the opening on both faces.
	for _, z in { z0 - 0.15, z1 + 0.15 } do
		k.box(
			parent,
			"OpeningTrim",
			V(x0 - 0.5, 0, z - 0.15),
			V(x0, 9.5, z + 0.15),
			S.BrickDark,
			Style.brick()
		)
		k.box(
			parent,
			"OpeningTrim",
			V(x1, 0, z - 0.15),
			V(x1 + 0.5, 9.5, z + 0.15),
			S.BrickDark,
			Style.brick()
		)
		k.box(
			parent,
			"OpeningTrim",
			V(x0 - 0.5, 9, z - 0.15),
			V(x1 + 0.5, 9.5, z + 0.15),
			S.BrickDark,
			Style.brick()
		)
	end
end

-- The glazed half-moon above a room front (hidden above the arch line by the spandrels and the vault).
local function fanlight(k: Kit.Kit, parent: Instance, z0: number, z1: number)
	k.box(parent, "Fanlight", V(FRONT + 0.3, SPRING, z0), V(FRONT + 0.6, CROWN + 0.6, z1), S.Glass, {
		material = Enum.Material.Glass,
		transparency = 0.35,
		shadow = false,
	})
	local step = (z1 - z0) / 4
	for i = 1, 3 do
		local z = z0 + step * i
		k.box(
			parent,
			"FanlightBar",
			V(FRONT + 0.2, SPRING, z - 0.12),
			V(FRONT + 0.3, CROWN, z + 0.12),
			C.Metal,
			{
				shadow = false,
			}
		)
	end
	k.box(
		parent,
		"FanlightBar",
		V(FRONT + 0.2, 12.9, z0),
		V(FRONT + 0.3, 13.1, z1),
		C.Metal,
		{ shadow = false }
	)
end

-- A room front between z0 and z1 (wall up to the springing line) with a window and a 6-wide, 9-high doorway.
local function roomFront(
	k: Kit.Kit,
	parent: Instance,
	z0: number,
	z1: number,
	window: { number },
	door: { number }
)
	local x0, x1 = FRONT, FRONT + 1
	local cuts = { window, door }
	table.sort(cuts, function(p, q)
		return p[1] < q[1]
	end)
	local z = z0
	for _, cut in cuts do
		if cut[1] > z then
			k.box(parent, "FrontWall", V(x0, 0, z), V(x1, SPRING, cut[1]), S.Brick, Style.brick())
		end
		z = cut[2]
	end
	if z < z1 then
		k.box(parent, "FrontWall", V(x0, 0, z), V(x1, SPRING, z1), S.Brick, Style.brick())
	end
	-- Window: wall below (sill) and above, frame and glass.
	k.box(parent, "FrontWall", V(x0, 0, window[1]), V(x1, 3, window[2]), S.Brick, Style.brick())
	k.box(parent, "FrontWall", V(x0, 8, window[1]), V(x1, SPRING, window[2]), S.Brick, Style.brick())
	local wz = (window[1] + window[2]) / 2
	k.window(
		parent,
		CFrame.lookAt(V(FRONT + 0.5, 5.5, wz), V(FRONT - 1, 5.5, wz)),
		window[2] - window[1] - 0.6,
		4.4,
		true,
		S.Orange
	)
	-- Doorway: lintel and an orange steel frame.
	k.box(
		parent,
		"FrontWall",
		V(x0, Style.DOOR_HEIGHT, door[1]),
		V(x1, SPRING, door[2]),
		S.Brick,
		Style.brick()
	)
	k.box(
		parent,
		"DoorFrame",
		V(x0 - 0.15, 0, door[1]),
		V(x1 + 0.1, 9.2, door[1] + 0.2),
		S.Orange,
		Style.metal()
	)
	k.box(
		parent,
		"DoorFrame",
		V(x0 - 0.15, 0, door[2] - 0.2),
		V(x1 + 0.1, 9.2, door[2]),
		S.Orange,
		Style.metal()
	)
	k.box(
		parent,
		"DoorFrame",
		V(x0 - 0.15, Style.DOOR_HEIGHT, door[1]),
		V(x1 + 0.1, 9.2, door[2]),
		S.Orange,
		Style.metal()
	)
	fanlight(k, parent, z0, z1)
end

local function viaduct(k: Kit.Kit, parent: Instance)
	local f = Builder.folder(parent, "Viaduct")
	-- Abutments at both ends, piers between the bays.
	k.box(f, "Abutment", V(FRONT, 0, -50), V(Style.BACK, TOP, -38), S.Brick, Style.brick())
	k.box(f, "Abutment", V(FRONT, 0, 64), V(Style.BACK, TOP, 70), S.Brick, Style.brick())
	local piers = Style.Piers
	pier(k, f, piers[1][1], piers[1][2], nil)
	pier(k, f, piers[2][1], piers[2][2], Style.PASSAGE)
	pier(k, f, piers[3][1], piers[3][2], Style.PASSAGE)
	pier(k, f, piers[4][1], piers[4][2], Style.YARD_DOOR)
	-- Stone imposts where the arches spring.
	for _, p in piers do
		k.box(f, "Impost", V(FRONT - 0.5, SPRING - 0.6, p[1] - 0.3), V(FRONT, SPRING, p[2] + 0.3), C.Stone, {
			material = Enum.Material.Slate,
		})
	end
	-- Deck, cornice and parapets (the railway runs on top).
	k.box(f, "Deck", V(FRONT - 0.4, DECK, -50), V(Style.BACK + 0.4, TOP, 70), S.Brick, Style.brick())
	k.box(f, "Cornice", V(FRONT - 1, TOP - 0.7, -50), V(FRONT - 0.4, TOP, 70), C.Stone, {
		material = Enum.Material.Slate,
	})
	k.box(f, "Parapet", V(FRONT - 0.4, TOP, -50), V(FRONT + 0.4, TOP + 1.6, 70), S.BrickDark, Style.brick())
	k.box(
		f,
		"Parapet",
		V(Style.BACK - 0.4, TOP, -50),
		V(Style.BACK + 0.4, TOP + 1.6, 70),
		S.BrickDark,
		Style.brick()
	)
	-- Back wall behind every bay.
	k.box(f, "BackWall", V(Style.BACK, 0, -38), V(Style.BACK + 1.2, DECK, 64), S.BrickWarm, Style.brick())
	for _, bay in Style.Bays do
		archBay(k, f, bay[1], bay[2])
	end
end

local function fronts(k: Kit.Kit, parent: Instance)
	local f = Builder.folder(parent, "Fronts")
	local W, L = Style.Bays.Workshop, Style.Bays.Lounge
	roomFront(k, f, W[1], W[2], { -32, -25 }, { -22, -16 })
	roomFront(k, f, L[1], L[2], { 16, 23 }, { 26, 32 })

	-- Van bay: open roller door (16 wide, 12 high) with brick infill above.
	k.box(f, "BayWall", V(FRONT, 0, -10), V(FRONT + 1, 12, -8), S.Brick, Style.brick())
	k.box(f, "BayWall", V(FRONT, 0, 8), V(FRONT + 1, 12, 10), S.Brick, Style.brick())
	k.box(f, "BayHeader", V(FRONT, 12, -10), V(FRONT + 1, DECK, 10), S.Brick, Style.brick())
	k.block(
		f,
		"RollerDrum",
		V(16.4, 1.4, 1.4),
		CFrame.new(FRONT + 1.6, 12.75, 0) * CFrame.Angles(0, math.rad(90), 0),
		C.Metal,
		{ material = Enum.Material.CorrodedMetal, shape = Enum.PartType.Cylinder }
	)
	-- Guide rails on the facade, outside the opening.
	for _, z in { -8.4, 8.4 } do
		k.box(f, "RollerRail", V(FRONT - 0.4, 0, z - 0.2), V(FRONT, 12, z + 0.2), C.Metal, Style.metal())
	end
	k.sign(f, "THE GARAGE", V(FRONT - 0.5, 15, 0), V(-1, 0, 0), 14, 2.4, V(-34, 5, 0), { depth = 0.9 })
	for i = 0, 7 do
		-- Hazard stripes on the threshold.
		local z = -8 + i * 2
		k.box(
			f,
			"Stripe",
			V(FRONT, 0, z),
			V(FRONT + 1.4, 0.05, z + 1),
			if i % 2 == 0 then C.Safety else C.StoneDark,
			Style.decal()
		)
	end

	-- Yard: a 12-high fence (jump height is 7.2) between the forecourt and the practice yard.
	local Y = Style.Bays.Yard
	k.box(f, "YardFence", V(FRONT - 0.15, 0, Y[1]), V(FRONT + 0.05, 12, Y[2]), C.Metal, {
		material = Enum.Material.DiamondPlate,
		transparency = 0.6,
		shadow = false,
	})
	for i = 0, 4 do
		local z = Y[1] + 0.3 + (Y[2] - Y[1] - 0.6) * i / 4
		k.box(
			f,
			"FencePost",
			V(FRONT - 0.35, 0, z - 0.25),
			V(FRONT + 0.15, 12.2, z + 0.25),
			C.Metal,
			Style.metal()
		)
	end
	for _, y in { 0.3, 11.8 } do
		k.box(
			f,
			"FenceRail",
			V(FRONT - 0.3, y - 0.15, Y[1]),
			V(FRONT + 0.1, y + 0.15, Y[2]),
			C.Metal,
			Style.metal()
		)
	end
end

local function ground(k: Kit.Kit, parent: Instance, rng: Random)
	local f = Builder.folder(parent, "Ground")
	k.box(f, "Forecourt", V(-36, -8, -50), V(FRONT, 0, 70), C.Cobble, {
		material = Enum.Material.Cobblestone,
		variant = "CC_Cobble",
	})
	k.box(f, "Floor", V(FRONT, -1, -50), V(Style.BACK + 1.2, 0, 36), S.Floor, Style.concrete())
	k.box(f, "YardFloor", V(FRONT, -1, 36), V(Style.BACK + 1.2, 0, 70), S.Asphalt, {
		material = Enum.Material.Asphalt,
	})
	-- Canal: quay wall, edge stones, bed and part water (top at y −3).
	k.box(f, "QuayWall", V(-36.6, -8, -50), V(-36, 0, 70), S.BrickDark, Style.brick())
	k.box(f, "QuayEdge", V(-37, 0, -50), V(-35.6, 0.3, 70), C.Stone, { material = Enum.Material.Granite })
	k.box(f, "CanalBed", V(-56, -12, -50), V(-36.6, -8, 70), Color3.fromRGB(40, 46, 44), {
		material = Enum.Material.Mud,
	})
	k.box(f, "CanalWater", V(-56, -8, -50), V(-36.6, -3, 70), S.Water, {
		transparency = 0.15,
		collide = false,
		shadow = false,
		query = false,
	})
	-- Far bank with a row of low-detail canal houses facing us.
	k.box(f, "FarQuayWall", V(-56.6, -8, -50), V(-56, 0, 70), S.BrickDark, Style.brick())
	k.box(f, "FarBank", V(-80, -8, -50), V(-56.6, 0, 70), C.Cobble, { material = Enum.Material.Cobblestone })
	Kit.farRow(k, f, V(-60, 0, -50), V(-60, 0, 70), V(1, 0, 0), rng)
	-- Iron railing along the canal edge.
	for i = 0, 20 do
		local z = -49 + i * 118 / 20
		k.box(f, "RailingPost", V(-36.2, 0.3, z - 0.15), V(-35.9, 3.2, z + 0.15), C.Metal, Style.metal())
	end
	k.box(f, "Railing", V(-36.25, 2.9, -49), V(-35.85, 3.2, 69), C.Metal, Style.metal())
	-- Brick walls closing the forecourt at both ends.
	k.box(f, "EndWall", V(-36, 0, -50.6), V(FRONT, 6, -50), S.Brick, Style.brick())
	k.box(f, "EndWall", V(-36, 0, 70), V(FRONT, 6, 70.6), S.Brick, Style.brick())
end

-- Invisible walls ≥ 14 high at the edges (beta-spec-maps §2), so nobody falls into the canal or leaves the area.
local function edges(k: Kit.Kit, parent: Instance)
	local f = Builder.folder(parent, "Edges")
	local opts: Builder.PartOpts = { transparency = 1, query = false, shadow = false }
	k.box(f, "EdgeCanal", V(-36.4, 0, -51), V(-35.8, 16, 71), C.Stone, opts)
	k.box(f, "EdgeSouth", V(-36, 0, -51.2), V(FRONT, 16, -50.6), C.Stone, opts)
	k.box(f, "EdgeNorth", V(-36, 0, 70.6), V(FRONT, 16, 71.2), C.Stone, opts)
end

local function forecourt(k: Kit.Kit, parent: Instance)
	local f = Builder.folder(parent, "Forecourt")
	Style.streetLamp(k, f, V(-34, 0, -24), 34)
	Style.streetLamp(k, f, V(-34, 0, 24), 34)
	-- Parking bay in front of the roller door.
	for _, z in { -6, 6 } do
		k.box(f, "ParkingLine", V(-34, 0, z - 0.2), V(FRONT, 0.05, z + 0.2), C.Trim, Style.decal())
	end
	-- Oil drums and crates against the viaduct, clear of the doors.
	for i, spot in { V(-22, 0, -36), V(-22.3, 0, -12.4), V(-22, 0, 35.5) } do
		k.prop(f, "Barrel", spot, i * 40, {
			scale = 1.3,
			fallback = function(p, g)
				return Builder.cylinder(p, "Drum", 2.4, 3.2, g + V(0, 1.6, 0), S.Orange, {
					material = Enum.Material.Metal,
				})
			end,
		})
	end
	for _, spot in { V(-23, 0, 40.5), V(-23, 0, 12.6) } do
		k.prop(f, "Crate", spot, 10, {
			fallback = function(p, g)
				return Builder.block(p, "Crate", V(4, 3.8, 4), CFrame.new(g + V(0, 1.9, 0)), C.Wood, {
					material = Enum.Material.WoodPlanks,
				})
			end,
		})
	end
	-- A bench by the water.
	k.box(f, "BenchSeat", V(-33.5, 1.6, 44), V(-31.5, 1.9, 50), C.WoodDark, Style.wood())
	k.box(f, "BenchLeg", V(-33.3, 0, 44.5), V(-31.7, 1.6, 45), C.Metal, Style.metal())
	k.box(f, "BenchLeg", V(-33.3, 0, 49), V(-31.7, 1.6, 49.5), C.Metal, Style.metal())
end

function Structure.build(k: Kit.Kit, folder: Folder, rng: Random)
	ground(k, folder, rng)
	viaduct(k, folder)
	fronts(k, folder)
	edges(k, folder)
	forecourt(k, folder)
end

return Structure
