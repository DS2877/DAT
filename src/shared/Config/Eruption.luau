--!strict
-- The volcano eruption (EruptionService, EruptionController): every
-- `interval` seconds (on one clock for every server, `offset` into it) the
-- volcano rumbles for `rumble` seconds, then erupts: the sky turns red and
-- `meteors` fireballs arc out of the crater over `erupt` seconds. Each lands
-- somewhere on the island as a smoking meteor dig spot with much better odds
-- (rolled from the area it lands in). Unclaimed ones cool off after
-- `linger` seconds. In Frostbite Peaks the Frozen Peak sends comets instead.

local Eruption = {
	interval = 1800, -- every 30 minutes
	offset = 300, -- at :05 and :35 (between Treasure Rush and the Mega Dig)
	rumble = 30,
	erupt = 20,
	meteors = 10,
	flight = 3.5, -- seconds a fireball is in the air
	linger = 240,
	-- How the landing spots spread over the areas (weights).
	areaWeights = { Beach = 3, Jungle = 3, Ruins = 2, Volcano = 2 } :: { [string]: number },
	oddsMultipliers = {
		Common = 0.2,
		Uncommon = 0.6,
		Rare = 2,
		Epic = 3,
		Legendary = 4,
		Mythic = 5,
		Secret = 5,
	} :: { [string]: number },
	color = "#FF6A1A",
	frostColor = "#7FDBFF",
}

return table.freeze(Eruption)
