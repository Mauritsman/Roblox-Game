--!strict
-- Per-player round counters (beta-spec §8). StatsService keeps one Counters table per player and round; every
-- service reports moments by name through `StatsService:Event(name, player, data)`. From the counters come the
-- inputs for Logic/Awards (`awardStats`) and meta's CrewStats in RoundResult (`crewStats`), and the stars.
--
-- Event names (data is optional; `amount` defaults to 1, `value` is added to "<name>Value"):
--   LootPicked · LootBanked {value, class, main} · ThrowCaught (thrower) · UncaughtDrop (thrower/dropper) ·
--   CarriedTogether · JustMadeIt                                                   — mechanics A (loot, round)
--   Caught · Rescue · HeroDrop · Sneeze · TraceCleaned · BoefFed · BoefDistracted · Seen · HidFromChase — B
--   SelfEmp · BubbledTeammate · BubbledGuard · DeviceRestart                       — C
-- Unknown names are counted too, so new events need no change here.

local RoundStats = {}

export type Counters = { [string]: number }

export type EventData = {
	amount: number?,
	value: number?,
	class: string?, -- LootBanked: loot class
	main: boolean?, -- LootBanked: the heist's main loot
}

function RoundStats.new(): Counters
	return {}
end

local function bump(counters: Counters, key: string, amount: number)
	counters[key] = (counters[key] or 0) + amount
end

function RoundStats.add(counters: Counters, name: string, data: EventData?)
	local amount = if data and type(data.amount) == "number" then data.amount else 1
	bump(counters, name, amount)
	if data and type(data.value) == "number" then
		bump(counters, name .. "Value", data.value)
	end
	if name == "LootBanked" and data then
		if data.class == "Small" then
			bump(counters, "SmallBanked", amount)
		elseif data.class == "Heavy" or data.class == "Main" then
			bump(counters, "HeavyBanked", amount)
		end
		if data.main then
			bump(counters, "MainLootBanked", amount)
		end
	end
end

function RoundStats.get(counters: Counters, name: string): number
	return counters[name] or 0
end

-- Inputs for Logic/Awards.assign (same field names as Awards.Stats).
function RoundStats.awardStats(counters: Counters): { [string]: any }
	local function n(name: string): number
		return counters[name] or 0
	end
	return {
		mainLootBanked = n("MainLootBanked") > 0,
		rescues = n("Rescue"),
		heroDrops = n("HeroDrop"),
		justMadeIt = n("JustMadeIt") > 0,
		selfEmp = n("SelfEmp"),
		sneezes = n("Sneeze"),
		tracesCleaned = n("TraceCleaned"),
		uncaughtDrops = n("UncaughtDrop"),
		bubbledTeammates = n("BubbledTeammate"),
		throwsCaught = n("ThrowCaught"),
		boefFed = n("BoefFed"),
		deviceRestarts = n("DeviceRestart"),
		timesCaught = n("Caught"),
		lootValueBanked = n("LootBankedValue"),
		everSeen = n("Seen") > 0,
	}
end

-- meta's CrewStats (beta-spec-meta §3.4; missing = 0).
function RoundStats.crewStats(counters: Counters): { [string]: number }
	local function n(name: string): number
		return counters[name] or 0
	end
	return {
		lootBanked = n("LootBanked"),
		lootValueBanked = n("LootBankedValue"),
		smallBanked = n("SmallBanked"),
		heavyBanked = n("HeavyBanked"),
		rescues = n("Rescue"),
		bubbledGuards = n("BubbledGuard"),
		hidFromChase = n("HidFromChase"),
		boefDistracted = n("BoefDistracted") + n("BoefFed"),
		carriedTogether = n("CarriedTogether"),
		timesCaught = n("Caught"),
	}
end

-- Stars (beta-spec §8): 1★ van loot ≥ t[1], 2★ ≥ t[2], 3★ main loot banked and ≥ t[3]. Only after an escape.
function RoundStats.stars(
	vanLoot: number,
	mainBanked: boolean,
	escaped: boolean,
	thresholds: { number }?
): number
	if not escaped then
		return 0
	end
	local t = thresholds or { 500, 1500, 2500 }
	local stars = 0
	if vanLoot >= (t[1] or math.huge) then
		stars = 1
	end
	if vanLoot >= (t[2] or math.huge) then
		stars = 2
	end
	if mainBanked and vanLoot >= (t[3] or math.huge) then
		stars = 3
	end
	return stars
end

return RoundStats
