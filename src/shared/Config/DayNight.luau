--!strict
-- Day and night. One clock for every server (from the server time): a day
-- lasts `cycle` seconds, `dayLength` of it daytime (the sun goes from
-- `dawn` to `dusk`), the rest night. At night the sky darkens (lit enough
-- to play), crickets and owls sound, and moonlit dig spots glow in every
-- area with much better odds.

local DayNight = {
	cycle = 1200, -- seconds for a whole day
	dayLength = 900, -- seconds of daytime (then 5 minutes of night)
	offset = 0, -- shifts the clock (seconds)
	dawn = 6.5, -- ClockTime when the day starts
	dusk = 18.8, -- ClockTime when the night starts
	fade = 25, -- seconds to blend the lighting at dusk and dawn
	-- Night lighting (blended in on top of the world's own day lighting).
	night = {
		ambient = "#3C4466",
		outdoorAmbient = "#5A6894",
		brightness = 1.4,
	},
	-- Moonlit dig spots: this many per area during the night (a dug one
	-- comes back somewhere else after `respawn` seconds).
	moonlit = {
		perArea = 2,
		respawn = 20,
		color = "#A9DCFF",
		oddsMultipliers = {
			Common = 0.3,
			Uncommon = 1,
			Rare = 2.5,
			Epic = 3,
			Legendary = 3,
			Mythic = 3,
			Secret = 3,
		} :: { [string]: number },
	},
}

return table.freeze(DayNight)
