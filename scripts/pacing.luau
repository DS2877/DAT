-- Pacing simulator. Usage: lune run scripts/pacing.luau [runs]
--
-- Plays the real loot / upgrade config (including clues, mutations and dig
-- streaks) with a simple bot and prints median
-- times to the spec's pacing milestones. Timing assumptions (walking between
-- spots, trips to the sell pad) are rough guesses: tune them against
-- analytics once real players exist. All areas are simulated as enabled so
-- the full progression can be checked before later phases ship.

local process = require("@lune/process")

local Loader = require("../tests/loader")
local Areas = Loader.requireShared("Config/Areas")
local Loot = Loader.requireShared("Config/Loot")
local LootRoller = Loader.requireShared("Logic/LootRoller")
local Streak = Loader.requireShared("Logic/Streak")
local Progression = Loader.requireShared("Logic/Progression")

-- Assumptions (seconds).
local WALK_BETWEEN_SPOTS = 4.0
local ROUND_TRIP_TO_SELL = { Beach = 22, Jungle = 34, Ruins = 44, Volcano = 55 }
local SHOP_TIME = 4

local function seededRng(seed: number)
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

local function bestArea(shovelLevel: number): string
	local best = "Beach"
	for _, areaId in Areas.Order do
		if shovelLevel >= Areas.Defs[areaId].requiredShovel then
			best = areaId
		end
	end
	return best
end

local MILESTONES =
	{ "firstFind", "firstSale", "firstUpgrade", "jungle", "ruins", "volcano", "legendaryShovel" }

local function simulate(seed: number): { [string]: number }
	local rng = seededRng(seed)
	local t, cash, shovel, bag = 0, 0, 1, 1
	local reached: { [string]: number } = {}
	local function mark(name: string)
		if reached[name] == nil then
			reached[name] = t
		end
	end

	while shovel < Progression.MaxShovelLevel and t < 6 * 3600 do
		local area = bestArea(shovel)
		local def = Progression.getShovel(shovel)
		local capacity = Progression.bagCapacity(bag)
		local bagValue = 0
		for dig = 1, capacity do
			t += WALK_BETWEEN_SPOTS + def.hits * def.hitInterval
			-- Clue spots, mutations and the dig streak (the bot chains every dig).
			local clue = rng() < Loot.clueChance
			local roll = LootRoller.roll(
				area,
				rng,
				{ oddsMultipliers = if clue then Loot.clueOddsMultipliers else nil }
			)
			local _, multiplier = LootRoller.rollMutation(rng)
			bagValue += math.floor(roll.value * multiplier * (1 + Streak.bonus(dig)))
			mark("firstFind")
		end
		t += ROUND_TRIP_TO_SELL[area]
		cash += bagValue
		mark("firstSale")

		-- Greedy shopping: next shovel first; a bag when it's cheap relative to it.
		local bought = true
		while bought do
			bought = false
			local nextShovel = Progression.nextUpgrade("Shovel", shovel)
			local nextBag = Progression.nextUpgrade("Bag", bag)
			if nextShovel and cash >= nextShovel.cost then
				cash -= nextShovel.cost
				shovel = nextShovel.level
				bought = true
			elseif
				nextBag
				and cash >= nextBag.cost
				and (not nextShovel or nextBag.cost <= nextShovel.cost * 0.5)
			then
				cash -= nextBag.cost
				bag = nextBag.level
				bought = true
			end
			if bought then
				t += SHOP_TIME
				mark("firstUpgrade")
			end
		end
		if shovel >= Areas.Defs.Jungle.requiredShovel then
			mark("jungle")
		end
		if shovel >= Areas.Defs.Ruins.requiredShovel then
			mark("ruins")
		end
		if shovel >= Areas.Defs.Volcano.requiredShovel then
			mark("volcano")
		end
	end
	if shovel >= Progression.MaxShovelLevel then
		mark("legendaryShovel")
	end
	return reached
end

local function fmt(seconds: number?): string
	if not seconds then
		return "   n/a"
	end
	if seconds < 120 then
		return string.format("%5.0fs", seconds)
	end
	return string.format("%5.1fm", seconds / 60)
end

local runs = tonumber(process.args[1]) or 300
local samples: { [string]: { number } } = {}
for _, name in MILESTONES do
	samples[name] = {}
end
for seed = 1, runs do
	local reached = simulate(seed * 7919)
	for _, name in MILESTONES do
		if reached[name] then
			table.insert(samples[name], reached[name])
		end
	end
end

local targets = {
	firstFind = "< 10s",
	firstSale = "< 90s",
	firstUpgrade = "< 2m",
	jungle = "~10m",
	ruins = "30-40m",
	volcano = "~90m",
	legendaryShovel = "(rebirth ~3-4h)",
}

print(string.format("Pacing over %d simulated players (median / p10 / p90):\n", runs))
print(string.format("%-16s %7s %7s %7s   %s", "milestone", "median", "p10", "p90", "spec target"))
for _, name in MILESTONES do
	local list = samples[name]
	table.sort(list)
	local function pct(p: number): number?
		if #list == 0 then
			return nil
		end
		return list[math.clamp(math.floor(#list * p + 0.5), 1, #list)]
	end
	print(
		string.format(
			"%-16s %7s %7s %7s   %s",
			name,
			fmt(pct(0.5)),
			fmt(pct(0.1)),
			fmt(pct(0.9)),
			targets[name]
		)
	)
end
