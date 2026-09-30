--!strict
-- Shovel and bag ladders. Level 1 of each is free (starting gear).
-- Costs are tuned with scripts/pacing.luau toward the pacing targets (a
-- typical player: Jungle ~8 min, Ruins ~30 min, Volcano ~80 min, first
-- rebirth ~3 h); re-tune from analytics once real players exist.
-- Dig time per spot = hits * hitInterval (Wooden: 3 hits x 0.5s = 1.5s).

export type ShovelDef = {
	level: number,
	name: string,
	cost: number,
	hits: number,
	hitInterval: number,
	-- Visuals (hex colors + Enum.Material name) used by ShovelBuilder.
	bladeColor: string,
	handleColor: string,
	bladeMaterial: string,
	glow: boolean,
}

export type BagDef = {
	level: number,
	name: string,
	capacity: number,
	cost: number,
}

local Upgrades = {}

-- stylua: ignore
Upgrades.Shovels = {
	{ level = 1, name = "Wooden Shovel", cost = 0, hits = 3, hitInterval = 0.5, bladeColor = "#A8773F", handleColor = "#7A5230", bladeMaterial = "Wood", glow = false },
	{ level = 2, name = "Stone Shovel", cost = 250, hits = 3, hitInterval = 0.43, bladeColor = "#8C8F94", handleColor = "#7A5230", bladeMaterial = "Slate", glow = false },
	{ level = 3, name = "Iron Shovel", cost = 5000, hits = 3, hitInterval = 0.37, bladeColor = "#C9CED6", handleColor = "#5B3A22", bladeMaterial = "Metal", glow = false },
	{ level = 4, name = "Golden Shovel", cost = 20000, hits = 3, hitInterval = 0.32, bladeColor = "#FFC933", handleColor = "#5B3A22", bladeMaterial = "Metal", glow = false },
	{ level = 5, name = "Diamond Shovel", cost = 80000, hits = 3, hitInterval = 0.27, bladeColor = "#7FF3FF", handleColor = "#2E4A6B", bladeMaterial = "Glass", glow = false },
	{ level = 6, name = "Rainbow Shovel", cost = 200000, hits = 3, hitInterval = 0.23, bladeColor = "#FF5FD2", handleColor = "#FFFFFF", bladeMaterial = "Neon", glow = true },
	{ level = 7, name = "Magma Shovel", cost = 800000, hits = 3, hitInterval = 0.2, bladeColor = "#FF6A1A", handleColor = "#2B2323", bladeMaterial = "Neon", glow = true },
	{ level = 8, name = "Legendary Shovel", cost = 5000000, hits = 3, hitInterval = 0.17, bladeColor = "#B66BFF", handleColor = "#FFD24A", bladeMaterial = "Neon", glow = true },
} :: { ShovelDef }

-- stylua: ignore
Upgrades.Bags = {
	{ level = 1, name = "Pouch", capacity = 10, cost = 0 },
	{ level = 2, name = "Satchel", capacity = 15, cost = 150 },
	{ level = 3, name = "Backpack", capacity = 20, cost = 2500 },
	{ level = 4, name = "Explorer Pack", capacity = 30, cost = 10000 },
	{ level = 5, name = "Treasure Sack", capacity = 40, cost = 32000 },
	{ level = 6, name = "Giant Sack", capacity = 60, cost = 80000 },
	{ level = 7, name = "Pirate Chest Pack", capacity = 80, cost = 300000 },
	{ level = 8, name = "Bottomless Bag", capacity = 100, cost = 1600000 },
} :: { BagDef }

return table.freeze(Upgrades)
