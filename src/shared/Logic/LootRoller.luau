--!strict
-- Pure loot rolls. `rng` returns a float in [0, 1) so tests can inject a
-- deterministic generator and the server can use Random.

local Areas = require(script.Parent.Parent.Config.Areas)
local Economy = require(script.Parent.Parent.Config.Economy)
local Loot = require(script.Parent.Parent.Config.Loot)
local Rarities = require(script.Parent.Parent.Config.Rarities)
local Treasures = require(script.Parent.Parent.Config.Treasures)

export type Rng = () -> number
export type Roll = { id: string, rarity: string, value: number }
export type RollOptions = {
	-- Rarities ranked below this are removed from the odds (e.g. guaranteed Rare).
	minRarity: string?,
	-- Per-rarity weight multipliers (e.g. Loot.clueOddsMultipliers).
	oddsMultipliers: { [string]: number }?,
	-- The player's rebirth count (unlocks rebirth-only Secrets).
	rebirths: number?,
}

local LootRoller = {}

local poolCache: { [string]: { Treasures.TreasureDef } } = {}

-- Treasures that can drop for a rarity in an area: the area's own treasures
-- of that rarity, or, if it has none, all earlier areas' treasures of it.
-- Rebirth-only treasures join once the player has enough rebirths.
function LootRoller.getPool(areaId: string, rarity: string, rebirths: number?): { Treasures.TreasureDef }
	local r = rebirths or 0
	local key = areaId .. "|" .. rarity .. "|" .. r
	local cached = poolCache[key]
	if cached then
		return cached
	end
	local area = Areas.Defs[areaId]
	assert(area, "Unknown area " .. areaId)

	local native, earlier = {}, {}
	for _, def in Treasures.List do
		if def.rarity == rarity and (def.rebirths == nil or r >= def.rebirths) then
			local home = Areas.Defs[def.area]
			if def.area == areaId then
				table.insert(native, def)
			elseif home and home.order < area.order then
				table.insert(earlier, def)
			end
		end
	end
	local pool = if #native > 0 then native else earlier
	poolCache[key] = pool
	return pool
end

-- Odds for an area after applying options. Rarities with an empty pool are
-- dropped so a roll can never land on nothing.
function LootRoller.getOdds(areaId: string, options: RollOptions?): { [string]: number }
	local area = Areas.Defs[areaId]
	assert(area, "Unknown area " .. areaId)
	local minRank = if options and options.minRarity then Rarities.rank(options.minRarity) else 0
	local odds = {}
	local multipliers = options and options.oddsMultipliers
	local rebirths = options and options.rebirths
	for rarity, chance in area.odds do
		if
			chance > 0
			and Rarities.rank(rarity) >= minRank
			and #LootRoller.getPool(areaId, rarity, rebirths) > 0
		then
			odds[rarity] = chance * (if multipliers then multipliers[rarity] or 1 else 1)
		end
	end
	if next(odds) == nil and minRank > 0 then
		-- The area cannot produce the minimum rarity; give its best instead.
		local best, bestRank = nil, 0
		for rarity, chance in area.odds do
			local rank = Rarities.rank(rarity)
			if chance > 0 and rank > bestRank and #LootRoller.getPool(areaId, rarity) > 0 then
				best, bestRank = rarity, rank
			end
		end
		if best then
			odds[best] = 1
		end
	end
	return odds
end

function LootRoller.rollRarity(odds: { [string]: number }, rng: Rng): string
	local total = 0
	for _, rarity in Rarities.Order do
		total += odds[rarity] or 0
	end
	assert(total > 0, "Odds table is empty")
	local x = rng() * total
	local last = ""
	for _, rarity in Rarities.Order do
		local chance = odds[rarity] or 0
		if chance > 0 then
			last = rarity
			if x < chance then
				return rarity
			end
			x -= chance
		end
	end
	return last
end

function LootRoller.pickTreasure(pool: { Treasures.TreasureDef }, rng: Rng): Treasures.TreasureDef
	local total = 0
	for _, def in pool do
		total += def.weight or 1
	end
	local x = rng() * total
	for _, def in pool do
		x -= def.weight or 1
		if x < 0 then
			return def
		end
	end
	return pool[#pool]
end

function LootRoller.rollValue(baseValue: number, rng: Rng): number
	local variance = Economy.valueVariance
	local factor = 1 + (rng() * 2 - 1) * variance
	return math.max(1, math.floor(baseValue * factor + 0.5))
end

-- Rolls a mutation independently of rarity. Returns the mutation id and its
-- value multiplier, or nil and 1.
-- `chanceMultiplier` scales every mutation's chance (Lucky Lemonade).
function LootRoller.rollMutation(rng: Rng, chanceMultiplier: number?): (string?, number)
	for _, mutation in Loot.mutations do
		if rng() < mutation.chance * (chanceMultiplier or 1) then
			return mutation.id, mutation.multiplier
		end
	end
	return nil, 1
end

function LootRoller.mutationMultiplier(mutationId: string?): number
	for _, mutation in Loot.mutations do
		if mutation.id == mutationId then
			return mutation.multiplier
		end
	end
	return 1
end

function LootRoller.roll(areaId: string, rng: Rng, options: RollOptions?): Roll
	local rarity = LootRoller.rollRarity(LootRoller.getOdds(areaId, options), rng)
	local def = LootRoller.pickTreasure(LootRoller.getPool(areaId, rarity, options and options.rebirths), rng)
	return { id = def.id, rarity = def.rarity, value = LootRoller.rollValue(def.value, rng) }
end

return LootRoller
