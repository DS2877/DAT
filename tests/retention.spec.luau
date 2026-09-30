local Rebirth = requireShared("Logic/Rebirth")
local Daily = requireShared("Logic/Daily")
local Rush = requireShared("Logic/Rush")
local Boosts = requireShared("Logic/Boosts")
local Bonuses = requireShared("Logic/Bonuses")
local LeaderboardScore = requireShared("Logic/LeaderboardScore")
local LootRoller = requireShared("Logic/LootRoller")
local Collection = requireShared("Logic/Collection")
local DataSchema = requireShared("Logic/DataSchema")
local Retention = requireShared("Config/Retention")
local Treasures = requireShared("Config/Treasures")

test("rebirth needs the Legendary Shovel and enough cash, then resets the run", function()
	local data = DataSchema.template()
	data.shovelLevel = 7
	data.cash = 1e9
	local ok, reason = Rebirth.canRebirth(data)
	expect.eq(ok, false)
	expect.eq(reason, "NeedShovel")

	data.shovelLevel = 8
	data.cash = Rebirth.cost(0) - 10
	ok, reason = Rebirth.canRebirth(data)
	expect.eq(reason, "NotEnoughCash")

	data.cash = Rebirth.cost(0)
	data.bagLevel = 6
	data.bagContents = { { id = "Shell", v = 10 } }
	data.discovered = { Shell = { normal = true } }
	expect.eq((Rebirth.canRebirth(data)), true)
	Rebirth.apply(data)
	expect.eq(data.rebirths, 1)
	expect.eq(data.cash, 0)
	expect.eq(data.shovelLevel, 1)
	expect.eq(data.bagLevel, 1)
	expect.eq(#data.bagContents, 0)
	expect.truthy(data.discovered.Shell, "collection is kept")
end)

test("rebirth cost grows, titles and tints exist for every count", function()
	expect.truthy(Rebirth.cost(1) > Rebirth.cost(0))
	expect.eq(Rebirth.title(0), "")
	expect.eq(Rebirth.title(1), Retention.rebirth.titles[1])
	expect.truthy(#Rebirth.title(50) > 0)
	expect.eq(Rebirth.tint(0), nil)
	for r = 1, 30 do
		expect.truthy(Rebirth.tint(r), "tint " .. r)
	end
	expect.eq(Rebirth.secretTier(4), 0)
	expect.eq(Rebirth.secretTier(5), 1)
end)

test("rebirth-only secrets need their rebirth count and stay out of sets", function()
	local function secretIds(rebirths)
		local ids = {}
		for _, def in LootRoller.getPool("Volcano", "Secret", rebirths) do
			ids[def.id] = true
		end
		return ids
	end
	expect.eq(secretIds(0).RainbowSkull, nil)
	expect.eq(secretIds(5).RainbowSkull, true)
	expect.eq(secretIds(5).CrystalDragonEgg, nil)
	expect.eq(secretIds(15).CosmicCrown, true)

	local discovered = {}
	for _, def in Treasures.List do
		if def.area == "Volcano" and def.rebirths == nil then
			discovered[def.id] = { normal = true }
		end
	end
	expect.eq(#Collection.completedSets(discovered), 1)
end)

test("daily calendar: claim once per day, streak advances, missed day restarts", function()
	local state = DataSchema.template().dailyState
	expect.eq(Daily.claim(state, 100), 1)
	expect.eq(Daily.claim(state, 100), nil) -- same day
	expect.eq(Daily.claim(state, 101), 2)
	local can, day = Daily.status(state, 101)
	expect.eq(can, false)
	expect.eq(day, 3)
	for d = 102, 106 do
		Daily.claim(state, d)
	end
	expect.eq(state.streak, 7)
	expect.eq(Daily.claim(state, 107), 1) -- wraps after day 7
	expect.eq(Daily.claim(state, 110), 1) -- missed days restart at 1
	expect.eq(#Retention.daily, 7)
end)

test("rush runs for its duration every interval on a global clock", function()
	local interval, duration = Retention.rush.interval, Retention.rush.duration
	local base = interval * 1000
	local active, left = Rush.state(base + 10)
	expect.eq(active, true)
	expect.eq(left, duration - 10)
	active, left = Rush.state(base + duration + 5)
	expect.eq(active, false)
	expect.eq(left, interval - duration - 5)
	expect.eq(Rush.id(base + 1), Rush.id(base + interval - 1))
end)

test("boosts add, stack by extending, expire", function()
	local active = {}
	Boosts.add(active, "Cash2x", 300, 1000)
	expect.eq(Boosts.isActive(active, "Cash2x", 1200), true)
	expect.eq(Boosts.multiplier(active, "Cash2x", 1200), 2)
	Boosts.add(active, "Cash2x", 300, 1200)
	expect.eq(active.Cash2x, 1600)
	expect.eq(Boosts.isActive(active, "Cash2x", 1600), false)
	expect.eq(Boosts.multiplier(active, "Cash2x", 1700), 1)
	active.Bogus = 99999
	Boosts.prune(active, 1700)
	expect.eq(active.Cash2x, nil)
	expect.eq(active.Bogus, nil)
end)

test("cash multiplier combines sets, rebirths, friends and boosts", function()
	local data = DataSchema.template()
	expect.eq(Bonuses.cashMultiplier(data, 0, 0), 1)
	data.rebirths = 2
	expect.near(Bonuses.cashMultiplier(data, 0, 0), 1.5, 1e-9)
	expect.near(Bonuses.cashMultiplier(data, 5, 0), 1.5 * 1.3, 1e-9) -- friends capped at +30%
	Boosts.add(data.activeBoosts, "Cash2x", 60, 0)
	expect.near(Bonuses.cashMultiplier(data, 1, 10), 1.5 * 1.1 * 2, 1e-9)
end)

test("reward cash scales with the next goal and has a floor", function()
	local data = DataSchema.template()
	expect.eq(Bonuses.rewardCash({ goalPercent = 0.1, min = 100 }, data), 100) -- 10% of $250 < floor
	data.shovelLevel = 5 -- next: Rainbow $100,000
	expect.eq(Bonuses.rewardCash({ goalPercent = 0.1, min = 100 }, data), 10000)
end)

test("dig speed boost halves the hit interval", function()
	local data = DataSchema.template()
	expect.near(Bonuses.hitInterval(data, 0), 0.5, 1e-9)
	Boosts.add(data.activeBoosts, "DigSpeed2x", 60, 0)
	expect.near(Bonuses.hitInterval(data, 10), 0.25, 1e-9)
end)

test("rarest-find scores sort by rarity then value and decode back", function()
	local shell = LeaderboardScore.encode("Shell")
	local goldenShell = LeaderboardScore.encode("Shell", "Golden")
	local goldCoin = LeaderboardScore.encode("GoldCoin")
	local secret = LeaderboardScore.encode("ForbiddenTreasure")
	expect.truthy(goldenShell > shell)
	expect.truthy(goldCoin > goldenShell)
	expect.truthy(secret > goldCoin)
	for _, def in Treasures.List do
		for _, variant in { "", "Shiny", "Golden" } do
			local m = if variant == "" then nil else variant
			local id, mutation = LeaderboardScore.decode(LeaderboardScore.encode(def.id, m))
			expect.eq(id, def.id)
			expect.eq(mutation, m)
		end
	end
	expect.truthy(LeaderboardScore.encode("CosmicCrown", "Golden") < 2 ^ 53)
end)

test("old saves gain the Phase 4 fields without losing data", function()
	local data = DataSchema.migrate({ schemaVersion = 2, cash = 50, dailyState = {}, stats = { digs = 5 } })
	expect.eq(data.cash, 50)
	expect.eq(data.dailyState.lastDay, 0)
	expect.eq(data.digCharges.Rare, 0)
	expect.eq(data.weekly.week, 0)
	expect.eq(data.groupRewardClaimed, false)
end)
