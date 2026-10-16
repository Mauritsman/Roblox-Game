--!strict
-- M0 STUB (meta): always The Golden Wheel on Normal.

local LobbyService = {}

export type SelectedJob = {
	cardId: string,
	heistId: string,
	difficulty: string,
	modifierId: string?,
	isHotJob: boolean,
	mostWanted: boolean,
}

function LobbyService:GetSelectedJob(_boarders: { Player }, _roundId: string?): SelectedJob
	return {
		cardId = "GoldenWheel",
		heistId = "GoldenWheel",
		difficulty = "Normal",
		modifierId = nil,
		isHotJob = false,
		mostWanted = false,
	}
end

return LobbyService
