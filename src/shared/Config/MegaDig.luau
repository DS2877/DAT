--!strict
-- The Mega Dig: every 15 minutes (on a global clock, halfway between two
-- Treasure Rushes) a huge dig site appears somewhere on the beach. Everyone
-- in the server can help dig it out; it takes a while. It holds a Mythic or
-- better, and one of the helpers wins it in a draw (more hits = more
-- tickets). Everyone else who helped gets some cash.

local MegaDig = {
	interval = 900, -- seconds between Mega Digs
	offset = 450, -- after the start of each interval (Rush starts at 0)
	timeLimit = 300, -- seconds to dig it out before it collapses
	requiredHits = 300, -- hits to dig it out alone...
	hitsPerExtraPlayer = 90, -- ...plus this many per other player in the server
	maxRequiredHits = 1200,
	radius = 8, -- the site's size (studs)
	digRange = 16, -- how far from the center players can dig it
	area = "Beach", -- where it appears (everyone can reach the beach)
	lootArea = "Volcano", -- whose treasure pool it draws from
	minRarity = "Mythic",
	minHitsToEnter = 3, -- hits needed to be in the draw
	drawSeconds = 7, -- the draw animation
	-- Helpers who don't win get this (a share of their next goal), scaled
	-- by how much they helped (full at `fullShareHits`).
	consolation = { goalPercent = 0.25, min = 300 },
	fullShareHits = 60,
}

return table.freeze(MegaDig)
