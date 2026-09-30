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

local Areas = {}

Areas.Order = { "Beach", "Jungle", "Ruins", "Volcano" }

Areas.Defs = {
	Beach = {
		id = "Beach",
		order = 1,
		displayName = "Beach",
		requiredShovel = 1,
		enabled = true,
		activeSpots = 20,
		odds = { Common = 70, Uncommon = 25, Rare = 5 },
	},
	Jungle = {
		id = "Jungle",
		order = 2,
		displayName = "Jungle",
		requiredShovel = 3,
		enabled = true,
		activeSpots = 20,
		odds = { Common = 45, Uncommon = 35, Rare = 15, Epic = 4.5, Legendary = 0.5 },
	},
	Ruins = {
		id = "Ruins",
		order = 3,
		displayName = "Ancient Ruins",
		requiredShovel = 5,
		enabled = true,
		activeSpots = 20,
		odds = { Common = 25, Uncommon = 35, Rare = 25, Epic = 12, Legendary = 2.8, Mythic = 0.2 },
	},
	Volcano = {
		id = "Volcano",
		order = 4,
		displayName = "Volcano",
		requiredShovel = 7,
		enabled = true,
		activeSpots = 18,
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

return table.freeze(Areas)
