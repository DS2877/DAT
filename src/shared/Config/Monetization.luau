--!strict
-- Game passes and how the game offers them.
--
-- Rules (Roblox policy + this game's own):
--   * passes only ever grant a fixed, described perk (no paid random items)
--   * the Roblox purchase prompt opens only when the player taps a buy button
--   * no pass is needed to reach anything: perks are conveniences
--
-- `id` is the pass's id from Creator Hub (Creations > Monetization > Passes).
-- 0 = not created yet: the perk is then free for everyone and never offered.
-- `price` is what the pass is set to in Creator Hub (the real price shown in
-- game is read from Roblox).

export type Pass = { id: number, name: string, description: string, icon: string, price: number }

local Monetization = {
	Passes = {
		AutoDig = {
			id = 0, -- TODO: set to the Auto Dig pass id
			name = "Auto Dig",
			description = "Hold DIG to keep digging",
			icon = "⛏️",
			price = 80,
		},
	} :: { [string]: Pass },

	-- The Auto Dig offer: a small bubble beside the DIG button, shown when a
	-- player without the pass keeps holding DIG (it only digs once per tap).
	AutoDigOffer = {
		holdSeconds = 0.7, -- holding DIG this long counts as "trying to hold"
		cooldown = 180, -- seconds before the bubble can show again
		maxPerSession = 3,
		visibleSeconds = 7, -- the bubble hides by itself after this long
	},

	-- Ownership lookups on join are retried this many times.
	ownershipRetries = 3,
}

return Monetization
