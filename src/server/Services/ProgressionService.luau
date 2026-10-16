--!strict
-- Progression (owner: meta): Crew Rank from Rep, skill points and the 3×3 perk tree, heist and tier unlocks,
-- rank-up rewards. docs/beta-spec-meta.md §4. Perk EFFECTS are mechanics' (Logic/Perks, LoadoutService:StatsOf).
--
-- For mechanics:  GetPerks(player) → {[perkId] = 1} (read at Briefing), CrewHeists(players), CrewTiers(players,
-- heistId), IsTutorialDone(player), RoundsCompleted(player), GetRank(player).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local DataSchema = require(ReplicatedStorage.Shared.Logic.DataSchema)
local JobBoard = require(ReplicatedStorage.Shared.Logic.JobBoard)
local PerkTree = require(ReplicatedStorage.Shared.Logic.PerkTree)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Settlement = require(ReplicatedStorage.Shared.Logic.Settlement)

local Meta = script.Parent.Parent.Meta
local Access = require(Meta.Access)
local Features = require(Meta.Features)
local RequestGuard = require(Meta.RequestGuard)
local AnalyticsTracker = require(script.Parent.AnalyticsTracker)
local DataService = require(script.Parent.DataService)

type PlayerData = DataSchema.PlayerData

export type Unlock = { kind: string, id: string, name: string }

local P = MetaConfig.Progression
local TREE = MetaConfig.PerkTree

local ProgressionService = {}

function ProgressionService:GetRank(player: Player): number
	local data = DataService:Get(player)
	return if data then Access.rank(data) else 1
end

function ProgressionService:SkillPoints(player: Player): number
	local data = DataService:Get(player)
	return if data then Access.skillPoints(data) else 0
end

-- Equipped perks as {perkId = 1}; empty while mechanics' Config.Features.Perks is off.
function ProgressionService:GetPerks(player: Player): { [string]: number }
	local data = DataService:Get(player)
	if not data or not Features.on("Perks") then
		return {}
	end
	return PerkTree.equippedSet(data.perks)
end

function ProgressionService:IsTutorialDone(player: Player): boolean
	local data = DataService:Get(player)
	return data ~= nil and data.onboarding.done
end

function ProgressionService:RoundsCompleted(player: Player): number
	local data = DataService:Get(player)
	return if data then data.stats.rounds or 0 else 0
end

-- Union of the group's unlocks: {[heistId] = {open, unlockedBy (display name), tiers}}.
-- Tiers other than Normal are only offered while mechanics' Config.Features.Difficulty is on.
function ProgressionService:CrewHeists(players: { Player }): { [string]: JobBoard.CrewHeist }
	local members: { JobBoard.Member } = {}
	for _, player in players do
		local data = DataService:Get(player)
		if data then
			table.insert(members, Access.member(player.DisplayName, data))
		end
	end
	local union = JobBoard.union(members, MetaConfig.Heists.Order, MetaConfig.Difficulty.Order)
	-- The default heist is always open, even before anyone's data loaded.
	local default = union[MetaConfig.Heists.Default]
	if default then
		default.open = true
		default.tiers[MetaConfig.Difficulty.Default] = true
	end
	if not Features.on("Difficulty") then
		for _, entry in union do
			for tier in entry.tiers do
				entry.tiers[tier] = tier == MetaConfig.Difficulty.Default
			end
		end
	end
	return union
end

function ProgressionService:CrewTiers(players: { Player }, heistId: string): { [string]: boolean }
	local entry = ProgressionService:CrewHeists(players)[heistId]
	if not entry then
		return { [MetaConfig.Difficulty.Default] = true }
	end
	return entry.tiers
end

-- What opens between two ranks (for the payout screen and RankUp): free items, slots, heists, titles.
function ProgressionService.unlocksBetween(before: number, after: number): { Unlock }
	local list: { Unlock } = {}
	for rank = before + 1, after do
		for slot, slotRank in P.SlotRank do
			if slotRank == rank and slot ~= "Gadget" then
				table.insert(list, { kind = "Slot", id = slot, name = `{slot} slot` })
			end
		end
		for _, item in Catalog.List do
			if item.MinRank == rank and (item.Free or item.Price ~= nil) then
				table.insert(
					list,
					{ kind = if item.Free then "Item" else "ShopItem", id = item.Id, name = item.Name }
				)
			end
		end
		for _, heistId in MetaConfig.Heists.Order do
			local rule = P.HeistUnlock[heistId]
			if rule and rule.Rank == rank then
				table.insert(
					list,
					{ kind = "Heist", id = heistId, name = MetaConfig.Heists.Names[heistId] or heistId }
				)
			end
		end
		local title = P.Titles[rank]
		if title then
			table.insert(list, { kind = "Title", id = tostring(rank), name = title })
		end
	end
	return list
end

-- Inside an Update: pays every unpaid rank-up reward. Returns the Cash paid.
function ProgressionService.claimRankRewards(data: PlayerData): number
	return Settlement.claimRankRewards(data, MetaConfig, { Progression = Progression } :: any)
end

-- Tells the player about a rank-up and logs it (call after the Update that raised Rep).
function ProgressionService:NotifyRankUp(player: Player, before: number, after: number, rankCash: number)
	if after <= before then
		return
	end
	local data = DataService:Get(player)
	local title = Progression.title(after, P.Titles)
	local skillPoints = Progression.skillPoints(after)
	Net.send(player, "RankUp", after, title, ProgressionService.unlocksBetween(before, after), skillPoints)
	AnalyticsTracker:Custom(player, "RankUp", after)
	if rankCash > 0 and data then
		AnalyticsTracker:Economy(
			player,
			"Source",
			rankCash,
			data.cash,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			"RankUp"
		)
	end
end

-- Requests ---------------------------------------------------------------------------------------------------

local function result(player: Player, action: string, ok: boolean, id: string?, reason: string?)
	Net.send(player, "MetaResult", action, ok, id or "", reason or "")
end

local function refuseCommon(player: Player, action: string, id: string?): boolean
	if not DataService:IsLoaded(player) then
		result(player, action, false, id, "Busy")
		return true
	end
	if RequestGuard.inRound(player) then
		result(player, action, false, id, "InRound")
		return true
	end
	if not Features.on("Perks") then
		result(player, action, false, id, "Locked")
		return true
	end
	return false
end

local function onUnlockPerk(player: Player, perkId: any)
	local id = RequestGuard.id(perkId)
	if not id then
		return
	end
	if refuseCommon(player, "Perk", id) then
		return
	end
	local current = DataService:Get(player)
	if not current then
		return
	end
	local okUnlock, reason = PerkTree.canUnlock(TREE, current.perks, id, Access.skillPoints(current))
	local spent = 0
	if okUnlock then
		okUnlock = DataService:Update(player, "UnlockPerk", function(data)
			PerkTree.unlock(TREE, data.perks, id, Access.skillPoints(data))
			spent = PerkTree.spent(TREE, data.perks.unlocked)
		end)
		reason = if okUnlock then nil else "Busy"
	end
	result(player, "Perk", okUnlock, id, reason)
	if okUnlock then
		AnalyticsTracker:Custom(player, "PerkUnlocked", spent, { id })
	end
end

local function onEquipPerks(player: Player, list: any)
	if refuseCommon(player, "Perk", nil) then
		return
	end
	local data = DataService:Get(player)
	if not data then
		return
	end
	local ok, reason, clean = PerkTree.validateEquip(TREE, data.perks, list)
	if ok and clean then
		local equipList = clean
		DataService:Update(player, "EquipPerks", function(d)
			d.perks.equipped = equipList
		end)
	end
	result(player, "Perk", ok, nil, reason)
end

local function onRespecPerks(player: Player)
	if refuseCommon(player, "Respec", nil) then
		return
	end
	local respecs = 0
	local ok = DataService:Update(player, "RespecPerks", function(data)
		PerkTree.respec(TREE, data.perks)
		respecs = data.perks.respecs
	end)
	result(player, "Respec", ok, nil, if ok then nil else "Busy")
	if ok then
		AnalyticsTracker:Custom(player, "PerkRespec", respecs)
	end
end

function ProgressionService:Start()
	RequestGuard.on("UnlockPerk", onUnlockPerk)
	RequestGuard.on("EquipPerks", onEquipPerks)
	RequestGuard.on("RespecPerks", onRespecPerks, { burst = 2, perSecond = 0.5 })

	-- Repair perks after config changes and pay rank rewards the player is owed (e.g. a raised cap).
	DataService.Loaded:Connect(function(player: Player, data: PlayerData)
		local before = data.rankRewarded
		local skillPoints = Access.skillPoints(data)
		local probe = DataSchema.deepCopy(data.perks)
		local needsRepair = PerkTree.repair(TREE, probe, skillPoints)
		local owed = Access.rank(data) > data.rankRewarded
		if not needsRepair and not owed then
			return
		end
		local cash = 0
		DataService:Update(player, "ProgressionRepair", function(d)
			PerkTree.repair(TREE, d.perks, skillPoints)
			cash = ProgressionService.claimRankRewards(d)
		end)
		if owed then
			ProgressionService:NotifyRankUp(player, before, Access.rank(data), cash)
		end
	end)
end

return ProgressionService
