--!strict
-- Pure: when the next scheduled Mega Dig starts (synced server time).

local MegaDig = require(script.Parent.Parent.Config.MegaDig)

local MegaDigClock = {}

function MegaDigClock.nextStart(now: number): number
	local base = math.floor((now - MegaDig.offset) / MegaDig.interval) * MegaDig.interval + MegaDig.offset
	if base <= now then
		base += MegaDig.interval
	end
	return base
end

-- mm:ss for the clock faces and the HUD.
function MegaDigClock.format(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return MegaDigClock
