--!strict
-- Pure: what a Tiki Bar drink costs this player right now.

local Drinks = require(script.Parent.Parent.Config.Drinks)
local Goals = require(script.Parent.Goals)

local DrinkPrice = {}

-- The tutorial's first drink is on the house (works on the saved profile
-- and on the client's snapshot).
function DrinkPrice.isFree(data: { [string]: any }): boolean
	local onboarding = data.onboarding
	local used = if onboarding then onboarding.freeDrinkUsed else data.freeDrinkUsed
	local done = if onboarding then onboarding.guideDone else data.guideDone
	return used == false and done == false
end

function DrinkPrice.of(drink: Drinks.Drink, data: { [string]: any }): number
	if DrinkPrice.isFree(data) then
		return 0
	end
	local goalCost = Goals.current(data).cost
	return math.max(drink.min, math.floor(goalCost * drink.goalPercent + 0.5))
end

return DrinkPrice
