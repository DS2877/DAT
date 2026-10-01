--!strict
-- Everything sold for Robux, and how the game offers it.
--
-- Rules (Roblox policy + this game's own):
--   * every purchase grants a fixed, described item (no paid random items)
--   * the Roblox purchase prompt opens only when the player taps a buy button
--   * nothing paid is needed to reach an area or find a treasure: purchases
--     speed things up, add convenience, or add cosmetics
--
-- `id` is the pass / product id on Roblox. scripts/store-sync.luau creates
-- every entry on Roblox from this file (name, description, price, icon in
-- store/icons/<icon>.png) and prints the ids to paste here. 0 = not created
-- yet: the item is hidden from the shop and its perk is off.

export type Pass = {
	id: number,
	name: string,
	description: string, -- shown on Roblox's pass page
	blurb: string, -- the shop card's one-liner (plain words, with numbers)
	emoji: string,
	icon: string, -- store/icons/<icon>.png
	price: number,
	order: number,
	toggle: string?, -- the settings key that turns the perk on/off
	enabled: boolean?, -- false = not sold (and not created on Roblox)
}

export type Product = {
	id: number,
	name: string,
	description: string,
	blurb: string,
	emoji: string,
	icon: string,
	price: number,
	order: number,
	tab: "Boosts" | "Cash" | "Skins",
	grant: { [string]: any },
	oneTime: boolean?, -- can only be bought once (hidden after)
	enabled: boolean?,
}

local Monetization = {
	-- Permanent perks. A price ladder from cheap convenience to VIP.
	Passes = {
		AutoDig = {
			id = 0,
			name = "Auto Dig",
			description = "Hold the DIG button to keep digging, instead of tapping for every hit. Turn it on or off any time in the Shop or Settings.",
			blurb = "Hold DIG to keep digging. On/off any time.",
			emoji = "⛏️",
			icon = "AutoDig",
			price = 80,
			order = 1,
			toggle = "autoDig",
		},
		TreasureRadar = {
			id = 0,
			name = "Treasure Radar",
			description = "An arrow points to the nearest clue spot (clue spots have better odds). Turn it on or off any time.",
			blurb = "An arrow points to the nearest clue spot.",
			emoji = "🧭",
			icon = "TreasureRadar",
			price = 99,
			order = 2,
			toggle = "radar",
		},
		BigBag = {
			id = 0,
			name = "+50% Bag",
			description = "Your bag holds 50% more treasure, at every bag level (10 becomes 15, 100 becomes 150).",
			blurb = "Your bag holds 50% more (10 → 15).",
			emoji = "🎒",
			icon = "BigBag",
			price = 149,
			order = 3,
		},
		AutoSell = {
			id = 0,
			name = "Auto Sell",
			description = "Sell from anywhere: your bag sells itself the moment it's full, and you can tap SELL on your bag any time. No more walking back. Turn auto-selling on or off any time.",
			blurb = "Sells your bag the moment it's full, anywhere. Plus a SELL button on your bag.",
			emoji = "💰",
			icon = "AutoSell",
			price = 199,
			order = 4,
			toggle = "autoSell",
		},
		FastDig = {
			id = 0,
			name = "2x Dig Speed",
			description = "Dig twice as fast, forever. Adds up with Dig Speed boosts (3x together).",
			blurb = "Dig 2x faster, forever.",
			emoji = "⚡",
			icon = "FastDig",
			price = 249,
			order = 5,
		},
		CashX2 = {
			id = 0,
			name = "2x Cash",
			description = "Every treasure sells for 2x cash, forever. Stacks with boosts, rebirths and set bonuses.",
			blurb = "Every treasure sells for 2x, forever.",
			emoji = "💵",
			icon = "CashX2",
			price = 299,
			order = 6,
		},
		VIP = {
			id = 0,
			name = "VIP",
			description = "Includes Auto Dig and Auto Sell, +10% cash on every sale, a gold name and [VIP] chat tag, the VIP Gold shovel skin, and the VIP dig spot at the base.",
			blurb = "Auto Dig + Auto Sell, +10% cash, gold name, [VIP] tag, VIP shovel, VIP dig spot.",
			emoji = "👑",
			icon = "VIP",
			price = 399,
			order = 7,
		},
		-- Off until the developer decides (see the Phase 5 report): luck on
		-- free gameplay loot. Not created on Roblox while disabled.
		Luck2x = {
			id = 0,
			name = "2x Luck",
			description = "Doubles the chance of Rare and better finds on every dig (Common chances shrink to make room).",
			blurb = "2x the chance of Rare and better finds.",
			emoji = "🍀",
			icon = "Luck2x",
			price = 349,
			order = 8,
			enabled = false,
		},
	} :: { [string]: Pass },

	-- What each pass does (read by Logic/Perks).
	Perks = {
		vipIncludes = { "AutoDig", "AutoSell" },
		vipCashBonus = 0.10,
		cashPassMultiplier = 2,
		bigBagMultiplier = 1.5,
		fastDigBonus = 1, -- adds to the dig speed multiplier (1 + pass + boost)
		maxDigSpeed = 3,
		luckMultiplier = 2,
	},

	-- Repeatable purchases (plus a one-time starter pack and skins).
	Products = {
		StarterPack = {
			id = 0,
			name = "Starter Pack",
			description = "One time only: cash for your next shovel, 30 minutes of 2x Cash, and the Explorer shovel skin.",
			blurb = "Cash for your next shovel + 30 min 2x Cash + Explorer shovel skin.",
			emoji = "🎁",
			icon = "StarterPack",
			price = 49,
			order = 0,
			tab = "Cash",
			oneTime = true,
			grant = {
				kind = "Bundle",
				items = {
					{ kind = "Cash", goalPercent = 1.0, min = 1500 },
					{ kind = "Boost", boost = "Cash2x", seconds = 1800 },
					{ kind = "Skin", skin = "Explorer" },
				},
			},
		},
		CashSmall = {
			id = 0,
			name = "Pouch of Cash",
			description = "Cash worth 30% of your next shovel (at least $300).",
			blurb = "30% of your next shovel.",
			emoji = "💰",
			icon = "CashSmall",
			price = 29,
			order = 1,
			tab = "Cash",
			grant = { kind = "Cash", goalPercent = 0.3, min = 300 },
		},
		CashMedium = {
			id = 0,
			name = "Sack of Cash",
			description = "Cash worth your whole next shovel (at least $1,000).",
			blurb = "Enough for your next shovel.",
			emoji = "💰",
			icon = "CashMedium",
			price = 79,
			order = 2,
			tab = "Cash",
			grant = { kind = "Cash", goalPercent = 1.0, min = 1000 },
		},
		CashLarge = {
			id = 0,
			name = "Chest of Cash",
			description = "Cash worth 3x your next shovel (at least $3,000).",
			blurb = "3x your next shovel.",
			emoji = "💎",
			icon = "CashLarge",
			price = 199,
			order = 3,
			tab = "Cash",
			grant = { kind = "Cash", goalPercent = 3.0, min = 3000 },
		},
		BoostCash = {
			id = 0,
			name = "2x Cash Boost (15 min)",
			description = "Everything you sell is worth 2x for 15 minutes. Buying more adds time.",
			blurb = "2x cash for 15 minutes.",
			emoji = "💵",
			icon = "BoostCash",
			price = 49,
			order = 1,
			tab = "Boosts",
			grant = { kind = "Boost", boost = "Cash2x", seconds = 900 },
		},
		BoostDig = {
			id = 0,
			name = "2x Dig Speed Boost (15 min)",
			description = "Dig twice as fast for 15 minutes. Buying more adds time.",
			blurb = "Dig 2x faster for 15 minutes.",
			emoji = "⚡",
			icon = "BoostDig",
			price = 49,
			order = 2,
			tab = "Boosts",
			grant = { kind = "Boost", boost = "DigSpeed2x", seconds = 900 },
		},
		ServerBoost = {
			id = 0,
			name = "Server 2x Cash (10 min)",
			description = "2x cash for EVERYONE in your server for 10 minutes, with a thank-you shout-out to you.",
			blurb = "2x cash for everyone in the server for 10 min. Everyone sees who boosted!",
			emoji = "📣",
			icon = "ServerBoost",
			price = 199,
			order = 3,
			tab = "Boosts",
			grant = { kind = "ServerBoost", seconds = 600 },
		},
		InstantDeepDig = {
			id = 0,
			name = "Instant Deep Dig",
			description = "Finish a Deep Dig in one tap. If your Deep Dig is already done, it's saved for your next one.",
			blurb = "Finish a Deep Dig in one tap (saved for later if none is active).",
			emoji = "🌋",
			icon = "InstantDeepDig",
			price = 25,
			order = 4,
			tab = "Boosts",
			grant = { kind = "InstantDeepDig" },
		},
		SkinPirate = {
			id = 0,
			name = "Pirate Shovel",
			description = "A cosmetic shovel skin: dark wood and gold. Looks only, works at every shovel level.",
			blurb = "Dark wood and gold. Looks only.",
			emoji = "⚓",
			icon = "SkinPirate",
			price = 99,
			order = 1,
			tab = "Skins",
			oneTime = true,
			grant = { kind = "Skin", skin = "Pirate" },
		},
		SkinIce = {
			id = 0,
			name = "Ice Shovel",
			description = "A cosmetic shovel skin: glowing ice. Looks only, works at every shovel level.",
			blurb = "Glowing ice. Looks only.",
			emoji = "🧊",
			icon = "SkinIce",
			price = 149,
			order = 2,
			tab = "Skins",
			oneTime = true,
			grant = { kind = "Skin", skin = "Ice" },
		},
		SkinLava = {
			id = 0,
			name = "Lava Shovel",
			description = "A cosmetic shovel skin: molten lava with a glow. Looks only, works at every shovel level.",
			blurb = "Molten lava with a glow. Looks only.",
			emoji = "🔥",
			icon = "SkinLava",
			price = 199,
			order = 3,
			tab = "Skins",
			oneTime = true,
			grant = { kind = "Skin", skin = "Lava" },
		},
	} :: { [string]: Product },

	-- Shovel skins (cosmetic only). `source` says how a skin is unlocked.
	Skins = {
		Explorer = {
			name = "Explorer",
			blade = "#3FA34D",
			handle = "#C8A26B",
			material = "Metal",
			glow = false,
			source = "StarterPack",
		},
		Pirate = {
			name = "Pirate",
			blade = "#E8B923",
			handle = "#2B1D14",
			material = "Metal",
			glow = false,
			source = "SkinPirate",
		},
		Ice = {
			name = "Ice",
			blade = "#A5F2FF",
			handle = "#E8FBFF",
			material = "Glass",
			glow = true,
			source = "SkinIce",
		},
		Lava = {
			name = "Lava",
			blade = "#FF5A1F",
			handle = "#2B2323",
			material = "Neon",
			glow = true,
			source = "SkinLava",
		},
		VIPGold = {
			name = "VIP Gold",
			blade = "#FFD700",
			handle = "#1E1E1E",
			material = "Neon",
			glow = true,
			source = "VIP",
		},
	},
	SkinOrder = { "Explorer", "Pirate", "Ice", "Lava", "VIPGold" },

	-- Contextual offers: a small bubble, never a prompt. At most one every
	-- `offerCooldown` seconds, and each offer at most `maxPerSession` times.
	Offers = {
		offerCooldown = 180,
		maxPerSession = 2,
		visibleSeconds = 7,
		autoDigHoldSeconds = 0.7, -- holding DIG this long without Auto Dig
		autoSellMinDistance = 120, -- bag full this far from the sell pad
	},

	-- The VIP dig spot at the base: rolls like a clue spot in the player's
	-- best unlocked area, and comes back quickly.
	VipSpot = { respawnSeconds = 8 },

	-- TODO(shop): replaced by Offers once the Shop lands.
	AutoDigOffer = { holdSeconds = 0.7, cooldown = 180, maxPerSession = 3, visibleSeconds = 7 },

	-- Ownership lookups on join are retried this many times.
	ownershipRetries = 3,
	-- How many purchase ids each profile remembers (receipt idempotency).
	receiptHistory = 200,

	-- Rewarded video ads: off until the game meets Roblox's eligibility rules.
	ads = { enabled = false },
}

return Monetization
