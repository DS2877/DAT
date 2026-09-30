--!strict
-- Rarity tiers, in ascending order. Colors are hex strings so this module stays
-- free of Roblox datatypes (it is loaded by the offline test runner).

export type RarityInfo = {
	id: string,
	rank: number,
	displayName: string,
	color: string,
	-- Presentation tier used by the reveal effects (0 = small pop ... 3 = unique).
	fxTier: number,
}

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarities.Info = {
	Common = { id = "Common", rank = 1, displayName = "Common", color = "#D8D2C4", fxTier = 0 },
	Uncommon = { id = "Uncommon", rank = 2, displayName = "Uncommon", color = "#5BE36B", fxTier = 0 },
	Rare = { id = "Rare", rank = 3, displayName = "Rare", color = "#3FA9FF", fxTier = 1 },
	Epic = { id = "Epic", rank = 4, displayName = "Epic", color = "#B45CFF", fxTier = 1 },
	Legendary = { id = "Legendary", rank = 5, displayName = "Legendary", color = "#FFB21E", fxTier = 2 },
	Mythic = { id = "Mythic", rank = 6, displayName = "Mythic", color = "#FF3D6E", fxTier = 2 },
	Secret = { id = "Secret", rank = 7, displayName = "SECRET", color = "#FFFFFF", fxTier = 3 },
} :: { [string]: RarityInfo }

function Rarities.rank(rarityId: string): number
	local info = Rarities.Info[rarityId]
	return if info then info.rank else 0
end

return table.freeze(Rarities)
