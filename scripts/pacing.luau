-- Pacing simulator. Usage: lune run scripts/pacing.luau [runs] [pace]
--
-- Plays the real config with a simple bot: loot odds, clues, mutations, dig
-- streaks, first-find x2, collection set bonuses, playtime gifts and their
-- boosts, upgrades and the first rebirth. Prints median / p10 / p90 times
-- to the spec's pacing milestones.
--
-- `pace` scales all walking / shopping time: 1.0 is a focused player who
-- always walks straight to the next spot; 1.5 (default) is a typical kid
-- who wanders, watches reveals and reads the UI. Tune these assumptions
-- against analytics once real players exist.

local process = require("@lune/process")

local Loader = require("../tests/loader")
local Areas = Loader.requireShared("Config/Areas")
local Bonuses = Loader.requireShared("Logic/Bonuses")
local Boosts = Loader.requireShared("Logic/Boosts")
local DataSchema = Loader.requireShared("Logic/DataSchema")
local Loot = Loader.requireShared("Config/Loot")
local LootRoller = Loader.requireShared("Logic/LootRoller")
local Progression = Loader.requireShared("Logic/Progression")
local Rebirth = Loader.requireShared("Logic/Rebirth")
local Retention = Loader.requireShared("Config/Retention")
local Streak = Loader.requireShared("Logic/Streak")

local runs = tonumber(process.args[1]) or 300
local PACE = tonumber(process.args[2]) or 1.5

-- Base assumptions for a focused player (seconds), scaled by PACE.
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

local MILESTONES = {
	"firstFind",
	"firstSale",
	"firstUpgrade",
	"jungle",
	"ruins",
	"volcano",
	"legendaryShovel",
	"firstRebirth",
}

local function simulate(seed: number): { [string]: number }
	local rng = seededRng(seed)
	local data = DataSchema.template()
	local t = 0
	local reached: { [string]: number } = {}
	local nextGift = 1
	local function mark(name: string)
		if reached[name] == nil then
			reached[name] = t
		end
	end
	-- Playtime gifts (one session; claimed as soon as they're ready).
	local function claimGifts()
		while nextGift <= #Retention.playtimeGifts and t >= Retention.playtimeGifts[nextGift].minutes * 60 do
			local reward = Retention.playtimeGifts[nextGift].reward
			if reward.kind == "Cash" then
				data.cash += Bonuses.rewardCash(reward, data)
			elseif reward.kind == "Boost" then
				Boosts.add(data.activeBoosts, reward.boost, reward.seconds, t)
			end
			nextGift += 1
		end
	end

	while t < 8 * 3600 do
		local area = bestArea(data.shovelLevel)
		local capacity = Progression.bagCapacity(data.bagLevel)
		local streak = Streak.new()
		local bagValue = 0
		for _ = 1, capacity do
			t += WALK_BETWEEN_SPOTS * PACE + 3 * Bonuses.hitInterval(data, t)
			local clue = rng() < Loot.clueChance
			local roll = LootRoller.roll(
				area,
				rng,
				{ oddsMultipliers = if clue then Loot.clueOddsMultipliers else nil }
			)
			local _, mutation = LootRoller.rollMutation(rng)
			local firstFind = if data.discovered[roll.id] then 1 else Loot.firstFindMultiplier
			local multiplier = Bonuses.cashMultiplier(data, 0, t)
			data.discovered[roll.id] = { normal = true }
			bagValue += math.floor(
				roll.value * mutation * firstFind * (1 + Streak.bonus(Streak.onDig(streak, t))) * multiplier
			)
			mark("firstFind")
		end
		t += ROUND_TRIP_TO_SELL[area] * PACE
		data.cash += bagValue
		mark("firstSale")
		claimGifts()

		-- Greedy shopping: next shovel first; a bag when it's cheap relative to it.
		local bought = true
		while bought do
			bought = false
			local nextShovel = Progression.nextUpgrade("Shovel", data.shovelLevel)
			local nextBag = Progression.nextUpgrade("Bag", data.bagLevel)
			if nextShovel and data.cash >= nextShovel.cost then
				data.cash -= nextShovel.cost
				data.shovelLevel = nextShovel.level
				bought = true
			elseif
				nextBag
				and data.cash >= nextBag.cost
				and (not nextShovel or nextBag.cost <= nextShovel.cost * 0.5)
			then
				data.cash -= nextBag.cost
				data.bagLevel = nextBag.level
				bought = true
			end
			if bought then
				t += SHOP_TIME * PACE
				mark("firstUpgrade")
			end
		end
		if data.shovelLevel >= Areas.Defs.Jungle.requiredShovel then
			mark("jungle")
		end
		if data.shovelLevel >= Areas.Defs.Ruins.requiredShovel then
			mark("ruins")
		end
		if data.shovelLevel >= Areas.Defs.Volcano.requiredShovel then
			mark("volcano")
		end
		if data.shovelLevel >= Progression.MaxShovelLevel then
			mark("legendaryShovel")
			if Rebirth.canRebirth(data) then
				mark("firstRebirth")
				break
			end
		end
	end
	return reached
end

local function fmt(seconds: number?): string
	if not seconds then
		return "   n/a"
	end
	if seconds < 120 then
		return string.format("%5.0fs", seconds)
	elseif seconds < 7200 then
		return string.format("%5.1fm", seconds / 60)
	end
	return string.format("%5.2fh", seconds / 3600)
end

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
	legendaryShovel = "",
	firstRebirth = "3-4h",
}

print(string.format("Pacing over %d simulated players at pace %.1f (median / p10 / p90):\n", runs, PACE))
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
