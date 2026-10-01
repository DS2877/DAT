--!strict
-- Pure: what a Tiki Bar drink costs this player right now.

local Drinks = require(script.Parent.Parent.Config.Drinks)
local Goals = require(script.Parent.Goals)

local DrinkPrice = {}

function DrinkPrice.of(drink: Drinks.Drink, data: { [string]: any }): number
	local goalCost = Goals.current(data).cost
	return math.max(drink.min, math.floor(goalCost * drink.goalPercent + 0.5))
end

return DrinkPrice
