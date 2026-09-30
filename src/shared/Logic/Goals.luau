--!strict
-- The one "next goal" everyone agrees on (HUD bar, sale nudge, reward
-- sizing): the next shovel, and once the Legendary Shovel is owned, the
-- rebirth. Bags are a side upgrade, never the headline goal. Pure.

local Economy = require(script.Parent.Parent.Config.Economy)
local Progression = require(script.Parent.Progression)
local Rebirth = require(script.Parent.Rebirth)

export type Goal = {
	kind: "Shovel" | "Rebirth",
	name: string,
	cost: number,
	cash: number,
	missing: number,
	affordable: boolean,
}

local Goals = {}

function Goals.current(data: { [string]: any }): Goal
	local cash = data.cash
	local nextShovel = Progression.nextUpgrade("Shovel", data.shovelLevel)
	local kind: "Shovel" | "Rebirth" = "Shovel"
	local name, cost
	if nextShovel then
		name, cost = nextShovel.name, nextShovel.cost
	else
		kind, name, cost = "Rebirth", "Rebirth", Rebirth.cost(data.rebirths)
	end
	local missing = math.max(0, cost - cash)
	return { kind = kind, name = name, cost = cost, cash = cash, missing = missing, affordable = missing == 0 }
end

-- Close enough to nudge ("Only $320 to go!").
function Goals.isNear(goal: Goal): boolean
	return not goal.affordable and goal.missing <= goal.cost * Economy.nearGoalFraction
end

return Goals
