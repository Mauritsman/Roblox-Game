--!strict
-- Retry with exponential backoff for DataStore calls: delay min(2^(n-1), max) seconds + 0–0.5 s jitter.
-- Pure: sleeping and randomness are passed in (task.wait / math.random in Roblox, fakes in tests).

local Backoff = {}

-- Seconds to wait after failed attempt `attempt` (1-based). `jitter` is a number in [0, 1).
function Backoff.delay(attempt: number, maxSeconds: number, jitter: number): number
	return math.min(2 ^ (attempt - 1), maxSeconds) + math.clamp(jitter, 0, 1) * 0.5
end

-- Calls fn up to `attempts` times until it does not error.
-- Returns ok, the result (or the last error message) and the number of attempts used.
function Backoff.retry(
	fn: () -> any,
	attempts: number,
	maxSeconds: number,
	sleep: (seconds: number) -> (),
	random: () -> number
): (boolean, any, number)
	local lastError: any = "no attempts"
	for attempt = 1, math.max(1, attempts) do
		local ok, result = pcall(fn)
		if ok then
			return true, result, attempt
		end
		lastError = result
		if attempt < attempts then
			sleep(Backoff.delay(attempt, maxSeconds, random()))
		end
	end
	return false, lastError, math.max(1, attempts)
end

return Backoff
