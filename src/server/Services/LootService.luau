--!strict
-- Server-side loot: rolls a treasure for a finished dig and records the find.
-- Applies, in order: early guarantees, clue odds, the base roll, a mutation
-- roll, and the dig streak bonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guarantees = require(ReplicatedStorage.Shared.Logic.Guarantees)
local Loot = require(ReplicatedStorage.Shared.Config.Loot)
local LootRoller = require(ReplicatedStorage.Shared.Logic.LootRoller)
local Streak = require(ReplicatedStorage.Shared.Logic.Streak)

local LootService = {}

local random = Random.new()
local function rng(): number
	return random:NextNumber()
end

export type Find = {
	id: string,
	rarity: string,
	value: number,
	mutation: string?,
	isNew: boolean, -- first time this treasure was ever found
	isNewVariant: boolean, -- first time this mutation of it was found
	streak: number,
	streakBonus: number,
}

export type DigContext = {
	areaId: string,
	clue: string?,
	streak: number,
}

function LootService.rollFor(data: { [string]: any }, context: DigContext): Find
	local digNumber = data.stats.digs + 1
	local minRarity = Guarantees.beforeRoll(data.onboarding, context.areaId, digNumber, os.time(), rng)
	local roll = LootRoller.roll(context.areaId, rng, {
		minRarity = minRarity,
		oddsMultipliers = if context.clue then Loot.clueOddsMultipliers else nil,
	})
	Guarantees.afterRoll(data.onboarding, roll.rarity)

	local mutation, multiplier = LootRoller.rollMutation(rng)
	local streakBonus = Streak.bonus(context.streak)
	local value = math.max(1, math.floor(roll.value * multiplier * (1 + streakBonus) + 0.5))

	local entry = data.discovered[roll.id]
	local isNew = entry == nil
	if entry == nil then
		entry = {}
		data.discovered[roll.id] = entry
	end
	local variantKey = if mutation == "Shiny"
		then "shiny"
		elseif mutation == "Golden" then "golden"
		else "normal"
	local isNewVariant = not entry[variantKey]
	entry[variantKey] = true

	return {
		id = roll.id,
		rarity = roll.rarity,
		value = value,
		mutation = mutation,
		isNew = isNew,
		isNewVariant = isNewVariant,
		streak = context.streak,
		streakBonus = streakBonus,
	}
end

return LootService
