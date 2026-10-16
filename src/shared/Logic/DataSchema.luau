--!strict
-- Player data schema: defaults, ordered migrations and a deep "reconcile" that fills missing keys.
-- Pure: no Roblox APIs, no requires. The starter items come in as arguments (from Catalog).
--
-- Rules (docs/beta-spec-meta.md §1):
--   * `version` field; migrations[n] turns version n into n + 1; missing version = 0.
--   * reconcile never deletes unknown keys (a newer feature may have written them).
--   * version > CURRENT → "newer" (a newer server saved it: kick, never overwrite).
--   * a stored value that is not a table → "corrupt" (back it up, start fresh).

local DataSchema = {}

DataSchema.CURRENT = 1

export type Contract = {
	id: string,
	tier: string,
	target: number,
	progress: number,
	reward: number,
	done: boolean,
}
export type HeistRecord = { stars: { [string]: number }, clears: { [string]: number }, bestLoot: number }
export type Trophy = { loot: string, heist: string, tier: string, crew: number, at: number }

export type PlayerData = {
	version: number,
	cash: number,
	rep: number,
	rankRewarded: number,
	owned: { [string]: number },
	robuxOwned: { [string]: number },
	equipped: { [string]: string },
	loadout: { string },
	perks: { unlocked: { [string]: boolean }, equipped: { string }, respecs: number },
	heists: { [string]: HeistRecord },
	recentHeists: { string },
	lastDifficulty: string,
	onboarding: { done: boolean, steps: { [string]: boolean } },
	daily: { day: number, contracts: { Contract }, firstJobUsed: boolean, rerolls: number },
	weekly: { week: number, mostWantedDone: boolean },
	collection: { [string]: number },
	collectionRewards: { [string]: number },
	trophies: { Trophy },
	stats: { [string]: number },
	settings: { [string]: any },
	seenTips: { [string]: number },
	receipts: { [string]: number },
	purchases: { [string]: number },
	recentRounds: { string },
	firstSeen: number,
	lastSeen: number,
}

export type Starter = { equipped: { [string]: string }, loadout: { string } }

DataSchema.StatKeys = {
	"rounds",
	"escapes",
	"busts",
	"mainLoot",
	"rescues",
	"lootBanked",
	"cashEarned",
	"cashSpent",
	"bestPayout",
	"playSeconds",
	"sessions",
}

-- A fresh profile. `starter` = Catalog.DefaultEquipped / DefaultLoadout.
function DataSchema.defaults(now: number, starter: Starter): PlayerData
	local stats: { [string]: number } = {}
	for _, key in DataSchema.StatKeys do
		stats[key] = 0
	end
	return {
		version = DataSchema.CURRENT,
		cash = 0,
		rep = 0,
		rankRewarded = 1,
		owned = {},
		robuxOwned = {},
		equipped = table.clone(starter.equipped),
		loadout = table.clone(starter.loadout),
		perks = { unlocked = {}, equipped = {}, respecs = 0 },
		heists = {},
		recentHeists = {},
		lastDifficulty = "Normal",
		onboarding = { done = false, steps = {} },
		daily = { day = 0, contracts = {}, firstJobUsed = false, rerolls = 0 },
		weekly = { week = 0, mostWantedDone = false },
		collection = {},
		collectionRewards = {},
		trophies = {},
		stats = stats,
		settings = {},
		seenTips = {},
		receipts = {},
		purchases = {},
		recentRounds = {},
		firstSeen = now,
		lastSeen = now,
	}
end

-- Deep copy of plain data (tables, strings, numbers, booleans).
function DataSchema.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = DataSchema.deepCopy(v)
	end
	return copy :: any
end

local function isArray(t: { [any]: any }): boolean
	return #t > 0 or next(t) == nil
end

-- Fills keys that are missing in `data` from `template`, deeply. Keys only in `data` are kept.
-- A value with the wrong type is replaced by the template's value. Arrays and empty template tables are
-- never merged element by element (a stored list wins as a whole). Returns how many values were repaired.
function DataSchema.reconcile(data: { [any]: any }, template: { [any]: any }): number
	local repaired = 0
	for key, default in template do
		local current = data[key]
		if current == nil or type(current) ~= type(default) then
			data[key] = DataSchema.deepCopy(default)
			repaired += 1
		elseif type(default) == "table" and not isArray(default) then
			repaired += DataSchema.reconcile(current, default)
		end
	end
	return repaired
end

-- Ordered migrations: migrations[n](data) turns version n into n + 1 (in place).
DataSchema.migrations = {
	-- v0 = prototype-era record without a version field (capitalised Cash/Rep). Keep the money.
	[0] = function(data: { [string]: any })
		if type(data.Cash) == "number" and data.cash == nil then
			data.cash = data.Cash
		end
		if type(data.Rep) == "number" and data.rep == nil then
			data.rep = data.Rep
		end
		data.Cash = nil
		data.Rep = nil
		data.version = 1
	end,
} :: { [number]: (data: { [string]: any }) -> () }

local function wholeNonNegative(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge then
		return 0
	end
	return math.max(0, math.floor(value))
end

-- Keeps the money fields sane (integers ≥ 0) and lists within their limits.
function DataSchema.sanitize(data: PlayerData)
	data.cash = wholeNonNegative(data.cash)
	data.rep = wholeNonNegative(data.rep)
	data.rankRewarded = math.max(1, wholeNonNegative(data.rankRewarded))
	for key, value in data.stats do
		data.stats[key] = wholeNonNegative(value)
	end
end

export type PrepareStatus = "ok" | "newer" | "corrupt"

-- Turns a stored value into current-version PlayerData.
-- Returns status, data (nil unless "ok") and the number of migration steps that ran.
function DataSchema.prepare(raw: any, now: number, starter: Starter): (PrepareStatus, PlayerData?, number)
	if type(raw) ~= "table" then
		return "corrupt", nil, 0
	end
	local data = raw :: { [string]: any }
	local version = data.version
	if version == nil then
		version = 0
	end
	if type(version) ~= "number" or version ~= math.floor(version) or version < 0 then
		return "corrupt", nil, 0
	end
	if version > DataSchema.CURRENT then
		return "newer", nil, 0
	end
	local steps = 0
	while version < DataSchema.CURRENT do
		local migrate = DataSchema.migrations[version]
		if not migrate then
			return "corrupt", nil, steps
		end
		migrate(data)
		version += 1
		data.version = version
		steps += 1
	end
	DataSchema.reconcile(data, DataSchema.defaults(now, starter) :: any)
	local typed: PlayerData = data :: any
	DataSchema.sanitize(typed)
	return "ok", typed, steps
end

return DataSchema
