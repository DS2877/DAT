--!strict
-- Island geography used by MapBuilder (visuals) and Zones (server rules).
-- Coordinates in studs; -Z is north. Plain numbers only so this module can be
-- loaded by the offline test runner.
--
--            Volcano (z < volcanoSouthZ)
--     Jungle (x < 0)  |  Ruins (x >= 0)
--   ================ beachNorthZ ================
--                  Beach + Base (south)

local MapLayout = {
	waterLevel = 0,
	beachHeight = 3,
	plateauHeight = 9,

	-- Area boundaries.
	beachNorthZ = -10,
	volcanoSouthZ = -120,
	jungleRuinsX = 0,

	-- Island land masses (circles in XZ).
	beach = { x = 0, z = 40, radius = 130 },
	plateau = { x = 0, z = -60, radius = 140 },
	-- The cone sits at the back so the Volcano area has flat basalt to dig on.
	volcano = { x = 0, z = -222, radius = 60, height = 115 },

	-- Invisible play-area limits (stops swimming around the gates).
	bounds = { minX = -215, maxX = 215, minZ = -300, maxZ = 215 },

	-- Base deck (the sell / upgrade hub).
	base = { minX = -40, maxX = 40, minZ = 100, maxZ = 152, deckHeight = 1.4 },
	spawn = { x = 0, z = 139 },
	-- Trophy shelf along the back of the deck (slots spread along x).
	trophyShelf = { z = 149.5, minX = -24.5, maxX = 24.5 },
	sellPad = { x = 0, z = 113, size = 18 },
	shovelStation = { x = -27, z = 128, radius = 10 },
	bagStation = { x = 27, z = 128, radius = 10 },

	-- Dig spots never spawn inside this rectangle (the base plus a margin).
	spotExclusion = { minX = -50, maxX = 50, minZ = 92, maxZ = 162 },

	-- Candidate rectangles per area (points are further clipped to land/area).
	spotRegions = {
		Beach = { minX = -118, maxX = 118, minZ = -2, maxZ = 162 },
		Jungle = { minX = -125, maxX = -8, minZ = -112, maxZ = -18 },
		Ruins = { minX = 8, maxX = 125, minZ = -112, maxZ = -18 },
		Volcano = { minX = -90, maxX = 90, minZ = -172, maxZ = -128 },
	},

	-- Gates: openings in the boundary walls. `side` is the direction the
	-- locked area lies in from the gate ("north" or "east"/"west").
	gateWidth = 22,
	gates = {
		Jungle = { x = -65, z = -10, side = "north" },
		Ruins = { x = 65, z = -10, side = "north" },
		Volcano = { x = 45, z = -120, side = "north" },
	},
}

return table.freeze(MapLayout)
