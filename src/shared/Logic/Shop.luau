--!strict
-- Shop rules: ownership, buying, equipping cosmetics and the 2-gadget loadout. Pure.
-- Items have the Catalog shape (Id, Kind, Price?, MinRank, Free?). Clients only ever send ids.

local Shop = {}

export type Item = { Id: string, Kind: string, Price: number?, MinRank: number, Free: boolean? }
export type Owned = { owned: { [string]: number }, robuxOwned: { [string]: number }, rank: number }

function Shop.owns(item: Item, who: Owned): boolean
	if item.Free and who.rank >= item.MinRank then
		return true
	end
	return who.owned[item.Id] ~= nil or who.robuxOwned[item.Id] ~= nil
end

local function slotOpen(item: Item, who: Owned, slotRank: { [string]: number }): boolean
	return who.rank >= (slotRank[item.Kind] or 1)
end

-- Reasons: "Unknown", "NotForSale", "Owned", "Locked", "NotEnoughCash".
function Shop.canBuy(
	item: Item?,
	who: Owned,
	cash: number,
	slotRank: { [string]: number }
): (boolean, string?)
	if not item then
		return false, "Unknown"
	end
	if item.Price == nil then
		return false, "NotForSale"
	end
	if Shop.owns(item, who) then
		return false, "Owned"
	end
	if who.rank < item.MinRank or not slotOpen(item, who, slotRank) then
		return false, "Locked"
	end
	if cash < (item.Price :: number) then
		return false, "NotEnoughCash"
	end
	return true, nil
end

-- Cosmetics only (Mask / Hat / Van). Reasons: "Unknown", "Locked", "NotOwned".
function Shop.canEquip(item: Item?, who: Owned, slotRank: { [string]: number }): (boolean, string?)
	if not item or (item.Kind ~= "Mask" and item.Kind ~= "Hat" and item.Kind ~= "Van") then
		return false, "Unknown"
	end
	if not slotOpen(item, who, slotRank) then
		return false, "Locked"
	end
	if not Shop.owns(item, who) then
		return false, "NotOwned"
	end
	return true, nil
end

-- Applies an equip. Equipping the hat you wear takes it off; masks and vans only swap.
-- Returns the id now worn in that slot (nil = no hat).
function Shop.equip(equipped: { [string]: string }, item: Item): string?
	if item.Kind == "Hat" and equipped.Hat == item.Id then
		(equipped :: any).Hat = nil
		return nil
	end
	equipped[item.Kind] = item.Id
	return item.Id
end

-- Validates a loadout request: `slots` distinct gadget ids, owned (or free), available in this build
-- (mechanics' Config.Gadgets), never the Crowbar. Reasons: "Invalid", "TooMany", "Unknown", "Duplicate", "NotOwned".
function Shop.validateLoadout(
	picks: any,
	items: { [string]: Item },
	who: Owned,
	available: { [string]: boolean },
	slots: number
): (boolean, string?, { string }?)
	if type(picks) ~= "table" then
		return false, "Invalid", nil
	end
	local count = 0
	for _ in picks do
		count += 1
	end
	if count ~= #picks then
		return false, "Invalid", nil
	end
	if #picks ~= slots then
		return false, if #picks > slots then "TooMany" else "Invalid", nil
	end
	local seen: { [string]: boolean } = {}
	local clean: { string } = {}
	for _, id in picks do
		local item = if type(id) == "string" then items[id] else nil
		if not item or item.Kind ~= "Gadget" or not available[item.Id] then
			return false, "Unknown", nil
		end
		if seen[item.Id] then
			return false, "Duplicate", nil
		end
		if not Shop.owns(item, who) then
			return false, "NotOwned", nil
		end
		seen[item.Id] = true
		table.insert(clean, item.Id)
	end
	return true, nil, clean
end

-- A stored loadout that is still valid, or the default (e.g. a gadget was removed from the game).
function Shop.sanitizeLoadout(
	loadout: { string },
	items: { [string]: Item },
	who: Owned,
	available: { [string]: boolean },
	default: { string }
): { string }
	local ok, _, clean = Shop.validateLoadout(loadout, items, who, available, #default)
	if ok and clean then
		return clean
	end
	return table.clone(default)
end

return Shop
