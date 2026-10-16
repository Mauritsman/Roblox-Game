--!strict
-- Gadget loadouts and per-player stats (beta-spec §5, §7.4). LoadoutService feeds it meta's loadout
-- (ShopService:GetLoadout → {"Crowbar", a, b}) and the Config tables; Lib/PlayerStats feeds it the perks.
--   Loadout.picks(raw, pickable, slots, fallback)   → the valid picks (never the Crowbar, no duplicates, ≤ slots)
--   Loadout.charges(picks, gadgetsConfig, bonus)    → {[gadget] = charges} (Perks.charges does the perk maths)
--   Loadout.panic(charges, picks, extra)            → charges after the Panic Pack (+extra per pick)
--   Loadout.list(picks, always)                     → the `Gadgets` attribute ("a,b,Crowbar")
--   Loadout.stats(defaults, tier, perks, effects, applyPerks) → stats: defaults, then the tier, then perks
--   Loadout.label(name, gadgetsConfig)              → the one player-facing name (B-004: "BUBBLE BLASTER")

local Perks = if script then require(script.Parent.Perks) else require("./Perks")

local Loadout = {}

-- Logic/Perks Stats and Effect (typed loosely here: the conditional require hides Perks' exported types).
type Stats = { [string]: any }
type Effect = { Stat: string, Set: number?, Add: number?, Mul: number? }

-- The player's valid picks in their order. `raw` may contain the Crowbar, unknown names, duplicates or junk;
-- missing picks are filled from `fallback` (meta's default loadout) so everyone always has `slots` gadgets.
function Loadout.picks(raw: any, pickable: { string }, slots: number, fallback: { string }?): { string }
	local allowed: { [string]: boolean } = {}
	for _, name in pickable do
		allowed[name] = true
	end
	local result: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(name: any)
		if #result < slots and type(name) == "string" and allowed[name] and not seen[name] then
			seen[name] = true
			table.insert(result, name)
		end
	end
	if type(raw) == "table" then
		for _, name in raw do
			add(name)
		end
	end
	if fallback then
		for _, name in fallback do
			add(name)
		end
	end
	return result
end

-- Charges per pick from Config.Gadgets[name].Charges, plus FirstGadgetBonus on the first pick (Spare Batteries).
function Loadout.charges(picks: { string }, gadgets: { [string]: any }, stats: Stats): { [string]: number }
	local base: { [string]: number } = {}
	for _, name in picks do
		local def = gadgets[name]
		base[name] = if type(def) == "table" and type(def.Charges) == "number" then def.Charges else 0
	end
	return Perks.charges(picks, base, stats :: any, 0)
end

-- The Panic Pack (+extra on every pick). Returns a new table; `charges` is not changed.
function Loadout.panic(charges: { [string]: number }, picks: { string }, extra: number): { [string]: number }
	local result = table.clone(charges)
	for _, name in picks do
		result[name] = (result[name] or 0) + extra
	end
	return result
end

-- The `Gadgets` attribute: picks first (slots 1 and 2), the always-carried tool last.
function Loadout.list(picks: { string }, always: string?): string
	local names = table.clone(picks)
	if always then
		table.insert(names, always)
	end
	return table.concat(names, ",")
end

export type TierRow = { SelfEscapes: number }

-- Per-player stats: the Config defaults, then the difficulty tier (self-escapes), then the equipped perks.
-- `tier` = nil for the mini-job (no tier) or when difficulty is off; `applyPerks` = Config.Features.Perks.
function Loadout.stats(
	defaults: Stats,
	tier: TierRow?,
	perks: { [any]: any }?,
	effects: { [string]: { Effect } },
	applyPerks: boolean
): Stats
	local stats = table.clone(defaults)
	if tier then
		stats.SelfEscapes = tier.SelfEscapes
	end
	if applyPerks then
		local applied = Perks.apply(stats :: any, perks, effects)
		return applied :: any
	end
	return stats
end

local LABELS: { [string]: string } = {
	BubbleBlaster = "BUBBLE BLASTER",
}

-- Upper-case display name: Config.Gadgets[name].Label when set, else the id split into words.
function Loadout.label(name: string, gadgets: { [string]: any }?): string
	local def = gadgets and gadgets[name]
	if type(def) == "table" and type(def.Label) == "string" and def.Label ~= "" then
		return string.upper(def.Label)
	end
	if LABELS[name] then
		return LABELS[name]
	end
	local words = string.gsub(name, "(%l)(%u)", "%1 %2")
	return string.upper(words)
end

return Loadout
