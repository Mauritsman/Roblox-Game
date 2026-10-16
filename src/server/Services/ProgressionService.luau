--!strict
-- M0 STUB (meta): rank, perks and unlocks with beta defaults.

local ProgressionService = {}

function ProgressionService:GetRank(_player: Player): number
	return 1
end

function ProgressionService:GetPerks(_player: Player): { [string]: number }
	return {}
end

function ProgressionService:CrewHeists(
	_players: { Player }
): { [string]: { open: boolean, unlockedBy: string? } }
	return { GoldenWheel = { open = true } }
end

function ProgressionService:CrewTiers(_players: { Player }, _heistId: string): { [string]: boolean }
	return { Easy = true, Normal = true, Hard = false }
end

function ProgressionService:IsTutorialDone(_player: Player): boolean
	return true
end

function ProgressionService:RoundsCompleted(_player: Player): number
	return 0
end

return ProgressionService
