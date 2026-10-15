--!strict
-- De kade en de gracht van Polderdam (§10.1): grond, water, kaaimuren, grachtenpanden aan de overkant,
-- buurhuizen aan onze kant, lantaarns, paaltjes, fietsen, het busje met de gadgetrek en de spawn.
--
-- Assen: noord = -X (richting gracht). Gracht x -72..-54, kade x -54..-22, gevels van onze rij op x -22.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Builder = require(script.Parent.Builder)
local CanalHouse = require(script.Parent.CanalHouse)

local C = Builder.Colors

local Quay = {}

Quay.GadgetColors = {
	Drone = Color3.fromRGB(70, 160, 255),
	Noisemaker = Color3.fromRGB(255, 210, 60),
	EMP = Color3.fromRGB(80, 220, 255),
	BubbleBlaster = Color3.fromRGB(255, 140, 220),
	Crowbar = Color3.fromRGB(255, 90, 80),
}

local function lamp(parent: Instance, ground: Vector3, name: string)
	-- Grachtlantaarn: AI-prop als die er is, anders paal + lantaarn uit blokken.
	local post = Builder.prop(parent, "StreetLamp", ground, 0, {
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
	-- De lichtbron zelf is een apart "Lamp"-onderdeel: dat kan een EMP uitzetten.
	-- Bij de AI-lantaarn zit het glas op 9,1–10,2 studs hoog; een neon cilinder schijnt door de ruitjes.
	local isMesh = post ~= nil and post.Name == "StreetLamp"
	local bulb = if isMesh
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
	Builder.pointLight(bulb, 26, 1.4, C.LampWarm, true)
	bulb:SetAttribute(Tags.Disabled, false)
	CollectionService:AddTag(bulb, Tags.Lamp)
	CollectionService:AddTag(bulb, Tags.Electronic)
end

local function gadgetRack(parent: Instance)
	-- De gadgetrek achter het busje: per gadget een kist met een oplichtende plaat erbovenop.
	for index, gadgetName in Config.GadgetOrder do
		local z = -16 + (index - 1) * 8
		local color = Quay.GadgetColors[gadgetName] or Color3.new(1, 1, 1)
		local crate = Builder.prop(parent, "Crate", Vector3.new(-30, 0, z), (index - 1) * 6, {
			scale = 0.7,
			fallback = function(p, g)
				return Builder.block(
					p,
					"GearCrate",
					Vector3.new(3, 2.4, 3),
					CFrame.new(g + Vector3.new(0, 1.2, 0)),
					C.Wood,
					{
						material = Enum.Material.WoodPlanks,
					}
				)
			end,
		})
		local top = Builder.topOf(crate) or 2.4
		local pedestal = Builder.block(
			parent,
			"Pedestal_" .. gadgetName,
			Vector3.new(2.4, 0.3, 2.4),
			CFrame.new(-30, top + 0.15, z),
			color,
			{
				material = Enum.Material.Neon,
			}
		)
		pedestal:SetAttribute("Gadget", gadgetName)
		CollectionService:AddTag(pedestal, Tags.GadgetPedestal)
		Builder.label(pedestal, (Config.Gadgets[gadgetName].Label or gadgetName):upper(), color, 2.6)
		Builder.pointLight(pedestal, 8, 0.8, color)
	end
end

local function bridge(parent: Instance, z: number)
	-- Een Amsterdamse grachtbrug: dek, twee bogen en lage leuningen. Sluit de gracht visueel af.
	local deckY = 0.6
	Builder.box(
		parent,
		"BridgeDeck",
		Vector3.new(-74, deckY - 1.2, z - 5),
		Vector3.new(-52, deckY, z + 5),
		C.Stone,
		{
			material = Enum.Material.Cobblestone,
			variant = "CC_Cobble",
		}
	)
	for _, side in { -1, 1 } do
		Builder.box(
			parent,
			"BridgeRail",
			Vector3.new(-74, deckY, z + side * 5 - 0.5),
			Vector3.new(-52, deckY + 2.4, z + side * 5 + 0.5),
			C.BrickDark,
			{
				material = Enum.Material.Brick,
				variant = "CC_Brick",
			}
		)
		Builder.box(
			parent,
			"BridgeRailCap",
			Vector3.new(-74, deckY + 2.4, z + side * 5 - 0.7),
			Vector3.new(-52, deckY + 2.8, z + side * 5 + 0.7),
			C.Stone,
			{
				material = Enum.Material.Granite,
			}
		)
	end
	-- Boog onder het dek (blokken die naar het midden toe dunner worden).
	for i = 0, 8 do
		local x = -72 + i * 2
		local depth = 1.2 + math.abs(i - 4) * 0.9
		Builder.box(
			parent,
			"BridgeArch",
			Vector3.new(x, deckY - 1.2 - depth, z - 5),
			Vector3.new(x + 2, deckY - 1.2, z + 5),
			C.BrickDark,
			{
				material = Enum.Material.Brick,
				variant = "CC_Brick",
			}
		)
	end
	-- Lantaarn in het midden van de brug, met fietsen ertegen.
	lamp(parent, Vector3.new(-63, deckY, z + 4.2), `BridgeLamp{z}`)
	Builder.prop(parent, "Bicycle", Vector3.new(-60, deckY, z + 3.6), 90, { collide = false })
end

function Quay.build(level: Folder, rng: Random)
	local quay = Builder.folder(level, "Quay")
	local terrain = workspace.Terrain

	-- Grond: west-oever en ons land, met de gracht ertussen.
	Builder.box(quay, "GroundWest", Vector3.new(-160, -8, -130), Vector3.new(-72, 0, 130), C.Cobble, {
		material = Enum.Material.Cobblestone,
		variant = "CC_Cobble",
	})
	-- Kade in drie stroken: kasseien aan het water, klinkerweg, en een verhoogde stoep langs de gevels.
	Builder.box(quay, "GroundQuayEdge", Vector3.new(-54, -8, -130), Vector3.new(-46, 0, 130), C.Cobble, {
		material = Enum.Material.Cobblestone,
		variant = "CC_Cobble",
	})
	Builder.box(
		quay,
		"GroundRoad",
		Vector3.new(-46, -8, -130),
		Vector3.new(-22, 0, 130),
		Color3.fromRGB(84, 70, 66),
		{
			material = Enum.Material.Brick,
		}
	)
	Builder.box(
		quay,
		"Sidewalk",
		Vector3.new(-27.7, 0, -130),
		Vector3.new(-22, Builder.SIDEWALK, 130),
		Color3.fromRGB(128, 126, 122),
		{
			material = Enum.Material.Slate,
		}
	)
	Builder.box(
		quay,
		"Curb",
		Vector3.new(-28.3, 0, -130),
		Vector3.new(-27.7, Builder.SIDEWALK + 0.1, 130),
		C.Stone,
		{
			material = Enum.Material.Granite,
		}
	)
	Builder.box(quay, "EdgeCurb", Vector3.new(-46.3, 0, -130), Vector3.new(-45.7, 0.12, 130), C.StoneDark, {
		material = Enum.Material.Granite,
	})
	Builder.box(quay, "GroundEast", Vector3.new(-22, -8, -130), Vector3.new(160, 0, 130), C.StoneDark, {
		material = Enum.Material.Pavement,
	})
	Builder.box(
		quay,
		"CanalBed",
		Vector3.new(-72, -12, -130),
		Vector3.new(-54, -8, 130),
		Color3.fromRGB(40, 46, 44),
		{
			material = Enum.Material.Mud,
		}
	)
	-- Kaaimuren in baksteen met een granieten rand.
	for _, x in { -54, -72 } do
		local inward = if x == -54 then 0.3 else -0.3
		Builder.box(
			quay,
			"QuayWall",
			Vector3.new(x - inward, -8, -130),
			Vector3.new(x + inward, 0, 130),
			C.BrickDark,
			{
				material = Enum.Material.Brick,
				variant = "CC_Brick",
			}
		)
		Builder.box(
			quay,
			"QuayEdge",
			Vector3.new(x - 0.9, 0, -130),
			Vector3.new(x + 0.9, 0.35, 130),
			C.Stone,
			{
				material = Enum.Material.Granite,
			}
		)
	end
	-- Water (Terrain): leegmaken en vullen.
	terrain:FillBlock(CFrame.new(-63, -3, 0), Vector3.new(18, 12, 260), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(-63, -5.5, 0), Vector3.new(18, 5, 260), Enum.Material.Water)
	terrain.WaterColor = Color3.fromRGB(28, 54, 62)
	terrain.WaterReflectance = 0.55
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6

	-- Grachtenpanden aan de overkant (achtergrond) en aan onze kant buiten het perceel.
	CanalHouse.row(
		quay,
		Vector3.new(-75, 0, -126),
		Vector3.new(-75, 0, 126),
		Vector3.new(1, 0, 0),
		rng,
		{ depth = 18 }
	)
	CanalHouse.row(
		quay,
		Vector3.new(-22, 0, -126),
		Vector3.new(-22, 0, -40.6),
		Vector3.new(-1, 0, 0),
		rng,
		{ depth = 40 }
	)
	CanalHouse.row(
		quay,
		Vector3.new(-22, 0, 40.6),
		Vector3.new(-22, 0, 126),
		Vector3.new(-1, 0, 0),
		rng,
		{ depth = 40 }
	)
	-- Huizen aan het eind van de straat en bruggen over de gracht: zo eindigt de wereld niet in het niets.
	for _, z in { -127, 127 } do
		local facing = Vector3.new(0, 0, -math.sign(z))
		CanalHouse.row(quay, Vector3.new(-54, 0, z), Vector3.new(-22, 0, z), facing, rng, { depth = 14 })
		CanalHouse.row(quay, Vector3.new(-160, 0, z), Vector3.new(-75, 0, z), facing, rng, { depth = 14 })
		bridge(quay, z - math.sign(z) * 16)
		Builder.box(
			quay,
			"CanalEnd",
			Vector3.new(-72, -12, z),
			Vector3.new(-54, 0, z + math.sign(z) * 3),
			C.BrickDark,
			{
				material = Enum.Material.Brick,
				variant = "CC_Brick",
			}
		)
	end
	-- Buurpakhuis achter onze hal, zodat de horizon dicht is.
	Builder.box(quay, "NeighbourWarehouse", Vector3.new(62, 0, -60), Vector3.new(110, 22, 60), C.BrickDark, {
		material = Enum.Material.Brick,
		variant = "CC_Brick",
	})
	Builder.box(quay, "NeighbourBlockN", Vector3.new(0, 0, 41), Vector3.new(62, 18, 126), C.BrickRed, {
		material = Enum.Material.Brick,
		variant = "CC_Brick",
	})
	Builder.box(quay, "NeighbourBlockS", Vector3.new(0, 0, -126), Vector3.new(62, 18, -41), C.BrickRed, {
		material = Enum.Material.Brick,
		variant = "CC_Brick",
	})

	-- Lantaarns langs de gracht en paaltjes (Amsterdammertjes).
	local lampIndex = 0
	for z = -108, 108, 24 do
		lampIndex += 1
		lamp(quay, Vector3.new(-51.5, 0, z), `StreetBulb{lampIndex}`)
	end
	for z = -114, 114, 6 do
		if math.abs(z % 24 - 12) > 2 then
			Builder.cylinder(
				quay,
				"Bollard",
				0.6,
				2.4,
				Vector3.new(-52.5, 1.2, z),
				Color3.fromRGB(110, 30, 30),
				{
					material = Enum.Material.Metal,
				}
			)
		end
	end

	-- Iepen langs de gracht (niet bij het busje), en sloepjes aangemeerd in het water.
	for z = -96, 96, 24 do
		if z < -6 or z > 14 then
			Builder.tree(quay, Vector3.new(-48.6, 0, z), rng)
		end
	end
	Builder.boat(quay, Vector3.new(-57.4, -2.6, -70), Color3.fromRGB(40, 90, 70))
	Builder.boat(quay, Vector3.new(-57.4, -2.6, -28), Color3.fromRGB(220, 220, 210))
	Builder.boat(quay, Vector3.new(-68.6, -2.6, -4), Color3.fromRGB(40, 60, 110))
	Builder.boat(quay, Vector3.new(-68.6, -2.6, 78), Color3.fromRGB(150, 50, 40))

	-- Fietsen tegen de gevel naast de winkel, een bankje aan het water en bloembakken.
	for i = 0, 3 do
		Builder.prop(quay, "Bicycle", Vector3.new(-25.2, Builder.SIDEWALK, -52 + i * 3.4), 90 + (i % 2) * 6, {
			fallback = function(p, g)
				return Builder.block(
					p,
					"BikeStub",
					Vector3.new(5, 3, 0.4),
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

	-- Woonboot in de gracht (decor).
	Builder.box(
		quay,
		"HouseboatHull",
		Vector3.new(-68, -3.6, 30),
		Vector3.new(-58, -1.2, 56),
		Color3.fromRGB(36, 52, 70),
		{
			material = Enum.Material.Wood,
		}
	)
	Builder.box(
		quay,
		"HouseboatCabin",
		Vector3.new(-67, -1.2, 34),
		Vector3.new(-59, 3.6, 52),
		Color3.fromRGB(120, 160, 140),
		{
			material = Enum.Material.WoodPlanks,
		}
	)
	for i = 0, 2 do
		Builder.window(
			quay,
			CFrame.lookAt(Vector3.new(-58.9, 1.4, 38 + i * 5), Vector3.new(-50, 1.4, 38 + i * 5)),
			2.4,
			2,
			i ~= 1
		)
	end
	Builder.box(
		quay,
		"HouseboatRoof",
		Vector3.new(-67.5, 3.6, 33.5),
		Vector3.new(-58.5, 4.2, 52.5),
		C.StoneDark
	)

	-- Het busje van de crew en de gadgetrek.
	Builder.prop(quay, "Van", Vector3.new(-40, 0, 4), 0, {
		fallback = function(p, g)
			local van = Builder.block(
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
				{
					material = Enum.Material.Glass,
				}
			)
			return van
		end,
	})
	local vanLabelAnchor =
		Builder.block(quay, "VanLabel", Vector3.new(1, 1, 1), CFrame.new(-40, 8.5, 4), C.CrewOrange, {
			transparency = 1,
			collide = false,
			query = false,
		})
	Builder.label(vanLabelAnchor, "THE VAN", Color3.new(1, 1, 1), 0, 80)
	gadgetRack(quay)

	-- Spawn naast het busje.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CrewSpawn"
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = CFrame.new(-36, 0.2, -10)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = quay

	-- Onzichtbare grenzen: niet in de gracht, niet de straat uit.
	Builder.box(quay, "BarrierCanal", Vector3.new(-55.5, 0, -130), Vector3.new(-54.5, 14, 130), C.Stone, {
		transparency = 1,
		query = false,
	})
	Builder.box(quay, "BarrierSouth", Vector3.new(-54, 0, -116), Vector3.new(-22, 14, -115), C.Stone, {
		transparency = 1,
		query = false,
	})
	Builder.box(quay, "BarrierNorth", Vector3.new(-54, 0, 115), Vector3.new(-22, 14, 116), C.Stone, {
		transparency = 1,
		query = false,
	})
	-- Wegafzetting als zichtbare reden waarom de straat ophoudt.
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
