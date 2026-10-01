--!strict
-- Treasure Rush schedule on a fixed global clock (pure). Pass a synced
-- time: workspace:GetServerTimeNow() on both server and client, so the
-- countdown players see is exactly when the rush starts.

local Retention = require(script.Parent.Parent.Config.Retention)

local Rush = {}

-- Returns active, secondsLeft (if active) or secondsUntilStart (if not).
-- `overrideUntil`: a rush an admin started runs until then (pass
-- workspace's "RushUntil" attribute).
function Rush.state(now: number, overrideUntil: any?): (boolean, number)
	if type(overrideUntil) == "number" and overrideUntil > now then
		return true, overrideUntil - now
	end
	local interval, duration = Retention.rush.interval, Retention.rush.duration
	local start = math.floor(now / interval) * interval
	local elapsed = now - start
	if elapsed < duration then
		return true, duration - elapsed
	end
	return false, start + interval - now
end

function Rush.isActive(now: number, overrideUntil: any?): boolean
	return (Rush.state(now, overrideUntil))
end

-- An id for the current / next rush (for once-per-rush analytics).
function Rush.id(now: number): number
	return math.floor(now / Retention.rush.interval)
end

return Rush
