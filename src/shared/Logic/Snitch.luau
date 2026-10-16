--!strict
-- Snitches (beta-spec §4.3, §6.2; advisor: kept): Karel and the Health Inspector see crew like a guard but slower
-- (Karel fill ×0.5, Inspector ×0.67, range 25). A full meter = "I'M TELLING!": +20 alarm, the 2 nearest guards
-- investigate. Once per player per `cooldown` (30 s); the meter empties after a report.

local Snitch = {}

-- One meter step: `rate` = meter per second while seen (0 = not seen), `decay` per second otherwise.
-- Returns (meter, full).
function Snitch.step(meter: number, dt: number, rate: number, decay: number): (number, boolean)
	if rate > 0 then
		local next = math.min(1, meter + rate * dt)
		return next, next >= 1
	end
	return math.max(0, meter - decay * dt), false
end

-- May this snitch tell on this player again?
function Snitch.canReport(lastReportAt: number?, now: number, cooldown: number): boolean
	return lastReportAt == nil or now - lastReportAt >= cooldown
end

return Snitch
