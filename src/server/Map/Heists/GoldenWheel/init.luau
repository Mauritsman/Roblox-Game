--!strict
-- Heist 1: "The Golden Wheel" in Polderdam (gameplan §10.1–10.2; beta retrofit: beta-spec-maps §6).
-- This is the Registry's definition. The parts live next to this file: Quay (canal street, van, neighbours),
-- Shop (shop, security room + cell, courtyard, landmark), Warehouse (hall, cage, office, chute, cameras),
-- Grounds (the ring: lanes, yard, trench, basin + boat, alleys), Cellar (cold cellar) and Markers (anchors,
-- hide spots, zones). Shared coordinates: Layout.
--
-- Axes (studs, ground = y 0): north = -X. Canal x -72..-54, quay x -54..-22, shop/yard x -22..0, hall x 0..60.

local Common = script.Parent.Parent.Common
local Atmosphere = require(Common.Atmosphere)

local Cellar = require(script.Cellar)
local Grounds = require(script.Grounds)
local Layout = require(script.Layout)
local Markers = require(script.Markers)
local Quay = require(script.Quay)
local Shop = require(script.Shop)
local Warehouse = require(script.Warehouse)

-- Do not change the order: the parts share the same rng, so a different order gives a different look.
local function build(level: Folder, rng: Random)
	Quay.build(level, rng)
	Shop.build(level, rng)
	Warehouse.build(level, rng)
	Grounds.build(level)
	Cellar.build(level, rng)
	Markers.build(level)
end

local function wp(x: number, z: number, wait: number?, y: number?)
	return { Pos = Vector3.new(x, y or 0, z), Wait = wait }
end

local function path(points: { { number } }): { Vector3 }
	local out = {}
	for _, p in points do
		table.insert(out, Vector3.new(p[1], 0, p[2]))
	end
	return out
end

local CORNER, END = 1.5, 2.5

return {
	Id = "GoldenWheel",
	DisplayName = "The Golden Wheel",
	-- Fixed seed: every build looks the same (facade colours, lit windows).
	Seed = 1854,
	Atmosphere = Atmosphere.BlueNight,
	Rank = 1,
	Description = "A cosy cheese shop on the canal with a ripening hall full of wheels. "
		.. "The Golden Gouda waits in the cage, the office or the cold cellar.",
	GuardBonus = 0,
	HasDog = true,
	ExtraNpcs = 0,
	-- ±4,000 per round for every crew size (beta-spec §2.1).
	Loot = {
		{ Type = "CheeseCube", Count = 6 },
		{ Type = "TipJar", Count = 2 },
		{ Type = "CashDrawer", Count = 1, Group = "Drawer" },
		{ Type = "CheeseWheel", Count = 8 },
		{ Type = "BigWheel", Count = 2 },
		{ Type = "GoldenGouda", Count = 1 },
		-- One of the two secrets (proposed: a 150–500 "stash" loot type; CashDrawer stands in until mechanics adds it).
		{ Type = "CashDrawer", Count = 1, Group = "Secret" },
	},
	Stars = { 500, 1500, 2500 },
	Bounds = { Min = Vector3.new(-80, -14, -135), Max = Vector3.new(70, 12, 135) },
	LoudEscape = "Stay",
	Objectives = {
		{ Id = "Office", Type = "Keycard", Required = true, Group = "Keycard" },
		{
			Id = "OfficeSafe",
			Type = "Safe",
			Required = false,
			Group = "OfficeSafe",
			Loot = { { Type = "CashDrawer", Count = 2 } },
		},
	},
	-- Important positions used by other services.
	Points = {
		Spawn = Layout.Spawn, -- by the van
		-- Prototype fallback until GuardService reads GuardRoutes.
		GuardStart = Vector3.new(6, 3, -17),
		GuardRoute = path({ { 6, -17 }, { 47, -17 }, { 47, 16 }, { 6, 16 } }),
		-- ≥ 6 routes, 2 variants each, straight legs, ≤ 25 s per loop at patrol speed 6 (incl. waits).
		-- Lowest Priority first: solo = the two hall guards, four players = + Shop and Courtyard.
		GuardRoutes = {
			{
				Id = "HallWest",
				Priority = 1,
				Variants = {
					{ wp(6, -17, CORNER), wp(19.5, -17, CORNER), wp(19.5, 16, CORNER), wp(6, 16, CORNER) },
					{ wp(4, -2, CORNER), wp(19.5, -2, CORNER), wp(19.5, -17, CORNER), wp(4, -17, CORNER) },
				},
			},
			{
				Id = "HallEast",
				Priority = 1,
				Variants = {
					{ wp(32, -18, CORNER), wp(47, -18, CORNER), wp(47, 16, CORNER), wp(32, 16, CORNER) },
					{ wp(32, -4, CORNER), wp(47, -4, CORNER), wp(47, 16, CORNER), wp(32, 16, CORNER) },
				},
			},
			{
				Id = "Shop",
				Priority = 2,
				Variants = {
					{ wp(-4, -20, END), wp(-14, -20, END) },
					{ wp(-4, -23.5, END), wp(-14, -23.5, END) },
				},
			},
			{
				Id = "Courtyard",
				Priority = 2,
				Variants = {
					{ wp(-4, 16, CORNER), wp(-17, 11, CORNER), wp(-17, 19, CORNER), wp(-4, 19, CORNER) },
					{ wp(-4, 17, END), wp(-14, 27, END) },
				},
			},
			{
				Id = "BackAlley",
				Priority = 3,
				Variants = {
					{ wp(6, 30, END), wp(58, 30, END) },
					{ wp(6, 40, END), wp(58, 40, END) },
				},
			},
			{
				Id = "DockApron",
				Priority = 3,
				Variants = {
					{ wp(64, -44, END), wp(64, 8, END) },
					{ wp(64, -8, END), wp(64, 36, END) },
				},
			},
			{
				Id = "BackYard",
				Priority = 3,
				Variants = {
					{ wp(8, -29, END), wp(58, -29, END) },
					{ wp(32, -44, END), wp(58, -44, END) },
				},
			},
		},
		KarelRoute = path({
			{ -3, -20 },
			{ 6, -20 },
			{ 6, 0 },
			{ -4, -2 },
			{ 6, 0 },
			{ 6, 17 },
			{ -6, 17 },
			{ 6, 17 },
			{ 6, 16 },
			{ 32, 16 },
			{ 32, -19 },
			{ 6, -19 },
			{ 6, -20 },
			{ -3, -20 },
		}),
		DogRoute = path({ { -5, 12 }, { -19, 14 }, { -10, 26 }, { -8, 31 } }),
		Rides = { CheeseChute = Layout.ChutePath },
	},
	Build = build,
}
