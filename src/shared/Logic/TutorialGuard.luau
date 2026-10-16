--!strict
-- The mini-job's sleeping guard (beta-spec §1.6 and §13, ux §3.1). He is not a real guard and can never catch
-- anyone:
--   * asleep ("Zzz"): a player who is not crouching within StirRadius makes him stir ("Hmm?") → hint "Crouch!"
--   * lockdown: he gets up and follows at GuardChaseSpeed (10; a rolled Gouda at 11 slowly pulls away). He never
--     comes closer than GuardTripDistance (4): when the player stops, he trips over his own feet just short.
-- Pure maths on distances; TutorialService moves the model.

local TutorialGuard = {}

export type Rules = {
	stirRadius: number,
	wakeRange: number,
	chaseSpeed: number,
	tripDistance: number,
	tripSeconds: number,
	coneCos: number, -- cos of the cone's half angle
}

function TutorialGuard.rulesFrom(config: any): Rules
	local t = config.Tutorial
	return {
		stirRadius = t.StirRadius,
		wakeRange = t.WakeRange,
		chaseSpeed = t.GuardChaseSpeed,
		tripDistance = t.GuardTripDistance,
		tripSeconds = t.GuardTripSeconds or 1.5,
		coneCos = math.cos(math.rad(config.Guard.ConeHalfAngle)),
	}
end

-- Asleep: does this player make him stir?
function TutorialGuard.stirs(distance: number, crouching: boolean, rules: Rules): boolean
	return distance <= rules.stirRadius and not crouching
end

-- Lockdown: how far he walks this step towards a player `distance` away, and whether he trips (the player is
-- standing still and he would get closer than tripDistance). He never closes the last tripDistance studs.
function TutorialGuard.follow(
	distance: number,
	playerMoving: boolean,
	dt: number,
	rules: Rules
): (number, boolean)
	local room = distance - rules.tripDistance
	if room <= 0 then
		return 0, not playerMoving
	end
	local step = math.min(rules.chaseSpeed * dt, room)
	local tripped = not playerMoving and step >= room
	return step, tripped
end

-- Lockdown: is the player inside his cone (to hint "Hide!")? `dot` = cos of the angle between his look and the
-- player, as from Vector3 maths.
function TutorialGuard.sees(distance: number, dot: number, hidden: boolean, rules: Rules): boolean
	return not hidden and distance <= rules.wakeRange and dot >= rules.coneCos
end

return TutorialGuard
