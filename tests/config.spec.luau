-- Config integrity: catches typos and broken tuning before they ship.
local Areas = requireShared("Config/Areas")
local Monetization = requireShared("Config/Monetization")
local Rarities = requireShared("Config/Rarities")
local Treasures = requireShared("Config/Treasures")
local Upgrades = requireShared("Config/Upgrades")

test("area odds sum to 100", function()
	for _, areaId in Areas.Order do
		local total = 0
		for rarity, chance in Areas.Defs[areaId].odds do
			expect.truthy(Rarities.Info[rarity], areaId .. " has unknown rarity " .. rarity)
			total += chance
		end
		expect.near(total, 100, 1e-6, areaId .. " odds")
	end
end)

test("areas are ordered and gated by increasing shovel level", function()
	local lastShovel = 0
	for index, areaId in Areas.Order do
		local def = Areas.Defs[areaId]
		expect.eq(def.order, index, areaId .. " order")
		expect.truthy(def.requiredShovel >= lastShovel, areaId .. " shovel requirement")
		expect.truthy(def.requiredShovel <= #Upgrades.Shovels, areaId .. " requires a shovel that exists")
		lastShovel = def.requiredShovel
	end
	expect.eq(Areas.Defs.Beach.requiredShovel, 1)
	expect.eq(Areas.Defs.Beach.enabled, true)
end)

test("treasure values fall inside their rarity band", function()
	local bands = {
		Common = { 10, 100 },
		Uncommon = { 100, 500 },
		Rare = { 500, 2500 },
		Epic = { 2500, 10000 },
		Legendary = { 10000, 50000 },
		Mythic = { 50000, 250000 },
		Secret = { 250000, math.huge },
	}
	for _, def in Treasures.List do
		-- Junk is allowed to be worth a laughable amount.
		local band = if def.set == "Junk" then { 1, 100 } else bands[def.rarity]
		expect.truthy(band, def.id .. " unknown rarity")
		expect.truthy(Areas.Defs[def.area], def.id .. " unknown area")
		expect.truthy(def.value >= band[1] and def.value <= band[2], def.id .. " value outside band")
	end
end)

test("every area has at least one native treasure (its collection set)", function()
	for _, areaId in Areas.Order do
		local count = 0
		for _, def in Treasures.List do
			if def.area == areaId then
				count += 1
			end
		end
		expect.truthy(count >= 5, areaId .. " set too small")
	end
end)

test("upgrade ladders start free and get strictly more expensive and better", function()
	expect.eq(Upgrades.Shovels[1].cost, 0)
	expect.eq(Upgrades.Bags[1].cost, 0)
	for i = 2, #Upgrades.Shovels do
		local prev, cur = Upgrades.Shovels[i - 1], Upgrades.Shovels[i]
		expect.eq(cur.level, i)
		expect.truthy(cur.cost > prev.cost, cur.name .. " cost")
		expect.truthy(
			cur.hits * cur.hitInterval < prev.hits * prev.hitInterval,
			cur.name .. " must dig faster"
		)
	end
	for i = 2, #Upgrades.Bags do
		local prev, cur = Upgrades.Bags[i - 1], Upgrades.Bags[i]
		expect.eq(cur.level, i)
		expect.truthy(cur.cost > prev.cost, cur.name .. " cost")
		expect.truthy(cur.capacity > prev.capacity, cur.name .. " capacity")
	end
end)

test("spec numbers: wooden shovel digs in ~1.5s with 3 hits, bags 10..100", function()
	local wooden = Upgrades.Shovels[1]
	expect.eq(wooden.hits, 3)
	expect.near(wooden.hits * wooden.hitInterval, 1.5, 0.01)
	expect.eq(Upgrades.Bags[1].capacity, 5)
	expect.eq(Upgrades.Bags[2].capacity, 10)
	expect.truthy(Upgrades.Bags[2].cost <= 200, "the first bag upgrade is cheap")
	expect.truthy(Upgrades.Bags[3].cost >= 5000, "bigger bags are a real goal")
end)

test("every treasure's model archetype exists in TreasureBuilder", function()
	local source = readFile("src/shared/Builders/TreasureBuilder.luau")
	for _, def in Treasures.List do
		expect.truthy(
			source:find("function Archetypes." .. def.model .. "(", 1, true),
			def.id .. " uses missing archetype " .. def.model
		)
	end
end)

test("game passes are well formed", function()
	local ids = {}
	for name, pass in Monetization.Passes do
		expect.truthy(pass.id >= 0 and pass.id % 1 == 0, name .. " id must be 0 (not set up) or a pass id")
		expect.truthy(pass.id == 0 or not ids[pass.id], name .. " reuses another pass's id")
		ids[pass.id] = true
		expect.truthy(pass.price >= 1 and pass.price % 1 == 0, name .. " price must be whole Robux")
		expect.truthy(#pass.name > 0 and #pass.description > 0, name .. " needs a name and description")
	end
	local offers = Monetization.Offers
	expect.truthy(offers.offerCooldown >= 60, "offers must not nag (cooldown >= 60 s)")
	expect.truthy(offers.maxPerSession >= 1 and offers.visibleSeconds > 0, "offer limits")
end)
