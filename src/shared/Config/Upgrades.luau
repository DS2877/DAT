--!strict
-- Shovel and bag ladders. Level 1 of each is free (starting gear).
-- Costs are tuned with scripts/pacing.luau toward the pacing targets (a
-- typical player: Jungle ~8 min, Ruins ~30 min, Volcano ~80 min, first
-- rebirth ~3 h); re-tune from analytics once real players exist.
-- Bags: start small (5), a cheap first step to 10, about a shovel's price
-- up to 20, and much more after that (late-game goals).
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
	-- What happens where it hits the ground (client ImpactFx): "Dust",
	-- "Pebbles", "Sparks", "Coins", "Sparkle", "Rainbow", "Lava", "Cosmic",
	-- "Snow", "Shards", "Aurora".
	impact: string?,
}

export type BagDef = {
	level: number,
	name: string,
	capacity: number,
	cost: number,
}

local CurrentWorld = require(script.Parent.Parent.Logic.CurrentWorld)

local Upgrades = {}

-- stylua: ignore
Upgrades.Shovels = {
	{ level = 1, name = "Wooden Shovel", cost = 0, hits = 3, hitInterval = 0.5, bladeColor = "#C0602A", handleColor = "#5B3A22", bladeMaterial = "Wood", glow = false, impact = "Dust" },
	{ level = 2, name = "Stone Shovel", cost = 250, hits = 3, hitInterval = 0.43, bladeColor = "#5E6A78", handleColor = "#4A2F1C", bladeMaterial = "Slate", glow = false, impact = "Pebbles" },
	{ level = 3, name = "Iron Shovel", cost = 5000, hits = 3, hitInterval = 0.37, bladeColor = "#9FB3CC", handleColor = "#2E2A33", bladeMaterial = "Metal", glow = false, impact = "Sparks" },
	{ level = 4, name = "Golden Shovel", cost = 20000, hits = 3, hitInterval = 0.32, bladeColor = "#FFC933", handleColor = "#5B3A22", bladeMaterial = "Metal", glow = false, impact = "Coins" },
	{ level = 5, name = "Diamond Shovel", cost = 80000, hits = 3, hitInterval = 0.27, bladeColor = "#7FF3FF", handleColor = "#2E4A6B", bladeMaterial = "Glass", glow = false, impact = "Sparkle" },
	{ level = 6, name = "Rainbow Shovel", cost = 400000, hits = 3, hitInterval = 0.23, bladeColor = "#FF5FD2", handleColor = "#FFFFFF", bladeMaterial = "Neon", glow = true, impact = "Rainbow" },
	{ level = 7, name = "Magma Shovel", cost = 800000, hits = 3, hitInterval = 0.2, bladeColor = "#FF6A1A", handleColor = "#2B2323", bladeMaterial = "Neon", glow = true, impact = "Lava" },
	{ level = 8, name = "Legendary Shovel", cost = 5000000, hits = 3, hitInterval = 0.17, bladeColor = "#B66BFF", handleColor = "#FFD24A", bladeMaterial = "Neon", glow = true, impact = "Cosmic" },
} :: { ShovelDef }

-- stylua: ignore
Upgrades.Bags = {
	{ level = 1, name = "Pouch", capacity = 5, cost = 0 },
	{ level = 2, name = "Satchel", capacity = 10, cost = 100 },
	{ level = 3, name = "Backpack", capacity = 15, cost = 8000 },
	{ level = 4, name = "Explorer Pack", capacity = 20, cost = 30000 },
	{ level = 5, name = "Treasure Sack", capacity = 30, cost = 350000 },
	{ level = 6, name = "Giant Sack", capacity = 45, cost = 1500000 },
	{ level = 7, name = "Pirate Chest Pack", capacity = 65, cost = 5000000 },
	{ level = 8, name = "Bottomless Bag", capacity = 90, cost = 15000000 },
} :: { BagDef }

-- Frostbite Peaks starts over with its own ladders: new shovels (an icy
-- design each) and bags, priced for the bigger frost treasure values.
-- stylua: ignore
local FrostShovels = {
	{ level = 1, name = "Frostbite Shovel", cost = 0, hits = 3, hitInterval = 0.5, bladeColor = "#BFE6F2", handleColor = "#3B4A5A", bladeMaterial = "Ice", glow = false, impact = "Snow" },
	{ level = 2, name = "Icicle Shovel", cost = 3750, hits = 3, hitInterval = 0.43, bladeColor = "#A8E6FF", handleColor = "#5A6E80", bladeMaterial = "Glass", glow = false, impact = "Shards" },
	{ level = 3, name = "Snowdrift Shovel", cost = 75000, hits = 3, hitInterval = 0.37, bladeColor = "#F4FBFF", handleColor = "#2E4A6B", bladeMaterial = "Snow", glow = false, impact = "Snow" },
	{ level = 4, name = "Glacier Shovel", cost = 300000, hits = 3, hitInterval = 0.32, bladeColor = "#5CC6F2", handleColor = "#1E3A5A", bladeMaterial = "Glacier", glow = false, impact = "Shards" },
	{ level = 5, name = "Aurora Shovel", cost = 1200000, hits = 3, hitInterval = 0.27, bladeColor = "#6CFFC4", handleColor = "#3B2A6B", bladeMaterial = "Neon", glow = true, impact = "Aurora" },
	{ level = 6, name = "Blizzard Shovel", cost = 6000000, hits = 3, hitInterval = 0.23, bladeColor = "#E8F8FF", handleColor = "#5CC6F2", bladeMaterial = "Neon", glow = true, impact = "Snow" },
	{ level = 7, name = "Permafrost Shovel", cost = 12000000, hits = 3, hitInterval = 0.2, bladeColor = "#2E6FD8", handleColor = "#0F1E33", bladeMaterial = "Neon", glow = true, impact = "Shards" },
	{ level = 8, name = "Frost King Shovel", cost = 75000000, hits = 3, hitInterval = 0.17, bladeColor = "#7FDBFF", handleColor = "#FFD24A", bladeMaterial = "Neon", glow = true, impact = "Cosmic" },
} :: { ShovelDef }

-- stylua: ignore
local FrostBags = {
	{ level = 1, name = "Fur Pouch", capacity = 5, cost = 0 },
	{ level = 2, name = "Woolly Satchel", capacity = 10, cost = 1500 },
	{ level = 3, name = "Sled Pack", capacity = 15, cost = 120000 },
	{ level = 4, name = "Expedition Pack", capacity = 20, cost = 450000 },
	{ level = 5, name = "Yeti Sack", capacity = 30, cost = 5250000 },
	{ level = 6, name = "Avalanche Sack", capacity = 45, cost = 22500000 },
	{ level = 7, name = "Glacier Chest Pack", capacity = 65, cost = 75000000 },
	{ level = 8, name = "Bottomless Frost Bag", capacity = 90, cost = 225000000 },
} :: { BagDef }

if CurrentWorld.isFrost() then
	Upgrades.Shovels = FrostShovels
	Upgrades.Bags = FrostBags
end

return table.freeze(Upgrades)
