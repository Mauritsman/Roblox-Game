--!strict
-- List of all heists (maps). MapService builds one of them; without a choice, the DefaultHeist.
-- Adding a new heist: see README.md in this folder.

local Atmosphere = require(script.Parent.Common.Atmosphere)

-- One guard waypoint (beta-spec §9.7): position at floor height (y 0, upper floors y 9; a leg that changes floor
-- uses pathfinding), optional wait in seconds (RoundPlan adds ±1 s).
export type Waypoint = {
	Pos: Vector3,
	Wait: number?,
}

-- A patrol route: lowest Priority is used first; each variant is a loop of straight legs.
export type GuardRouteDef = {
	Id: string,
	Priority: number,
	Variants: { { Waypoint } },
}

export type Points = {
	Spawn: Vector3, -- where players appear (by the van)
	GuardStart: Vector3, -- fallback until the heist has GuardRoutes (prototype GuardService)
	GuardRoute: { Vector3 }, -- fallback patrol points at y = 0, in order (then back to the first)
	GuardRoutes: { GuardRouteDef }?, -- ≥ 6 routes, 2 variants each
	KarelRoute: { Vector3 }?,
	DogRoute: { Vector3 }?, -- map 1 (Boef)
	Rides: { [string]: { Vector3 } }?, -- path per Ride folder's RideId (server-moved seats)
}

-- Loot per round: Count items of Type (a key of Config.Loot.Types); Group = only anchors with that Group.
export type LootEntry = {
	Type: string,
	Count: number,
	Group: string?,
}

-- Objective (beta-spec §7.3): Type "Keycard" | "Safe". Group = anchor Group (keycard spots, safe loot).
export type ObjectiveDef = {
	Id: string,
	Type: string,
	Required: boolean,
	BonusPct: number?, -- optional objectives (default Config.Objectives.BonusPct)
	Group: string?,
	Loot: { LootEntry }?, -- what spawns in a safe when the device finishes
}

export type Heist = {
	Id: string, -- same as the key below and the folder name in Heists/
	DisplayName: string, -- name shown to players (English)
	Seed: number, -- fixed seed for Build's rng
	Atmosphere: Atmosphere.Settings,
	Points: Points,
	Build: (level: Folder, rng: Random) -> (),

	-- Beta fields (beta-spec §9.7); all optional so a heist can be retrofitted step by step.
	Rank: number?, -- display only; unlock rules live in meta's Config.Progression.HeistUnlock
	Description: string?,
	GuardBonus: number?, -- added to Config.Guard.CountByCrew (maps 2–3: 1)
	HasDog: boolean?,
	ExtraNpcs: number?, -- e.g. the Robo-Mop; counts toward Config.Npc.Cap
	Loot: { LootEntry }?,
	Stars: { number }?, -- van loot (base value) for 1★, 2★, 3★ (3★ also needs the main loot)
	RoundSeconds: number?, -- default Config.Round.RoundSeconds
	Bounds: { Min: Vector3, Max: Vector3 }?, -- Terrain region cleared when the heist is replaced
	LoudEscape: string?, -- "Stay" (van stays) | "LockdownExit" (maps 2–3: exit attributes QuietOnly/LockdownOnly)
	Objectives: { ObjectiveDef }?,
}

local Heists = script.Parent.Heists

local heists: { [string]: Heist } = {
	GoldenWheel = require(Heists.GoldenWheel) :: Heist,
}

local Registry = {}

Registry.Heists = heists
Registry.DefaultHeist = "GoldenWheel"

-- Returns the definition of a heist, or nil if that id does not exist.
function Registry.get(id: string): Heist?
	return heists[id]
end

return Registry
