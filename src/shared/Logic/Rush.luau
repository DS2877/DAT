--!strict
-- Treasure Rush schedule on a fixed global clock (pure). Pass a synced
-- time: workspace:GetServerTimeNow() on both server and client, so the
-- countdown players see is exactly when the rush starts.

local Retention = require(script.Parent.Parent.Config.Retention)

local Rush = {}

-- Returns active, secondsLeft (if active) or secondsUntilStart (if not).
function Rush.state(now: number): (boolean, number)
	local interval, duration = Retention.rush.interval, Retention.rush.duration
	local start = math.floor(now / interval) * interval
	local elapsed = now - start
	if elapsed < duration then
		return true, duration - elapsed
	end
	return false, start + interval - now
end

function Rush.isActive(now: number): boolean
	return (Rush.state(now))
end

-- An id for the current / next rush (for once-per-rush analytics).
function Rush.id(now: number): number
	return math.floor(now / Retention.rush.interval)
end

return Rush
