--!strict
-- Token-bucket rate limiter keyed by any value (e.g. a Player). Pure: pass a
-- clock function (os.clock on the server) so tests control time.

export type RateLimiter = {
	allow: (self: RateLimiter, key: any) -> boolean,
	forget: (self: RateLimiter, key: any) -> (),
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(ratePerSecond: number, burst: number, clock: (() -> number)?)
	local self = setmetatable({}, RateLimiter)
	self._rate = ratePerSecond
	self._burst = burst
	self._clock = clock or os.clock
	self._buckets = {} :: { [any]: { tokens: number, t: number } }
	return self
end

function RateLimiter.allow(self: any, key: any): boolean
	local now = self._clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._burst, t = now }
		self._buckets[key] = bucket
	end
	bucket.tokens = math.min(self._burst, bucket.tokens + (now - bucket.t) * self._rate)
	bucket.t = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.forget(self: any, key: any)
	self._buckets[key] = nil
end

return RateLimiter
