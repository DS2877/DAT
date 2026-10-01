--!strict
-- Retention systems: rebirth, playtime gifts, daily reward, Golden X,
-- Treasure Rush, boosts, friends bonus, group reward, leaderboards.
--
-- Reward entries: { kind = "Cash", goalPercent, min } (scaled to the player's
-- next goal), { kind = "Boost", boost, seconds }, { kind = "RareDig" |
-- "EpicDig", count } (guaranteed rarity on the next digs), or
-- { kind = "Bundle", items = { ... } }.

local Retention = {
	rebirth = {
		requiredShovel = 8, -- the Legendary Shovel
		baseCost = 3000000, -- cash needed (on top of owning the shovel)
		costGrowth = 1.3, -- each rebirth costs this much more
		cashBonusPerRebirth = 0.25,
		-- One title per rebirth (the last repeats with a number after it).
		titles = {
			"Bronze Hunter",
			"Silver Hunter",
			"Gold Hunter",
			"Diamond Hunter",
			"Master Hunter",
			"Grand Master",
			"Island Legend",
			"Mythic Legend",
		},
		-- Shovel tint per rebirth (cycles).
		tints = { "#CD7F32", "#D9DEE4", "#FFD700", "#7FF3FF", "#B45CFF", "#FF3D6E", "#FFFFFF", "#2EE88A" },
		-- A rebirth-only Secret joins the loot pool every this many rebirths.
		secretEvery = 5,
	},

	playtimeGifts = {
		{ minutes = 5, reward = { kind = "Cash", goalPercent = 0.15, min = 100 } },
		{ minutes = 10, reward = { kind = "Boost", boost = "Cash2x", seconds = 300 } },
		{ minutes = 20, reward = { kind = "RareDig", count = 1 } },
		{ minutes = 30, reward = { kind = "Cash", goalPercent = 0.3, min = 250 } },
		{ minutes = 45, reward = { kind = "Boost", boost = "DigSpeed2x", seconds = 600 } },
	},

	daily = {
		{ kind = "Cash", goalPercent = 0.10, min = 100 },
		{ kind = "Cash", goalPercent = 0.15, min = 150 },
		{ kind = "Boost", boost = "Cash2x", seconds = 600 },
		{ kind = "Cash", goalPercent = 0.25, min = 250 },
		{ kind = "RareDig", count = 2 },
		{ kind = "Boost", boost = "DigSpeed2x", seconds = 900 },
		{
			kind = "Bundle",
			items = {
				{ kind = "Cash", goalPercent = 0.6, min = 1000 },
				{ kind = "EpicDig", count = 1 },
			},
		},
	},

	goldenX = { minRarity = "Epic" },

	-- Treasure Rush runs on a fixed global clock: every `interval` seconds
	-- (aligned to UTC), for `duration` seconds.
	rush = {
		interval = 900,
		duration = 120,
		oddsMultipliers = {
			Common = 0.5,
			Uncommon = 1.2,
			Rare = 2,
			Epic = 2.5,
			Legendary = 3,
			Mythic = 3,
			Secret = 3,
		},
	},

	boosts = {
		Cash2x = { displayName = "2x Cash", multiplier = 2 },
		DigSpeed2x = { displayName = "2x Dig Speed", multiplier = 2 },
		-- Tiki Bar drinks (Config/Drinks).
		SpeedSoda = { displayName = "🥤 Speed Soda", multiplier = 1.5 }, -- walk speed
		JumpJuice = { displayName = "🍹 Jump Juice", multiplier = 2 }, -- jump height
		CoconutCash = { displayName = "🥥 +25% Cash", multiplier = 1.25 }, -- cash
		LuckyLemonade = { displayName = "🍋 Lucky", multiplier = 2 }, -- Shiny / Golden chance
	},

	friends = { bonusPerFriend = 0.10, maxBonus = 0.30 },

	-- One-time free reward for joining the game's Roblox group.
	-- TODO: set groupId to the game's group (0 hides the feature).
	group = { groupId = 0, reward = { kind = "Cash", goalPercent = 0.5, min = 500 } },

	leaderboards = {
		writeInterval = 120, -- seconds between a player's leaderboard writes
		readInterval = 90, -- seconds between board refreshes
		top = 10,
	},
}

return table.freeze(Retention)
