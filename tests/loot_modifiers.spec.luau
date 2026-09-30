local LootRoller = requireShared("Logic/LootRoller")
local Streak = requireShared("Logic/Streak")
local Guarantees = requireShared("Logic/Guarantees")
local Loot = requireShared("Config/Loot")
local Rarities = requireShared("Config/Rarities")
local DataSchema = requireShared("Logic/DataSchema")

local function rareShare(options, seed)
	local rng = seededRng(seed)
	local rare, n = 0, 100000
	for _ = 1, n do
		if Rarities.rank(LootRoller.roll("Beach", rng, options).rarity) >= Rarities.rank("Rare") then
			rare += 1
		end
	end
	return rare / n
end

test("clue spots clearly raise the chance of Rare+", function()
	local normal = rareShare(nil, 11)
	local clue = rareShare({ oddsMultipliers = Loot.clueOddsMultipliers }, 11)
	expect.near(normal, 0.05, 0.006, "normal beach rare share")
	expect.truthy(clue > normal * 2, string.format("clue share %.3f vs normal %.3f", clue, normal))
end)

test("every clue type and rarity multiplier is well formed", function()
	expect.truthy(#Loot.clueTypes >= 4)
	for _, rarity in Rarities.Order do
		expect.truthy((Loot.clueOddsMultipliers[rarity] or 0) > 0, rarity .. " multiplier")
	end
	expect.truthy(Loot.clueChance > 0 and Loot.clueChance < 1)
end)

test("mutation roll frequencies and multipliers", function()
	local rng = seededRng(4242)
	local counts, n = { Shiny = 0, Golden = 0 }, 400000
	for _ = 1, n do
		local id, mult = LootRoller.rollMutation(rng)
		if id then
			counts[id] += 1
			expect.eq(mult, LootRoller.mutationMultiplier(id))
		else
			expect.eq(mult, 1)
		end
	end
	expect.near(counts.Golden / n, 1 / 250, 0.0008, "Golden rate")
	expect.near(counts.Shiny / n, 1 / 40, 0.002, "Shiny rate")
	expect.eq(LootRoller.mutationMultiplier("Shiny"), 3)
	expect.eq(LootRoller.mutationMultiplier("Golden"), 10)
	expect.eq(LootRoller.mutationMultiplier(nil), 1)
end)

test("streak grows inside the window, resets quietly outside it", function()
	local state = Streak.new()
	expect.eq(Streak.onDig(state, 100), 1)
	expect.eq(Streak.onDig(state, 105), 2)
	expect.eq(Streak.onDig(state, 105 + Loot.streak.window), 3)
	expect.eq(Streak.onDig(state, 200), 1)
	expect.eq(Streak.bonus(1), 0)
	expect.near(Streak.bonus(3), 2 * Loot.streak.bonusPerStep, 1e-9)
	expect.eq(Streak.bonus(1000), Loot.streak.maxBonus)
end)

local function freshOnboarding()
	return DataSchema.template().onboarding
end

test("first Rare is forced by dig 10 at the latest, then never again", function()
	for seed = 1, 50 do
		local onboarding = freshOnboarding()
		local rng = seededRng(seed)
		local forcedAt = nil
		for dig = 1, 10 do
			local minRarity = Guarantees.beforeRoll(onboarding, "Beach", dig, dig * 5, rng)
			if minRarity then
				expect.eq(minRarity, "Rare")
				forcedAt = dig
				Guarantees.afterRoll(onboarding, "Rare")
				break
			end
			Guarantees.afterRoll(onboarding, "Common")
		end
		expect.truthy(
			forcedAt and forcedAt >= Loot.guarantees.rareByDig.min and forcedAt <= 10,
			"seed " .. seed
		)
		expect.eq(Guarantees.beforeRoll(onboarding, "Beach", 11, 100, rng), nil)
	end
end)

test("a lucky natural Rare cancels the forced one", function()
	local onboarding = freshOnboarding()
	local rng = seededRng(3)
	Guarantees.beforeRoll(onboarding, "Beach", 1, 0, rng)
	Guarantees.afterRoll(onboarding, "Rare")
	for dig = 2, 20 do
		expect.eq(Guarantees.beforeRoll(onboarding, "Beach", dig, dig, rng), nil)
	end
end)

test("first Jungle Epic is forced within 5 minutes of Jungle digging", function()
	for seed = 1, 30 do
		local onboarding = freshOnboarding()
		onboarding.firstRareFound = true
		local rng = seededRng(seed)
		local t, forcedAt = 1000, nil
		while t < 1000 + 400 do
			local minRarity = Guarantees.beforeRoll(onboarding, "Jungle", 50, t, rng)
			if minRarity == "Epic" then
				forcedAt = t - 1000
				break
			end
			Guarantees.afterRoll(onboarding, "Rare")
			t += 6
		end
		expect.truthy(forcedAt and forcedAt <= 300, "seed " .. seed .. " forced at " .. tostring(forcedAt))
	end
end)

test("Jungle time ignores long breaks and Beach digs", function()
	local onboarding = freshOnboarding()
	onboarding.firstRareFound = true
	local rng = seededRng(9)
	Guarantees.beforeRoll(onboarding, "Jungle", 1, 5000, rng)
	Guarantees.beforeRoll(onboarding, "Jungle", 2, 15000, rng) -- came back hours later
	expect.eq(onboarding.jungleSeconds, Loot.guarantees.jungleGapCap)
	Guarantees.beforeRoll(onboarding, "Beach", 3, 15010, rng)
	expect.eq(onboarding.jungleSeconds, Loot.guarantees.jungleGapCap)
end)

test("migration to v2 skips guarantees for players who already had them", function()
	local veteran = DataSchema.migrate({
		schemaVersion = 1,
		discovered = { GoldCoin = { normal = true } },
		stats = { digs = 3 },
		onboarding = { funnelStep = 4 },
	})
	expect.eq(veteran.schemaVersion, 2)
	expect.eq(veteran.onboarding.firstRareFound, true)
	expect.eq(veteran.onboarding.firstEpicFound, false)
	expect.eq(veteran.onboarding.funnelStep, 4)

	local busy = DataSchema.migrate({ schemaVersion = 1, stats = { digs = 40 } })
	expect.eq(busy.onboarding.firstRareFound, true)

	local newish = DataSchema.migrate({ schemaVersion = 1, stats = { digs = 2 } })
	expect.eq(newish.onboarding.firstRareFound, false)
	expect.eq(newish.onboarding.rareGuaranteeDig, 0)
end)

test("bag items keep their mutation through save sanitizing", function()
	local data = DataSchema.migrate({
		schemaVersion = 2,
		bagContents = {
			{ id = "Pearl", v = 450, m = "Shiny" },
			{ id = "Shell", v = 150, m = "Golden" },
			{ id = "Bottle", v = 12, m = "Hacked" },
		},
	})
	expect.eq(data.bagContents[1].m, "Shiny")
	expect.eq(data.bagContents[2].m, "Golden")
	expect.eq(data.bagContents[3].m, nil)
end)
