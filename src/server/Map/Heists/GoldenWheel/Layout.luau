--!strict
-- Shared coordinates of The Golden Wheel (beta-spec-maps §6), used by the definition (init) and the builders.
-- Axes: north = -X. Canal x -72..-54, quay x -54..-22, shop A x -22..0 z -40..-14, security room B z -14..4,
-- courtyard C z 4..40.6, hall D x 0..60 |z| ≤ 25, office E (mezzanine y 9.2) x 0..18 z 11..25.
-- The ring: Back Lane x -22..0 z -47..-40.6 · Back Yard x 0..67 z -47..-26 · Dock Apron x 61..67 · Back Alley
-- x 0..67 z 26..47 · Bin Alley x -22..0 z 40.6..47 · Loading Basin x 0..67 z -59..-47.
-- Cold cellar x -22..0 z -46..-20 (floor y -9.8); its ramp trench x 0..28 z -46..-40.

local Layout = {}

Layout.Spawn = Vector3.new(-38, 3, 20) -- beside the van, outside its bank zone
Layout.VanGround = Vector3.new(-40, 0, 4) -- van prop, nose to -Z, rear doors at +Z

-- Cheese Chute: office (west wall opening x -1..0, z 21..24) → courtyard. Car floor positions.
Layout.ChutePath = {
	Vector3.new(1.8, 9.2, 22.5), -- boarding station in the office
	Vector3.new(-1.5, 9.2, 22.5), -- through the wall
	Vector3.new(-3, 5.6, 25),
	Vector3.new(-4.5, 1.6, 27.6),
	Vector3.new(-5.5, 0.2, 29.5), -- spat out on the cobbles
}

Layout.CellarFloor = -9.8
Layout.OfficeFloor = 9.2

return Layout
