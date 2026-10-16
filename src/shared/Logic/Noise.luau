--!strict
-- How a guard reacts to a noise (beta-spec §3.2, §9.1). GuardService:HearNoise asks this module per guard.
--   noisemaker → Distract: walks over and ignores every other noise while distracted (the Crowbar window)
--   repeat     → LookAround: "Again?!", suspicious where he stands
--   everything else (crack, bzzt, thud, rumble, bark, sneeze, squeak, beep, splosh, …) → Investigate
-- Busy guards (Alert, Stunned, Carrying) and distracted guards ignore noises (a distracted guard still hears a new
-- Noisemaker).

local Noise = {}

export type Reaction = "Ignore" | "Investigate" | "LookAround" | "Distract"

-- Known kinds (unknown kinds are treated like a plain investigate noise).
Noise.KINDS = table.freeze({
	"noisemaker",
	"repeat",
	"crack",
	"bzzt",
	"thud",
	"rumble",
	"bark",
	"sneeze",
	"squeak",
	"beep",
	"splosh",
})

function Noise.reaction(kind: string?, distracted: boolean, busy: boolean): Reaction
	if busy then
		return "Ignore"
	elseif kind == "noisemaker" then
		return "Distract"
	elseif distracted then
		return "Ignore"
	elseif kind == "repeat" then
		return "LookAround"
	end
	return "Investigate"
end

-- Search time: the caller's value wins, else the kind's entry in `perKind` (Config.Guard.NoiseSearch), else `default`.
function Noise.searchSeconds(
	kind: string?,
	given: number?,
	perKind: { [string]: number }?,
	default: number
): number
	if given then
		return given
	end
	if kind and perKind and perKind[kind] then
		return perKind[kind]
	end
	return default
end

-- Indices of the `count` smallest distances (nearest first). Ties keep their original order.
-- Used for "the 2 nearest guards investigate" (snitches).
function Noise.nearest(distances: { number }, count: number): { number }
	local order = {}
	for index in distances do
		table.insert(order, index)
	end
	table.sort(order, function(a, b)
		if distances[a] ~= distances[b] then
			return distances[a] < distances[b]
		end
		return a < b
	end)
	local result = {}
	for i = 1, math.min(count, #order) do
		table.insert(result, order[i])
	end
	return result
end

return Noise
