-- Pets you dig up (Logic/Pets, Config/Pets).

local Pets = requireShared("Logic/Pets")
local Config = requireShared("Config/Pets")
local Rarities = requireShared("Config/Rarities")

local function fresh()
	return { pets = { owned = {}, equipped = "", digsSinceEgg = 0, eggs = 0 } }
end

test("every area of both worlds hatches something", function()
	for _, world in { "Island", "Frost" } do
		for _, area in { "Beach", "Jungle", "Ruins", "Volcano" } do
			expect.truthy(#Pets.pool(world, area) > 0, world .. " " .. area)
		end
	end
	local seen = {}
	for _, pet in Config.list do
		expect.truthy(not seen[pet.id], "unique id " .. pet.id)
		seen[pet.id] = true
		expect.truthy(
			Config.bonus[pet.rarity] ~= nil and Config.weights[pet.rarity] ~= nil,
			pet.id .. " rarity"
		)
		expect.truthy(Rarities.Info[pet.rarity] ~= nil, pet.id .. " is a real rarity")
		expect.truthy(#pet.parts >= 4, pet.id .. " has a model")
	end
end)

test("the first egg comes early, then the pity timer", function()
	local data = fresh()
	local digs = 0
	repeat
		digs += 1
	until Pets.rollEgg(data, {}, 0.999) or digs > 1000
	expect.eq(digs, Config.firstEggAt)
	expect.eq(data.pets.eggs, 1)
	digs = 0
	repeat
		digs += 1
	until Pets.rollEgg(data, {}, 0.999) or digs > 1000
	expect.eq(digs, Config.pity)
	-- Special digs turn up more eggs.
	expect.near(Pets.eggChance(data, { meteor = true }), Config.eggChance * Config.multipliers.meteor, 1e-9)
end)

test("hatching: new, level up, maxed; the first pet comes out", function()
	local data = fresh()
	expect.eq(Pets.hatch(data, "Crab"), "New")
	expect.eq(Pets.equipped(data), "Crab")
	expect.eq(Pets.hatch(data, "Turtle"), "New")
	expect.eq(Pets.equipped(data), "Crab")
	for _ = 2, Config.maxLevel do
		expect.eq(Pets.hatch(data, "Crab"), "LevelUp")
	end
	expect.eq(Pets.level(data, "Crab"), Config.maxLevel)
	expect.eq(Pets.hatch(data, "Crab"), "Maxed")
	expect.eq(Pets.level(data, "Crab"), Config.maxLevel)
	expect.eq(Pets.count(data), 2)
end)

test("only your pets come out, and the one that's out pays", function()
	local data = fresh()
	expect.eq(Pets.equip(data, "Phoenix"), false)
	Pets.hatch(data, "Phoenix")
	expect.near(Pets.cashBonus(data), Config.bonus.Epic, 1e-9)
	Pets.hatch(data, "Phoenix")
	expect.near(Pets.cashBonus(data), Config.bonus.Epic + Config.perLevel, 1e-9)
	expect.eq(Pets.equip(data, ""), true)
	expect.eq(Pets.cashBonus(data), 0)
	expect.eq(Pets.cashBonus({}), 0) -- old saves
end)

test("rarer pets hatch less often", function()
	local counts = {}
	for i = 0, 999 do
		local id = Pets.pick("Island", "Volcano", i / 1000)
		counts[id] = (counts[id] or 0) + 1
	end
	expect.truthy(counts.Salamander > counts.Phoenix, "Rare beats Epic")
	expect.truthy(counts.Phoenix > 0, "Epic still possible")
end)
