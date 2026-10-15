--!strict
-- List of all heists (maps). MapService builds one of them; without a choice, the DefaultHeist.
-- Adding a new heist: see README.md in this folder.

local Atmosphere = require(script.Parent.Common.Atmosphere)

export type Points = {
	Spawn: Vector3, -- where players appear and return to after being "caught" (by the van)
	GuardStart: Vector3, -- where the guard appears
	GuardRoute: { Vector3 }, -- patrol points at y = 0, in order (then back to the first)
}

export type Heist = {
	Id: string, -- same as the key below and the folder name in Heists/
	DisplayName: string, -- name shown to players (English)
	Seed: number, -- fixed seed for Build's rng
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

-- Returns the definition of a heist, or nil if that id does not exist.
function Registry.get(id: string): Heist?
	return heists[id]
end

return Registry
