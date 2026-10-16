--!strict
-- Meta test helpers, ONLY active in Roblox Studio (RunService:IsStudio()), like DevService. Lets the tester drive
-- saving, money and progression without buttons. From the Client datamodel:
--   Remotes.ToServer:FireServer("DevGiveCash", 5000)
--   Remotes.ToServer:FireServer("DevFakeRound", { vanLoot = 1000, maxAlarmTier = 2 })
-- Commands (docs/meta-api.md §6): DevGiveCash, DevGiveRep, DevSetRank, DevResetData, DevSetStars, DevFakeRound,
-- DevFakeReceipt, DevTimeOffset, DevDataMock, DevForeignLock, DevStealMyLock, DevLoadFixture,
-- DevCompleteOnboarding, DevPrintData.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local HeistRecords = require(ReplicatedStorage.Shared.Logic.HeistRecords)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)

local Meta = script.Parent.Parent.Meta
local Access = require(Meta.Access)
local Clock = require(Meta.Clock)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local LobbyService = require(script.Parent.LobbyService)
local ProgressionService = require(script.Parent.ProgressionService)
local ShopReceiptService = require(script.Parent.ShopReceiptService)

local MetaDevService = {}

local function num(value: any, default: number): number
	return if type(value) == "number" and value == value then value else default
end

local function say(player: Player, text: string)
	print(`[MetaDev] {player.Name}: {text}`)
	Net.send(player, "Toast", text)
end

local function setRep(player: Player, rep: number, reason: string)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local before = Access.rank(data)
	local cash = 0
	DataService:Update(player, reason, function(d)
		d.rep = math.max(0, math.floor(rep))
		local rank = Access.rank(d)
		if rank < d.rankRewarded then
			d.rankRewarded = rank
		end
		cash = ProgressionService.claimRankRewards(d)
	end)
	local after = Access.rank(DataService:Get(player) :: any)
	ProgressionService:NotifyRankUp(player, before, after, cash)
	say(player, `Rep {math.floor(rep)} → Rank {after}`)
end

-- Expected stars for map 1 thresholds: 1★ ≥ 500, 2★ ≥ 1,500, 3★ main loot + ≥ 2,500 (only when escaping).
local function starsFor(vanLoot: number, mainLoot: boolean, escaped: boolean): number
	if not escaped then
		return 0
	end
	if mainLoot and vanLoot >= 2500 then
		return 3
	elseif vanLoot >= 1500 then
		return 2
	elseif vanLoot >= 500 then
		return 1
	end
	return 0
end

local function fakeRound(player: Player, options: any)
	local o: { [string]: any } = if type(options) == "table" then options else {}
	local outcome = if type(o.outcome) == "string" then o.outcome else "Escaped"
	local vanLoot = num(o.vanLoot, 1000)
	local mainLoot = o.mainLoot == true
	local inVan = if type(o.inVan) == "boolean" then o.inVan else outcome == "Escaped"
	local banked = {}
	if mainLoot then
		table.insert(banked, { lootId = "GoldenGouda", name = "Golden Gouda", class = "Main", value = 1500 })
	end
	table.insert(banked, { lootId = "CheeseWheel", name = "Cheese Wheel", class = "Medium", value = 150 })
	local stats = if type(o.stats) == "table" then o.stats else { lootBanked = 3, lootValueBanked = vanLoot }
	local result = {
		roundId = if type(o.roundId) == "string" then o.roundId else HttpService:GenerateGUID(false),
		heistId = if type(o.heistId) == "string" then o.heistId else "GoldenWheel",
		difficulty = if type(o.difficulty) == "string" then o.difficulty else "Normal",
		modifierId = o.modifierId,
		isHotJob = o.isHotJob == true,
		outcome = outcome,
		vanLoot = vanLoot,
		stars = num(o.stars, starsFor(vanLoot, mainLoot, outcome == "Escaped" and inVan)),
		mainLootBanked = mainLoot,
		maxAlarmTier = num(o.maxAlarmTier, 2),
		lockdownAtEnd = mainLoot,
		durationSeconds = num(o.durationSeconds, 300),
		objectives = if type(o.objectives) == "table" then o.objectives else {},
		banked = banked,
		crew = { { player = player, inVanAtEnd = inVan, award = "PackMule", stats = stats } },
	}
	local summary = EconomyService:SettleRound(result :: any)
	local mine = summary[player.UserId]
	say(
		player,
		`Fake round {result.roundId}: {if mine then `+{mine.cash} Cash, +{mine.rep} Rep` else "already paid"}`
	)
end

local function fixture(name: string): ((any) -> any)?
	if name == "v0" then
		return function(_raw: any): any
			return {
				data = { Cash = 1234, Rep = 3000, legacyFlag = true },
				savedAt = 0,
				saveCount = 0,
				steals = 0,
			}
		end
	elseif name == "v99" then
		return function(_raw: any): any
			return { data = { version = 99, cash = 5 }, savedAt = 0, saveCount = 0, steals = 0 }
		end
	elseif name == "corrupt" then
		return function(_raw: any): any
			return "this is not a profile"
		end
	end
	return nil
end

function MetaDevService:Start()
	if not RunService:IsStudio() then
		return
	end

	Net.onRequest("DevGiveCash", function(player: Player, amount: any)
		local value = math.floor(num(amount, 1000))
		if value > 0 then
			EconomyService:Grant(player, value, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, "Dev")
		else
			DataService:Update(player, "DevTakeCash", function(d)
				d.cash = math.max(0, d.cash + value)
			end)
		end
		say(player, `Cash {value >= 0 and "+" or ""}{value}`)
	end)

	Net.onRequest("DevGiveRep", function(player: Player, amount: any)
		local data = DataService:Get(player)
		if data then
			setRep(player, data.rep + math.max(0, num(amount, 1000)), "DevGiveRep")
		end
	end)

	Net.onRequest("DevSetRank", function(player: Player, rank: any)
		local P = MetaConfig.Progression
		local target = math.clamp(math.floor(num(rank, 2)), 1, P.MaxRank)
		setRep(player, Progression.totalRep(target, P.RepPerRankStep), "DevSetRank")
	end)

	Net.onRequest("DevResetData", function(player: Player)
		local ok = DataService:DevResetAsync(player)
		say(player, if ok then "Profile reset to defaults" else "Reset failed")
	end)

	Net.onRequest("DevSetStars", function(player: Player, heistId: any, tier: any, stars: any)
		if type(heistId) ~= "string" or type(tier) ~= "string" then
			return
		end
		local value = math.clamp(math.floor(num(stars, 3)), 0, 3)
		DataService:Update(player, "DevSetStars", function(d)
			HeistRecords.get(d.heists, heistId).stars[tier] = value
		end)
		say(player, `{heistId} {tier}: {value}★`)
	end)

	Net.onRequest("DevFakeRound", fakeRound)

	Net.onRequest("DevFakeReceipt", function(player: Player, productKey: any, purchaseId: any)
		local key = if type(productKey) == "string" then productKey else "BetaTestToken"
		local id = if type(purchaseId) == "string" then purchaseId else HttpService:GenerateGUID(false)
		local decision = ShopReceiptService:Process({
			PlayerId = player.UserId,
			ProductId = 0,
			PurchaseId = id,
			CurrencySpent = 0,
		}, key)
		say(player, `Receipt {id} ({key}): {decision.Name}`)
	end)

	Net.onRequest("DevTimeOffset", function(player: Player, seconds: any)
		Clock.setOffset(num(seconds, 0))
		for _, other in game:GetService("Players"):GetPlayers() do
			local data = DataService:Get(other)
			if data then
				local now = Clock.now()
				DataService:Update(other, "DevTimeOffset", function(d)
					EconomyService.refreshPeriods(d, other.UserId, now)
				end)
			end
		end
		LobbyService:Refresh()
		say(player, `Clock offset {Clock.offset()} s`)
	end)

	Net.onRequest("DevDataMock", function(player: Player, failRate: any, latency: any)
		DataService:DevSetMock(num(failRate, 0), num(latency, 0))
		say(player, `DataStore mock: fail {num(failRate, 0)}, latency {num(latency, 0)} s`)
	end)

	-- A fresh lock from "another server" on my record, then rejoin: the load waits and steals after ~16–20 s.
	Net.onRequest("DevForeignLock", function(player: Player)
		say(player, "Foreign lock written; reloading (expect a ~16–20 s wait, then a steal)")
		local ok = DataService:DevReloadAsync(player, function(raw: any): any
			if type(raw) ~= "table" then
				return nil
			end
			raw.lock = { session = "DevOtherServer", job = "dev", place = 0, at = os.time() }
			return raw
		end)
		say(player, if ok then "Reloaded after stealing the lock" else "Reload failed")
	end)

	-- Another server "steals" my record: my next save is cancelled and I am kicked (nothing is overwritten).
	Net.onRequest("DevStealMyLock", function(player: Player)
		DataService:DevUpdateRecord(player.UserId, function(raw: any): any
			if type(raw) ~= "table" then
				return nil
			end
			raw.lock = { session = "DevThief", job = "dev", place = 0, at = os.time() }
			return raw
		end)
		say(player, "Lock stolen; the next save will be refused")
		task.delay(1, function()
			DataService:SaveNowAsync(player, "DevStealMyLock")
		end)
	end)

	-- Fixtures: "v0" (old format, migrates), "v99" (newer version, kick), "corrupt" (backup + fresh profile).
	Net.onRequest("DevLoadFixture", function(player: Player, name: any)
		local transform = if type(name) == "string" then fixture(name) else nil
		if not transform then
			say(player, "Fixtures: v0, v99, corrupt")
			return
		end
		local ok = DataService:DevReloadAsync(player, transform)
		say(player, `Fixture {name}: {if ok then "loaded" else "not loaded"}`)
	end)

	Net.onRequest("DevCompleteOnboarding", function(player: Player)
		DataService:Update(player, "DevOnboarding", function(d)
			d.onboarding.done = true
		end)
		say(player, "Onboarding marked done")
	end)

	Net.onRequest("DevPrintData", function(player: Player)
		local data = DataService:Get(player)
		if data then
			local ok, json = pcall(function()
				return HttpService:JSONEncode(data)
			end)
			print(`[MetaDev] {player.Name} data: {if ok then json else "?"}`)
		end
	end)
end

return MetaDevService
