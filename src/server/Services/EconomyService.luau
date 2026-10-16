--!strict
-- M0 STUB (meta): accepts RoundResult and does nothing yet. See docs/beta-spec-meta.md §3.4.

local EconomyService = {}

export type CrewStats = { [string]: number }
export type CrewEntry = { player: Player, inVanAtEnd: boolean, award: string?, stats: CrewStats? }
export type RoundResult = {
	roundId: string,
	heistId: string,
	difficulty: string,
	modifierId: string?,
	isHotJob: boolean?,
	outcome: string,
	vanLoot: number,
	stars: number,
	mainLootBanked: boolean?,
	maxAlarmTier: number?,
	lockdownAtEnd: boolean?,
	durationSeconds: number?,
	objectives: { { id: string, bonusPct: number } }?,
	banked: { { lootId: string, name: string, class: string, value: number } }?,
	crew: { CrewEntry },
}

function EconomyService:SettleRound(result: RoundResult): { [number]: { cash: number, rep: number } }
	print(`[Economy] (stub) SettleRound {result.roundId} {result.heistId} {result.outcome}`)
	return {}
end

return EconomyService
