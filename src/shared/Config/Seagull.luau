--!strict
-- The seagull hat thief (SeagullService, SeagullController). Now and then a
-- seagull swoops down on a player near the palms, steals their hat and sits
-- on top of a palm tree with it. Walk under that palm and it drops the hat
-- back on your head, with a shiny coin as an apology. Only on the Island,
-- only for players who finished the tutorial and wear a hat; if nobody
-- comes, the seagull gets bored and brings the hat back.

local Seagull = {
	checkEvery = 20, -- seconds between rolls
	chance = 0.05, -- per eligible player per roll
	firstAfter = 240, -- seconds in the server before a player can be picked
	cooldown = 1200, -- seconds before the same player can be robbed again
	palmRange = { min = 25, max = 90 }, -- how far away the seagull's palm is
	retrieveRadius = 11, -- stand this close to the palm (sideways) to get it back
	giveUpAfter = 150, -- seconds on the palm before it brings the hat back
	swoop = 2.2, -- seconds to dive in to the head
	toPalm = 3.2, -- seconds to fly to the palm
	away = 3, -- seconds to fly off at the end
	scale = 1.5,
	-- The apology: cash as a share of the player's next goal (Logic/Bonuses).
	reward = { kind = "Cash", goalPercent = 0.02, min = 25 },
	lines = {
		steal = {
			"🐦 SQUAWK! A seagull stole your hat!",
			"🐦 A seagull thinks your hat looks better on a seagull!",
			"🐦 Hey! That seagull just took your hat!",
		},
		perch = "It's sitting on a palm tree. Walk under it to get your hat back!",
		back = {
			"🎩 Hat recovered! The seagull says sorry with a shiny coin.",
			"🎩 Got it back! The seagull left a coin. Classy bird.",
		},
		giveUp = "🐦 The seagull got bored and dropped your hat back on your head.",
	},
}

return table.freeze(Seagull)
