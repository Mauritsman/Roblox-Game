--!strict
-- Guard routes (beta-spec §3.2, §9.7). RoundPlan picks a route, a variant, a start waypoint and waits per
-- waypoint; this module turns that into the list a guard walks. Positions are left as they are (Vector3 in the
-- game, plain tables in tests): only their `Y` / `y` matters here.
--   * A route is a loop: after the last waypoint comes the first.
--   * A leg whose two ends differ more than `floorStep` in height changes floor and uses pathfinding;
--     other legs are straight MoveTo (contracts §3: upper floors at y 9).

local Patrol = {}

export type Waypoint = { Pos: any?, Wait: number? }
export type RouteInfo = { Id: string, Priority: number?, Variants: { { Waypoint } } }
export type Step = { pos: any, wait: number }

-- Finds a route's variant (variant numbers outside the list fall back to the first variant).
function Patrol.variant(routes: { RouteInfo }?, routeId: string?, variant: number?): { Waypoint }?
	if routes == nil or routeId == nil then
		return nil
	end
	for _, route in routes do
		if route.Id == routeId then
			local list = route.Variants[variant or 1] or route.Variants[1]
			return list
		end
	end
	return nil
end

-- Steps from a variant with the plan's waits (missing waits = the waypoint's own Wait, else 0).
function Patrol.steps(points: { Waypoint }, waits: { number }?): { Step }
	local steps = {}
	for index, point in points do
		if point.Pos ~= nil then
			local wait = if waits and waits[index] then waits[index] else (point.Wait or 0)
			table.insert(steps, { pos = point.Pos, wait = math.max(0, wait) })
		end
	end
	return steps
end

-- Steps from a plain list of positions (the old `Points.GuardRoute`), no waits.
function Patrol.fromPositions(positions: { any }): { Step }
	local steps = {}
	for _, pos in positions do
		table.insert(steps, { pos = pos, wait = 0 })
	end
	return steps
end

function Patrol.nextIndex(index: number, count: number): number
	if count <= 0 then
		return 1
	end
	return index % count + 1
end

-- A valid start index for `count` waypoints (1 when out of range).
function Patrol.startIndex(start: number?, count: number): number
	if start == nil or count <= 0 or start < 1 or start > count then
		return 1
	end
	return math.floor(start)
end

-- Fallback route shared by several guards: spread their start waypoints evenly over the loop.
function Patrol.spreadStart(guardIndex: number, guardCount: number, count: number): number
	if count <= 0 or guardCount <= 0 then
		return 1
	end
	local step = count / guardCount
	return math.floor((guardIndex - 1) * step) % count + 1
end

local function heightOf(pos: any): number
	if type(pos) == "table" then
		return pos.y or pos.Y or 0
	end
	return pos.Y
end

-- Does the leg from `a` to `b` change floor?
function Patrol.changesFloor(a: any, b: any, floorStep: number): boolean
	return math.abs(heightOf(a) - heightOf(b)) > floorStep
end

-- Has a walker at floor height `walkerFloorY` reached waypoint `pos`? `flatDistance` = horizontal distance.
function Patrol.arrived(
	flatDistance: number,
	walkerFloorY: number,
	pos: any,
	range: number,
	floorStep: number
): boolean
	return flatDistance <= range and math.abs(walkerFloorY - heightOf(pos)) <= floorStep
end

return Patrol
