--!nocheck
-- The Garage (beta-spec-maps §4, §10, §12): meta/mechanics/ux tags and attributes, budgets, readable signs and
-- clear walking lanes, built in the mock engine with and without props.
local roblox = require("@lune/roblox")
local Mock = require("./MockRoblox")
local Geometry = require("./Geometry")
local Checks = require("./Checks")

local Vector3 = roblox.Vector3

-- Sizes of the real props (tools/props.json + beta-spec-maps §11 batch 1).
local PROPS = {
	Van = Vector3.new(8.125, 8.381, 13.046),
	Barrel = Vector3.new(2.6, 2.41, 2.12),
	Crate = Vector3.new(4, 3.821, 3.987),
	StreetLamp = Vector3.new(2.289, 13, 2.278),
	Workbench = Vector3.new(6, 4, 3),
	Sofa = Vector3.new(7, 3.5, 3.2),
	CrtTv = Vector3.new(3, 3.6, 2.4),
	StandMirror = Vector3.new(3, 7, 0.6),
	BasketTarget = Vector3.new(3, 5, 3),
	CardboardGuard = Vector3.new(3, 6, 0.4),
	TallCask = Vector3.new(3.6, 6, 3.6),
}

local function build(withProps)
	local world = Mock.world({ props = if withProps then PROPS else nil })
	local MapService = world.require(world.server.Services.MapService)
	local garage = MapService:BuildGarage()
	return world, MapService, garage
end

return function(t)
	for _, withProps in { false, true } do
		local label = if withProps then " (props)" else " (stand-ins)"

		t.test("Garage: part and light budget" .. label, function()
			local _, MapService, garage = build(withProps)
			local budget = MapService.GarageDef.Budget
			local counts = Checks.counts(garage)
			t.ok(counts.parts <= budget.Parts, `parts {counts.parts} > {budget.Parts}`)
			t.ok(counts.lights <= budget.Lights, `lights {counts.lights} > {budget.Lights}`)
			t.ok(counts.shadowed <= budget.Shadowed, `shadowed lights {counts.shadowed} > {budget.Shadowed}`)
			t.ok(counts.parts > 300, "the Garage is actually built")
		end)

		t.test("Garage: meta stations are tagged models with a PrimaryPart and a beacon" .. label, function()
			local world, _, garage = build(withProps)
			local MetaTags = world.require(world.shared.MetaTags)
			for _, tag in { "JobBoard", "GadgetRack", "Workbench", "Mirror", "TrophyWall", "CollectionBook" } do
				local list = Checks.tagged(garage, MetaTags[tag])
				t.eq(#list, 1, tag)
				local model = list[1]
				t.ok(model:IsA("Model"), tag .. " is a Model")
				t.ok(model.PrimaryPart and model.PrimaryPart:IsDescendantOf(model), tag .. " PrimaryPart")
				t.ok(model.PrimaryPart:FindFirstChild("Beacon"), tag .. " Beacon attachment")
				t.eq(
					model.ModelStreamingMode,
					roblox.Enum.ModelStreamingMode.Atomic,
					tag .. " streams as a whole"
				)
			end
			t.ok(#Checks.tagged(garage, MetaTags.VanPaint) >= 1, "VanPaint on the crew van")
		end)

		t.test("Garage: trophy wall has 12 indexed TrophySlots" .. label, function()
			local world, _, garage = build(withProps)
			local MetaTags = world.require(world.shared.MetaTags)
			local wall = Checks.tagged(garage, MetaTags.TrophyWall)[1]
			local seen = {}
			local slots = Checks.tagged(garage, MetaTags.TrophySlot)
			t.eq(#slots, 12)
			for _, slot in slots do
				t.ok(slot:IsDescendantOf(wall), "slot inside the TrophyWall")
				local index = slot:GetAttribute("Index")
				t.ok(
					type(index) == "number" and index >= 1 and index <= 12 and not seen[index],
					"unique Index"
				)
				seen[index] = true
			end
		end)

		t.test("Garage: map tags for mechanics and ux" .. label, function()
			local world, MapService, garage = build(withProps)
			local Tags = world.require(world.shared.Tags)
			-- Departure zone: 12 × 8 × 12 with a DrivePoint.
			local zones = Checks.tagged(garage, Tags.GarageVan)
			t.eq(#zones, 1)
			local zone = zones[1]
			t.near((zone.Size - Vector3.new(12, 8, 12)).Magnitude, 0, 1e-6, "GarageVan size")
			t.eq(zone.CanCollide, false)
			local drive = zone:FindFirstChild("DrivePoint")
			t.ok(drive, "DrivePoint")
			t.near((drive.Position - MapService.GaragePoints.DrivePoint).Magnitude, 0, 1e-6)
			t.near(
				(zone.Position - Vector3.new(0, 4, 0) - MapService.GaragePoints.VanZone).Magnitude,
				0,
				1e-6
			)
			-- TV, trophy board, practice baskets.
			local tvs = Checks.tagged(garage, Tags.GarageTV)
			t.eq(#tvs, 1)
			t.ok(tvs[1].PrimaryPart and tvs[1].PrimaryPart.Name == "Screen", "TV screen is the PrimaryPart")
			local boards = Checks.tagged(garage, Tags.TrophyBoard)
			t.eq(#boards, 1)
			t.ok(
				boards[1]:FindFirstChild("Text") and boards[1].Text:FindFirstChild("Label"),
				"Text.Label for meta"
			)
			local baskets = Checks.tagged(garage, Tags.PracticeTarget)
			t.eq(#baskets, 3)
			local distances = {}
			for _, basket in baskets do
				t.ok(basket.PrimaryPart and basket.PrimaryPart.Name == "Catch", "basket Catch volume")
				distances[basket:GetAttribute("Distance")] = true
			end
			t.ok(distances[6] and distances[8] and distances[10], "baskets at 6, 8 and 10 studs")
			t.eq(#Checks.tagged(garage, "GarageZone"), 1, "GarageZone")
		end)

		t.test("Garage: practice yard loot, bank zone and hide spots" .. label, function()
			local world, _, garage = build(withProps)
			local Tags = world.require(world.shared.Tags)
			local anchors = Checks.tagged(garage, Tags.LootAnchor)
			t.eq(#anchors, 3)
			local classes = {}
			for _, anchor in anchors do
				Checks.anchorContract(t, anchor)
				t.eq(anchor:GetAttribute("Fixed"), true)
				t.eq(anchor:GetAttribute("Session"), "Practice")
				local class = anchor:GetAttribute("AnchorClass")
				classes[class] = (classes[class] or 0) + 1
			end
			t.eq(classes.Medium, 2, "two practice wheels")
			t.eq(classes.Heavy, 1, "one Big Wheel")
			local banks = Checks.tagged(garage, Tags.BankZone)
			t.eq(#banks, 1)
			t.eq(banks[1]:GetAttribute("Session"), "Practice")
			local hides = Checks.tagged(garage, Tags.HideSpot)
			t.eq(#hides, 2)
			for _, spot in hides do
				Checks.hideSpotContract(t, spot)
				t.eq(spot:GetAttribute("HideKind"), "TallCask")
			end
		end)

		t.test("Garage: one SpawnLocation at Points.Spawn, outside the van zone" .. label, function()
			local world, MapService, garage = build(withProps)
			local Tags = world.require(world.shared.Tags)
			local spawns = {}
			for _, d in garage:GetDescendants() do
				if d:IsA("SpawnLocation") then
					table.insert(spawns, d)
				end
			end
			t.eq(#spawns, 1)
			local spawn = spawns[1]
			t.ok(spawn.Enabled and spawn.Neutral, "enabled and neutral")
			local p = MapService.GaragePoints.Spawn
			t.near(spawn.Position.X, p.X, 1e-6)
			t.near(spawn.Position.Z, p.Z, 1e-6)
			t.ok(spawn.CFrame.LookVector:Dot(MapService.GaragePoints.SpawnFacing) > 0.99, "faces SpawnFacing")
			local zone = Checks.tagged(garage, Tags.GarageVan)[1]
			t.ok(not Checks.overlaps(spawn, zone), "spawn pad is outside the GarageVan zone")
			for _, arrival in MapService.GaragePoints.Arrivals do
				t.ok(not Geometry.pointInside(arrival, zone, 0), "arrival outside the van zone")
			end
		end)

		t.test("Garage: signs are readable from their ViewFrom" .. label, function()
			local _, _, garage = build(withProps)
			local texts = Checks.signTexts(garage)
			for _, want in
				{
					"THE GARAGE",
					"JOB BOARD",
					"GEAR",
					"WORKBENCH",
					"LOOKS",
					"CREW WALL",
					"MOST GOUDAS",
					"THROW LINE",
				}
			do
				t.ok(texts[want], "sign " .. want)
			end
			t.ok(texts["PRACTICE\nYARD"], "sign PRACTICE YARD")
			local problems = Checks.signProblems(garage)
			t.eq(#problems, 0, table.concat(problems, "; "))
		end)

		t.test("Garage: walking lanes to every station are clear" .. label, function()
			local world, MapService, garage = build(withProps)
			local o = world.require(world.shared.Config).World.GarageOrigin
			local problems = Checks.lanes(garage, Vector3.new(o.X, o.Y, o.Z), MapService.GarageDef.Lanes)
			t.eq(#problems, 0, table.concat(problems, "; "))
		end)
	end
end
