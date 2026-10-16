--!strict
-- Fixed paths for rides (beta-spec-maps §3, §7–8): the Praline Box Rail, the Tulip trolley train, chutes and vents.
-- Cars never use free physics: the server (and, for smoothing, the client) puts each car at `pointAt(path, s)`,
-- where `s` is the distance travelled along the path in studs. Positions are plain {x, y, z} tables.
--   * A path is a polyline. It is a loop when asked, or when its last point is (almost) its first point.
--   * Loops wrap `s` around; open paths clamp it to [0, length].
--   * A car's distance is `s0 + rate × (now − t0)` (rate in studs per second, may be negative on open paths), so
--     server and client compute the same position from three replicated numbers.

local RidePath = {}

export type Vec = { x: number, y: number, z: number }

export type Path = {
	points: { Vec },
	cum: { number }, -- cum[i] = distance from points[1] to points[i]; loops have cum[#points + 1] = length
	length: number,
	loop: boolean,
}

RidePath.CLOSE = 0.5 -- last point this close to the first = a loop

local function vec(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end

local function sub(a: Vec, b: Vec): Vec
	return vec(a.x - b.x, a.y - b.y, a.z - b.z)
end

local function magnitude(v: Vec): number
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

local function unit(v: Vec): Vec
	local m = magnitude(v)
	if m < 1e-9 then
		return vec(0, 0, -1)
	end
	return vec(v.x / m, v.y / m, v.z / m)
end

local function lerp(a: Vec, b: Vec, t: number): Vec
	return vec(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
end

-- Builds a path from points (copied). Consecutive duplicates are dropped. `loop` nil = automatic (closed shape).
function RidePath.build(points: { Vec }, loop: boolean?): Path
	local list: { Vec } = {}
	for _, p in points do
		local last = list[#list]
		if last == nil or magnitude(sub(p, last)) > 1e-6 then
			table.insert(list, vec(p.x, p.y, p.z))
		end
	end
	local closed = #list >= 3 and magnitude(sub(list[#list], list[1])) <= RidePath.CLOSE
	if closed then
		table.remove(list) -- the closing point is the first point again
	end
	local isLoop = if loop == nil then closed else loop
	if #list < 2 then
		isLoop = false
	end
	local cum = { 0 }
	for i = 2, #list do
		cum[i] = cum[i - 1] + magnitude(sub(list[i], list[i - 1]))
	end
	local length = cum[#list] or 0
	if isLoop then
		length += magnitude(sub(list[1], list[#list]))
		cum[#list + 1] = length
	end
	return { points = list, cum = cum, length = length, loop = isLoop }
end

-- `s` folded into the path: wrapped on loops, clamped on open paths.
function RidePath.wrap(path: Path, s: number): number
	if path.length <= 0 then
		return 0
	end
	if path.loop then
		return s % path.length
	end
	return math.clamp(s, 0, path.length)
end

-- The segment that holds distance `s` (already wrapped): index i of points[i] → points[i + 1] (or → points[1]).
local function segmentAt(path: Path, s: number): number
	local count = if path.loop then #path.points else #path.points - 1
	local low, high = 1, math.max(1, count)
	while low < high do
		local mid = (low + high + 1) // 2
		if path.cum[mid] <= s then
			low = mid
		else
			high = mid - 1
		end
	end
	return low
end

local function segmentEnds(path: Path, i: number): (Vec, Vec)
	local a = path.points[i]
	local b = path.points[i + 1] or path.points[1]
	return a, b
end

-- Position and travel direction (unit) at distance `s`.
function RidePath.pointAt(path: Path, s: number): (Vec, Vec)
	local count = #path.points
	if count == 0 then
		return vec(0, 0, 0), vec(0, 0, -1)
	elseif count == 1 or path.length <= 0 then
		return vec(path.points[1].x, path.points[1].y, path.points[1].z), vec(0, 0, -1)
	end
	local w = RidePath.wrap(path, s)
	local i = segmentAt(path, w)
	local a, b = segmentEnds(path, i)
	local segLength = magnitude(sub(b, a))
	local t = if segLength > 1e-9 then (w - path.cum[i]) / segLength else 0
	return lerp(a, b, math.clamp(t, 0, 1)), unit(sub(b, a))
end

-- Travel direction at `s`, blended over `blend` studs around corners so cars turn smoothly.
function RidePath.heading(path: Path, s: number, blend: number): Vec
	local _, dir = RidePath.pointAt(path, s)
	if blend <= 0 or #path.points < 3 then
		return dir
	end
	local before = select(2, RidePath.pointAt(path, s - blend))
	local after = select(2, RidePath.pointAt(path, s + blend))
	if not path.loop then
		if s - blend < 0 then
			before = dir
		end
		if s + blend > path.length then
			after = dir
		end
	end
	return unit(
		vec(before.x + 2 * dir.x + after.x, before.y + 2 * dir.y + after.y, before.z + 2 * dir.z + after.z)
	)
end

-- Distance along the path of the point closest to `p`, and how far `p` is from it.
function RidePath.project(path: Path, p: Vec): (number, number)
	local count = #path.points
	if count == 0 then
		return 0, math.huge
	elseif count == 1 then
		return 0, magnitude(sub(p, path.points[1]))
	end
	local bestS, bestD = 0, math.huge
	local segments = if path.loop then count else count - 1
	for i = 1, segments do
		local a, b = segmentEnds(path, i)
		local ab = sub(b, a)
		local len2 = ab.x * ab.x + ab.y * ab.y + ab.z * ab.z
		local t = 0
		if len2 > 1e-12 then
			local ap = sub(p, a)
			t = math.clamp((ap.x * ab.x + ap.y * ab.y + ap.z * ab.z) / len2, 0, 1)
		end
		local d = magnitude(sub(p, lerp(a, b, t)))
		if d < bestD then
			bestD = d
			bestS = path.cum[i] + t * math.sqrt(len2)
		end
	end
	return bestS, bestD
end

-- Forward distance from `from` to `to` (wrapped on loops; may be negative on open paths).
function RidePath.forward(path: Path, from: number, to: number): number
	if path.loop and path.length > 0 then
		return (to - from) % path.length
	end
	return to - from
end

-- Did a car moving from `sFrom` by `travel` studs (≥ 0 forward, < 0 backward on open paths) pass `mark`?
-- Starting exactly on the mark does not count (the car was handled there already); ending on it does.
function RidePath.crossed(path: Path, sFrom: number, travel: number, mark: number): boolean
	if travel == 0 then
		return false
	end
	if path.loop then
		if travel < 0 or path.length <= 0 then
			return false
		end
		if travel >= path.length then
			return true
		end
		local d = RidePath.forward(path, RidePath.wrap(path, sFrom), RidePath.wrap(path, mark))
		return d > 1e-9 and d <= travel + 1e-9
	end
	local d = mark - sFrom
	if travel > 0 then
		return d > 1e-9 and d <= travel + 1e-9
	end
	return d < -1e-9 and d >= travel - 1e-9
end

-- A car's distance at `now` from its last anchor (s0 at t0, moving at rate).
function RidePath.distanceAt(s0: number, rate: number, t0: number, now: number): number
	return s0 + rate * (now - t0)
end

-- Points → "x,y,z;x,y,z" (3 decimals), for replicating a path to clients in one attribute.
function RidePath.serialize(points: { Vec }): string
	local parts = table.create(#points)
	for i, p in points do
		parts[i] = string.format("%.3f,%.3f,%.3f", p.x, p.y, p.z)
	end
	return table.concat(parts, ";")
end

-- The reverse of serialize; malformed entries are skipped.
function RidePath.parse(text: string): { Vec }
	local list: { Vec } = {}
	for entry in string.gmatch(text, "[^;]+") do
		local x, y, z = string.match(entry, "^%s*([%-%d%.eE]+),([%-%d%.eE]+),([%-%d%.eE]+)%s*$")
		local nx, ny, nz = tonumber(x), tonumber(y), tonumber(z)
		if nx and ny and nz then
			table.insert(list, vec(nx, ny, nz))
		end
	end
	return list
end

return RidePath
