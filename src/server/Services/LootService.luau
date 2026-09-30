--!strict
-- Server-side loot: rolls a treasure for a finished dig and records the find.
-- Applies, in order: early guarantees / Deep Dig minimum rarity, clue odds,
-- the base roll, a mutation roll, then value bonuses (first find, dig streak,
-- collection sets).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Collection = require(ReplicatedStorage.Shared.Logic.Collection)
local Guarantees = require(ReplicatedStorage.Shared.Logic.Guarantees)
local Loot = require(ReplicatedStorage.Shared.Config.Loot)
local LootRoller = require(ReplicatedStorage.Shared.Logic.LootRoller)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
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
	deep: boolean, -- came out of a Deep Dig
	firstFindBonus: boolean, -- value doubled for a first-ever find
	newBest: boolean, -- became the player's trophy-shelf find
}

export type DigContext = {
	areaId: string,
	clue: string?,
	streak: number,
	deep: boolean,
}

function LootService.rollFor(data: { [string]: any }, context: DigContext): Find
	local digNumber = data.stats.digs + 1
	local minRarity = Guarantees.beforeRoll(data.onboarding, context.areaId, digNumber, os.time(), rng)
	if
		context.deep
		and (minRarity == nil or Rarities.rank(minRarity) < Rarities.rank(Loot.deepDig.minRarity))
	then
		minRarity = Loot.deepDig.minRarity
	end
	local roll = LootRoller.roll(context.areaId, rng, {
		minRarity = minRarity,
		oddsMultipliers = if context.clue then Loot.clueOddsMultipliers else nil,
	})
	Guarantees.afterRoll(data.onboarding, roll.rarity)

	local mutation, multiplier = LootRoller.rollMutation(rng)
	local streakBonus = Streak.bonus(context.streak)
	local entry = data.discovered[roll.id]
	local isNew = entry == nil
	local firstFind = if isNew then Loot.firstFindMultiplier else 1
	-- The set multiplier is taken before recording this find, so the find
	-- that completes a set isn't boosted by its own bonus.
	local setMultiplier = Collection.cashMultiplier(data.discovered)
	local value =
		math.max(1, math.floor(roll.value * multiplier * firstFind * (1 + streakBonus) * setMultiplier + 0.5))

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

	local candidate = { id = roll.id, m = mutation }
	local current = if data.bestFind.id then data.bestFind else nil
	local newBest = Collection.isBetter(candidate, current)
	if newBest then
		data.bestFind = candidate
	end

	return {
		id = roll.id,
		rarity = roll.rarity,
		value = value,
		mutation = mutation,
		isNew = isNew,
		isNewVariant = isNewVariant,
		streak = context.streak,
		streakBonus = streakBonus,
		deep = context.deep,
		firstFindBonus = isNew,
		newBest = newBest,
	}
end

return LootService
