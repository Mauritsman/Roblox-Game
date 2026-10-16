--!strict
-- Daily contracts: generation (one Easy, one Medium, one Hard; same in every server for a player and day),
-- progress from finished rounds, and the free reroll. Pure: the rng comes in as an argument (Logic/Rng).

local Contracts = {}

Contracts.TierOrder = { "Easy", "Medium", "Hard" }

export type Template = {
	Id: string,
	Text: string,
	Tier: string,
	Counter: string,
	Target: number,
	NeedsCrew: boolean?,
	RequiresHeist: string?,
	NeedsHard: boolean?,
}
export type Contract = {
	id: string,
	tier: string,
	target: number,
	progress: number,
	reward: number,
	done: boolean,
}
export type Context = { heistsUnlocked: { [string]: boolean }, hardUnlocked: boolean }
-- Round facts for ONE player (built from RoundResult).
export type RoundFacts = {
	outcome: string,
	escaped: boolean, -- this player got away
	isHotJob: boolean,
	difficulty: string,
	stars: number,
	mainLootBanked: boolean,
	maxAlarmTier: number,
	stats: { [string]: number }, -- CrewStats of this player
}
export type RngLike = { int: (self: any, min: number, max: number) -> number }

function Contracts.seedFor(userId: number, day: number): number
	return (userId * 31 + day) % 2147483647
end

function Contracts.byId(templates: { Template }): { [string]: Template }
	local map: { [string]: Template } = {}
	for _, template in templates do
		map[template.Id] = template
	end
	return map
end

function Contracts.eligible(template: Template, ctx: Context): boolean
	if template.RequiresHeist and not ctx.heistsUnlocked[template.RequiresHeist] then
		return false
	end
	if template.NeedsHard and not ctx.hardUnlocked then
		return false
	end
	return true
end

local function make(template: Template, rewards: { [string]: number }): Contract
	return {
		id = template.Id,
		tier = template.Tier,
		target = template.Target,
		progress = 0,
		reward = rewards[template.Tier] or 0,
		done = false,
	}
end

local function candidates(
	templates: { Template },
	tier: string,
	ctx: Context,
	used: { [string]: boolean },
	crewAllowed: boolean
): { Template }
	local list: { Template } = {}
	for _, template in templates do
		if
			template.Tier == tier
			and not used[template.Id]
			and Contracts.eligible(template, ctx)
			and (crewAllowed or not template.NeedsCrew)
		then
			table.insert(list, template)
		end
	end
	return list
end

-- Three contracts, one per tier, at most `maxNeedsCrew` that need a crew (solo must always work).
function Contracts.generate(
	templates: { Template },
	ctx: Context,
	rewards: { [string]: number },
	maxNeedsCrew: number,
	rng: RngLike
): { Contract }
	local result: { Contract } = {}
	local used: { [string]: boolean } = {}
	local crewCount = 0
	for _, tier in Contracts.TierOrder do
		local list = candidates(templates, tier, ctx, used, crewCount < maxNeedsCrew)
		if #list > 0 then
			local template = list[rng:int(1, #list)]
			used[template.Id] = true
			if template.NeedsCrew then
				crewCount += 1
			end
			table.insert(result, make(template, rewards))
		end
	end
	return result
end

-- How much one round adds to a contract for this player.
function Contracts.amountFor(template: Template, facts: RoundFacts, quietMaxTier: number): number
	local finished = facts.outcome == "Escaped" or facts.outcome == "Busted"
	if not finished then
		return 0
	end
	local counter = template.Counter
	if counter == "roundsFinished" then
		return 1
	elseif counter == "twoStarRounds" then
		return if facts.escaped and facts.stars >= 2 then 1 else 0
	elseif counter == "hotJobEscapes" then
		return if facts.escaped and facts.isHotJob then 1 else 0
	elseif counter == "mainLootEscapes" then
		return if facts.escaped and facts.mainLootBanked then 1 else 0
	elseif counter == "quietEscapes" then
		return if facts.escaped and facts.maxAlarmTier <= quietMaxTier then 1 else 0
	elseif counter == "hardEscapes" then
		return if facts.escaped and facts.difficulty == "Hard" then 1 else 0
	end
	local value = facts.stats[counter]
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(0, math.floor(value))
end

-- Adds a round's progress. Returns the contracts that were completed by this round.
function Contracts.apply(
	contracts: { Contract },
	templatesById: { [string]: Template },
	facts: RoundFacts,
	quietMaxTier: number
): { Contract }
	local completed: { Contract } = {}
	for _, contract in contracts do
		local template = templatesById[contract.id]
		if template and not contract.done then
			local amount = Contracts.amountFor(template, facts, quietMaxTier)
			if amount > 0 then
				contract.progress = math.min(contract.target, contract.progress + amount)
				if contract.progress >= contract.target then
					contract.done = true
					table.insert(completed, contract)
				end
			end
		end
	end
	return completed
end

-- Replaces contract `index` with another template of the same tier. Reasons: "Invalid", "Done", "NoOptions".
function Contracts.reroll(
	contracts: { Contract },
	index: number,
	templates: { Template },
	ctx: Context,
	rewards: { [string]: number },
	maxNeedsCrew: number,
	rng: RngLike
): (boolean, string?)
	local current = contracts[index]
	if not current then
		return false, "Invalid"
	end
	if current.done then
		return false, "Done"
	end
	local byId = Contracts.byId(templates)
	local used: { [string]: boolean } = {}
	local crewCount = 0
	for i, contract in contracts do
		used[contract.id] = true
		local template = byId[contract.id]
		if i ~= index and template and template.NeedsCrew then
			crewCount += 1
		end
	end
	local list = candidates(templates, current.tier, ctx, used, crewCount < maxNeedsCrew)
	if #list == 0 then
		return false, "NoOptions"
	end
	contracts[index] = make(list[rng:int(1, #list)], rewards)
	return true, nil
end

return Contracts
