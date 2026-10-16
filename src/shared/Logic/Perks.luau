--!strict
-- Per-player numbers after perks (beta-spec §7.4, advisor's 3×3 tree). Mechanics reads them once at Briefing:
--   ProgressionService:GetPerks(player) → Perks.apply(Perks.defaultsFrom(Config), perks, Config.Perks)
-- and serves them through LoadoutService:StatsOf(player). Every per-player number in mechanics code comes from
-- these stats, never straight from Config. Meta owns the tree layout, costs, unlocking and the max of 3 equipped
-- (Config.PerkTree, Logic/PerkTree); this module only applies effects. Unknown perk ids are ignored.

local Perks = {}

export type Stats = {
	-- movement (Logic/Movement)
	Walk: number,
	Crouch: number,
	Medium: number,
	HeavySolo: number,
	HeavyRoll: number,
	TwoCarry: number,
	Jump: number,
	MediumJump: number,
	HeavyJump: number,
	-- loot and carrying
	PocketSlots: number,
	ThrowRange: number,
	-- hiding
	WarnAt: number,
	SneezeAt: number,
	-- capture
	RescueHold: number,
	SelfEscapeAfter: number,
	SelfEscapes: number,
	-- gadgets
	CrackRadius: number,
	FirstGadgetBonus: number, -- extra charges on the first picked gadget
}

export type Effect = {
	Stat: string,
	Set: number?,
	Add: number?,
	Mul: number?,
}

-- Stats with no perks, from the Config table.
function Perks.defaultsFrom(config: any): Stats
	local m = config.Movement
	return {
		Walk = m.Walk,
		Crouch = m.Crouch,
		Medium = m.Medium,
		HeavySolo = m.HeavySolo,
		HeavyRoll = m.HeavyRoll,
		TwoCarry = m.TwoCarry,
		Jump = m.Jump,
		MediumJump = m.MediumJump,
		HeavyJump = m.HeavyJump,
		PocketSlots = config.Loot.PocketSlots,
		ThrowRange = config.Carry.ThrowRange,
		WarnAt = config.Hiding.WarnAt,
		SneezeAt = config.Hiding.SneezeAt,
		RescueHold = config.Capture.RescueHold,
		SelfEscapeAfter = config.Capture.SelfEscapeAfter,
		SelfEscapes = config.Capture.SelfEscapes,
		CrackRadius = config.Gadgets.Crowbar.CrackRadius,
		FirstGadgetBonus = 0,
	}
end

-- The equipped perk ids, sorted. Accepts a list {"SoftShoes", …} or a map {[perkId] = 1 | true}.
function Perks.ids(perks: { [any]: any }?): { string }
	local ids = {}
	local seen = {}
	if perks then
		for key, value in perks do
			local id: any = nil
			if type(key) == "number" and type(value) == "string" then
				id = value
			elseif type(key) == "string" and value ~= false and value ~= 0 and value ~= nil then
				id = key
			end
			if id and not seen[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
	end
	table.sort(ids)
	return ids
end

-- Returns (stats, applied ids). `defaults` is not changed.
function Perks.apply(
	defaults: Stats,
	perks: { [any]: any }?,
	effects: { [string]: { Effect } }
): (Stats, { string })
	local stats: any = table.clone(defaults)
	local applied = {}
	for _, id in Perks.ids(perks) do
		local list = effects[id]
		if list then
			table.insert(applied, id)
			for _, effect in list do
				local current = stats[effect.Stat]
				if type(current) == "number" then
					if effect.Set ~= nil then
						current = effect.Set
					end
					if effect.Add ~= nil then
						current += effect.Add
					end
					if effect.Mul ~= nil then
						current *= effect.Mul
					end
					stats[effect.Stat] = current
				end
			end
		end
	end
	return stats :: Stats, applied
end

-- Charges per picked gadget at Briefing / JUMP IN: Config charges, plus FirstGadgetBonus on picks[1], plus
-- `extra` on every pick (the Panic Pack gives +1 at LOCKDOWN). The Crowbar is never in `picks`.
function Perks.charges(
	picks: { string },
	baseCharges: { [string]: number },
	stats: Stats,
	extra: number?
): { [string]: number }
	local result = {}
	for index, gadget in picks do
		local charges = (result[gadget] or baseCharges[gadget] or 0) + (extra or 0)
		if index == 1 then
			charges += stats.FirstGadgetBonus
		end
		result[gadget] = charges
	end
	return result
end

return Perks
