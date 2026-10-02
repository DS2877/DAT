--!strict
-- The Bounty Board: three small tasks at a time ("Find 2 Rares", "Dig 8 in
-- the Jungle", "Land 6 PERFECT hits"...). Finish one, claim its reward and
-- a new one takes its place. Every `bonusEvery` bounties there's a bonus.
-- Rewards are a share of the player's next goal (fair at every level), kept
-- small: bounties are short goals to chase, not a faster road to rebirth.

export type Template = {
	kind: string, -- "Dig" | "DigArea" | "Rarity" | "Treasure" | "Perfect" | "Junk" | "Sell"
	weight: number,
	count: { number }?, -- { min, max } how many
	rarity: string?, -- Rarity bounties: this rarity or better
	maxRarity: string?, -- Treasure bounties: pick a treasure up to this rarity
	minAreaOrder: number?, -- only once this many areas are unlocked
	goalShare: number?, -- Sell bounties: sell this share of the next goal
	reward: number, -- cash reward: this share of the next goal
}

local Bounties = {
	slots = 3,
	rewardMin = 100, -- smallest cash reward
	bonusEvery = 5,
	bonus = {
		kind = "Bundle",
		items = {
			{ kind = "EpicDig", count = 1 },
			{ kind = "Boost", boost = "Cash2x", seconds = 300 },
		},
	},
	templates = {
		{ kind = "Dig", weight = 3, count = { 8, 14 }, reward = 0.03 },
		{ kind = "DigArea", weight = 3, count = { 6, 10 }, reward = 0.035 },
		{ kind = "Rarity", weight = 2, rarity = "Rare", count = { 2, 3 }, reward = 0.04 },
		{ kind = "Rarity", weight = 1, rarity = "Epic", count = { 1, 1 }, minAreaOrder = 2, reward = 0.06 },
		{ kind = "Treasure", weight = 2, maxRarity = "Uncommon", reward = 0.05 },
		{ kind = "Perfect", weight = 2, count = { 6, 10 }, reward = 0.03 },
		{ kind = "Junk", weight = 1, count = { 1, 2 }, reward = 0.035 },
		{ kind = "Sell", weight = 1, goalShare = 0.4, reward = 0.025 },
	} :: { Template },
}

return table.freeze(Bounties)
