--!strict
-- Who may pick up what, pockets, and loot value changes (beta-spec §2). Used by LootService/CarryService.
--   * Small loot goes in the pocket (max PocketSlots, perks can raise it); hands may be full.
--   * Medium (and rare) loot needs empty hands: "Grab". Heavy/main loot: "Lift".
--   * Heavy/main loot carried by ONE other player within range: "Help" (two-player carry).
--   * Loot must be Placed, Dropped or Returning (Karel carrying it back: you may snatch it).
-- Results: (true, action) with action "Pocket" | "Grab" | "Lift" | "Help", or (false, reason) with reason
-- "NotFree" | "WrongSession" | "TooSlow" | "InFlight" | "Gone" | "PocketFull" | "HandsFull" | "TooFar".

local LootRules = {}

LootRules.ActionText = table.freeze({
	Pocket = "Pocket",
	Grab = "Grab",
	Lift = "Lift",
	Help = "Help carry",
})

export type Picker = {
	userId: number,
	free: boolean, -- not caught, hidden, frozen or slipping
	session: string,
	handsClass: string?, -- class held in the hands: "Medium" | "Heavy" | "Main" | nil
	pocketCount: number,
	pocketSlots: number, -- from StatsOf
}

export type LootView = {
	state: string, -- LootState: "Placed" | "Carried" | "Thrown" | "Dropped" | "Returning" | "Banked"
	class: string, -- "Small" | "Medium" | "Heavy" | "Main"
	session: string,
	carrierId: number?,
	helperId: number?,
	carrierDistance: number?, -- from the picker to the current carrier
}

local function isHeavy(class: string): boolean
	return class == "Heavy" or class == "Main"
end

function LootRules.canPick(picker: Picker, loot: LootView, helpRange: number): (boolean, string)
	if not picker.free then
		return false, "NotFree"
	elseif picker.session ~= loot.session then
		return false, "WrongSession"
	end

	local state = loot.state
	if state == "Banked" then
		return false, "Gone"
	elseif state == "Thrown" then
		return false, "InFlight"
	elseif state == "Carried" then
		if not isHeavy(loot.class) or loot.helperId ~= nil or loot.carrierId == picker.userId then
			return false, "TooSlow"
		elseif picker.handsClass ~= nil then
			return false, "HandsFull"
		elseif (loot.carrierDistance or math.huge) > helpRange then
			return false, "TooFar"
		end
		return true, "Help"
	elseif state ~= "Placed" and state ~= "Dropped" and state ~= "Returning" then
		return false, "Gone"
	end

	if loot.class == "Small" then
		if picker.pocketCount >= picker.pocketSlots then
			return false, "PocketFull"
		end
		return true, "Pocket"
	elseif picker.handsClass ~= nil then
		return false, "HandsFull"
	elseif isHeavy(loot.class) then
		return true, "Lift"
	end
	return true, "Grab"
end

-- Returns (new pocket, added). The pocket list is not changed.
function LootRules.pocketAdd(pocket: { string }, item: string, slots: number): ({ string }, boolean)
	if #pocket >= slots then
		return table.clone(pocket), false
	end
	local copy = table.clone(pocket)
	table.insert(copy, item)
	return copy, true
end

-- Returns (new pocket, removed). Removes the first match.
function LootRules.pocketRemove(pocket: { string }, item: string): ({ string }, boolean)
	local copy = table.clone(pocket)
	local index = table.find(copy, item)
	if index then
		table.remove(copy, index)
		return copy, true
	end
	return copy, false
end

local function roundHalfUp(x: number): number
	return math.floor(x + 0.5)
end

-- Fragile loot: loses `penalty` × base per uncaught landing, never below minFactor × base.
function LootRules.fragileValue(
	baseValue: number,
	landings: number,
	penalty: number,
	minFactor: number
): number
	local factor = math.max(minFactor, 1 - penalty * math.max(0, landings))
	return roundHalfUp(baseValue * factor)
end

-- Melting loot (maps 2–3): loses ratePerSecond × base per second outside a cold zone, never below minFactor.
function LootRules.meltedValue(
	baseValue: number,
	warmSeconds: number,
	ratePerSecond: number,
	minFactor: number
): number
	local factor = math.max(minFactor, 1 - ratePerSecond * math.max(0, warmSeconds))
	return roundHalfUp(baseValue * factor)
end

-- Loot banks only in a BankZone of its own session; Practice loot never banks.
function LootRules.canBank(lootSession: string, zoneSession: string): boolean
	return lootSession == zoneSession and lootSession ~= "Practice"
end

-- Two-player carry: the helper loses grip when the carriers are further apart than `tether`.
function LootRules.gripLost(distance: number, tether: number): boolean
	return distance > tether
end

-- Anti-teleport: the carrier's root moved more than `maxStuds` in one check (0.5 s).
function LootRules.teleported(distance: number, maxStuds: number): boolean
	return distance > maxStuds
end

return LootRules
