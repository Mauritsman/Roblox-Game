--!strict
-- Stars per heist and difficulty, star bonuses, heist and tier unlocks, mastery and star masks. Pure.
-- records = PlayerData.heists: { [heistId] = { stars = {[tier]: 0–3}, clears = {[tier]: n}, bestLoot = n } }

local HeistRecords = {}

export type Record = { stars: { [string]: number }, clears: { [string]: number }, bestLoot: number }
export type Records = { [string]: Record }
export type UnlockRule = { StarsOn: string?, Stars: number?, Rank: number? }
export type TierRule = { Tier: string, Stars: number }

function HeistRecords.get(records: Records, heistId: string): Record
	local record = records[heistId]
	if not record then
		record = { stars = {}, clears = {}, bestLoot = 0 }
		records[heistId] = record
	end
	return record
end

function HeistRecords.bestStars(records: Records, heistId: string, tier: string): number
	local record = records[heistId]
	return if record then record.stars[tier] or 0 else 0
end

-- Sum of the best stars over every tier of one heist.
function HeistRecords.starsOn(records: Records, heistId: string): number
	local record = records[heistId]
	if not record then
		return 0
	end
	local total = 0
	for _, stars in record.stars do
		total += stars
	end
	return total
end

function HeistRecords.totalStars(records: Records): number
	local total = 0
	for heistId in records do
		total += HeistRecords.starsOn(records, heistId)
	end
	return total
end

-- Is this heist open for one player? Returns the route: "Always", "Stars" or "Rank" (stars win if both).
function HeistRecords.isUnlocked(
	records: Records,
	rank: number,
	heistId: string,
	rules: { [string]: UnlockRule }
): (boolean, string?)
	local rule = rules[heistId]
	if not rule then
		return false, nil
	end
	if rule.StarsOn == nil and rule.Rank == nil then
		return true, "Always"
	end
	if rule.StarsOn and rule.Stars and HeistRecords.starsOn(records, rule.StarsOn) >= rule.Stars then
		return true, "Stars"
	end
	if rule.Rank and rank >= rule.Rank then
		return true, "Rank"
	end
	return false, nil
end

-- "3★ on The Golden Wheel or Rank 4" (nil for heists that are always open).
function HeistRecords.requirementText(
	heistId: string,
	rules: { [string]: UnlockRule },
	names: { [string]: string }
): string?
	local rule = rules[heistId]
	if not rule or (rule.StarsOn == nil and rule.Rank == nil) then
		return nil
	end
	local parts = {}
	if rule.StarsOn and rule.Stars then
		table.insert(parts, `{rule.Stars}★ on {names[rule.StarsOn] or rule.StarsOn}`)
	end
	if rule.Rank then
		table.insert(parts, `Rank {rule.Rank}`)
	end
	return table.concat(parts, " or ")
end

-- Which difficulty tiers this player has on a heist. Tiers without a rule come with the heist.
function HeistRecords.tiers(
	records: Records,
	heistId: string,
	tierOrder: { string },
	tierRules: { [string]: TierRule }
): { [string]: boolean }
	local result: { [string]: boolean } = {}
	for _, tier in tierOrder do
		local rule = tierRules[tier]
		result[tier] = rule == nil or HeistRecords.bestStars(records, heistId, rule.Tier) >= rule.Stars
	end
	return result
end

-- Records a finished round. Stars only count when this player escaped (1★ needs an escape anyway).
-- Returns the number of NEW stars (best stars only ever rise).
function HeistRecords.record(
	records: Records,
	heistId: string,
	tier: string,
	stars: number,
	escaped: boolean,
	vanLoot: number
): number
	local record = HeistRecords.get(records, heistId)
	if vanLoot > record.bestLoot then
		record.bestLoot = math.floor(vanLoot)
	end
	if not escaped then
		return 0
	end
	record.clears[tier] = (record.clears[tier] or 0) + 1
	local before = record.stars[tier] or 0
	local now = math.clamp(math.floor(stars), 0, 3)
	if now > before then
		record.stars[tier] = now
		return now - before
	end
	return 0
end

-- Cash for new stars: per star round-half-up(StarBonus × tier multiplier) (Easy 240, Normal 300, Hard 420).
function HeistRecords.starCash(newStars: number, starBonus: number, tierMultiplier: number): number
	return newStars * math.floor(starBonus * tierMultiplier + 0.5)
end

-- Reward masks earned and not owned yet: 3★ on `masteryTier` per heist, and the total-star masks.
function HeistRecords.rewardItems(
	records: Records,
	masteryMasks: { [string]: string },
	masteryTier: string,
	starMasks: { [number]: string },
	owned: { [string]: number }
): { string }
	local list: { string } = {}
	for heistId, itemId in masteryMasks do
		if HeistRecords.bestStars(records, heistId, masteryTier) >= 3 and not owned[itemId] then
			table.insert(list, itemId)
		end
	end
	local total = HeistRecords.totalStars(records)
	for needed, itemId in starMasks do
		if total >= needed and not owned[itemId] then
			table.insert(list, itemId)
		end
	end
	table.sort(list)
	return list
end

return HeistRecords
