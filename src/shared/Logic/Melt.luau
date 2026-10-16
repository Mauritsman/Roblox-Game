--!strict
-- Melting loot (Praline Palace, beta-spec-maps §7; advisor-maps "Stakes, melting"): chocolate outside a ColdZone loses
-- ratePerSecond × base value per second, never below minFactor × base (50%). It starts once the item has left its
-- display (lifted, dropped, riding a car); Karel putting it back home stops it. The loss is applied in whole Cash
-- steps: fractions are carried over in `pending`, so cheap items melt as steadily as the Golden Praline.

local Melt = {}

export type View = {
	melts: boolean, -- the loot type melts (Config.Loot.Types[...].Melts)
	state: string, -- LootState
	inCold: boolean, -- inside a ColdZone (the vault, the Cold Room, the van's / barge's cold box)
	moved: boolean, -- away from its home anchor
}

function Melt.melting(view: View): boolean
	if not view.melts or view.inCold or view.state == "Banked" then
		return false
	end
	return view.moved or view.state ~= "Placed"
end

-- The lowest value melting may reach.
function Melt.floor(base: number, minFactor: number): number
	return math.ceil(base * minFactor - 1e-9)
end

-- Whole Cash lost this tick and the new pending fraction. `value` is the item's current value (fragile drops may
-- already have lowered it); melting stops at Melt.floor.
function Melt.step(
	pending: number,
	value: number,
	base: number,
	dt: number,
	rate: number,
	minFactor: number
): (number, number)
	local floor = Melt.floor(base, minFactor)
	if base <= 0 or rate <= 0 or dt <= 0 or value <= floor then
		return 0, 0
	end
	local total = pending + base * rate * dt
	local loss = math.floor(total + 1e-9)
	if loss >= value - floor then
		return value - floor, 0
	end
	return loss, total - loss
end

return Melt
