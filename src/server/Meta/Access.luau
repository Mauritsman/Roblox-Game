--!strict
-- What one profile has unlocked (rank, heists, tiers), derived from PlayerData with the pure Logic modules.
-- Shared by DataService (view, attributes), ProgressionService and LobbyService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local DataSchema = require(ReplicatedStorage.Shared.Logic.DataSchema)
local HeistRecords = require(ReplicatedStorage.Shared.Logic.HeistRecords)
local JobBoard = require(ReplicatedStorage.Shared.Logic.JobBoard)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)

type PlayerData = DataSchema.PlayerData

local Access = {}

export type HeistAccess = { open: boolean, route: string?, tiers: { [string]: boolean } }

function Access.rank(data: PlayerData): number
	local P = MetaConfig.Progression
	return Progression.rankForRep(data.rep, P.RepPerRankStep, P.MaxRank)
end

function Access.skillPoints(data: PlayerData): number
	return Progression.skillPoints(Access.rank(data))
end

function Access.heists(data: PlayerData): { [string]: HeistAccess }
	local rank = Access.rank(data)
	local result: { [string]: HeistAccess } = {}
	for _, heistId in MetaConfig.Heists.Order do
		local open, route =
			HeistRecords.isUnlocked(data.heists, rank, heistId, MetaConfig.Progression.HeistUnlock)
		local tiers = HeistRecords.tiers(
			data.heists,
			heistId,
			MetaConfig.Difficulty.Order,
			MetaConfig.Difficulty.Unlock
		)
		result[heistId] = { open = open, route = route, tiers = tiers }
	end
	return result
end

-- Ordered list of open heist ids.
function Access.openList(data: PlayerData): { string }
	local list: { string } = {}
	local heists = Access.heists(data)
	for _, heistId in MetaConfig.Heists.Order do
		if heists[heistId].open then
			table.insert(list, heistId)
		end
	end
	return list
end

function Access.member(name: string, data: PlayerData): JobBoard.Member
	local heists: { [string]: JobBoard.HeistAccess } = {}
	for heistId, access in Access.heists(data) do
		heists[heistId] = { open = access.open, tiers = access.tiers }
	end
	return { name = name, heists = heists }
end

-- Contract generation context for this profile.
function Access.contractContext(
	data: PlayerData
): { heistsUnlocked: { [string]: boolean }, hardUnlocked: boolean }
	local unlocked: { [string]: boolean } = {}
	local hard = false
	for heistId, access in Access.heists(data) do
		if access.open then
			unlocked[heistId] = true
			if access.tiers.Hard then
				hard = true
			end
		end
	end
	return { heistsUnlocked = unlocked, hardUnlocked = hard }
end

return Access
