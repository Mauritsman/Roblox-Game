--!strict
-- Job board rules: what a group of players has open (union of their unlocks) and the vote tally at departure.
-- Pure. Votes are keyed by UserId; `at` is when the vote was cast (earliest wins ties).

local JobBoard = {}

export type Vote = { cardId: string, difficulty: string, at: number }
export type CardState = { open: boolean, tiers: { [string]: boolean } }
export type HeistAccess = { open: boolean, tiers: { [string]: boolean } }
export type Member = { name: string, heists: { [string]: HeistAccess } }
export type CrewHeist = { open: boolean, unlockedBy: string?, tiers: { [string]: boolean } }
export type Selection = { cardId: string, difficulty: string, votes: number, fromDefault: boolean }

-- Union over a group: a heist (or tier) is open when anyone has it. `unlockedBy` = the first member who has it.
function JobBoard.union(
	members: { Member },
	heistOrder: { string },
	tierOrder: { string }
): { [string]: CrewHeist }
	local result: { [string]: CrewHeist } = {}
	for _, heistId in heistOrder do
		local entry: CrewHeist = { open = false, unlockedBy = nil, tiers = {} }
		for _, tier in tierOrder do
			entry.tiers[tier] = false
		end
		for _, member in members do
			local access = member.heists[heistId]
			if access and access.open then
				if not entry.open then
					entry.open = true
					entry.unlockedBy = member.name
				end
				for tier, on in access.tiers do
					if on then
						entry.tiers[tier] = true
					end
				end
			end
		end
		result[heistId] = entry
	end
	return result
end

local function tierIndex(tierOrder: { string }, tier: string): number?
	for i, id in tierOrder do
		if id == tier then
			return i
		end
	end
	return nil
end

-- The highest offered tier at or below `wanted` (falls back to the lowest offered, then `fallback`).
function JobBoard.clampTier(
	wanted: string,
	offered: { [string]: boolean },
	tierOrder: { string },
	fallback: string
): string
	local start = tierIndex(tierOrder, wanted) or tierIndex(tierOrder, fallback) or 1
	for i = start, 1, -1 do
		if offered[tierOrder[i]] then
			return tierOrder[i]
		end
	end
	for _, tier in tierOrder do
		if offered[tier] then
			return tier
		end
	end
	return fallback
end

-- Most votes among `voters` on open cards wins; ties → the card with the earliest vote; no votes → default.
-- Difficulty = the LOWEST tier any voter of the winning card chose, clamped to what that card offers.
function JobBoard.tally(
	votes: { [number]: Vote },
	voters: { number },
	cards: { [string]: CardState },
	tierOrder: { string },
	defaultCard: string,
	defaultTier: string
): Selection
	local counts: { [string]: number } = {}
	local earliest: { [string]: number } = {}
	local lowest: { [string]: number } = {}
	for _, userId in voters do
		local vote = votes[userId]
		local card = vote and cards[vote.cardId]
		if vote and card and card.open then
			local id = vote.cardId
			counts[id] = (counts[id] or 0) + 1
			earliest[id] = math.min(earliest[id] or math.huge, vote.at)
			local index = tierIndex(tierOrder, vote.difficulty) or tierIndex(tierOrder, defaultTier) or 1
			lowest[id] = math.min(lowest[id] or math.huge, index)
		end
	end
	local best: string? = nil
	for id, count in counts do
		if
			best == nil
			or count > counts[best]
			or (count == counts[best] and earliest[id] < earliest[best :: string])
		then
			best = id
		end
	end
	if best == nil then
		local card = cards[defaultCard]
		local offered = if card then card.tiers else {}
		return {
			cardId = defaultCard,
			difficulty = JobBoard.clampTier(defaultTier, offered, tierOrder, defaultTier),
			votes = 0,
			fromDefault = true,
		}
	end
	local winner = best :: string
	local wanted = tierOrder[lowest[winner]] or defaultTier
	return {
		cardId = winner,
		difficulty = JobBoard.clampTier(wanted, cards[winner].tiers, tierOrder, defaultTier),
		votes = counts[winner],
		fromDefault = false,
	}
end

return JobBoard
