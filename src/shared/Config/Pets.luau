--!strict
-- Pets you dig up (PetService, PetController). Now and then a dig turns up
-- an egg as well as the treasure; it hatches right away into one of the
-- pets of the area you dug in. The pet follows you around and gives a small
-- cash bonus while it's out (one at a time). Digging up a pet you already
-- have levels it up. Free for everyone: eggs only come from digging.
--
-- Pets are kept forever (every world). Each area has its own pets, rarer
-- ones in the later areas; `weights` is how often each rarity hatches from
-- an area's eggs.

export type Pet = {
	id: string,
	name: string,
	icon: string,
	world: string, -- "Island" | "Frost"
	area: string,
	rarity: string,
	fly: boolean?, -- hovers at shoulder height instead of walking
	glow: string?, -- a light (and flames) in this color
	-- The model, built from parts (Builders/PetBuilder): feet at the origin,
	-- facing -Z. shape: "Ball" | "Block" | "Cylinder" | "Wedge"; at / size in
	-- studs; rot in degrees; neon for glowing bits.
	parts: {
		{
			shape: string,
			size: { number },
			at: { number },
			rot: { number }?,
			color: string,
			neon: boolean?,
		}
	},
}

local Pets = {
	eggChance = 1 / 150, -- per dig
	firstEggAt = 40, -- digs: the first egg comes by then for sure
	pity = 220, -- digs without an egg before one is certain
	-- More eggs from special digs.
	multipliers = { deep = 2, moonlit = 3, meteor = 3, eggRush = 10 }, -- eggRush: an admin Egg Rush
	maxLevel = 5,
	-- Cash bonus while the pet is out, by rarity, and what each level adds.
	bonus = { Common = 0.04, Uncommon = 0.06, Rare = 0.08, Epic = 0.12 } :: { [string]: number },
	perLevel = 0.02,
	weights = { Common = 60, Uncommon = 28, Rare = 12, Epic = 5 } :: { [string]: number },
	-- A pet hatched at max level turns into cash (a share of the next goal).
	maxedReward = { kind = "Cash", goalPercent = 0.05, min = 100 },
	list = {} :: { Pet },
}

local function p(
	shape: string,
	size: { number },
	at: { number },
	color: string,
	rot: { number }?,
	neon: boolean?
)
	return { shape = shape, size = size, at = at, color = color, rot = rot, neon = neon }
end

Pets.list = {
	-- The Island ----------------------------------------------------------
	{
		id = "Crab",
		name = "Sandy the Crab",
		icon = "🦀",
		world = "Island",
		area = "Beach",
		rarity = "Common",
		parts = {
			p("Cylinder", { 0.7, 1.9, 1.9 }, { 0, 0.75, 0 }, "#E8573A", { 0, 0, 90 }),
			p("Cylinder", { 0.5, 0.12, 0.12 }, { -0.3, 1.25, -0.6 }, "#E8573A", { 0, 0, 90 }),
			p("Cylinder", { 0.5, 0.12, 0.12 }, { 0.3, 1.25, -0.6 }, "#E8573A", { 0, 0, 90 }),
			p("Ball", { 0.3, 0.3, 0.3 }, { -0.3, 1.55, -0.6 }, "#FFFFFF"),
			p("Ball", { 0.3, 0.3, 0.3 }, { 0.3, 1.55, -0.6 }, "#FFFFFF"),
			p("Ball", { 0.15, 0.15, 0.15 }, { -0.3, 1.58, -0.73 }, "#1E1E1E"),
			p("Ball", { 0.15, 0.15, 0.15 }, { 0.3, 1.58, -0.73 }, "#1E1E1E"),
			p("Ball", { 0.65, 0.65, 0.65 }, { -1.15, 0.75, -0.75 }, "#D9452B"),
			p("Ball", { 0.65, 0.65, 0.65 }, { 1.15, 0.75, -0.75 }, "#D9452B"),
			p("Block", { 0.15, 0.6, 0.15 }, { -1.15, 0.35, 0 }, "#C93F27", { 0, 0, 30 }),
			p("Block", { 0.15, 0.6, 0.15 }, { 1.15, 0.35, 0 }, "#C93F27", { 0, 0, -30 }),
			p("Block", { 0.15, 0.6, 0.15 }, { -1.05, 0.35, 0.45 }, "#C93F27", { 0, 0, 30 }),
			p("Block", { 0.15, 0.6, 0.15 }, { 1.05, 0.35, 0.45 }, "#C93F27", { 0, 0, -30 }),
		},
	},
	{
		id = "Turtle",
		name = "Shelly the Turtle",
		icon = "🐢",
		world = "Island",
		area = "Beach",
		rarity = "Uncommon",
		parts = {
			p("Ball", { 1.7, 1.7, 1.7 }, { 0, 0.55, 0 }, "#5B7F3A"),
			p("Cylinder", { 0.3, 1.9, 1.9 }, { 0, 0.4, 0 }, "#8FB85A", { 0, 0, 90 }),
			p("Ball", { 0.7, 0.7, 0.7 }, { 0, 0.75, -1.15 }, "#9BCB6B"),
			p("Ball", { 0.15, 0.15, 0.15 }, { -0.2, 0.9, -1.45 }, "#1E1E1E"),
			p("Ball", { 0.15, 0.15, 0.15 }, { 0.2, 0.9, -1.45 }, "#1E1E1E"),
			p("Cylinder", { 0.4, 0.4, 0.4 }, { -0.7, 0.2, -0.6 }, "#9BCB6B", { 0, 0, 90 }),
			p("Cylinder", { 0.4, 0.4, 0.4 }, { 0.7, 0.2, -0.6 }, "#9BCB6B", { 0, 0, 90 }),
			p("Cylinder", { 0.4, 0.4, 0.4 }, { -0.7, 0.2, 0.6 }, "#9BCB6B", { 0, 0, 90 }),
			p("Cylinder", { 0.4, 0.4, 0.4 }, { 0.7, 0.2, 0.6 }, "#9BCB6B", { 0, 0, 90 }),
		},
	},
	{
		id = "Parrot",
		name = "Captain Parrot",
		icon = "🦜",
		world = "Island",
		area = "Jungle",
		rarity = "Common",
		fly = true,
		parts = {
			p("Ball", { 1, 1, 1 }, { 0, 0.5, 0 }, "#E53935"),
			p("Ball", { 0.75, 0.75, 0.75 }, { 0, 1.1, -0.3 }, "#E53935"),
			p("Wedge", { 0.25, 0.35, 0.4 }, { 0, 1.0, -0.8 }, "#FFC93C", { 0, 180, 0 }),
			p("Ball", { 0.15, 0.15, 0.15 }, { -0.25, 1.25, -0.55 }, "#1E1E1E"),
			p("Ball", { 0.15, 0.15, 0.15 }, { 0.25, 1.25, -0.55 }, "#1E1E1E"),
			p("Block", { 1.0, 0.12, 0.6 }, { -0.75, 0.6, 0.05 }, "#1E88E5", { 0, 0, 20 }),
			p("Block", { 1.0, 0.12, 0.6 }, { 0.75, 0.6, 0.05 }, "#1E88E5", { 0, 0, -20 }),
			p("Block", { 0.3, 0.12, 1.1 }, { 0, 0.35, 0.8 }, "#FFC93C", { 20, 0, 0 }),
		},
	},
	{
		id = "Monkey",
		name = "Coco the Monkey",
		icon = "🐒",
		world = "Island",
		area = "Jungle",
		rarity = "Rare",
		parts = {
			p("Ball", { 1.2, 1.2, 1.2 }, { 0, 0.75, 0 }, "#7A4E2D"),
			p("Ball", { 1, 1, 1 }, { 0, 1.65, -0.1 }, "#7A4E2D"),
			p("Ball", { 0.65, 0.65, 0.65 }, { 0, 1.55, -0.45 }, "#E8C39E"),
			p("Ball", { 0.4, 0.4, 0.4 }, { -0.55, 1.75, -0.05 }, "#E8C39E"),
			p("Ball", { 0.4, 0.4, 0.4 }, { 0.55, 1.75, -0.05 }, "#E8C39E"),
			p("Ball", { 0.15, 0.15, 0.15 }, { -0.18, 1.75, -0.6 }, "#1E1E1E"),
			p("Ball", { 0.15, 0.15, 0.15 }, { 0.18, 1.75, -0.6 }, "#1E1E1E"),
			p("Block", { 0.2, 0.9, 0.2 }, { -0.6, 0.6, -0.1 }, "#7A4E2D", { 0, 0, 20 }),
			p("Block", { 0.2, 0.9, 0.2 }, { 0.6, 0.6, -0.1 }, "#7A4E2D", { 0, 0, -20 }),
			p("Block", { 0.15, 0.15, 1.1 }, { 0, 0.5, 0.75 }, "#7A4E2D", { -30, 0, 0 }),
			p("Block", { 0.15, 0.7, 0.15 }, { 0, 1.0, 1.25 }, "#7A4E2D"),
			p("Ball", { 0.5, 0.5, 0.5 }, { 0.65, 0.2, -0.3 }, "#FFE135"),
		},
	},
	{
		id = "Scarab",
		name = "Golden Scarab",
		icon = "🪲",
		world = "Island",
		area = "Ruins",
		rarity = "Uncommon",
		parts = {
			p("Ball", { 1.4, 1.4, 1.4 }, { 0, 0.6, 0.1 }, "#E0B33A"),
			p("Block", { 0.06, 0.7, 1.3 }, { 0, 1.0, 0.1 }, "#8C6A1A"),
			p("Ball", { 0.7, 0.7, 0.7 }, { 0, 0.55, -0.75 }, "#3B2F1A"),
			p("Wedge", { 0.15, 0.5, 0.3 }, { 0, 0.95, -0.95 }, "#E0B33A"),
			p("Block", { 1.8, 0.1, 0.12 }, { 0, 0.25, -0.3 }, "#3B2F1A"),
			p("Block", { 1.8, 0.1, 0.12 }, { 0, 0.25, 0.1 }, "#3B2F1A"),
			p("Block", { 1.8, 0.1, 0.12 }, { 0, 0.25, 0.5 }, "#3B2F1A"),
		},
	},
	{
		id = "Cat",
		name = "Pharaoh Cat",
		icon = "🐈",
		world = "Island",
		area = "Ruins",
		rarity = "Epic",
		parts = {
			p("Block", { 0.8, 0.8, 1.5 }, { 0, 0.75, 0.1 }, "#D9B26F"),
			p("Ball", { 0.95, 0.95, 0.95 }, { 0, 1.45, -0.65 }, "#D9B26F"),
			p("Wedge", { 0.15, 0.4, 0.3 }, { -0.28, 1.95, -0.6 }, "#D9B26F"),
			p("Wedge", { 0.15, 0.4, 0.3 }, { 0.28, 1.95, -0.6 }, "#D9B26F"),
			p("Ball", { 0.18, 0.18, 0.18 }, { -0.2, 1.55, -1.08 }, "#29B6F6", nil, true),
			p("Ball", { 0.18, 0.18, 0.18 }, { 0.2, 1.55, -1.08 }, "#29B6F6", nil, true),
			p("Cylinder", { 0.18, 0.75, 0.75 }, { 0, 1.1, -0.6 }, "#FFD54F", { 0, 0, 90 }),
			p("Block", { 0.15, 0.15, 1.0 }, { 0, 1.1, 1.0 }, "#C49A55", { -45, 0, 0 }),
			p("Block", { 0.18, 0.4, 0.18 }, { -0.25, 0.2, -0.5 }, "#C49A55"),
			p("Block", { 0.18, 0.4, 0.18 }, { 0.25, 0.2, -0.5 }, "#C49A55"),
			p("Block", { 0.18, 0.4, 0.18 }, { -0.25, 0.2, 0.6 }, "#C49A55"),
			p("Block", { 0.18, 0.4, 0.18 }, { 0.25, 0.2, 0.6 }, "#C49A55"),
		},
	},
	{
		id = "Salamander",
		name = "Lava Salamander",
		icon = "🦎",
		world = "Island",
		area = "Volcano",
		rarity = "Rare",
		glow = "#FF7A2E",
		parts = {
			p("Block", { 0.8, 0.5, 1.6 }, { 0, 0.45, 0 }, "#FF7A2E"),
			p("Block", { 0.7, 0.45, 0.7 }, { 0, 0.55, -1.05 }, "#FF7A2E"),
			p("Ball", { 0.2, 0.2, 0.2 }, { -0.25, 0.8, -1.2 }, "#1E1E1E"),
			p("Ball", { 0.2, 0.2, 0.2 }, { 0.25, 0.8, -1.2 }, "#1E1E1E"),
			p("Wedge", { 0.4, 0.3, 1.3 }, { 0, 0.35, 1.4 }, "#E85A1A"),
			p("Ball", { 0.3, 0.3, 0.3 }, { -0.2, 0.75, 0.2 }, "#FFD54F", nil, true),
			p("Ball", { 0.3, 0.3, 0.3 }, { 0.2, 0.75, -0.3 }, "#FFD54F", nil, true),
			p("Block", { 0.2, 0.35, 0.2 }, { -0.5, 0.15, -0.5 }, "#E85A1A"),
			p("Block", { 0.2, 0.35, 0.2 }, { 0.5, 0.15, -0.5 }, "#E85A1A"),
			p("Block", { 0.2, 0.35, 0.2 }, { -0.5, 0.15, 0.5 }, "#E85A1A"),
			p("Block", { 0.2, 0.35, 0.2 }, { 0.5, 0.15, 0.5 }, "#E85A1A"),
		},
	},
	{
		id = "Phoenix",
		name = "Baby Phoenix",
		icon = "🔥",
		world = "Island",
		area = "Volcano",
		rarity = "Epic",
		fly = true,
		glow = "#FF9F1C",
		parts = {
			p("Ball", { 1.1, 1.1, 1.1 }, { 0, 0.55, 0 }, "#FF6F00"),
			p("Ball", { 0.8, 0.8, 0.8 }, { 0, 1.2, -0.35 }, "#FF8F00"),
			p("Wedge", { 0.2, 0.3, 0.4 }, { 0, 1.1, -0.9 }, "#FFE082", { 0, 180, 0 }),
			p("Ball", { 0.16, 0.16, 0.16 }, { -0.25, 1.35, -0.65 }, "#1E1E1E"),
			p("Ball", { 0.16, 0.16, 0.16 }, { 0.25, 1.35, -0.65 }, "#1E1E1E"),
			p("Wedge", { 0.12, 0.8, 1.3 }, { -0.85, 0.85, 0.1 }, "#FFC400", { 0, 0, 60 }, true),
			p("Wedge", { 0.12, 0.8, 1.3 }, { 0.85, 0.85, 0.1 }, "#FFC400", { 0, 0, -60 }, true),
			p("Wedge", { 0.12, 0.5, 0.9 }, { 0, 1.75, -0.2 }, "#FF3D00", nil, true),
			p("Wedge", { 0.4, 0.3, 1.2 }, { 0, 0.4, 0.95 }, "#FF3D00", { 180, 0, 0 }, true),
		},
	},
	-- Frostbite Peaks ------------------------------------------------------
	{
		id = "Penguin",
		name = "Pebble the Penguin",
		icon = "🐧",
		world = "Frost",
		area = "Beach",
		rarity = "Common",
		parts = {
			p("Ball", { 1.3, 1.3, 1.3 }, { 0, 0.75, 0 }, "#263238"),
			p("Ball", { 1.0, 1.0, 1.0 }, { 0, 0.7, -0.25 }, "#FAFAFA"),
			p("Ball", { 0.9, 0.9, 0.9 }, { 0, 1.6, 0 }, "#263238"),
			p("Wedge", { 0.25, 0.25, 0.4 }, { 0, 1.5, -0.55 }, "#FF9800", { 0, 180, 0 }),
			p("Ball", { 0.15, 0.15, 0.15 }, { -0.2, 1.7, -0.4 }, "#FFFFFF"),
			p("Ball", { 0.15, 0.15, 0.15 }, { 0.2, 1.7, -0.4 }, "#FFFFFF"),
			p("Block", { 0.15, 0.7, 0.4 }, { -0.68, 0.8, 0 }, "#263238", { 0, 0, 15 }),
			p("Block", { 0.15, 0.7, 0.4 }, { 0.68, 0.8, 0 }, "#263238", { 0, 0, -15 }),
			p("Block", { 0.35, 0.1, 0.5 }, { -0.25, 0.05, -0.2 }, "#FF9800"),
			p("Block", { 0.35, 0.1, 0.5 }, { 0.25, 0.05, -0.2 }, "#FF9800"),
		},
	},
	{
		id = "SnowHare",
		name = "Snow Hare",
		icon = "🐇",
		world = "Frost",
		area = "Jungle",
		rarity = "Uncommon",
		parts = {
			p("Ball", { 1.2, 1.2, 1.2 }, { 0, 0.6, 0.1 }, "#F5F5F5"),
			p("Ball", { 0.85, 0.85, 0.85 }, { 0, 1.25, -0.45 }, "#F5F5F5"),
			p("Block", { 0.2, 0.9, 0.12 }, { -0.18, 2.0, -0.4 }, "#F5F5F5", { 0, 0, 8 }),
			p("Block", { 0.2, 0.9, 0.12 }, { 0.18, 2.0, -0.4 }, "#F5F5F5", { 0, 0, -8 }),
			p("Block", { 0.1, 0.6, 0.05 }, { -0.18, 2.0, -0.47 }, "#F8BBD0", { 0, 0, 8 }),
			p("Block", { 0.1, 0.6, 0.05 }, { 0.18, 2.0, -0.47 }, "#F8BBD0", { 0, 0, -8 }),
			p("Ball", { 0.15, 0.15, 0.15 }, { -0.22, 1.35, -0.8 }, "#1E1E1E"),
			p("Ball", { 0.15, 0.15, 0.15 }, { 0.22, 1.35, -0.8 }, "#1E1E1E"),
			p("Ball", { 0.12, 0.12, 0.12 }, { 0, 1.2, -0.88 }, "#F48FB1"),
			p("Ball", { 0.45, 0.45, 0.45 }, { 0, 0.7, 0.75 }, "#FFFFFF"),
		},
	},
	{
		id = "SnowFox",
		name = "Frost Fox",
		icon = "🦊",
		world = "Frost",
		area = "Ruins",
		rarity = "Rare",
		parts = {
			p("Block", { 0.8, 0.8, 1.5 }, { 0, 0.8, 0.1 }, "#ECEFF1"),
			p("Ball", { 0.9, 0.9, 0.9 }, { 0, 1.45, -0.7 }, "#ECEFF1"),
			p("Wedge", { 0.3, 0.3, 0.6 }, { 0, 1.3, -1.25 }, "#ECEFF1", { 0, 180, 0 }),
			p("Ball", { 0.12, 0.12, 0.12 }, { 0, 1.35, -1.55 }, "#263238"),
			p("Wedge", { 0.15, 0.45, 0.35 }, { -0.28, 1.95, -0.65 }, "#ECEFF1"),
			p("Wedge", { 0.15, 0.45, 0.35 }, { 0.28, 1.95, -0.65 }, "#ECEFF1"),
			p("Ball", { 0.16, 0.16, 0.16 }, { -0.2, 1.6, -1.1 }, "#4FC3F7", nil, true),
			p("Ball", { 0.16, 0.16, 0.16 }, { 0.2, 1.6, -1.1 }, "#4FC3F7", nil, true),
			p("Block", { 0.5, 0.5, 1.2 }, { 0, 1.1, 1.2 }, "#B3E5FC", { -30, 0, 0 }),
			p("Block", { 0.18, 0.45, 0.18 }, { -0.25, 0.22, -0.5 }, "#CFD8DC"),
			p("Block", { 0.18, 0.45, 0.18 }, { 0.25, 0.22, -0.5 }, "#CFD8DC"),
			p("Block", { 0.18, 0.45, 0.18 }, { -0.25, 0.22, 0.6 }, "#CFD8DC"),
			p("Block", { 0.18, 0.45, 0.18 }, { 0.25, 0.22, 0.6 }, "#CFD8DC"),
		},
	},
	{
		id = "Yeti",
		name = "Baby Yeti",
		icon = "❄️",
		world = "Frost",
		area = "Volcano",
		rarity = "Epic",
		glow = "#7FDBFF",
		parts = {
			p("Ball", { 1.5, 1.5, 1.5 }, { 0, 0.95, 0 }, "#E3F2FD"),
			p("Ball", { 1.1, 1.1, 1.1 }, { 0, 1.95, -0.1 }, "#E3F2FD"),
			p("Ball", { 0.75, 0.75, 0.75 }, { 0, 1.85, -0.4 }, "#90A4AE"),
			p("Ball", { 0.16, 0.16, 0.16 }, { -0.2, 2.0, -0.75 }, "#1E1E1E"),
			p("Ball", { 0.16, 0.16, 0.16 }, { 0.2, 2.0, -0.75 }, "#1E1E1E"),
			p("Block", { 0.3, 0.12, 0.08 }, { 0, 1.7, -0.78 }, "#1E1E1E"),
			p("Wedge", { 0.15, 0.4, 0.3 }, { -0.4, 2.55, -0.1 }, "#7FDBFF", nil, true),
			p("Wedge", { 0.15, 0.4, 0.3 }, { 0.4, 2.55, -0.1 }, "#7FDBFF", nil, true),
			p("Block", { 0.35, 1.0, 0.35 }, { -0.85, 1.0, -0.1 }, "#E3F2FD", { 0, 0, 15 }),
			p("Block", { 0.35, 1.0, 0.35 }, { 0.85, 1.0, -0.1 }, "#E3F2FD", { 0, 0, -15 }),
			p("Block", { 0.4, 0.4, 0.5 }, { -0.35, 0.2, -0.1 }, "#B0BEC5"),
			p("Block", { 0.4, 0.4, 0.5 }, { 0.35, 0.2, -0.1 }, "#B0BEC5"),
		},
	},
}

return table.freeze(Pets)
