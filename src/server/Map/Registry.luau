--!strict
-- Lijst van alle heists (maps). MapService bouwt er één van; zonder keuze de DefaultHeist.
-- Een nieuwe heist toevoegen: zie README.md in deze map.

local Atmosphere = require(script.Parent.Common.Atmosphere)

export type Points = {
	Spawn: Vector3, -- waar spelers verschijnen en na "gepakt" terugkomen (bij het busje)
	GuardStart: Vector3, -- waar de bewaker verschijnt
	GuardRoute: { Vector3 }, -- patrouillepunten op y = 0, in volgorde (daarna terug naar het eerste)
}

export type Heist = {
	Id: string, -- zelfde als de sleutel hieronder en de mapnaam in Heists/
	DisplayName: string, -- naam voor spelers (Engels)
	Seed: number, -- vaste seed voor de rng van Build
	Atmosphere: Atmosphere.Settings,
	Points: Points,
	Build: (level: Folder, rng: Random) -> (),
}

local Heists = script.Parent.Heists

local heists: { [string]: Heist } = {
	GoldenWheel = require(Heists.GoldenWheel),
}

local Registry = {}

Registry.Heists = heists
Registry.DefaultHeist = "GoldenWheel"

-- Geeft de definitie van een heist, of nil als die id niet bestaat.
function Registry.get(id: string): Heist?
	return heists[id]
end

return Registry
