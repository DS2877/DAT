--!strict
-- Treasure catalog. `area` is the treasure's home area: it drops there and
-- counts toward that area's collection set. When an area has no native
-- treasure of a rolled rarity (e.g. Commons in the Jungle), the pool falls back
-- to earlier areas' treasures of that rarity (see LootRoller).
--
-- `model` picks a primitive-part archetype in TreasureBuilder; `color` and
-- `accent` are hex strings. Add new treasures by appending rows here.

export type TreasureDef = {
	id: string,
	name: string,
	rarity: string,
	area: string,
	value: number,
	model: string,
	color: string,
	accent: string?,
	weight: number?,
	-- Rebirth-only Secret: drops only for players with at least this many
	-- rebirths, and doesn't count toward its area's collection set.
	rebirths: number?,
	-- The world it drops in: nil = the island, "Frost" = Frostbite Peaks.
	world: string?,
}

local CurrentWorld = require(script.Parent.Parent.Logic.CurrentWorld)

-- stylua: ignore
local All: { TreasureDef } = {
	-- Beach ---------------------------------------------------------------
	{ id = "Bottle", name = "Bottle", rarity = "Common", area = "Beach", value = 12, model = "Bottle", color = "#6FCF97", accent = "#F2E6C9" },
	{ id = "Shell", name = "Shell", rarity = "Common", area = "Beach", value = 15, model = "Shell", color = "#FFB3A7", accent = "#FFF1E0" },
	{ id = "RustySpoon", name = "Rusty Spoon", rarity = "Common", area = "Beach", value = 20, model = "Spoon", color = "#A0643C" },
	{ id = "OldCoin", name = "Old Coin", rarity = "Common", area = "Beach", value = 28, model = "Coin", color = "#B08D57" },
	{ id = "BrokenCompass", name = "Broken Compass", rarity = "Common", area = "Beach", value = 40, model = "Compass", color = "#8A6A45", accent = "#E8E1D0" },
	{ id = "SilverCoin", name = "Silver Coin", rarity = "Uncommon", area = "Beach", value = 110, model = "Coin", color = "#D9DEE4" },
	{ id = "Pearl", name = "Pearl", rarity = "Uncommon", area = "Beach", value = 150, model = "Pearl", color = "#FFF8EE", accent = "#FFB3A7" },
	{ id = "PirateMug", name = "Pirate Mug", rarity = "Uncommon", area = "Beach", value = 190, model = "Mug", color = "#8B5A2B", accent = "#C9CED6" },
	{ id = "GoldCoin", name = "Gold Coin", rarity = "Rare", area = "Beach", value = 550, model = "Coin", color = "#FFC933" },
	{ id = "GoldenCompass", name = "Golden Compass", rarity = "Rare", area = "Beach", value = 750, model = "Compass", color = "#FFC933", accent = "#FFF6D6" },

	-- Jungle --------------------------------------------------------------
	{ id = "OldWatch", name = "Old Watch", rarity = "Uncommon", area = "Jungle", value = 280, model = "Watch", color = "#C9A45C", accent = "#FFFFFF" },
	{ id = "SmallIdol", name = "Small Idol", rarity = "Uncommon", area = "Jungle", value = 400, model = "Idol", color = "#6B8E4E" },
	{ id = "Emerald", name = "Emerald", rarity = "Rare", area = "Jungle", value = 1100, model = "Gem", color = "#2EE88A" },
	{ id = "Ruby", name = "Ruby", rarity = "Rare", area = "Jungle", value = 1600, model = "Gem", color = "#FF2E4D" },
	{ id = "GiantPearl", name = "Giant Pearl", rarity = "Epic", area = "Jungle", value = 3000, model = "Pearl", color = "#FDF3FF", accent = "#D7A8FF" },
	{ id = "GoldenIdol", name = "Golden Idol", rarity = "Epic", area = "Jungle", value = 4200, model = "Idol", color = "#FFC933" },
	{ id = "GoldenSkull", name = "Golden Skull", rarity = "Legendary", area = "Jungle", value = 12000, model = "Skull", color = "#FFC933" },

	-- Ancient Ruins -------------------------------------------------------
	{ id = "AncientCoin", name = "Ancient Coin", rarity = "Rare", area = "Ruins", value = 2200, model = "Coin", color = "#4FD1C5" },
	{ id = "AncientStatue", name = "Ancient Statue", rarity = "Epic", area = "Ruins", value = 5500, model = "Statue", color = "#C8B99A" },
	{ id = "RoyalNecklace", name = "Royal Necklace", rarity = "Epic", area = "Ruins", value = 7000, model = "Necklace", color = "#FFC933", accent = "#3FA9FF" },
	{ id = "PirateCrown", name = "Pirate Crown", rarity = "Epic", area = "Ruins", value = 9000, model = "Crown", color = "#E0B040", accent = "#222222" },
	{ id = "DragonStatue", name = "Dragon Statue", rarity = "Legendary", area = "Ruins", value = 18000, model = "Statue", color = "#2EE88A" },
	{ id = "AncientCrown", name = "Ancient Crown", rarity = "Legendary", area = "Ruins", value = 25000, model = "Crown", color = "#FFC933", accent = "#FF2E4D" },
	{ id = "AncientRelic", name = "Ancient Relic", rarity = "Mythic", area = "Ruins", value = 60000, model = "Relic", color = "#4FD1C5", accent = "#FFC933" },
	{ id = "LostKingsCrown", name = "Lost King's Crown", rarity = "Mythic", area = "Ruins", value = 90000, model = "Crown", color = "#FFE27A", accent = "#B45CFF" },

	-- Volcano -------------------------------------------------------------
	{ id = "PirateTreasureChest", name = "Pirate Treasure Chest", rarity = "Legendary", area = "Volcano", value = 35000, model = "Chest", color = "#8B5A2B", accent = "#FFC933" },
	{ id = "GiantDiamond", name = "Giant Diamond", rarity = "Legendary", area = "Volcano", value = 48000, model = "Gem", color = "#BFF6FF" },
	{ id = "GoldenDragonEgg", name = "Golden Dragon Egg", rarity = "Mythic", area = "Volcano", value = 120000, model = "Egg", color = "#FFC933", accent = "#FF6A1A" },
	{ id = "CursedIdol", name = "Cursed Idol", rarity = "Mythic", area = "Volcano", value = 160000, model = "Idol", color = "#5B2A86", accent = "#2EE88A" },
	{ id = "Meteorite", name = "Meteorite", rarity = "Mythic", area = "Volcano", value = 220000, model = "Meteor", color = "#3A3030", accent = "#FF6A1A" },
	{ id = "GoldenBanana", name = "Golden Banana", rarity = "Secret", area = "Volcano", value = 300000, model = "Banana", color = "#FFD83D" },
	{ id = "GiantGoldenToilet", name = "Giant Golden Toilet", rarity = "Secret", area = "Volcano", value = 450000, model = "Toilet", color = "#FFC933" },
	{ id = "AlienArtifact", name = "Alien Artifact", rarity = "Secret", area = "Volcano", value = 650000, model = "Relic", color = "#7CFF4F", accent = "#B45CFF" },
	{ id = "ForbiddenTreasure", name = "The Forbidden Treasure", rarity = "Secret", area = "Volcano", value = 1000000, model = "Chest", color = "#1B1B1B", accent = "#FF2E4D" },

	-- Rebirth-only Secrets (one more unlocks every 5 rebirths) ----------
	{ id = "RainbowSkull", name = "Rainbow Skull", rarity = "Secret", area = "Volcano", value = 1500000, model = "Skull", color = "#FF5FD2", rebirths = 5 },
	{ id = "CrystalDragonEgg", name = "Crystal Dragon Egg", rarity = "Secret", area = "Volcano", value = 2500000, model = "Egg", color = "#7FF3FF", accent = "#B45CFF", rebirths = 10 },
	{ id = "CosmicCrown", name = "Cosmic Crown", rarity = "Secret", area = "Volcano", value = 4000000, model = "Crown", color = "#3F2BFF", accent = "#FFFFFF", rebirths = 15 },

	-- Frostbite Peaks (same areas, frost biomes) ---------------------------
	-- Frost Shore
	{ id = "FrostSnowGlobe", name = "Snow Globe", rarity = "Common", area = "Beach", value = 150, model = "Pearl", color = "#E8F8FF", accent = "#7FDBFF", world = "Frost" },
	{ id = "FrostBottle", name = "Frozen Bottle", rarity = "Common", area = "Beach", value = 180, model = "Bottle", color = "#A8E6FF", accent = "#FFFFFF", world = "Frost" },
	{ id = "FrostSpoon", name = "Icicle Spoon", rarity = "Common", area = "Beach", value = 240, model = "Spoon", color = "#BFE6F2", world = "Frost" },
	{ id = "FrostPenguinCoin", name = "Penguin Coin", rarity = "Common", area = "Beach", value = 340, model = "Coin", color = "#9FB3CC", world = "Frost" },
	{ id = "FrostCompass", name = "Frosted Compass", rarity = "Common", area = "Beach", value = 480, model = "Compass", color = "#6F8FAF", accent = "#E8F8FF", world = "Frost" },
	{ id = "FrostSnowflakeCoin", name = "Silver Snowflake Coin", rarity = "Uncommon", area = "Beach", value = 1300, model = "Coin", color = "#E3EEF7", world = "Frost" },
	{ id = "FrostPearl", name = "Frost Pearl", rarity = "Uncommon", area = "Beach", value = 1800, model = "Pearl", color = "#DFF6FF", accent = "#7FDBFF", world = "Frost" },
	{ id = "FrostCocoaMug", name = "Hot Cocoa Mug", rarity = "Uncommon", area = "Beach", value = 2300, model = "Mug", color = "#D8443C", accent = "#FFFFFF", world = "Frost" },
	{ id = "FrostDiamondCoin", name = "Ice Diamond Coin", rarity = "Rare", area = "Beach", value = 6600, model = "Coin", color = "#7FF3FF", world = "Frost" },
	{ id = "FrostNorthCompass", name = "Northern Compass", rarity = "Rare", area = "Beach", value = 9000, model = "Compass", color = "#5CC6F2", accent = "#FFFFFF", world = "Frost" },

	-- Pine Woods
	{ id = "FrostWatch", name = "Frozen Pocket Watch", rarity = "Uncommon", area = "Jungle", value = 3400, model = "Watch", color = "#C9D6E2", accent = "#BFF6FF", world = "Frost" },
	{ id = "FrostSnowIdol", name = "Snow Idol", rarity = "Uncommon", area = "Jungle", value = 4800, model = "Idol", color = "#F4FBFF", world = "Frost" },
	{ id = "FrostSapphire", name = "Sapphire", rarity = "Rare", area = "Jungle", value = 13200, model = "Gem", color = "#2E6FD8", world = "Frost" },
	{ id = "FrostOpal", name = "Frost Opal", rarity = "Rare", area = "Jungle", value = 19200, model = "Gem", color = "#B8F2E6", world = "Frost" },
	{ id = "FrostYetiPearl", name = "Yeti Pearl", rarity = "Epic", area = "Jungle", value = 36000, model = "Pearl", color = "#FFFFFF", accent = "#9FD8FF", world = "Frost" },
	{ id = "FrostMammothIdol", name = "Mammoth Idol", rarity = "Epic", area = "Jungle", value = 50400, model = "Idol", color = "#8B6A4E", world = "Frost" },
	{ id = "FrostYetiSkull", name = "Yeti Skull", rarity = "Legendary", area = "Jungle", value = 144000, model = "Skull", color = "#E8F8FF", world = "Frost" },

	-- Ice Ruins
	{ id = "FrostGlacierCoin", name = "Glacier Coin", rarity = "Rare", area = "Ruins", value = 26400, model = "Coin", color = "#5CC6F2", world = "Frost" },
	{ id = "FrostKnightStatue", name = "Frozen Knight Statue", rarity = "Epic", area = "Ruins", value = 66000, model = "Statue", color = "#A8C8E0", world = "Frost" },
	{ id = "FrostNecklace", name = "Snowflake Necklace", rarity = "Epic", area = "Ruins", value = 84000, model = "Necklace", color = "#E3EEF7", accent = "#7FDBFF", world = "Frost" },
	{ id = "FrostTiara", name = "Ice Queen's Tiara", rarity = "Epic", area = "Ruins", value = 108000, model = "Crown", color = "#DFF6FF", accent = "#5CC6F2", world = "Frost" },
	{ id = "FrostDragonStatue", name = "Ice Dragon Statue", rarity = "Legendary", area = "Ruins", value = 216000, model = "Statue", color = "#7FDBFF", world = "Frost" },
	{ id = "FrostKingCrown", name = "Frost King's Crown", rarity = "Legendary", area = "Ruins", value = 300000, model = "Crown", color = "#BFF6FF", accent = "#2E6FD8", world = "Frost" },
	{ id = "FrostAuroraRelic", name = "Aurora Relic", rarity = "Mythic", area = "Ruins", value = 720000, model = "Relic", color = "#6CFFC4", accent = "#B45CFF", world = "Frost" },
	{ id = "FrostEternalCrown", name = "Eternal Ice Crown", rarity = "Mythic", area = "Ruins", value = 1080000, model = "Crown", color = "#E8F8FF", accent = "#7FF3FF", world = "Frost" },

	-- Frozen Peak
	{ id = "FrostChest", name = "Frozen Treasure Chest", rarity = "Legendary", area = "Volcano", value = 420000, model = "Chest", color = "#5A7A99", accent = "#BFF6FF", world = "Frost" },
	{ id = "FrostGlacierDiamond", name = "Glacier Diamond", rarity = "Legendary", area = "Volcano", value = 576000, model = "Gem", color = "#DFFBFF", world = "Frost" },
	{ id = "FrostDragonEgg", name = "Ice Dragon Egg", rarity = "Mythic", area = "Volcano", value = 1440000, model = "Egg", color = "#7FDBFF", accent = "#FFFFFF", world = "Frost" },
	{ id = "FrostIdol", name = "Frozen Idol", rarity = "Mythic", area = "Volcano", value = 1920000, model = "Idol", color = "#3F6FD8", accent = "#BFF6FF", world = "Frost" },
	{ id = "FrostComet", name = "Comet Shard", rarity = "Mythic", area = "Volcano", value = 2640000, model = "Meteor", color = "#2A3A55", accent = "#7FF3FF", world = "Frost" },
	{ id = "FrostBanana", name = "Frozen Banana", rarity = "Secret", area = "Volcano", value = 3600000, model = "Banana", color = "#E8FBFF", world = "Frost" },
	{ id = "FrostThrone", name = "Ice Throne", rarity = "Secret", area = "Volcano", value = 5400000, model = "Toilet", color = "#BFF6FF", world = "Frost" },
	{ id = "FrostAuroraArtifact", name = "Aurora Artifact", rarity = "Secret", area = "Volcano", value = 7800000, model = "Relic", color = "#6CFFC4", accent = "#FF5FD2", world = "Frost" },
	{ id = "FrostHeart", name = "The Frozen Heart", rarity = "Secret", area = "Volcano", value = 12000000, model = "Chest", color = "#0F1E33", accent = "#7FF3FF", world = "Frost" },
}

-- Every world's treasures are known everywhere (bags, trophies and boards
-- show them); only the current world's drop and fill its collection book.
local world = CurrentWorld.id()
local ById: { [string]: TreasureDef } = {}
local List: { TreasureDef } = {}
for _, def in All do
	assert(ById[def.id] == nil, "Duplicate treasure id " .. def.id)
	ById[def.id] = table.freeze(def)
	if (def.world or "Island") == world then
		table.insert(List, def)
	end
end

return table.freeze({
	List = table.freeze(List),
	All = table.freeze(All),
	ById = table.freeze(ById),
})
