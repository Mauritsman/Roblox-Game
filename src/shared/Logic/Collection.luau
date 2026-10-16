--!strict
-- Collection book (times banked per loot type, pages per heist) and the trophy log. Pure.

local Collection = {}

export type Banked = { lootId: string }
export type Trophy = { loot: string, heist: string, tier: string, crew: number, at: number }

-- Every loot id that appears on any page (keycards and other non-collectables are ignored).
function Collection.tracked(pages: { [string]: { string } }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, page in pages do
		for _, lootId in page do
			set[lootId] = true
		end
	end
	return set
end

-- Counts banked loot. Returns the loot ids collected for the first time.
function Collection.record(
	collection: { [string]: number },
	banked: { Banked },
	tracked: { [string]: boolean }
): { string }
	local new: { string } = {}
	for _, item in banked do
		local id = item.lootId
		if type(id) == "string" and tracked[id] then
			if not collection[id] then
				table.insert(new, id)
			end
			collection[id] = (collection[id] or 0) + 1
		end
	end
	return new
end

function Collection.pageComplete(collection: { [string]: number }, page: { string }): boolean
	if #page == 0 then
		return false
	end
	for _, lootId in page do
		if not collection[lootId] then
			return false
		end
	end
	return true
end

-- Complete pages whose reward has not been given yet (sorted, so results are stable).
function Collection.newPages(
	collection: { [string]: number },
	pages: { [string]: { string } },
	rewarded: { [string]: number }
): { string }
	local list: { string } = {}
	for pageId, page in pages do
		if not rewarded[pageId] and Collection.pageComplete(collection, page) then
			table.insert(list, pageId)
		end
	end
	table.sort(list)
	return list
end

-- Appends a trophy and keeps the newest `max`.
function Collection.pushTrophy(trophies: { Trophy }, trophy: Trophy, max: number)
	table.insert(trophies, trophy)
	while #trophies > max do
		table.remove(trophies, 1)
	end
end

return Collection
