--!strict
-- Shovel and bag ladders. Level 1 of each is free (starting gear).
-- Costs are tuned with scripts/pacing.luau toward the pacing targets (a
-- typical player: Jungle ~8 min, Ruins ~30 min, Volcano ~80 min, first
-- rebirth ~3 h); re-tune from analytics once real players exist.
-- Bags: start small (5), a cheap first step to 10, then each step costs
-- about as much as a shovel of the same stage.
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
	{ level = 1, name = "Wooden Shovel", cost = 0, hits = 3, hitInterval = 0.5, bladeColor = "#C0602A", handleColor = "#5B3A22", bladeMaterial = "Wood", glow = false },
	{ level = 2, name = "Stone Shovel", cost = 250, hits = 3, hitInterval = 0.43, bladeColor = "#5E6A78", handleColor = "#4A2F1C", bladeMaterial = "Slate", glow = false },
	{ level = 3, name = "Iron Shovel", cost = 5000, hits = 3, hitInterval = 0.37, bladeColor = "#9FB3CC", handleColor = "#2E2A33", bladeMaterial = "Metal", glow = false },
	{ level = 4, name = "Golden Shovel", cost = 20000, hits = 3, hitInterval = 0.32, bladeColor = "#FFC933", handleColor = "#5B3A22", bladeMaterial = "Metal", glow = false },
	{ level = 5, name = "Diamond Shovel", cost = 80000, hits = 3, hitInterval = 0.27, bladeColor = "#7FF3FF", handleColor = "#2E4A6B", bladeMaterial = "Glass", glow = false },
	{ level = 6, name = "Rainbow Shovel", cost = 200000, hits = 3, hitInterval = 0.23, bladeColor = "#FF5FD2", handleColor = "#FFFFFF", bladeMaterial = "Neon", glow = true },
	{ level = 7, name = "Magma Shovel", cost = 800000, hits = 3, hitInterval = 0.2, bladeColor = "#FF6A1A", handleColor = "#2B2323", bladeMaterial = "Neon", glow = true },
	{ level = 8, name = "Legendary Shovel", cost = 5000000, hits = 3, hitInterval = 0.17, bladeColor = "#B66BFF", handleColor = "#FFD24A", bladeMaterial = "Neon", glow = true },
} :: { ShovelDef }

-- stylua: ignore
Upgrades.Bags = {
	{ level = 1, name = "Pouch", capacity = 5, cost = 0 },
	{ level = 2, name = "Satchel", capacity = 10, cost = 100 },
	{ level = 3, name = "Backpack", capacity = 15, cost = 8000 },
	{ level = 4, name = "Explorer Pack", capacity = 20, cost = 30000 },
	{ level = 5, name = "Treasure Sack", capacity = 30, cost = 120000 },
	{ level = 6, name = "Giant Sack", capacity = 45, cost = 400000 },
	{ level = 7, name = "Pirate Chest Pack", capacity = 65, cost = 1500000 },
	{ level = 8, name = "Bottomless Bag", capacity = 90, cost = 5000000 },
} :: { BagDef }

return table.freeze(Upgrades)
