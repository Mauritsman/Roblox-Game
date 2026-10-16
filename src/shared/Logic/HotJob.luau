--!strict
-- The rotating Hot Job: one heist + modifier per 30-minute slot, the same on every server.
-- The modifier is drawn first, so it never depends on which heists a server has open. Pure (rng passed in).

local HotJob = {}

export type RngLike = { int: (self: any, min: number, max: number) -> number }
export type Pick = { heistId: string?, modifierId: string }

function HotJob.seedFor(slot: number): number
	return (slot * 7919 + 104729) % 2147483647
end

-- heistId = the first open heist in a seeded order (never a locked one; nil if nothing is open).
function HotJob.pick(
	rng: RngLike,
	heistOrder: { string },
	open: { [string]: boolean },
	modifiers: { string }
): Pick
	local modifierId = modifiers[rng:int(1, #modifiers)]
	local order = table.clone(heistOrder)
	for i = #order, 2, -1 do
		local j = rng:int(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for _, heistId in order do
		if open[heistId] then
			return { heistId = heistId, modifierId = modifierId }
		end
	end
	return { heistId = nil, modifierId = modifierId }
end

return HotJob
