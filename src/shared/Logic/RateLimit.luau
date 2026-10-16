--!strict
-- Token bucket per player and request: `burst` requests at once, refilled at `perSecond`. Pure (time passed in).

local RateLimit = {}

export type Bucket = { tokens: number, at: number }

function RateLimit.new(burst: number, now: number): Bucket
	return { tokens = burst, at = now }
end

-- Takes `cost` tokens (default 1). Returns false (and takes nothing) when the bucket is too empty.
function RateLimit.take(bucket: Bucket, now: number, burst: number, perSecond: number, cost: number?): boolean
	local elapsed = math.max(0, now - bucket.at)
	bucket.tokens = math.min(burst, bucket.tokens + elapsed * perSecond)
	bucket.at = now
	local price = cost or 1
	if bucket.tokens < price then
		return false
	end
	bucket.tokens -= price
	return true
end

return RateLimit
