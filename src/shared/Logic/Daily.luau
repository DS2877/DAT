--!strict
-- Pure 7-day daily reward calendar. Days are UTC day numbers. Missing a day
-- restarts the calendar at day 1; nothing already claimed is taken away.
-- state = { lastDay = number (0 = never), streak = number (last claimed 1..7) }

local Retention = require(script.Parent.Parent.Config.Retention)

local Daily = {}

local DAY = 86400

function Daily.today(unixTime: number): number
	return math.floor(unixTime / DAY)
end

function Daily.secondsUntilTomorrow(unixTime: number): number
	return (Daily.today(unixTime) + 1) * DAY - unixTime
end

-- Returns whether today's reward can be claimed and which calendar day
-- (1..7) it is (or would be, if already claimed today: the next one).
function Daily.status(state: { [string]: any }, today: number): (boolean, number)
	local length = #Retention.daily
	if state.lastDay == today then
		return false, state.streak % length + 1
	elseif state.lastDay == today - 1 then
		return true, state.streak % length + 1
	end
	return true, 1
end

-- Claims today's reward. Returns the calendar day claimed, or nil.
function Daily.claim(state: { [string]: any }, today: number): number?
	local can, day = Daily.status(state, today)
	if not can then
		return nil
	end
	state.lastDay = today
	state.streak = day
	return day
end

return Daily
