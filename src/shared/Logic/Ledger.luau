--!strict
-- Idempotency helpers: Robux receipts (each PurchaseId granted once) and settled rounds (each roundId paid once).
-- Pure.

local Ledger = {}

export type ReceiptAction = "NotProcessedYet" | "AlreadyGranted" | "Grant"
export type ReceiptState = {
	playerPresent: boolean,
	dataLoaded: boolean,
	alreadyProcessed: boolean,
	productKnown: boolean,
	productEnabled: boolean,
}

-- ProcessReceipt decision (docs/beta-spec-meta.md §7.1). "AlreadyGranted" still needs a saved profile before
-- the caller answers PurchaseGranted.
function Ledger.decideReceipt(state: ReceiptState): ReceiptAction
	if not state.playerPresent or not state.dataLoaded then
		return "NotProcessedYet"
	end
	if state.alreadyProcessed then
		return "AlreadyGranted"
	end
	if not state.productKnown or not state.productEnabled then
		return "NotProcessedYet"
	end
	return "Grant"
end

-- Records a receipt and keeps the newest `max` (oldest by time are dropped first).
function Ledger.recordReceipt(receipts: { [string]: number }, purchaseId: string, now: number, max: number)
	receipts[purchaseId] = now
	local count = 0
	for _ in receipts do
		count += 1
	end
	while count > max do
		local oldestId: string? = nil
		local oldestAt = math.huge
		for id, at in receipts do
			if at < oldestAt or (at == oldestAt and oldestId ~= nil and id < oldestId) then
				oldestId, oldestAt = id, at
			end
		end
		if oldestId == nil or oldestId == purchaseId then
			break
		end
		receipts[oldestId] = nil
		count -= 1
	end
end

function Ledger.contains(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

-- Appends `value` (newest last) and keeps the newest `max`.
function Ledger.push(list: { string }, value: string, max: number)
	table.insert(list, value)
	while #list > max do
		table.remove(list, 1)
	end
end

return Ledger
