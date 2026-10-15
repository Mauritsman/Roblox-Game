--!strict
-- Heist 1: "The Golden Wheel" in Polderdam (gameplan §10.1–10.2). This is the Registry's definition.
-- The parts live next to this file: Quay (quay, canal, van with gadget rack), Shop (shop, security room,
-- courtyard) and Warehouse (ripening hall, cage, cameras, office).
--
-- Axes (studs, ground = y 0): north = -X. Canal x -72..-54, quay x -54..-22, shop/yard x -22..0,
-- hall x 0..60.

local Atmosphere = require(script.Parent.Parent.Common.Atmosphere)
local Quay = require(script.Quay)
local Shop = require(script.Shop)
local Warehouse = require(script.Warehouse)

-- Do not change the order: the parts share the same rng, so a different order gives a different look.
local function build(level: Folder, rng: Random)
	Quay.build(level, rng)
	Shop.build(level, rng)
	Warehouse.build(level, rng)
end

return {
	Id = "GoldenWheel",
	DisplayName = "The Golden Wheel",
	-- Fixed seed: every build looks the same (facade colours, lit windows).
	Seed = 1854,
	Atmosphere = Atmosphere.BlueNight,
	-- Important positions used by other services.
	Points = {
		Spawn = Vector3.new(-36, 3, -10), -- by the van
		GuardStart = Vector3.new(8, 3, -18),
		GuardRoute = {
			Vector3.new(8, 0, -18),
			Vector3.new(48, 0, -18),
			Vector3.new(48, 0, 18),
			Vector3.new(8, 0, 18),
		},
	},
	Build = build,
}
