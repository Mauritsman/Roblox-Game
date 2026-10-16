--!strict
-- Crew Rank from lifetime Rep, titles, skill points and rank-up rewards. Pure.
-- Rank n → n + 1 costs step × n Rep, so the total for rank n = step / 2 × n × (n − 1) (step 1,000: 500·n·(n−1)).

local Progression = {}

export type Progress = { rank: number, repIntoRank: number, repForNext: number, atMax: boolean }

function Progression.totalRep(rank: number, step: number): number
	return step / 2 * rank * (rank - 1)
end

function Progression.rankForRep(rep: number, step: number, maxRank: number): number
	local rank = 1
	while rank < maxRank and rep >= Progression.totalRep(rank + 1, step) do
		rank += 1
	end
	return rank
end

-- Rank plus how far into it the player is (for the Rep bar). At the cap repForNext is 0.
function Progression.progress(rep: number, step: number, maxRank: number): Progress
	local rank = Progression.rankForRep(rep, step, maxRank)
	local base = Progression.totalRep(rank, step)
	if rank >= maxRank then
		return { rank = rank, repIntoRank = rep - base, repForNext = 0, atMax = true }
	end
	return { rank = rank, repIntoRank = rep - base, repForNext = step * rank, atMax = false }
end

-- One skill point per rank from Rank 2.
function Progression.skillPoints(rank: number): number
	return math.max(0, rank - 1)
end

-- The title of the highest titled rank ≤ rank.
function Progression.title(rank: number, titles: { [number]: string }): string
	local best, bestRank = "", -1
	for at, name in titles do
		if at <= rank and at > bestRank then
			best, bestRank = name, at
		end
	end
	return best
end

export type RankReward = { rank: number, cash: number }

-- Rewards for every rank above `rankRewarded` up to `rank` (skipping ranks pays each one).
-- Returns the list and the new rankRewarded value.
function Progression.rankRewards(
	rankRewarded: number,
	rank: number,
	cashPerRank: number
): ({ RankReward }, number)
	local list: { RankReward } = {}
	for r = rankRewarded + 1, rank do
		table.insert(list, { rank = r, cash = cashPerRank * r })
	end
	return list, math.max(rankRewarded, rank)
end

return Progression
