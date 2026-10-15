--!strict
-- Heist 1: "The Golden Wheel" in Polderdam (gameplan §10.1–10.2). Dit is de definitie die de Registry kent.
-- De onderdelen staan naast dit bestand: Quay (kade, gracht, busje met gadgetrek), Shop (winkel,
-- beveiligingsruimte, binnenkoer) en Warehouse (rijpingshal, kooi, camera's, kantoor).
--
-- Assen (studs, grond = y 0): noord = -X. Gracht x -72..-54, kade x -54..-22, winkel/koer x -22..0, hal x 0..60.

local Atmosphere = require(script.Parent.Parent.Common.Atmosphere)
local Quay = require(script.Quay)
local Shop = require(script.Shop)
local Warehouse = require(script.Warehouse)

-- Volgorde niet wijzigen: de onderdelen delen dezelfde rng, dus een andere volgorde geeft een ander uitzicht.
local function build(level: Folder, rng: Random)
	Quay.build(level, rng)
	Shop.build(level, rng)
	Warehouse.build(level, rng)
end

return {
	Id = "GoldenWheel",
	DisplayName = "The Golden Wheel",
	-- Vaste seed: elke build ziet er hetzelfde uit (gevelkleuren, verlichte ramen).
	Seed = 1854,
	Atmosphere = Atmosphere.BlueNight,
	-- Belangrijke posities die andere services gebruiken.
	Points = {
		Spawn = Vector3.new(-36, 3, -10), -- bij het busje
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
