--!strict
-- Pure: the next start of something that happens every `interval` seconds,
-- `offset` seconds into the interval, on the shared server clock.

local Schedule = {}

function Schedule.nextStart(now: number, interval: number, offset: number): number
	local base = math.floor((now - offset) / interval) * interval + offset
	if base <= now then
		base += interval
	end
	return base
end

return Schedule
