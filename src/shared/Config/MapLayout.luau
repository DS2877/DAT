--!strict
-- Island geography used by MapBuilder (visuals) and Zones (server rules).
-- Coordinates in studs; -Z is north. Plain numbers only so this module can be
-- loaded by the offline test runner.
--
--                 Volcano cone (backdrop)
--        Volcano highland (z < volcanoSouthZ)        <- tier 3
--   ======== cliff at volcanoSouthZ (gate on the Ruins side) ========
--      Jungle (x < 0)   | ridge |   Ancient Ruins (x >= 0)   <- tier 2
--   ======== cliff at beachNorthZ (two gates) ========
--                    Beach + Base (south)                 <- tier 1
--
-- Each tier sits higher than the one before, so every area stays in view
-- from the base. Heights below are terrain FILL tops. Roblox draws terrain
-- a few studs above a fill top (voxel rounding), so builders measure the
-- real ground with raycasts instead of trusting these numbers.

local MapLayout = {
	waterLevel = 0,
	beachHeight = 4,
	plateauHeight = 20,
	highlandHeight = 36,

	-- Area boundaries.
	beachNorthZ = -24,
	volcanoSouthZ = -250,
	jungleRuinsX = 0,

	-- Land masses. Beach is a circle plus lobes; the plateau and highland
	-- are ellipses (rx, rz).
	beach = { x = 0, z = 150, radius = 215 },
	beachLobes = {
		{ x = -190, z = 60, r = 52 },
		{ x = 190, z = 70, r = 56 },
		{ x = -150, z = 250, r = 46 },
		{ x = 150, z = 262, r = 50 },
		{ x = 0, z = 330, r = 60 },
	},
	plateau = { x = 0, z = -135, rx = 285, rz = 160 },
	highland = { x = 0, z = -390, rx = 255, rz = 165 },
	-- The volcano cone stands at the back of the highland.
	volcano = { x = 0, z = -575, radius = 175, height = 210 },

	-- Invisible play-area limits.
	bounds = { minX = -300, maxX = 300, minZ = -425, maxZ = 400 },

	-- Base plaza (the sell / upgrade hub). The deck height is measured from
	-- the real sand at build time; deckHeight is how far it stands above it.
	base = { minX = -50, maxX = 50, minZ = 160, maxZ = 238, deckHeight = 1 },
	spawn = { x = 0, z = 206 },
	sellPad = { x = 0, z = 178, size = 18 },
	shovelStation = { x = -30, z = 194, radius = 10 },
	bagStation = { x = 30, z = 194, radius = 10 },
	-- Rebirth altar on the sand, front-left of the plaza.
	rebirthAltar = { x = -84, z = 176, radius = 9 },
	-- Leaderboard boards along the back of the plaza, facing north.
	leaderboards = { z = 233, xs = { -36, 0, 36 } },
	-- The Mega Dig clock tower, just outside the plaza's entrance by the path.
	megaClock = { x = -26, z = 134 },
	-- The Island Guide board (map, how to play, events) on the plaza's east
	-- side, facing the spawn.
	infoBoard = { x = 40, z = 214, width = 17, height = 11 },
	-- Trophy shelf in front of the boards (slots spread along x).
	trophyShelf = { z = 224, minX = -24.5, maxX = 24.5 },

	-- The VIP dig site on the sand, front-right of the plaza (mirrors the altar).
	-- carpetZ: where its red carpet meets the deck's east edge (an open
	-- stretch between the corner planter and the bag shop).
	vipSite = { x = 84, z = 176, radius = 8, carpetZ = 175 },

	-- Dig spots never spawn inside this rectangle (the base, altar, VIP site
	-- and margin).
	spotExclusion = { minX = -104, maxX = 104, minZ = 146, maxZ = 262 },

	-- Candidate rectangles per area (points are further clipped to land/area).
	spotRegions = {
		Beach = { minX = -195, maxX = 195, minZ = -12, maxZ = 290 },
		Jungle = { minX = -268, maxX = -16, minZ = -244, maxZ = -36 },
		Ruins = { minX = 16, maxX = 268, minZ = -244, maxZ = -36 },
		Volcano = { minX = -225, maxX = 225, minZ = -400, maxZ = -264 },
	},

	-- Paths (polylines of { x, z }) drawn into the terrain, lined with torches.
	paths = {
		Beach = {
			{ { 0, 156 }, { 0, 72 }, { -64, 24 }, { -100, -8 } },
			{ { 0, 72 }, { 64, 24 }, { 100, -8 } },
		},
		Jungle = {
			{ { -100, -76 }, { -112, -112 }, { -150, -128 }, { -182, -136 }, { -214, -146 } },
			{ { -112, -112 }, { -92, -160 }, { -80, -190 } },
		},
		Ruins = {
			{ { 100, -76 }, { 112, -100 }, { 140, -112 }, { 160, -132 } },
			{ { 112, -100 }, { 82, -168 }, { 108, -238 } },
		},
		Volcano = { { { 110, -300 }, { 64, -318 }, { 0, -328 }, { -90, -320 } } },
	},

	-- Landmarks (centers).
	ancientTree = { x = -226, z = -152 },
	jungleShrine = { x = -78, z = -210 },
	temple = { x = 162, z = -178, size = 72 },
	skullRock = { x = -70, z = -372 },

	-- The Jungle river: falls from the highland cliff, winds south and drops
	-- off the front cliff onto the beach as a waterfall.
	river = { { -128, -246 }, { -140, -200 }, { -184, -160 }, { -186, -110 }, { -168, -64 }, { -172, -26 } },
	beachPool = { x = -172, z = -6, radius = 15 },
	-- Ruins oasis pond.
	oasis = { x = 214, z = -92, radius = 20 },

	-- Lava rivers on the Volcano floor (polylines of { x, z }).
	lavaRivers = {
		{ { -30, -398 }, { -54, -370 }, { -90, -352 }, { -130, -346 }, { -170, -360 } },
		{ { 34, -398 }, { 48, -366 }, { 40, -334 }, { 58, -300 }, { 50, -268 } },
	},
	lavaLake = { x = -168, z = -362, radius = 22 },

	-- Gates: openings in the cliffs. Each climbs a ramp through a canyon to
	-- the next tier. `side` is the direction the locked area lies in.
	gateWidth = 24,
	rampLength = 46,
	gates = {
		Jungle = { x = -100, z = -24, side = "north" },
		Ruins = { x = 100, z = -24, side = "north" },
		Volcano = { x = 110, z = -250, side = "north" },
	},
}

return table.freeze(MapLayout)
