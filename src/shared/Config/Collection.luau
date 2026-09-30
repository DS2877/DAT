--!strict
-- Collection sets, set bonuses, badges and server announcements.

local Collection = {
	-- Completing every treasure of an area (its base versions) adds this much
	-- permanent cash bonus (applied to every find's value).
	setBonus = 0.10,

	-- Roblox badge ids awarded for completing each area's set.
	-- TODO: create the badges on the Creator Dashboard and put their ids here.
	-- 0 = no badge (skipped safely).
	setBadges = {
		Beach = 0,
		Jungle = 0,
		Ruins = 0,
		Volcano = 0,
	},

	-- Server-wide announcements.
	announce = {
		minRarity = "Legendary", -- any find at or above this rarity
		golden = true, -- every Golden mutation
		shinyMinRarity = "Rare", -- Shiny mutations at or above this rarity
		perPlayerCooldown = 15, -- seconds between one player's announcements
		globalGap = 2.5, -- minimum seconds between any two announcements
	},

	-- Trophy shelf slots at the base (one per player in the server).
	shelfSlots = 8,
}

return table.freeze(Collection)
