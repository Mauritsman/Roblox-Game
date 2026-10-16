--!strict
-- UTC calendar maths for resets: day (contracts, daily ×2), week (Most Wanted, Monday 00:00 UTC) and the
-- 30-minute Hot Job slot. `now` is os.time() (seconds since 1 Jan 1970 UTC). Pure.

local Calendar = {}

local DAY = 86400
local WEEK = 604800
local WEEK_OFFSET = 345600 -- 1 Jan 1970 was a Thursday; +4 days = Monday 5 Jan 1970 00:00 UTC

function Calendar.day(now: number): number
	return math.floor(now / DAY)
end

function Calendar.dayResetsAt(now: number): number
	return (Calendar.day(now) + 1) * DAY
end

function Calendar.week(now: number): number
	return math.floor((now - WEEK_OFFSET) / WEEK)
end

function Calendar.weekResetsAt(now: number): number
	return (Calendar.week(now) + 1) * WEEK + WEEK_OFFSET
end

function Calendar.slot(now: number, slotSeconds: number): number
	return math.floor(now / slotSeconds)
end

function Calendar.slotEndsAt(now: number, slotSeconds: number): number
	return (Calendar.slot(now, slotSeconds) + 1) * slotSeconds
end

return Calendar
