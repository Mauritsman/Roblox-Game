--!strict
-- One award per crew member at payout (beta-spec §8). Awards are handed out in priority order; each award goes
-- to at most one player and each player gets at most one. "Most …" awards go to the highest count; ties go to the
-- lowest UserId so the result is deterministic. Whoever is left gets the fallback "Sightseer".
-- Ids are stable: ux maps them to icons and text, meta passes them through in RoundResult.crew[i].award.

local Awards = {}

-- Per-player round facts (missing = 0 / false). Names overlap with meta's CrewStats where they mean the same.
export type Stats = {
	mainLootBanked: boolean?, -- this player banked the main loot (Golden Gouda, …)
	rescues: number?,
	heroDrops: number?, -- made a carrying guard drop a captive
	justMadeIt: boolean?, -- entered the van in the last Config.Round.JustMadeItSeconds
	selfEmp: number?, -- hit their own drone with an EMP
	sneezes: number?, -- sneezed out of a hiding spot
	tracesCleaned: number?, -- traces Karel cleaned up after them
	uncaughtDrops: number?, -- drops and throws that landed uncaught
	bubbledTeammates: number?,
	throwsCaught: number?, -- their throws a teammate caught
	boefFed: number?,
	deviceRestarts: number?,
	timesCaught: number?,
	lootValueBanked: number?,
	everSeen: boolean?, -- a guard or camera meter on them ever reached full
}

Awards.FALLBACK = "Sightseer"
Awards.TUTORIAL = "FreshCrook" -- the mini-job's award (given directly by TutorialService)

type Rule = {
	id: string,
	score: (Stats) -> number, -- 0 = not eligible; higher wins
}

local function num(value: number?): number
	return value or 0
end

local function atLeast(value: number?, minimum: number): number
	local n = num(value)
	return if n >= minimum then n else 0
end

local function flag(value: boolean?): number
	return if value then 1 else 0
end

-- Priority order (beta-spec §8).
Awards.RULES = {
	{
		id = "GoudaGetter",
		score = function(s: Stats)
			return flag(s.mainLootBanked)
		end,
	},
	{
		id = "Jailbreaker",
		score = function(s: Stats)
			return num(s.rescues)
		end,
	},
	{
		id = "BubbleHero",
		score = function(s: Stats)
			return num(s.heroDrops)
		end,
	},
	{
		id = "JustMadeIt",
		score = function(s: Stats)
			return flag(s.justMadeIt)
		end,
	},
	{
		id = "SelfEmp",
		score = function(s: Stats)
			return num(s.selfEmp)
		end,
	},
	{
		id = "Achoo",
		score = function(s: Stats)
			return num(s.sneezes)
		end,
	},
	{
		id = "KarelsNemesis",
		score = function(s: Stats)
			return atLeast(s.tracesCleaned, 2)
		end,
	},
	{
		id = "Butterfingers",
		score = function(s: Stats)
			return atLeast(s.uncaughtDrops, 2)
		end,
	},
	{
		id = "OopsBubbled",
		score = function(s: Stats)
			return num(s.bubbledTeammates)
		end,
	},
	{
		id = "CheeseCannon",
		score = function(s: Stats)
			return atLeast(s.throwsCaught, 2)
		end,
	},
	{
		id = "DogWhisperer",
		score = function(s: Stats)
			return num(s.boefFed)
		end,
	},
	{
		id = "Safecracker",
		score = function(s: Stats)
			return num(s.deviceRestarts)
		end,
	},
	{
		id = "CellRegular",
		score = function(s: Stats)
			return atLeast(s.timesCaught, 2)
		end,
	},
	{
		id = "Ghost",
		score = function(s: Stats)
			return if num(s.lootValueBanked) > 0 and not s.everSeen then num(s.lootValueBanked) else 0
		end,
	},
	{
		id = "PackMule",
		score = function(s: Stats)
			return num(s.lootValueBanked)
		end,
	},
} :: { Rule }

-- All award ids, in priority order, with the fallback last.
function Awards.ids(): { string }
	local list = {}
	for _, rule in Awards.RULES do
		table.insert(list, rule.id)
	end
	table.insert(list, Awards.FALLBACK)
	return list
end

-- statsByPlayer: {[userId] = Stats} → {[userId] = awardId}.
function Awards.assign(statsByPlayer: { [number]: Stats }): { [number]: string }
	local players = {}
	for userId in statsByPlayer do
		table.insert(players, userId)
	end
	table.sort(players)

	local result: { [number]: string } = {}
	for _, rule in Awards.RULES do
		local best: number? = nil
		local bestScore = 0
		for _, userId in players do
			if result[userId] == nil then
				local score = rule.score(statsByPlayer[userId])
				if score > bestScore then
					best, bestScore = userId, score
				end
			end
		end
		if best ~= nil then
			result[best] = rule.id
		end
	end
	for _, userId in players do
		if result[userId] == nil then
			result[userId] = Awards.FALLBACK
		end
	end
	return result
end

return Awards
