--!strict
-- Van bay (z −10..10): the crew van (meta: VanPaint), the departure zone `GarageVan` (mechanics: standing in it
-- starts the van countdown; child `DrivePoint`), the job board (meta: JobBoard) and the Garage SpawnLocation.
--
--   x −15..−2 van (nose to the roller door) · x −2..10 GarageVan zone · spawn (13.5, 0) · job board on the back wall

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MetaTags = require(ReplicatedStorage.Shared.MetaTags)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Builder = require(script.Parent.Parent.Common.Builder)
local Kit = require(script.Parent.Kit)
local Style = require(script.Parent.Style)

local C = Builder.Colors
local S = Style.Colors
local V = Vector3.new

local BACK = Style.BACK

local VanBay = {}

-- Stand-in van when the Van prop is missing: body, windscreen, bumper, stripe and wheels. Nose = local −Z.
function VanBay.vanFallback(color: Color3): (Instance, Vector3, number) -> Instance
	return function(parent: Instance, ground: Vector3, rotY: number): Instance
		local m = Instance.new("Model")
		m.Name = "VanStandIn"
		m.Parent = parent
		local base = CFrame.new(ground) * CFrame.Angles(0, math.rad(rotY), 0)
		Builder.block(m, "Body", V(7.6, 6, 12.4), base * CFrame.new(0, 3.9, 0.2), color)
		Builder.block(m, "Windscreen", V(6.8, 2.2, 0.3), base * CFrame.new(0, 5.4, -6.05), C.WindowDark, {
			material = Enum.Material.Glass,
		})
		Builder.block(m, "Bumper", V(7.8, 0.8, 0.6), base * CFrame.new(0, 1.2, -6.3), C.Metal)
		Builder.block(
			m,
			"Stripe",
			V(7.7, 0.6, 12),
			base * CFrame.new(0, 3.6, 0.2),
			C.Trim,
			{ shadow = false }
		)
		for _, sx in { -3.5, 3.5 } do
			for _, sz in { -4.2, 4.2 } do
				Builder.block(
					m,
					"Wheel",
					V(0.9, 2.4, 2.4),
					base * CFrame.new(sx, 1.2, sz),
					Color3.fromRGB(30, 30, 32),
					{ shape = Enum.PartType.Cylinder, material = Enum.Material.Rubber }
				)
			end
		end
		return m
	end
end

local function van(k: Kit.Kit, parent: Instance)
	local model = Kit.model(parent, "CrewVan")
	-- Nose towards the roller door (−X): rear doors at x −2, facing the departure zone.
	local prop = k.prop(model, "Van", V(-8.5, 0, 0), 90, { fallback = VanBay.vanFallback(C.CrewOrange) })
	local body = Kit.mainPart(prop)
	assert(body, "[Garage] van without parts")
	Kit.mark(body, MetaTags.VanPaint)
	model.PrimaryPart = body
end

local function departureZone(k: Kit.Kit, parent: Instance)
	-- GarageVan: 12 × 8 × 12 behind the van's rear doors.
	local zone = k.zone(parent, "GarageVan", V(-2, 0, -6), V(10, 8, 6), nil, Tags.GarageVan)
	k.anchor(zone, "DrivePoint", CFrame.lookAt(V(-18, 0, 0), V(-19, 0, 0)))
	Kit.attachment(zone, "Beacon", k.at(4, 6, 0))
	-- Orange outline and chevrons pointing at the van.
	local paint = Builder.folder(parent, "VanZonePaint")
	for _, z in { -6, 6 } do
		k.box(paint, "ZoneLine", V(-2, 0, z - 0.25), V(10, 0.05, z + 0.25), S.Orange, Style.decal())
	end
	k.box(paint, "ZoneLine", V(9.5, 0, -6), V(10, 0.05, 6), S.Orange, Style.decal())
	for _, x in { 1.5, 4.5, 7.5 } do
		for _, side in { -1, 1 } do
			k.block(
				paint,
				"Chevron",
				V(0.6, 0.05, 3),
				CFrame.new(x, 0.025, side * 1.1) * CFrame.Angles(0, math.rad(side * 40), 0),
				S.Orange,
				Style.decal()
			)
		end
	end
end

local function jobBoard(k: Kit.Kit, parent: Instance)
	local board = Kit.model(parent, "JobBoard", MetaTags.JobBoard)
	local cork = k.box(board, "Board", V(BACK - 0.4, 3.5, -5), V(BACK, 9.5, 5), S.Cork, {
		material = Enum.Material.WoodPlanks,
	})
	-- Orange frame.
	k.box(board, "BoardFrame", V(BACK - 0.5, 9.5, -5.2), V(BACK, 9.8, 5.2), S.Orange, Style.metal())
	k.box(board, "BoardFrame", V(BACK - 0.5, 3.2, -5.2), V(BACK, 3.5, 5.2), S.Orange, Style.metal())
	k.box(board, "BoardFrame", V(BACK - 0.5, 3.5, -5.2), V(BACK, 9.5, -5), S.Orange, Style.metal())
	k.box(board, "BoardFrame", V(BACK - 0.5, 3.5, 5), V(BACK, 9.5, 5.2), S.Orange, Style.metal())
	-- Pinned job cards: The Golden Wheel, Praline Palace, Tulip Auction and the Hot Job.
	local cards = {
		{ z = -3.2, color = C.Gold },
		{ z = -0.4, color = Color3.fromRGB(110, 66, 40) },
		{ z = 2.4, color = Color3.fromRGB(210, 60, 90) },
	}
	for _, card in cards do
		k.box(
			board,
			"JobCard",
			V(BACK - 0.48, 5.2, card.z - 1.1),
			V(BACK - 0.4, 8.6, card.z + 1.1),
			card.color,
			{
				shadow = false,
			}
		)
	end
	k.box(board, "HotJobCard", V(BACK - 0.48, 4, 3.9), V(BACK - 0.4, 6, 4.8), S.Orange, {
		material = Enum.Material.Neon,
		shadow = false,
	})
	Kit.station(board, cork, k.at(16.5, 13.4, 0))
	-- Light on the board (fixture above the sign, out of the line of sight).
	local fixture = k.block(board, "BoardLamp", V(1.2, 0.5, 1.6), CFrame.new(BACK - 1.6, 13.4, 0), C.Metal, {
		shadow = false,
	})
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 80
	spot.Range = 14
	spot.Brightness = 1.6
	spot.Color = S.Tungsten
	spot.Shadows = false
	spot.Parent = fixture
	k.sign(parent, "JOB BOARD", V(BACK - 0.2, 11.2, 0), V(-1, 0, 0), 9, 1.6, V(13.5, 5, 0))
end

local function spawnPoint(k: Kit.Kit, parent: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GarageSpawn"
	spawn.Size = V(6, 0.4, 6)
	-- Facing +X: players look at the job board, 6 studs ahead (just outside the van zone).
	spawn.CFrame = CFrame.lookAt(k.at(13.5, 0.2, 0), k.at(14.5, 0.2, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Parent = parent
	-- Painted crew circle on the floor.
	k.cylinder(parent, "SpawnMark", 5, 0.05, V(13.5, 0.025, 0), S.Orange, Style.decal())
end

local function clutter(k: Kit.Kit, parent: Instance)
	local f = Builder.folder(parent, "VanBayClutter")
	for _, z in { -8, 8 } do
		k.box(
			f,
			"ToolChest",
			V(16.5, 0, z - 1.5),
			V(18.6, 4, z + 1.5),
			Color3.fromRGB(176, 40, 36),
			Style.metal()
		)
		k.box(f, "ChestTop", V(16.4, 4, z - 1.6), V(18.7, 4.3, z + 1.6), C.Metal, Style.metal())
	end
end

function VanBay.build(k: Kit.Kit, folder: Folder)
	local f = Builder.folder(folder, "VanBay")
	van(k, f)
	departureZone(k, f)
	jobBoard(k, f)
	spawnPoint(k, f)
	clutter(k, f)
	Style.pendant(k, f, V(2, 13.4, 0), Style.CROWN, 30, 1.3, true)
end

return VanBay
