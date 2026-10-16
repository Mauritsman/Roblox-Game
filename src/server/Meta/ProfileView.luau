--!strict
-- Builds the client's copy of a profile (Net "ProfileSync") and the player attributes the UI reads.
-- The view is PlayerData minus receipts/recentRounds, plus derived values (docs/meta-api.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local MetaTags = require(ReplicatedStorage.Shared.MetaTags)
local Calendar = require(ReplicatedStorage.Shared.Logic.Calendar)
local DataSchema = require(ReplicatedStorage.Shared.Logic.DataSchema)
local HeistRecords = require(ReplicatedStorage.Shared.Logic.HeistRecords)
local Payout = require(ReplicatedStorage.Shared.Logic.Payout)
local PerkTree = require(ReplicatedStorage.Shared.Logic.PerkTree)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)

local Access = require(script.Parent.Access)
local Clock = require(script.Parent.Clock)
local Features = require(script.Parent.Features)

type PlayerData = DataSchema.PlayerData

local ProfileView = {}

local HIDDEN = { receipts = true, recentRounds = true }

-- This week's Most Wanted heist and reward item.
function ProfileView.mostWanted(now: number): (string, string, number)
	local MW = MetaConfig.MostWanted
	local week = Calendar.week(now)
	local index = week % #MW.Rotation + 1
	return MW.Rotation[index], MW.RewardPool[index], week
end

function ProfileView.build(data: PlayerData, saveStatus: string): { [string]: any }
	local view: { [string]: any } = {}
	for key, value in data :: any do
		if not HIDDEN[key] then
			view[key] = value
		end
	end
	local P = MetaConfig.Progression
	local now = Clock.now()
	local progress = Progression.progress(data.rep, P.RepPerRankStep, P.MaxRank)
	local skillPoints = Progression.skillPoints(progress.rank)
	view.rank = progress.rank
	view.repIntoRank = progress.repIntoRank
	view.repForNext = progress.repForNext
	view.title = Progression.title(progress.rank, P.Titles)
	view.skillPoints = skillPoints
	view.skillPointsFree = PerkTree.available(MetaConfig.PerkTree, data.perks.unlocked, skillPoints)

	local heists = Access.heists(data)
	local unlocked: { string } = {}
	local tiers: { [string]: { [string]: boolean } } = {}
	local fresh: { [string]: boolean } = {}
	for _, heistId in MetaConfig.Heists.Order do
		local access = heists[heistId]
		if access.open then
			table.insert(unlocked, heistId)
		end
		tiers[heistId] = access.tiers
		fresh[heistId] = Payout.isFresh(data.recentHeists, heistId, MetaConfig.Economy.FreshWindow)
	end
	view.heistsUnlocked = unlocked
	view.tiersUnlocked = tiers
	view.freshHeists = fresh
	view.totalStars = HeistRecords.totalStars(data.heists)
	view.canVoteHotJob = (data.stats.rounds or 0) >= MetaConfig.HotJob.MinRoundsToVote

	local mwHeist, mwItem, week = ProfileView.mostWanted(now)
	view.mostWanted = {
		heistId = mwHeist,
		item = mwItem,
		owned = data.owned[mwItem] ~= nil,
		done = data.weekly.week == week and data.weekly.mostWantedDone,
	}
	view.firstJobBonusAvailable = data.daily.day == Calendar.day(now) and not data.daily.firstJobUsed
	view.rerollsLeft = math.max(0, MetaConfig.Contracts.FreeRerollsPerDay - data.daily.rerolls)
	view.dayResetsAt = Calendar.dayResetsAt(now)
	view.weekResetsAt = Calendar.weekResetsAt(now)
	view.serverNow = now
	view.features = Features.snapshot()
	view.saveStatus = saveStatus
	return view
end

local function commaList(list: { string }): string
	return table.concat(list, ",")
end

-- Player attributes (state the UI and other roles read without waiting for a message).
function ProfileView.attributes(data: PlayerData): { [string]: any }
	local P = MetaConfig.Progression
	local progress = Progression.progress(data.rep, P.RepPerRankStep, P.MaxRank)
	local equipped = data.equipped
	return {
		[MetaTags.Cash] = data.cash,
		[MetaTags.Rep] = data.rep,
		[MetaTags.Rank] = progress.rank,
		[MetaTags.Title] = Progression.title(progress.rank, P.Titles),
		[MetaTags.SkillPoints] = Progression.skillPoints(progress.rank),
		[MetaTags.RepIntoRank] = progress.repIntoRank,
		[MetaTags.RepForNext] = progress.repForNext,
		[MetaTags.IsNewPlayer] = not data.onboarding.done,
		[MetaTags.RoundsPlayed] = data.stats.rounds or 0,
		[MetaTags.HeistsUnlocked] = commaList(Access.openList(data)),
		[MetaTags.Loadout] = commaList(data.loadout),
		[MetaTags.Perks] = commaList(data.perks.equipped),
		[MetaTags.MaskId] = equipped.Mask or Catalog.DefaultEquipped.Mask,
		[MetaTags.HatId] = equipped.Hat or "",
		[MetaTags.VanId] = equipped.Van or Catalog.DefaultEquipped.Van,
	}
end

return ProfileView
