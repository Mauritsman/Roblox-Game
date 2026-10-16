--!strict
-- 3×3 perk tree rules: unlock (row above first, enough points), equip (max 3, unlocked only), free respec.
-- Points are derived: available = skill points − sum of unlocked costs (never stored). Pure.

local PerkTree = {}

export type Tree = {
	BranchOrder: { string },
	Branches: { [string]: { string } },
	RowCost: { number },
	MaxEquipped: number,
}
export type Perks = { unlocked: { [string]: boolean }, equipped: { string }, respecs: number }

-- Branch and row (1–3) of a perk, or nil for unknown ids.
function PerkTree.find(tree: Tree, perkId: string): (string?, number?)
	for branch, list in tree.Branches do
		for row, id in list do
			if id == perkId then
				return branch, row
			end
		end
	end
	return nil, nil
end

function PerkTree.cost(tree: Tree, perkId: string): number
	local _, row = PerkTree.find(tree, perkId)
	return if row then tree.RowCost[row] or 0 else 0
end

function PerkTree.spent(tree: Tree, unlocked: { [string]: boolean }): number
	local total = 0
	for perkId, on in unlocked do
		if on then
			total += PerkTree.cost(tree, perkId)
		end
	end
	return total
end

function PerkTree.available(tree: Tree, unlocked: { [string]: boolean }, skillPoints: number): number
	return skillPoints - PerkTree.spent(tree, unlocked)
end

-- Reasons: "Unknown", "Owned", "Locked" (row above not unlocked), "NoPoints".
function PerkTree.canUnlock(tree: Tree, perks: Perks, perkId: string, skillPoints: number): (boolean, string?)
	local branch, row = PerkTree.find(tree, perkId)
	if not branch or not row then
		return false, "Unknown"
	end
	if perks.unlocked[perkId] then
		return false, "Owned"
	end
	if row > 1 then
		local above = tree.Branches[branch][row - 1]
		if not perks.unlocked[above] then
			return false, "Locked"
		end
	end
	if PerkTree.available(tree, perks.unlocked, skillPoints) < (tree.RowCost[row] or math.huge) then
		return false, "NoPoints"
	end
	return true, nil
end

function PerkTree.unlock(tree: Tree, perks: Perks, perkId: string, skillPoints: number): (boolean, string?)
	local ok, reason = PerkTree.canUnlock(tree, perks, perkId, skillPoints)
	if ok then
		perks.unlocked[perkId] = true
	end
	return ok, reason
end

-- Validates an equip list from the client. Reasons: "Invalid", "TooMany", "Unknown", "NotOwned", "Duplicate".
function PerkTree.validateEquip(tree: Tree, perks: Perks, list: any): (boolean, string?, { string }?)
	if type(list) ~= "table" then
		return false, "Invalid", nil
	end
	local count = 0
	for _ in list do
		count += 1
	end
	if count ~= #list then
		return false, "Invalid", nil
	end
	if #list > tree.MaxEquipped then
		return false, "TooMany", nil
	end
	local seen: { [string]: boolean } = {}
	local clean: { string } = {}
	for _, perkId in list do
		if type(perkId) ~= "string" or not PerkTree.find(tree, perkId) then
			return false, "Unknown", nil
		end
		if not perks.unlocked[perkId] then
			return false, "NotOwned", nil
		end
		if seen[perkId] then
			return false, "Duplicate", nil
		end
		seen[perkId] = true
		table.insert(clean, perkId)
	end
	return true, nil, clean
end

-- Free respec: everything back. Returns the refunded points.
function PerkTree.respec(tree: Tree, perks: Perks): number
	local refunded = PerkTree.spent(tree, perks.unlocked)
	perks.unlocked = {}
	perks.equipped = {}
	perks.respecs += 1
	return refunded
end

-- Repairs stored perks after a config change: unknown ids dropped, equipped ⊆ unlocked (max N),
-- and a full respec when more points are spent than the player has. Returns true if something changed.
function PerkTree.repair(tree: Tree, perks: Perks, skillPoints: number): boolean
	local changed = false
	for perkId in perks.unlocked do
		if not PerkTree.find(tree, perkId) then
			perks.unlocked[perkId] = nil
			changed = true
		end
	end
	if PerkTree.spent(tree, perks.unlocked) > skillPoints then
		perks.unlocked = {}
		perks.equipped = {}
		return true
	end
	local kept: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, perkId in perks.equipped do
		if perks.unlocked[perkId] and not seen[perkId] and #kept < tree.MaxEquipped then
			seen[perkId] = true
			table.insert(kept, perkId)
		else
			changed = true
		end
	end
	perks.equipped = kept
	return changed
end

-- {perkId = 1} for every equipped perk (what mechanics' Logic/Perks.apply expects).
function PerkTree.equippedSet(perks: Perks): { [string]: number }
	local set: { [string]: number } = {}
	for _, perkId in perks.equipped do
		if perks.unlocked[perkId] then
			set[perkId] = 1
		end
	end
	return set
end

return PerkTree
