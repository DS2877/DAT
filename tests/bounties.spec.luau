-- The Bounty Board's rules (Logic/Bounties).

local Bounties = requireShared("Logic/Bounties")
local BountyConfig = requireShared("Config/Bounties")
local DataSchema = requireShared("Logic/DataSchema")
local Treasures = requireShared("Config/Treasures")

local function player(shovelLevel: number)
	local data = DataSchema.template()
	data.shovelLevel = shovelLevel
	return data
end

test("the board fills up with different bounties", function()
	local rng = seededRng(7)
	for _ = 1, 40 do
		local data = player(1)
		local state = {}
		Bounties.ensure(state, data, rng)
		expect.eq(#state.slots, BountyConfig.slots)
		expect.eq(state.completed, 0)
		local seen = {}
		for _, b in state.slots do
			expect.truthy(not seen[Bounties.key(b)], "duplicate " .. Bounties.key(b))
			seen[Bounties.key(b)] = true
			expect.truthy(b.target >= 1, "target")
			expect.eq(b.progress, 0)
			expect.truthy(Bounties.describe(b) ~= "?", "described: " .. b.kind)
			-- A beginner (Beach only) never gets an Epic bounty or one elsewhere.
			expect.truthy(not (b.kind == "Rarity" and b.param == "Epic"), "no Epic bounty on the Beach")
			if b.kind == "DigArea" then
				expect.eq(b.param, "Beach")
			end
			if b.kind == "Treasure" then
				local def = Treasures.ById[b.param]
				expect.truthy(def and def.area == "Beach", "a Beach treasure")
			end
		end
	end
end)

test("progress counts the right events", function()
	local dig = { kind = "DigArea", target = 2, param = "Jungle", progress = 0, reward = {} }
	expect.eq(
		Bounties.progress(
			dig,
			{ type = "Find", areaId = "Beach", rarity = "Common", id = "Shell", junk = false }
		),
		false
	)
	expect.eq(
		Bounties.progress(
			dig,
			{ type = "Find", areaId = "Jungle", rarity = "Rare", id = "Ruby", junk = false }
		),
		true
	)
	Bounties.progress(dig, { type = "Find", areaId = "Jungle", rarity = "Rare", id = "Ruby", junk = false })
	expect.truthy(Bounties.isDone(dig), "done")
	expect.eq(
		Bounties.progress(
			dig,
			{ type = "Find", areaId = "Jungle", rarity = "Rare", id = "Ruby", junk = false }
		),
		false
	)

	local rare = { kind = "Rarity", target = 2, param = "Rare", progress = 0, reward = {} }
	Bounties.progress(
		rare,
		{ type = "Find", areaId = "Beach", rarity = "Uncommon", id = "Pearl", junk = false }
	)
	Bounties.progress(rare, { type = "Find", areaId = "Beach", rarity = "Epic", id = "X", junk = false })
	expect.eq(rare.progress, 1)

	local junk = { kind = "Junk", target = 1, progress = 0, reward = {} }
	Bounties.progress(
		junk,
		{ type = "Find", areaId = "Beach", rarity = "Common", id = "OldBoot", junk = true }
	)
	expect.truthy(Bounties.isDone(junk), "junk counted")

	local perfect = { kind = "Perfect", target = 3, progress = 0, reward = {} }
	Bounties.progress(perfect, { type = "Perfect" })
	expect.eq(perfect.progress, 1)

	local sell = { kind = "Sell", target = 1000, progress = 0, reward = {} }
	Bounties.progress(sell, { type = "Sell", amount = 700 })
	Bounties.progress(sell, { type = "Sell", amount = 700 })
	expect.eq(sell.progress, 1000)
	expect.eq(Bounties.progressText(sell), "$1,000 / $1,000")
end)

test("later players get bounties from all their areas", function()
	local rng = seededRng(3)
	local areas = {}
	local epic = false
	for _ = 1, 200 do
		local b = Bounties.generate(player(8), rng)
		if b.kind == "DigArea" then
			areas[b.param] = true
		end
		epic = epic or (b.kind == "Rarity" and b.param == "Epic")
	end
	expect.truthy(areas.Volcano and areas.Beach, "areas from the Beach to the Volcano")
	expect.truthy(epic, "Epic bounties once past the Beach")
end)
