--!strict
-- Small, deterministic random generator (LCG) that works in both Roblox and Lune.
-- Same seed → same round (handy for reproducing bugs).
local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { state: number }, Rng))

function Rng.new(seed: number): Rng
	return setmetatable({ state = math.floor(math.abs(seed)) % 2147483647 + 1 }, Rng)
end

-- Number in [0, 1).
function Rng.next(self: Rng): number
	self.state = (self.state * 48271) % 2147483647
	return (self.state - 1) / 2147483646
end

-- Integer in [min, max].
function Rng.int(self: Rng, min: number, max: number): number
	return min + math.floor(self:next() * (max - min + 1))
end

-- Random order (Fisher-Yates), returns a new list.
function Rng.shuffle<T>(self: Rng, list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = self:int(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- Pick one item by weight: { {item, weight}, ... }.
function Rng.weighted<T>(self: Rng, entries: { { any } }): T
	local total = 0
	for _, e in entries do
		total += e[2]
	end
	local roll = self:next() * total
	for _, e in entries do
		roll -= e[2]
		if roll < 0 then
			return e[1]
		end
	end
	return entries[#entries][1]
end

return Rng
