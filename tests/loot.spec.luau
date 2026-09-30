local LootRoller = requireShared("Logic/LootRoller")
local Treasures = requireShared("Config/Treasures")
local Rarities = requireShared("Config/Rarities")
local Areas = requireShared("Config/Areas")

test("beach pools only contain beach treasures", function()
	for _, rarity in { "Common", "Uncommon", "Rare" } do
		local pool = LootRoller.getPool("Beach", rarity)
		expect.truthy(#pool > 0, "Beach " .. rarity .. " pool empty")
		for _, def in pool do
			expect.eq(def.area, "Beach")
			expect.eq(def.rarity, rarity)
		end
	end
end)

test("areas without native commons fall back to earlier areas", function()
	local pool = LootRoller.getPool("Jungle", "Common")
	expect.truthy(#pool > 0)
	for _, def in pool do
		expect.eq(def.area, "Beach")
	end
end)

test("every rarity with odds in an area has a non-empty pool", function()
	for _, areaId in Areas.Order do
		for rarity, chance in Areas.Defs[areaId].odds do
			if chance > 0 then
				expect.truthy(#LootRoller.getPool(areaId, rarity) > 0, areaId .. "/" .. rarity)
			end
		end
	end
end)

test("rollRarity walks the odds table in rarity order", function()
	local odds = { Common = 70, Uncommon = 25, Rare = 5 }
	expect.eq(LootRoller.rollRarity(odds, scriptedRng({ 0 })), "Common")
	expect.eq(LootRoller.rollRarity(odds, scriptedRng({ 0.6999 })), "Common")
	expect.eq(LootRoller.rollRarity(odds, scriptedRng({ 0.70 })), "Uncommon")
	expect.eq(LootRoller.rollRarity(odds, scriptedRng({ 0.9499 })), "Uncommon")
	expect.eq(LootRoller.rollRarity(odds, scriptedRng({ 0.95 })), "Rare")
	expect.eq(LootRoller.rollRarity(odds, scriptedRng({ 0.99999 })), "Rare")
end)

test("beach distribution matches configured odds over many rolls", function()
	local rng = seededRng(12345)
	local counts = {}
	local n = 200000
	for _ = 1, n do
		local roll = LootRoller.roll("Beach", rng)
		counts[roll.rarity] = (counts[roll.rarity] or 0) + 1
	end
	expect.near(counts.Common / n, 0.70, 0.01, "Common share")
	expect.near(counts.Uncommon / n, 0.25, 0.01, "Uncommon share")
	expect.near(counts.Rare / n, 0.05, 0.005, "Rare share")
	expect.eq(counts.Epic, nil)
end)

test("volcano can roll secrets at roughly 0.2%", function()
	local rng = seededRng(777)
	local secrets, n = 0, 300000
	for _ = 1, n do
		if LootRoller.roll("Volcano", rng).rarity == "Secret" then
			secrets += 1
		end
	end
	expect.near(secrets / n, 0.002, 0.0006)
end)

test("rolled values stay within +/-10% of base", function()
	local rng = seededRng(99)
	for _ = 1, 5000 do
		local roll = LootRoller.roll("Beach", rng)
		local base = Treasures.ById[roll.id].value
		expect.truthy(
			roll.value >= math.floor(base * 0.9) and roll.value <= math.ceil(base * 1.1),
			roll.id .. " value " .. roll.value
		)
		expect.truthy(roll.value >= 1)
	end
end)

test("minRarity removes lower rarities", function()
	local rng = seededRng(5)
	for _ = 1, 2000 do
		local roll = LootRoller.roll("Beach", rng, { minRarity = "Rare" })
		expect.eq(roll.rarity, "Rare")
	end
end)

test("minRarity above what an area offers falls back to its best rarity", function()
	local roll = LootRoller.roll("Beach", seededRng(1), { minRarity = "Epic" })
	expect.eq(roll.rarity, "Rare")
	expect.truthy(Rarities.rank(roll.rarity) > 0)
end)
