--!strict
-- Pure progression rules: upgrade ladders, affordability, next goal, area unlocks.

local Areas = require(script.Parent.Parent.Config.Areas)
local Economy = require(script.Parent.Parent.Config.Economy)
local Upgrades = require(script.Parent.Parent.Config.Upgrades)

export type UpgradeKind = "Shovel" | "Bag"

export type Goal = {
	kind: UpgradeKind,
	level: number,
	name: string,
	cost: number,
	cash: number,
	missing: number,
	affordable: boolean,
}

local Progression = {}

Progression.MaxShovelLevel = #Upgrades.Shovels
Progression.MaxBagLevel = #Upgrades.Bags

local function clampLevel(level: number, max: number): number
	return math.clamp(math.floor(level), 1, max)
end

function Progression.getShovel(level: number): Upgrades.ShovelDef
	return Upgrades.Shovels[clampLevel(level, Progression.MaxShovelLevel)]
end

function Progression.getBag(level: number): Upgrades.BagDef
	return Upgrades.Bags[clampLevel(level, Progression.MaxBagLevel)]
end

function Progression.bagCapacity(bagLevel: number): number
	return Progression.getBag(bagLevel).capacity
end

-- The definition of the next level for an upgrade kind, or nil when maxed.
function Progression.nextUpgrade(
	kind: UpgradeKind,
	currentLevel: number
): (Upgrades.ShovelDef | Upgrades.BagDef)?
	if kind == "Shovel" then
		return Upgrades.Shovels[currentLevel + 1]
	elseif kind == "Bag" then
		return Upgrades.Bags[currentLevel + 1]
	end
	return nil
end

-- Returns ok, reason ("Maxed" | "NotEnoughCash" | "BadKind"), missing cash.
function Progression.canBuy(kind: UpgradeKind, currentLevel: number, cash: number): (boolean, string?, number)
	if kind ~= "Shovel" and kind ~= "Bag" then
		return false, "BadKind", 0
	end
	local nextDef = Progression.nextUpgrade(kind, currentLevel)
	if not nextDef then
		return false, "Maxed", 0
	end
	if cash < nextDef.cost then
		return false, "NotEnoughCash", nextDef.cost - cash
	end
	return true, nil, 0
end

-- The always-visible next goal: the next shovel, or the next bag once the
-- shovel is maxed. Nil when everything is maxed (rebirth arrives in Phase 4).
function Progression.nextGoal(cash: number, shovelLevel: number, bagLevel: number): Goal?
	local kind: UpgradeKind = "Shovel"
	local def: any = Progression.nextUpgrade("Shovel", shovelLevel)
	if not def then
		kind = "Bag"
		def = Progression.nextUpgrade("Bag", bagLevel)
	end
	if not def then
		return nil
	end
	local missing = math.max(0, def.cost - cash)
	return {
		kind = kind,
		level = def.level,
		name = def.name,
		cost = def.cost,
		cash = cash,
		missing = missing,
		affordable = missing == 0,
	}
end

-- True when the goal is close enough to nudge the player ("Only $320 to go!").
function Progression.isNearGoal(goal: Goal): boolean
	return not goal.affordable and goal.missing <= goal.cost * Economy.nearGoalFraction
end

function Progression.isAreaUnlocked(areaId: string, shovelLevel: number): boolean
	local def = Areas.Defs[areaId]
	if not def or not def.enabled then
		return false
	end
	return shovelLevel >= def.requiredShovel
end

function Progression.unlockedAreas(shovelLevel: number): { string }
	local result = {}
	for _, areaId in Areas.Order do
		if Progression.isAreaUnlocked(areaId, shovelLevel) then
			table.insert(result, areaId)
		end
	end
	return result
end

return Progression
