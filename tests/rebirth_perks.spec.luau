-- Rebirth perks (Logic/RebirthPerks) and their effects.

local RebirthPerks = requireShared("Logic/RebirthPerks")
local PerkConfig = requireShared("Config/RebirthPerks")
local DataSchema = requireShared("Logic/DataSchema")
local Perks = requireShared("Logic/Perks")
local Bonuses = requireShared("Logic/Bonuses")

test("each rebirth gives a set of different perk cards", function()
	local data = DataSchema.template()
	data.rebirths = 2
	expect.truthy(RebirthPerks.grantChoices(data, seededRng(1)), "added")
	expect.eq(#data.perkChoices, 2)
	expect.eq(data.perksEarned, 2)
	local set = data.perkChoices[1]
	expect.eq(#set, PerkConfig.choices)
	expect.truthy(set[1] ~= set[2] and set[2] ~= set[3] and set[1] ~= set[3], "different cards")
	-- Nothing new until the next rebirth.
	expect.eq(RebirthPerks.grantChoices(data, seededRng(2)), false)
	expect.eq(#data.perkChoices, 2)
end)

test("picking a card levels the perk; only offered cards count", function()
	local data = DataSchema.template()
	data.rebirths = 1
	RebirthPerks.grantChoices(data, seededRng(4))
	local set = data.perkChoices[1]
	local notOffered = nil
	for _, perk in PerkConfig.list do
		if not table.find(set, perk.id) then
			notOffered = perk.id
			break
		end
	end
	expect.eq(RebirthPerks.choose(data, notOffered), false)
	expect.eq(RebirthPerks.choose(data, set[2]), true)
	expect.eq(RebirthPerks.level(data, set[2]), 1)
	expect.eq(#data.perkChoices, 0)
	expect.eq(RebirthPerks.choose(data, set[1]), false)
end)

test("maxed perks aren't offered", function()
	local data = DataSchema.template()
	for _, perk in PerkConfig.list do
		data.rebirthPerks[perk.id] = perk.max
	end
	data.rebirthPerks.Lucky = 0
	local set = RebirthPerks.roll(data, seededRng(9))
	expect.eq(#set, 1)
	expect.eq(set[1], "Lucky")
end)

test("perks do what they say", function()
	local data = DataSchema.template()
	local bag = Perks.bagCapacity(data)
	local cash = Bonuses.cashMultiplier(data, 0, 0)
	data.rebirthPerks = { BigPockets = 2, Haggler = 2 }
	expect.eq(Perks.bagCapacity(data), bag + 2)
	expect.near(Bonuses.cashMultiplier(data, 0, 0), cash + 0.1, 1e-9)
	expect.eq(RebirthPerks.describe("Haggler", 2), "+10% cash on every treasure")
	expect.eq(RebirthPerks.describe("BigPockets", 3), "+3 bag space")
	expect.eq(RebirthPerks.describe("Collector", 1), "New finds are worth x2 + 0.5")
end)
