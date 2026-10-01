--!strict
-- Every audio / animation asset in one place.
--
-- Audio comes from Roblox's own licensed Creator Store libraries, free to
-- use in any experience: Pro Sound Effects ("ProSoundEffects"), APM Music
-- ("APMOfficial") and the Roblox UI sound pack (creator "Roblox"). Nothing
-- third-party.
--
-- Each sound is a list of variants (one is picked at random per play):
--   id      rbxassetid
--   volume  measured so every sound sits at a consistent level
--   start   seconds to skip (many library clips have a lead-in)
--   length  seconds to play before stopping (nil = to the end)
-- `jitter` randomizes the pitch by +/- that fraction on every play.
-- The game must run fine if any id is missing: empty lists simply don't play.

export type Clip = { id: string, volume: number, start: number, length: number? }
export type SoundDef = { clips: { Clip }, jitter: number?, duck: boolean? }

local function clip(id: number, volume: number, start: number?, length: number?): Clip
	return { id = "rbxassetid://" .. id, volume = volume, start = start or 0, length = length }
end

local AssetIds = {
	Sounds = {
		-- Digging: one set per ground type (Beach + Ruins = sand, Jungle =
		-- dirt, Volcano = rock). Sand Impacts 1 holds four separate hits.
		DigHitSand = {
			clips = {
				clip(9118767938, 0.84, 0.00, 0.35), -- Sand Impacts 1 (PSE)
				clip(9118767938, 0.98, 0.43, 0.35),
				clip(9118767938, 1.24, 0.74, 0.35),
				clip(9118767938, 0.95, 1.05, 0.35),
				clip(9118768256, 4.36, 0.19, 0.40), -- Sand Impacts 4 (PSE)
				clip(9118768199, 0.96, 0.31, 0.50), -- Sand Impacts 6 (PSE)
			},
			jitter = 0.08,
		},
		DigHitDirt = {
			clips = {
				clip(9114084427, 1.18, 0.21, 0.45), -- Dirt Digging With Pick 15 (PSE)
				clip(9114084044, 1.09, 0.17, 0.45), -- Dirt Digging With Pick 5 (PSE)
				clip(9114084422, 0.44, 0.23, 0.45), -- Dirt Digging With Pick 14 (PSE)
			},
			jitter = 0.08,
		},
		DigHitRock = {
			clips = {
				clip(9125869504, 4.2, 0, 0.5), -- Rock Cracks, Rock Hitting Rock (PSE)
				clip(9125869495, 3.7, 0, 0.5),
				clip(9125869107, 4.3, 0, 0.5),
			},
			jitter = 0.08,
		},
		-- The last hit: dirt bursts out of the hole.
		DigBurst = { clips = { clip(9114034583, 2.24, 0.18, 0.9) }, jitter = 0.06 }, -- Debris Rain 4 (PSE)
		DeepDig = { clips = { clip(9113222895, 1.81, 1.0, 5.0) } }, -- Avalanche Rumble 12 (PSE)

		-- Reveals, escalating with rarity.
		RevealCommon = { clips = { clip(15675055424, 0.69, 0, 0.5) }, jitter = 0.06 }, -- Roblox_UI_Cute_Pop
		RevealRare = { clips = { clip(9116394876, 3.86, 0, 2.0) } }, -- Magic Glows Chiming Hits 2 (PSE)
		RevealEpic = { clips = { clip(1848287311, 0.43, 0.1, 2.5) }, duck = true }, -- "The Little Things - Hit" (APM)
		StingLegendary = { clips = { clip(1842141561, 0.40, 0, 5.0) }, duck = true }, -- "Celebration Nation (sting a)" (APM)
		StingSecret = { clips = { clip(1840095069, 0.62, 0, 7.5) }, duck = true }, -- "Make It Happen (sting b)" (APM)
		Whoosh = { clips = { clip(15675028888, 0.51) }, jitter = 0.05 }, -- Roblox_UI_Whoosh_02: find flies to the bag

		Streak = { clips = { clip(9126073001, 1.68, 0.1, 1.0) } }, -- Synth Sparkle Bell Ding (PSE)
		BagTick = { clips = { clip(9125444889, 0.68, 0, 0.6) }, jitter = 0.08 }, -- Coins Drop, Medallions (PSE)
		BagFull = { clips = { clip(9113260699, 0.55, 0, 1.2) } }, -- Bag Zipper (PSE)
		Sell = { clips = { clip(9113728042, 0.59, 1.45, 0.65) } }, -- Cash Register 1, the "ka-ching" (PSE)
		SellCoins = { clips = { clip(9113849492, 1.93, 0, 1.2) }, jitter = 0.05 }, -- Coins Jingle 6 (PSE)
		Upgrade = { clips = { clip(9045808250, 0.43, 0, 3.4) }, duck = true }, -- "High Five Happy (sting)" (APM)
		AreaUnlocked = { clips = { clip(1847368343, 0.52, 0.12, 4.6) }, duck = true }, -- "Epic Love Promo H" (APM)
		Reward = { clips = { clip(15675043410, 0.41) } }, -- Roblox_UI_Tonal_Stinger
		Announce = { clips = { clip(9126073318, 1.09, 0.1, 1.5) } }, -- Synth Sparkle Bell Ding (PSE)
		SecretWorld = { clips = { clip(9120769331, 0.44, 0.1, 5.5) } }, -- Wind Whoosh Sonic Boom (PSE)
		Denied = { clips = { clip(15675062723, 0.25) } }, -- Roblox_UI_Whistle_Low
		UiClick = { clips = { clip(15675059323, 0.40) }, jitter = 0.04 }, -- Roblox_UI_Bright_Click
	} :: { [string]: SoundDef },

	-- Mix: each sound group's level (Settings toggles mute them). Effects
	-- sit a little under the music.
	Mix = { Effects = 0.7, Ambience = 1, Music = 1 } :: { [string]: number },

	-- Looping beds per area, crossfaded as the player moves.
	Ambience = {
		Beach = { clip(9120571708, 0.23), clip(9112870701, 3.41) }, -- Water Lap onto Rocks + distant Seagulls (PSE)
		Jungle = { clip(9114891624, 6.0) }, -- Jungle Ambience 4 (PSE)
		Ruins = { clip(9114057128, 5.4) }, -- Desert Wind, Whistley Light Gusts 2 (PSE)
		Volcano = { clip(9112823197, 0.21) }, -- Lava Rumble 1 (PSE)
	} :: { [string]: { Clip } },

	-- 3D loops attached to world objects (by part name) by AudioController.
	Emitters = {
		Waterfall = clip(9120552418, 4.7), -- Waterfall Small 1 (PSE)
		Fire = clip(9112780193, 6.0), -- Fireplace Constant Burning Flame 1 (PSE)
		Lava = clip(9112822943, 0.22), -- Lava Fire Deep Rumbling 2 (PSE)
	},

	Music = {
		Main = clip(9038762538, 0.21), -- "Easy Uke" (APM): light, positive ukulele
		Rush = clip(9039987815, 0.23), -- "Feeling Fresh" (APM): energetic ukulele for Treasure Rush
		MegaDig = clip(1847444965, 0.22), -- "Party Hype A" (APM): for the players digging a Mega Dig
	},

	Animations = {
		DigSwing = "", -- unused: the dig is a procedural whole-body animation (Effects.swing)
	},
}

return table.freeze(AssetIds)
