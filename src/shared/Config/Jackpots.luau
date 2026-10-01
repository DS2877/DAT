--!strict
-- Hidden treasures: every few minutes the server buries a Mythic (or, in the
-- Volcano, sometimes a Secret) under a random ordinary-looking dig spot and
-- tells everyone which AREA it's in, never where. The first player to dig
-- that spot gets it. When found, everyone hears who found it.

export type Choice = { rarity: string, area: string, weight: number }

local Jackpots = {
	interval = { min = 300, max = 540 }, -- seconds between hidden treasures
	firstDelay = 120, -- the first one after the server starts
	maxHidden = 2, -- at most this many hidden at once
	reminderAfter = 180, -- re-announce one that's still hidden after this long
	choices = {
		{ rarity = "Mythic", area = "Ruins", weight = 4 },
		{ rarity = "Mythic", area = "Volcano", weight = 4 },
		{ rarity = "Secret", area = "Volcano", weight = 1 },
	} :: { Choice },
}

return table.freeze(Jackpots)
