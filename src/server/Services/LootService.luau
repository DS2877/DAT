--!strict
-- Server-side loot: rolls a treasure for a finished dig and records the find.
-- Applies, in order:
--   1. minimum rarity: early guarantees, Deep Dig, Golden X, reward charges
--   2. odds boosts: clue spot, Treasure Rush
--   3. the base roll (rebirth-only Secrets included when unlocked)
--   4. a mutation roll
--   5. value bonuses: first find, dig streak, and the cash multiplier
--      (collection sets, rebirths, friends, 2x Cash boost)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local Collection = require(ReplicatedStorage.Shared.Logic.Collection)
local Guarantees = require(ReplicatedStorage.Shared.Logic.Guarantees)
local Loot = require(ReplicatedStorage.Shared.Config.Loot)
local LootRoller = require(ReplicatedStorage.Shared.Logic.LootRoller)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Rush = require(ReplicatedStorage.Shared.Logic.Rush)
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
	goldenX: boolean, -- came out of the daily Golden X
	rush: boolean, -- dug during a Treasure Rush
	firstFindBonus: boolean, -- value doubled for a first-ever find
	newBest: boolean, -- became the player's trophy-shelf find
}

export type DigContext = {
	areaId: string,
	clue: string?,
	streak: number,
	deep: boolean,
	goldenX: boolean,
	friends: number, -- friends in the server (cash bonus)
	luck: { [string]: number }?, -- 2x Luck pass odds multipliers (off by default)
	serverBoost: boolean?, -- a bought server-wide 2x Cash is running
	jackpot: string?, -- a hidden treasure's rarity (Config/Jackpots)
}

local function atLeast(current: string?, minimum: string): string
	if current == nil or Rarities.rank(current) < Rarities.rank(minimum) then
		return minimum
	end
	return current
end

local function combineMultipliers(a: { [string]: number }?, b: { [string]: number }?): { [string]: number }?
	if not a or not b then
		return a or b
	end
	local out = {}
	for _, rarity in Rarities.Order do
		out[rarity] = (a[rarity] or 1) * (b[rarity] or 1)
	end
	return out
end

function LootService.rollFor(data: { [string]: any }, context: DigContext): Find
	local now = os.time()
	local digNumber = data.stats.digs + 1
	local minRarity = Guarantees.beforeRoll(data.onboarding, context.areaId, digNumber, now, rng)
	if context.deep then
		local deep = Loot.deepDig.areas[context.areaId]
		minRarity = atLeast(minRarity, if deep then deep.minRarity else "Epic")
	end
	if context.goldenX then
		minRarity = atLeast(minRarity, Retention.goldenX.minRarity)
	end
	if context.jackpot then
		minRarity = atLeast(minRarity, context.jackpot)
	end
	-- Reward charges (from gifts / daily): spent only when they'd matter.
	local charges = data.digCharges
	if charges.Epic > 0 and (minRarity == nil or Rarities.rank(minRarity) < Rarities.rank("Epic")) then
		charges.Epic -= 1
		minRarity = "Epic"
	elseif charges.Rare > 0 and minRarity == nil then
		charges.Rare -= 1
		minRarity = "Rare"
	end

	local rushActive = Rush.isActive(workspace:GetServerTimeNow())
	local roll = LootRoller.roll(context.areaId, rng, {
		minRarity = minRarity,
		oddsMultipliers = combineMultipliers(
			combineMultipliers(
				if context.clue then Loot.clueOddsMultipliers else nil,
				if rushActive then Retention.rush.oddsMultipliers else nil
			),
			context.luck
		),
		rebirths = data.rebirths,
	})
	Guarantees.afterRoll(data.onboarding, roll.rarity)

	local mutation, multiplier =
		LootRoller.rollMutation(rng, Boosts.multiplier(data.activeBoosts, "LuckyLemonade", now))
	local streakBonus = Streak.bonus(context.streak)
	local entry = data.discovered[roll.id]
	local isNew = entry == nil
	local firstFind = if isNew then Loot.firstFindMultiplier else 1
	-- Bonuses are taken before recording this find, so the find that
	-- completes a set isn't boosted by its own set bonus.
	local cashMultiplier = Bonuses.cashMultiplier(data, context.friends, now, context.serverBoost)
	local value = math.max(
		1,
		math.floor(roll.value * multiplier * firstFind * (1 + streakBonus) * cashMultiplier + 0.5)
	)

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
		goldenX = context.goldenX,
		rush = rushActive,
		firstFindBonus = isNew,
		newBest = newBest,
	}
end

return LootService
