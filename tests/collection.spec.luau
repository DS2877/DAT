local Collection = requireShared("Logic/Collection")
local CollectionConfig = requireShared("Config/Collection")
local Treasures = requireShared("Config/Treasures")
local Loot = requireShared("Config/Loot")

local function discoverArea(discovered, areaId, except)
	for _, def in Treasures.List do
		if def.area == areaId and def.id ~= except then
			discovered[def.id] = { normal = true }
		end
	end
end

test("set progress counts base discoveries per area", function()
	local discovered = {}
	discoverArea(discovered, "Beach", "GoldCoin")
	local found, total = Collection.setProgress(discovered, "Beach")
	expect.eq(total, 10)
	expect.eq(found, 9)
	expect.eq(#Collection.completedSets(discovered), 0)
	expect.eq(Collection.cashMultiplier(discovered), 1)
end)

test("a shiny-only discovery still counts for the set", function()
	local discovered = {}
	discoverArea(discovered, "Beach", "GoldCoin")
	discovered.GoldCoin = { shiny = true }
	expect.eq(#Collection.completedSets(discovered), 1)
	expect.near(Collection.cashMultiplier(discovered), 1 + CollectionConfig.setBonus, 1e-9)
end)

test("completed sets stack their bonus", function()
	local discovered = {}
	discoverArea(discovered, "Beach")
	discoverArea(discovered, "Jungle")
	expect.near(Collection.cashMultiplier(discovered), 1 + 2 * CollectionConfig.setBonus, 1e-9)
end)

test("totals split base, shiny and golden", function()
	local discovered =
		{ Shell = { normal = true, shiny = true }, Pearl = { golden = true }, Unknown = { normal = true } }
	local normal, shiny, golden, total = Collection.totals(discovered)
	expect.eq(normal, 2)
	expect.eq(shiny, 1)
	expect.eq(golden, 1)
	expect.eq(total, #Treasures.List)
end)

test("best find ranks rarity first, then mutated value", function()
	expect.truthy(Collection.isBetter({ id = "Shell" }, nil))
	expect.truthy(Collection.isBetter({ id = "GoldCoin" }, { id = "PirateMug", m = "Golden" }))
	expect.truthy(Collection.isBetter({ id = "Shell", m = "Golden" }, { id = "BrokenCompass" }))
	expect.truthy(not Collection.isBetter({ id = "Shell" }, { id = "Shell" }))
	expect.truthy(Collection.isBetter({ id = "ForbiddenTreasure" }, { id = "Meteorite", m = "Golden" }))
end)

test("deep dig config is sane", function()
	for area, deep in Loot.deepDig.areas do
		expect.truthy(deep.chance > 0 and deep.chance < 0.2, area .. " deep dig chance")
		expect.truthy(deep.extraHits >= 10, area .. " deep digs take a while")
	end
	expect.eq(Loot.deepDig.areas.Beach, nil)
	expect.eq(Loot.deepDig.areas.Volcano.minRarity, "Legendary")
	expect.truthy(Loot.deepDig.areas.Volcano.chance > Loot.deepDig.areas.Jungle.chance, "deeper = more often")
	expect.eq(Loot.firstFindMultiplier, 2)
end)
