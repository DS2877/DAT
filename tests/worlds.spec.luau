-- Worlds: Frostbite Peaks' configs and the per-world runs in the save.

local WorldState = requireShared("Logic/WorldState")
local DataSchema = requireShared("Logic/DataSchema")
local IslandTreasures = requireShared("Config/Treasures")
local IslandScore = requireShared("Logic/LeaderboardScore")

local frost = requireSharedIn("Frost")
local FrostWorld = frost("Logic/CurrentWorld")
local FrostTreasures = frost("Config/Treasures")
local FrostUpgrades = frost("Config/Upgrades")
local FrostAreas = frost("Config/Areas")
local FrostLoot = frost("Logic/LootRoller")
local FrostRebirth = frost("Logic/Rebirth")
local FrostGoals = frost("Logic/Goals")
local FrostScore = frost("Logic/LeaderboardScore")
local Rarities = frost("Config/Rarities")

test("the island is the default world", function()
	expect.eq(requireShared("Logic/CurrentWorld").id(), "Island")
	expect.eq(FrostWorld.id(), "Frost")
	for _, def in IslandTreasures.List do
		expect.eq(def.world, nil, def.id)
	end
end)

test("Frostbite Peaks has its own treasures, shovels, bags and areas", function()
	expect.truthy(#FrostTreasures.List >= 30, "frost treasures")
	for _, def in FrostTreasures.List do
		expect.eq(def.world, "Frost", def.id)
		expect.truthy(FrostAreas.Defs[def.area] ~= nil, def.id .. " area")
	end
	-- Every world's treasures are known everywhere (bags, trophies, boards).
	expect.eq(#FrostTreasures.All, #IslandTreasures.All)
	expect.truthy(
		FrostTreasures.ById.Pearl ~= nil and IslandTreasures.ById.FrostHeart ~= nil,
		"ById covers all"
	)
	expect.eq(FrostUpgrades.Shovels[1].name, "Frostbite Shovel")
	expect.eq(FrostUpgrades.Bags[1].name, "Fur Pouch")
	expect.eq(FrostAreas.Defs.Beach.displayName, "Frost Shore")
	expect.eq(FrostAreas.Defs.Volcano.displayName, "Frozen Peak")
	for i = 2, #FrostUpgrades.Shovels do
		expect.truthy(
			FrostUpgrades.Shovels[i].cost > FrostUpgrades.Shovels[i - 1].cost,
			"shovel prices climb"
		)
		local material = FrostUpgrades.Shovels[i].bladeMaterial
		expect.truthy(
			material == "Ice"
				or material == "Glass"
				or material == "Snow"
				or material == "Glacier"
				or material == "Neon",
			"blade material " .. material
		)
	end
end)

test("frost odds can always be rolled, and pay more than the island", function()
	for areaId, area in FrostAreas.Defs do
		for rarity, chance in area.odds do
			if chance > 0 then
				expect.truthy(#FrostLoot.getPool(areaId, rarity) > 0, areaId .. " " .. rarity)
			end
		end
	end
	local rng = seededRng(42)
	local total, n = 0, 400
	for _ = 1, n do
		local roll = FrostLoot.roll("Beach", rng)
		expect.truthy(string.sub(roll.id, 1, 5) == "Frost", roll.id)
		total += roll.value
	end
	expect.truthy(total / n > 500, "a Frost Shore dig is worth far more than a beach dig")
	expect.truthy(#FrostLoot.getPool("Volcano", "Secret") > 0, "secrets on the Frozen Peak")
	expect.truthy(Rarities.rank("Secret") > 0, "rarities")
end)

test("rebirths happen on the island only", function()
	local ok, reason = FrostRebirth.canRebirth({ shovelLevel = 8, cash = 1e12, rebirths = 3 })
	expect.eq(ok, false)
	expect.eq(reason, "IslandOnly")
	-- With the top shovel, the next goal is never a rebirth there.
	local goal = FrostGoals.current({ cash = 0, shovelLevel = 8, bagLevel = 3, rebirths = 3 })
	expect.eq(goal.kind, "Shovel")
	expect.eq(goal.name, FrostUpgrades.Bags[4].name)
end)

test("leaderboard codes are the same in every world", function()
	expect.eq(FrostScore.encode("Pearl", nil), IslandScore.encode("Pearl", nil))
	local code = FrostScore.encode("FrostHeart", "Golden")
	expect.eq(IslandScore.decode(code), "FrostHeart")
	local id, mutation = FrostScore.decode(code)
	expect.eq(id, "FrostHeart")
	expect.eq(mutation, "Golden")
end)

test("a world's run swaps in on load and back out for saving", function()
	local data = DataSchema.migrate(nil)
	data.cash = 5000
	data.shovelLevel = 8
	data.bagContents = { { id = "Pearl", v = 150 } }
	data.rebirths = 3

	-- First visit: a fresh run.
	WorldState.enter(data, "Frost")
	expect.eq(data.cash, 0)
	expect.eq(data.shovelLevel, 1)
	expect.eq(#data.bagContents, 0)
	expect.eq(data.rebirths, 3)

	data.cash = 999
	data.bagContents = { { id = "FrostPearl", v = 1800 } }
	local stored = WorldState.stored(data, "Frost")
	expect.eq(stored.cash, 5000)
	expect.eq(stored.shovelLevel, 8)
	expect.eq(stored.bagContents[1].id, "Pearl")
	expect.eq(stored.worldSaves.Frost.cash, 999)
	expect.eq(stored.worldSaves.Frost.bagContents[1].id, "FrostPearl")
	expect.eq(stored.worldSaves.Island, nil)
	expect.eq(data.cash, 999) -- the live data isn't touched

	-- Back on the island: the stored profile is the island run as before,
	-- with the frost run kept aside.
	local island = DataSchema.migrate(stored)
	WorldState.enter(island, "Island")
	expect.eq(island.cash, 5000)
	expect.eq(island.worldSaves.Frost.cash, 999)

	-- And the next frost visit picks the frost run up again.
	local again = DataSchema.migrate(stored)
	WorldState.enter(again, "Frost")
	expect.eq(again.cash, 999)
	expect.eq(again.bagContents[1].id, "FrostPearl")
end)

test("a profile reset in Frostbite Peaks resets the island run too", function()
	local data = DataSchema.template()
	data.cash = 42 -- the frost run after the reset
	local stored = WorldState.stored(data, "Frost")
	expect.eq(stored.cash, 0)
	expect.eq(stored.shovelLevel, 1)
	expect.eq(stored.worldSaves.Frost.cash, 42)
end)

test("broken world saves fall back to a fresh run", function()
	local data = DataSchema.migrate(nil)
	data.worldSaves = { Frost = { cash = "lots", shovelLevel = 3 } }
	WorldState.enter(data, "Frost")
	expect.eq(data.cash, 0)
	expect.eq(data.shovelLevel, 3)
	expect.eq(data.bagLevel, 1)
end)
