--!strict
-- Pure: the new-player tutorial's goals. It's complete once the player has
-- bought a bigger bag, a better shovel and their (free) first drink at the
-- Tiki Bar, in any order.

local Tutorial = {}

function Tutorial.isComplete(data: { [string]: any }): boolean
	return data.bagLevel > 1 and data.shovelLevel > 1 and data.onboarding.freeDrinkUsed == true
end

-- Marks the tutorial done once its goals are met. Returns true if it just finished.
function Tutorial.update(data: { [string]: any }): boolean
	if not data.onboarding.guideDone and Tutorial.isComplete(data) then
		data.onboarding.guideDone = true
		return true
	end
	return false
end

return Tutorial
