--!strict
-- Game calendar clock for meta (os.time(), UTC seconds) with a Studio-only offset so testers can jump to the
-- next day or Hot Job slot. Session locks always use the real os.time(), never this clock.

local RunService = game:GetService("RunService")

local Clock = {}

local offset = 0

function Clock.now(): number
	return os.time() + offset
end

function Clock.offset(): number
	return offset
end

-- Studio only (ignored in the live game).
function Clock.setOffset(seconds: number)
	if RunService:IsStudio() then
		offset = math.floor(seconds)
	end
end

return Clock
