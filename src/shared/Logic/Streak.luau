--!strict
-- Dig streak rules. Pure: callers pass the clock value.

local Loot = require(script.Parent.Parent.Config.Loot)

export type State = { count: number, lastAt: number }

local Streak = {}

function Streak.new(): State
	return { count = 0, lastAt = -math.huge }
end

-- Registers a finished dig at time `now`. Returns the new streak count.
function Streak.onDig(state: State, now: number): number
	if now - state.lastAt <= Loot.streak.window then
		state.count += 1
	else
		state.count = 1
	end
	state.lastAt = now
	return state.count
end

-- Value bonus (fraction) for a streak count: 0 for the first dig.
function Streak.bonus(count: number): number
	return math.min(Loot.streak.maxBonus, math.max(0, count - 1) * Loot.streak.bonusPerStep)
end

return Streak
