--!strict
-- Loot modifiers: clue spots, mutations, dig streaks and early guarantees.

local Loot = {
	-- Chance that a newly spawned dig spot shows a clue.
	clueChance = 1 / 6,
	clueTypes = { "Sparkle", "Bone", "Gem", "Glow", "OddDirt", "Symbol" },
	-- Clue spots multiply each rarity's weight (then odds are renormalized).
	clueOddsMultipliers = {
		Common = 0.35,
		Uncommon = 1.1,
		Rare = 2.2,
		Epic = 2.8,
		Legendary = 3,
		Mythic = 3,
		Secret = 3,
	},

	-- Mutations are rolled independently of rarity, rarest first.
	mutations = {
		{ id = "Golden", chance = 1 / 250, multiplier = 10 },
		{ id = "Shiny", chance = 1 / 40, multiplier = 3 },
	},

	-- Dig streak: finishing a dig within `window` seconds of the previous one
	-- grows the streak; each step past the first adds `bonusPerStep` value.
	streak = {
		window = 8,
		bonusPerStep = 0.02,
		maxBonus = 0.20,
	},

	-- Deep Dig: a rare event when finishing a dig outside the Beach. The spot
	-- needs extra hits, then yields a guaranteed Epic-or-better, shown huge.
	-- Per area: the chance a finished dig turns into a Deep Dig, how many
	-- extra hits it takes, and the rarity it guarantees. The deeper the
	-- area, the more often it happens and the bigger the prize.
	deepDig = {
		areas = {
			Jungle = { chance = 1 / 30, extraHits = 15, minRarity = "Epic" },
			Ruins = { chance = 1 / 20, extraHits = 20, minRarity = "Epic" },
			Volcano = { chance = 1 / 12, extraHits = 28, minRarity = "Legendary" },
		},
	},

	-- The first time a player ever finds a treasure, it's worth this much more.
	firstFindMultiplier = 2,

	guarantees = {
		-- A new player's first Rare-or-better is forced on a random dig in this
		-- range (only if luck hasn't already given them one).
		rareByDig = { min = 4, max = 10 },
		-- First Epic-or-better in the Jungle is forced after this much Jungle
		-- digging time (seconds), picked at random per player (< 5 minutes).
		jungleEpicSeconds = { min = 150, max = 270 },
		-- Longest gap between two Jungle digs that counts as Jungle time.
		jungleGapCap = 45,
	},
}

return table.freeze(Loot)
