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
}

-- stylua: ignore
local List: { TreasureDef } = {
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
}

local ById: { [string]: TreasureDef } = {}
for _, def in List do
	assert(ById[def.id] == nil, "Duplicate treasure id " .. def.id)
	ById[def.id] = table.freeze(def)
end

return table.freeze({
	List = table.freeze(List),
	ById = table.freeze(ById),
})
