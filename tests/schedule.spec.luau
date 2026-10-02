-- Shared-clock schedules (Logic/Schedule) and the eruption config.

local Schedule = requireShared("Logic/Schedule")
local Eruption = requireShared("Config/Eruption")
local Rarities = requireShared("Config/Rarities")

test("the next start is always ahead, on the offset", function()
	expect.eq(Schedule.nextStart(0, 1800, 300), 300)
	expect.eq(Schedule.nextStart(299.9, 1800, 300), 300)
	expect.eq(Schedule.nextStart(300, 1800, 300), 2100)
	expect.eq(Schedule.nextStart(1_000_000, 1800, 300), 1_000_000 - (1_000_000 - 300) % 1800 + 1800)
end)

test("an eruption fits its own interval and boosts the rare stuff", function()
	expect.truthy(Eruption.rumble + Eruption.erupt + Eruption.flight < Eruption.interval, "fits")
	expect.truthy(Eruption.linger < Eruption.interval, "meteor spots cool off before the next one")
	for _, rarity in Rarities.Order do
		expect.truthy(Eruption.oddsMultipliers[rarity] ~= nil, "a multiplier for " .. rarity)
	end
	expect.truthy(Eruption.oddsMultipliers.Common < 1 and Eruption.oddsMultipliers.Legendary > 1, "rarer")
end)
