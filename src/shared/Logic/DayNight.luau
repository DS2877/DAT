--!strict
-- Pure day/night clock (Config/DayNight), from the server time.

local Config = require(script.Parent.Parent.Config.DayNight)

local DayNight = {}

-- Seconds into the current day.
local function into(serverTime: number): number
	return (serverTime + Config.offset) % Config.cycle
end

function DayNight.isNight(serverTime: number): boolean
	return into(serverTime) >= Config.dayLength
end

-- The ClockTime (0..24) for a moment.
function DayNight.clockTime(serverTime: number): number
	local t = into(serverTime)
	if t < Config.dayLength then
		return Config.dawn + (t / Config.dayLength) * (Config.dusk - Config.dawn)
	end
	local nightLength = Config.cycle - Config.dayLength
	local n = (t - Config.dayLength) / nightLength
	return (Config.dusk + n * (24 - Config.dusk + Config.dawn)) % 24
end

-- 0 in full day, 1 in full night, blending over `fade` seconds.
function DayNight.nightness(serverTime: number): number
	local t = into(serverTime)
	local fade = math.max(1, Config.fade)
	if t < Config.dayLength then
		-- Dawn: fading out of the night that just ended.
		return math.clamp(1 - t / fade, 0, 1)
	end
	return math.clamp((t - Config.dayLength) / fade, 0, 1)
end

-- Seconds until the next night starts (0 while it's night).
function DayNight.untilNight(serverTime: number): number
	local t = into(serverTime)
	return if t >= Config.dayLength then 0 else Config.dayLength - t
end

return DayNight
