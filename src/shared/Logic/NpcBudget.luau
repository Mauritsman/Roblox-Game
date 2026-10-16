--!strict
-- How many guards fit (beta-spec §4.4): at most Config.Npc.Cap NPCs per server.
--   guards = clamp(base + mapBonus + modifier + difficulty, 1, cap − others)
-- `others` = Karel + Boef (map 1) + map extras (Robo-Mop) + Inspector. The mini-job's sleeping guard is not counted.
-- There is always at least 1 guard, even when the other NPCs fill the cap.

local NpcBudget = {}

export type Others = {
	karel: boolean?,
	dog: boolean?,
	extra: number?, -- map extras (heist ExtraNpcs)
	inspector: number?, -- Health Inspector modifier (Config.Modifiers.HealthInspector.Npcs)
}

-- Base guards for a crew size from a list such as Config.Guard.CountByCrew = {2, 3, 3, 4}.
function NpcBudget.baseFor(crew: number, countByCrew: { number }): number
	if #countByCrew == 0 then
		return 1
	end
	local index = math.clamp(math.floor(crew), 1, #countByCrew)
	return countByCrew[index]
end

local function sum(values: { number } | number | nil): number
	if values == nil then
		return 0
	elseif type(values) == "number" then
		return values
	end
	local total = 0
	for _, value in values do
		total += value
	end
	return total
end

-- `base` is the CountByCrew list (or a number); `bonuses` a list of numbers (or one number).
function NpcBudget.guardCount(
	crew: number,
	base: { number } | number,
	bonuses: { number } | number | nil,
	others: number,
	cap: number
): number
	local baseCount = if type(base) == "number" then base else NpcBudget.baseFor(crew, base)
	local wanted = baseCount + sum(bonuses)
	local room = math.max(1, cap - others)
	return math.clamp(wanted, 1, room)
end

-- The other NPCs that count toward the cap.
function NpcBudget.others(o: Others): number
	return (if o.karel then 1 else 0) + (if o.dog then 1 else 0) + (o.extra or 0) + (o.inspector or 0)
end

return NpcBudget
