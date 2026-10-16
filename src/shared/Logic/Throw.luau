--!strict
-- Throwing medium loot (beta-spec §2.3). Server (CarryService) and client (aim arc) use the same maths.
-- Positions are plain tables {x, y, z} (convert a Vector3 with {x = v.X, y = v.Y, z = v.Z}).
--   * the target is clamped to `maxRange` studs from the hands (3D, so you cannot throw onto high roofs)
--   * duration = distance / speed, clamped to [min, max] seconds (0.3–0.8)
--   * arc height = arc × distance, at least `minHeight` (35%, min 2), highest halfway

local Throw = {}

export type Vec3 = { x: number, y: number, z: number }

export type Catch = {
	CatchFlight: number, -- radius while the loot flies
	CatchLanding: number, -- radius when it lands
	SelfCatchDelay: number, -- the thrower cannot catch their own throw this soon
}

function Throw.distance(a: Vec3, b: Vec3): number
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Returns (target, clamped). A target further than maxRange is pulled back along the same direction.
function Throw.clampTarget(origin: Vec3, target: Vec3, maxRange: number): (Vec3, boolean)
	local distance = Throw.distance(origin, target)
	if distance <= maxRange then
		return { x = target.x, y = target.y, z = target.z }, false
	end
	local scale = maxRange / distance
	return {
		x = origin.x + (target.x - origin.x) * scale,
		y = origin.y + (target.y - origin.y) * scale,
		z = origin.z + (target.z - origin.z) * scale,
	},
		true
end

-- Flight time in seconds.
function Throw.timing(distance: number, speed: number, minSeconds: number, maxSeconds: number): number
	if speed <= 0 then
		return maxSeconds
	end
	return math.clamp(distance / speed, minSeconds, maxSeconds)
end

-- Arc height above the straight line between hands and target.
function Throw.height(distance: number, arc: number, minHeight: number): number
	return math.max(minHeight, distance * arc)
end

-- Position at alpha (0 = hands, 1 = target) on a parabola that peaks `height` above the midpoint.
function Throw.point(origin: Vec3, target: Vec3, alpha: number, height: number): Vec3
	local a = math.clamp(alpha, 0, 1)
	local lift = 4 * height * a * (1 - a)
	return {
		x = origin.x + (target.x - origin.x) * a,
		y = origin.y + (target.y - origin.y) * a + lift,
		z = origin.z + (target.z - origin.z) * a,
	}
end

-- Can a free player with empty hands catch it? `elapsed` = seconds since the throw.
function Throw.canCatch(
	distance: number,
	elapsed: number,
	isThrower: boolean,
	landed: boolean,
	rules: Catch
): boolean
	if isThrower and elapsed < rules.SelfCatchDelay then
		return false
	end
	local radius = if landed then rules.CatchLanding else rules.CatchFlight
	return distance <= radius
end

return Throw
