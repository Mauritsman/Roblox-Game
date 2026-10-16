--!strict
-- Gameplay markers of The Golden Wheel (beta-spec-maps §6, docs/contracts.md §2.5): loot anchors per class, keycard
-- spots, safe loot, secrets, hide spots, hazard anchors, Karel's home and the zone volumes (rings and Boef's yard).
-- Mechanics minimum on map 1: Small 12, Medium 12, Heavy 4, Main 3. Loot counts per round live in the definition.
--
-- Zones: Quay, Shop (Public) · Courtyard, Security, Hall, BackYard, BackAlley, DockApron (Staff) ·
--        Cage, Office, Cellar (Secure).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Common = script.Parent.Parent.Parent.Common
local Anchors = require(Common.Anchors)
local Builder = require(Common.Builder)

local Layout = require(script.Parent.Layout)

local Markers = {}

local F = Layout.CellarFloor
local O = Layout.OfficeFloor

export type LootSpot = { id: string, class: string, pos: Vector3, zone: string, opts: Anchors.LootOpts? }

local function L(id: string, class: string, pos: Vector3, zone: string, opts: Anchors.LootOpts?): LootSpot
	return { id = id, class = class, pos = pos, zone = zone, opts = opts }
end

-- AnchorId, AnchorClass, bottom centre, Zone, options
local LOOT: { LootSpot } = {
	-- Main ×3: the Golden Gouda waits on one of them (every spot has two exits and a ≥ 6-wide rolling path).
	L("G1", "Main", Vector3.new(55, 1.6, 0), "Cage"), -- cage plinth (2 cage doors)
	L("G2", "Main", Vector3.new(6.5, O, 22.5), "Office"), -- office, by the chute (keycard gate / chute)
	L("G3", "Main", Vector3.new(-16, F, -39.5), "Cellar"), -- cellar, in front of the press (ramp / stair)
	-- Heavy ×4 (Big Wheel), in the hall, off the patrol legs.
	L("H1", "Heavy", Vector3.new(25.5, 0.2, -14), "Hall"),
	L("H2", "Heavy", Vector3.new(26, 0.2, 0), "Hall"),
	L("H3", "Heavy", Vector3.new(46, 0.2, 21), "Hall"),
	L("H4", "Heavy", Vector3.new(10, 0.2, -22), "Hall"),
	-- Medium ×13 (Cheese Wheel): rack sections (aisle side), courtyard, yard, alley, cellar, quay.
	L("M1", "Medium", Vector3.new(13, 0.8, -8.25), "Hall"),
	L("M2", "Medium", Vector3.new(13, 0.8, 8.25), "Hall"),
	L("M3", "Medium", Vector3.new(26, 3.5, -8.25), "Hall"),
	L("M4", "Medium", Vector3.new(26, 3.5, 8.25), "Hall"),
	L("M5", "Medium", Vector3.new(38, 0.8, -8.25), "Hall"),
	L("M6", "Medium", Vector3.new(38, 0.8, 8.25), "Hall"),
	L("M7", "Medium", Vector3.new(-10, 0.7, 8), "Courtyard"), -- on the pallet
	L("M8", "Medium", Vector3.new(-17, 0.15, 24), "Courtyard"),
	L("M9", "Medium", Vector3.new(22, 1.4, -36), "BackYard"), -- pushcart
	L("M10", "Medium", Vector3.new(30, 4, 44.5), "BackAlley"), -- crate top
	L("M11", "Medium", Vector3.new(-18, -7, -28), "Cellar"), -- aging rack
	L("M12", "Medium", Vector3.new(-9.5, F, -24), "Cellar"),
	L("M13", "Medium", Vector3.new(-30, 2.4, -12), "Quay", { opener = true }), -- quay handcart
	-- Small ×12 (Cheese Cube / Tip Jar): Public 5, Staff 5, Secure 2.
	L("S1", "Small", Vector3.new(-20.6, 2.2, -33.5), "Shop"), -- window stand
	L("S2", "Small", Vector3.new(-10.5, 3.9, -34), "Shop"), -- counter
	L("S3", "Small", Vector3.new(-9.5, 4.5, -38.7), "Shop"), -- wall shelf
	L("S4", "Small", Vector3.new(-20.6, 2.2, -19.5), "Shop"), -- second window stand
	L("S5", "Small", Vector3.new(-49, 1.9, 33), "Quay", { opener = true }), -- bench by the water
	L("S6", "Small", Vector3.new(-10, 3.2, 2.2), "Security"), -- security desk
	L("S7", "Small", Vector3.new(40, 3, -23.4), "Hall"), -- packing table
	L("S8", "Small", Vector3.new(57, 8.2, -14), "Hall"), -- crate stack top
	L("S9", "Small", Vector3.new(54.5, 3, -19), "Hall"), -- forklift seat
	L("S10", "Small", Vector3.new(-18, 8.15, 36), "Courtyard"), -- crate stack top
	L("S11", "Small", Vector3.new(2.2, 14, 13.7), "Office"), -- filing cabinet
	L("S12", "Small", Vector3.new(-21, -7, -36), "Cellar"), -- aging rack
	-- Cash drawers (Group Drawer): the till and the office desk.
	L("D1", "Small", Vector3.new(-10.5, 5, -29.4), "Shop", { group = "Drawer" }),
	L("D2", "Small", Vector3.new(12, 12, 22.8), "Office", { group = "Drawer" }),
	-- Secrets (Group Secret): Karel's stash under the cellar stair, Boef's treasure beside the kennel.
	L("X1", "Small", Vector3.new(-3.5, F, -36), "Cellar", { group = "Secret" }),
	L("X2", "Small", Vector3.new(-7.6, 0.15, 35.5), "Courtyard", { group = "Secret" }),
	-- Keycard spots (Group Keycard; on 50% of rounds the card hangs on a guard instead).
	L("K1", "Small", Vector3.new(-8, 3.2, 2.2), "Security", { group = "Keycard" }),
	L("K2", "Small", Vector3.new(-11, 3.9, -32), "Shop", { group = "Keycard" }),
	L("K3", "Small", Vector3.new(42, 3, -23.6), "Hall", { group = "Keycard" }),
	L("K4", "Small", Vector3.new(20, 5.6, 45), "BackAlley", { group = "Keycard" }), -- dumpster lid
	L("K5", "Small", Vector3.new(11, 3.2, -37.5), "BackYard", { group = "Keycard" }), -- oil drum
	-- Office safe loot (Group OfficeSafe): appears when the Cheese Grater 3000 finishes.
	L("OS1", "Small", Vector3.new(6, O, 15.6), "Office", { group = "OfficeSafe" }),
	L("OS2", "Small", Vector3.new(6, O, 19), "Office", { group = "OfficeSafe" }),
}
Markers.Loot = LOOT

-- { HideKind, bottom centre, rotY (front = -Z turned) }: 12 spots, one within 15 studs of every loot cluster.
local HIDES: { { any } } = {
	{ "TallCask", Vector3.new(-5.8, 0.15, 7), 180 },
	{ "TallCask", Vector3.new(-9.5, 0.15, 34), 0 },
	{ "TallCask", Vector3.new(39, 0.2, 22.5), 0 },
	{ "TallCask", Vector3.new(48, 0.2, -23), 180 },
	{ "Crate", Vector3.new(55.5, 0.2, 9), 90 },
	{ "Locker", Vector3.new(-2, 0.2, -15.8), 90 },
	{ "Locker", Vector3.new(16.5, O, 13), 90 },
	{ "TallCask", Vector3.new(-20, F, -44), 180 },
	{ "Dumpster", Vector3.new(3.5, 0, -35), -90 },
	{ "Dumpster", Vector3.new(20, 0, 45), 0 },
	{ "TallCask", Vector3.new(14, 0.2, 3), 90 },
	{ "TallCask", Vector3.new(30, 0, -34), 90 },
}

local HAZARDS = {
	Vector3.new(-14, 0.2, -24),
	Vector3.new(-6, 0.2, -20),
	Vector3.new(8, 0.2, 0),
	Vector3.new(26, 0.2, -14),
	Vector3.new(26, 0.2, 14),
	Vector3.new(40, 0.2, 0),
	Vector3.new(-6, 0.2, -8),
	Vector3.new(-10, 0.15, 15),
	Vector3.new(24, 0, -30),
	Vector3.new(-15.5, F, -30),
}

-- Zone volumes: { tag, name, min, max }.
local ZONES: { { any } } = {
	{ Tags.StaffZone, "StaffBackLane", Vector3.new(-21.4, -1, -47), Vector3.new(0, 14, -40.6) },
	{ Tags.StaffZone, "StaffBackYard", Vector3.new(0, -11, -47), Vector3.new(67, 14, -26) },
	{ Tags.StaffZone, "StaffDockApron", Vector3.new(61, -1, -26), Vector3.new(67, 14, 26) },
	{ Tags.StaffZone, "StaffBackAlley", Vector3.new(0, -1, 26), Vector3.new(67, 14, 47) },
	{ Tags.StaffZone, "StaffBinAlley", Vector3.new(-21.4, -1, 40.6), Vector3.new(0, 14, 47) },
	{ Tags.StaffZone, "StaffCourtyard", Vector3.new(-21.4, -1, 4), Vector3.new(0, 14, 40.6) },
	{ Tags.StaffZone, "StaffSecurity", Vector3.new(-21.4, -1, -14), Vector3.new(0, 14, 4) },
	{ Tags.StaffZone, "StaffHall", Vector3.new(0, -1, -25), Vector3.new(60, 21, 25) },
	{ Tags.StaffZone, "StaffCellar", Vector3.new(-22, -11, -46), Vector3.new(0, -0.5, -20) },
	{ Tags.SecureZone, "SecureCage", Vector3.new(50, -1, -6), Vector3.new(58, 10.3, 6) },
	{ Tags.SecureZone, "SecureOffice", Vector3.new(0, 9, 11), Vector3.new(18, 20, 25) },
	{ Tags.SecureZone, "SecureCellar", Vector3.new(-22, -11, -46), Vector3.new(0, -0.5, -20) },
	{ Tags.DogZone, "DogZone", Vector3.new(-21, -1, 5), Vector3.new(-1, 14, 39) },
}

function Markers.build(level: Folder)
	local anchors = Anchors.folder(level)
	for _, spot in LOOT do
		Anchors.loot(anchors, spot.id, spot.class, spot.pos, spot.zone, spot.opts)
	end
	local hides = Builder.folder(level, "HideSpots")
	for _, h in HIDES do
		Anchors.hide(hides, h[1] :: string, h[2] :: Vector3, h[3] :: number)
	end
	for index, pos in HAZARDS do
		Anchors.hazard(anchors, index, pos)
	end
	for _, z in ZONES do
		Anchors.volume(anchors, z[2] :: string, z[1] :: string, z[3] :: Vector3, z[4] :: Vector3)
	end
	Anchors.point(anchors, "KarelHome", Tags.KarelHome, Vector3.new(-18, 0.2, -17), nil, 90)
end

return Markers
