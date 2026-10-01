--!strict
-- The four island areas. Unlocks are derived from shovel level (never saved).
-- `enabled = false` keeps an area's gate shut with an "opening soon" sign
-- (use it for areas whose content isn't ready yet).
-- Odds are percentages per rarity; missing rarities have 0% chance.

export type AreaDef = {
	id: string,
	order: number,
	displayName: string,
	requiredShovel: number,
	enabled: boolean,
	activeSpots: number,
	odds: { [string]: number },
}

local CurrentWorld = require(script.Parent.Parent.Logic.CurrentWorld)

local Areas = {}

Areas.Order = { "Beach", "Jungle", "Ruins", "Volcano" }

Areas.Defs = {
	Beach = {
		id = "Beach",
		order = 1,
		displayName = "Beach",
		requiredShovel = 1,
		enabled = true,
		activeSpots = 22,
		odds = { Common = 70, Uncommon = 25, Rare = 5 },
	},
	Jungle = {
		id = "Jungle",
		order = 2,
		displayName = "Jungle",
		requiredShovel = 3,
		enabled = true,
		activeSpots = 25,
		odds = { Common = 45, Uncommon = 35, Rare = 15, Epic = 4.5, Legendary = 0.5 },
	},
	Ruins = {
		id = "Ruins",
		order = 3,
		displayName = "Ancient Ruins",
		requiredShovel = 5,
		enabled = true,
		activeSpots = 25,
		odds = { Common = 25, Uncommon = 35, Rare = 25, Epic = 12, Legendary = 2.8, Mythic = 0.2 },
	},
	Volcano = {
		id = "Volcano",
		order = 4,
		displayName = "Volcano",
		requiredShovel = 7,
		enabled = true,
		activeSpots = 25,
		odds = {
			Common = 10,
			Uncommon = 25,
			Rare = 30,
			Epic = 22,
			Legendary = 10,
			Mythic = 2.8,
			Secret = 0.2,
		},
	},
} :: { [string]: AreaDef }

-- Frostbite Peaks: the same four areas on the same map (same ids), as frost
-- biomes, with better odds.
if CurrentWorld.isFrost() then
	Areas.Defs = {
		Beach = {
			id = "Beach",
			order = 1,
			displayName = "Frost Shore",
			requiredShovel = 1,
			enabled = true,
			activeSpots = 22,
			odds = { Common = 62, Uncommon = 29, Rare = 9 },
		},
		Jungle = {
			id = "Jungle",
			order = 2,
			displayName = "Pine Woods",
			requiredShovel = 3,
			enabled = true,
			activeSpots = 25,
			odds = { Common = 38, Uncommon = 36, Rare = 18, Epic = 7, Legendary = 1 },
		},
		Ruins = {
			id = "Ruins",
			order = 3,
			displayName = "Ice Ruins",
			requiredShovel = 5,
			enabled = true,
			activeSpots = 25,
			odds = { Common = 20, Uncommon = 33, Rare = 27, Epic = 15, Legendary = 4.5, Mythic = 0.5 },
		},
		Volcano = {
			id = "Volcano",
			order = 4,
			displayName = "Frozen Peak",
			requiredShovel = 7,
			enabled = true,
			activeSpots = 25,
			odds = {
				Common = 8,
				Uncommon = 22,
				Rare = 30,
				Epic = 24,
				Legendary = 12,
				Mythic = 3.6,
				Secret = 0.4,
			},
		},
	} :: { [string]: AreaDef }
end

return table.freeze(Areas)
