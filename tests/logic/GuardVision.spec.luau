--!nocheck
-- Guard vision cone (Logic/Detection.inViewCone) and the B-008 scenario: a masked player standing 6 studs in
-- front of a guard must fill his meter and make him Alert (eye 2.5 studs above the target point, as in the game).
local Detection = require("../../src/shared/Logic/Detection")
local Config = require("../../src/shared/Config")

local G = Config.Guard
local CONE = {
	halfAngle = G.ConeHalfAngle,
	range = G.RangeLit,
	maxPitch = G.ConeMaxPitch,
	verticalSlack = G.ConeVerticalSlack,
	overlap = G.ConeOverlap,
}
local EYE = G.HeadHeight -- eye above the guard's root; players are seen at their root (same height on one floor)

local function v(x, y, z)
	return { x = x, y = y, z = z }
end

local NORTH = v(0, 0, -1)

-- Old check (before B-008): a 3D cone with the vertical part halved.
local function oldCone(eye, forward, target, halfAngle)
	local dx, dy, dz = target.x - eye.x, target.y - eye.y, target.z - eye.z
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	local fx, fz = forward.x, forward.z
	local flen = math.sqrt(fx * fx + fz * fz)
	local ux, uy, uz = dx / len, dy / len * 0.5, dz / len
	local ulen = math.sqrt(ux * ux + uy * uy + uz * uz)
	return (ux * fx + uz * fz) / (ulen * flen) >= math.cos(math.rad(halfAngle))
end

return function(t)
	t.test("inViewCone: yaw cone on the ground plane, range", function()
		local eye = v(0, EYE, 0)
		t.ok(Detection.inViewCone(eye, NORTH, v(0, 0, -6), CONE))
		local a34, a36 = math.rad(34), math.rad(36)
		t.ok(Detection.inViewCone(eye, NORTH, v(math.sin(a34) * 10, 0, -math.cos(a34) * 10), CONE))
		t.ok(not Detection.inViewCone(eye, NORTH, v(math.sin(a36) * 10, 0, -math.cos(a36) * 10), CONE))
		t.ok(not Detection.inViewCone(eye, NORTH, v(0, 0, 6), CONE)) -- behind
		t.ok(not Detection.inViewCone(eye, NORTH, v(0, 0, -36), CONE)) -- too far
		t.ok(Detection.inViewCone(eye, v(0, 0.4, -5), v(0, 0, -10), CONE)) -- forward: only its yaw counts
		t.ok(not Detection.inViewCone(eye, v(0, 1, 0), v(0, 0, -10), CONE)) -- no heading
	end)

	t.test("B-008: a player right in front stays in view however close", function()
		local eye = v(0, EYE, 0)
		for _, d in { 6, 3, 2, 1.5, 1.2 } do
			t.ok(Detection.inViewCone(eye, NORTH, v(0, 0, -d), CONE), "in view at " .. d)
		end
		-- The old tilted cone lost him at 1.5 studs (and when the guard stood on top of him).
		t.ok(not oldCone(eye, NORTH, v(0, 0, -1.5), G.ConeHalfAngle))
		t.ok(not oldCone(v(0, 6.96 + EYE, 0), NORTH, v(0.3, 2.9, -0.1), G.ConeHalfAngle))
		-- Crouching (root ~1 stud lower) close by is still in view.
		t.ok(Detection.inViewCone(eye, NORTH, v(0, -1, -1.5), CONE))
	end)

	t.test("close behind the guard stays unseen (pickpocket), overlapping is seen", function()
		local eye = v(0, EYE, 0)
		t.ok(not Detection.inViewCone(eye, NORTH, v(0, 0, 1.5), CONE))
		t.ok(not Detection.inViewCone(eye, NORTH, v(1.5, 0, 0.5), CONE))
		t.ok(Detection.inViewCone(eye, NORTH, v(0.5, 0, 0.5), CONE)) -- inside him (no collision since B-007)
	end)

	t.test("other floors: within the pitch limit only", function()
		local eye = v(0, EYE, 0)
		-- Upper floor (y 9, root y 12) 10 studs ahead: 36° up.
		t.ok(Detection.inViewCone(eye, NORTH, v(0, 12, -10), CONE))
		-- Straight above or below at close range: no.
		t.ok(not Detection.inViewCone(eye, NORTH, v(0, 12, -3), CONE))
		t.ok(not Detection.inViewCone(eye, NORTH, v(0, -8, -2), CONE))
		t.ok(not Detection.inViewCone(eye, NORTH, v(0, 12, -0.2), CONE)) -- overlap needs the same floor
	end)

	t.test("B-008: masked player 6 studs in front → Alert within ~1.3 s (lit or dark)", function()
		local rates = {
			CrouchFillRate = G.CrouchFillRate,
			CarryFillRate = G.CarryFillRate,
			LockdownFillRate = G.LockdownFillRate,
			SleepyFillRate = Config.Modifiers.SleepyGuards.FillRate,
		}
		local factors = Detection.factorsFor({}, rates)
		for _, range in { G.RangeLit, G.RangeDark } do
			-- Guard at the origin facing north, player 6 studs ahead. From the Suspicious meter on he walks
			-- towards the player at InvestigateSpeed, stops 3 studs away and keeps facing him (the stare; before
			-- the fix he spun on the spot at 70°/s once he arrived).
			local guardZ, meter, elapsed = 0, 0, 0
			local dt = G.VisionInterval
			while meter < 1 and elapsed < 3 do
				elapsed += dt
				local eye = v(0, EYE, guardZ)
				local forward = NORTH
				local target = v(0, 0, -6)
				local cone = table.clone(CONE)
				cone.range = range
				if Detection.inViewCone(eye, forward, target, cone) then
					local dz = target.z - eye.z
					local distance = math.sqrt(EYE * EYE + dz * dz)
					meter = math.min(1, meter + dt * Detection.fillRate(distance, range, factors))
				else
					meter = math.max(0, meter - G.DecayPerSecond * dt)
				end
				if meter >= G.SuspiciousAt then
					guardZ = math.max(-3, guardZ - G.InvestigateSpeed * dt)
				end
			end
			t.ok(meter >= 1, "meter full")
			t.ok(elapsed <= 1.3, string.format("Alert after %.1f s (range %d)", elapsed, range))
		end
	end)
end
