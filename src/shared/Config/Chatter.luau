--!strict
-- What the island's people say (ChatterController shows it in speech
-- bubbles over their heads, only for you). Keyed by the NPC's model name.
--   greet: when you walk up to them (each NPC at most every `greetCooldown`)
--   sell:  the merchant on what you just sold
--   bought / broke: the shopkeepers on your upgrade

local Chatter = {
	greetDistance = 15, -- studs
	greetCooldown = 40, -- seconds before the same NPC greets you again
	bubbleSeconds = 4,

	greet = {
		ShovelKeeper = {
			"Best shovels on the island! Probably.",
			"Dig harder, not smarter!",
			"Every shovel comes with a free blister.",
			"I sharpen them with my teeth. Kidding! ...Mostly.",
		},
		BagKeeper = {
			"Bigger bag, bigger dreams!",
			"Pockets full? I've got you.",
			"This one has a secret pocket. For snacks.",
		},
		SellKeeper = {
			"Got treasure? I've got coins!",
			"No refunds. No questions. Mostly no questions.",
			"Bring me shiny things!",
		},
		Bartender = {
			"Thirsty? A drink makes you dig faster!",
			"Fresh coconut, fresh vibes.",
			"Don't drink the seawater. Trust me.",
		},
		Fisherman = {
			"Caught a boot again...",
			"The fish are laughing at me. I can hear them.",
			"One day I'll catch the Golden Banana.",
		},
		Lifeguard = {
			"No digging in the ocean!",
			"I've been on duty since 1987.",
			"Swim at your own risk. Dig at your own reward!",
		},
		Camper = {
			"Want a marshmallow?",
			"They say the volcano rumbles before something falls from the sky...",
			"The ruins are haunted. Probably.",
		},
		Sunbather = {
			"Zzz...",
			"Five more minutes...",
			"Could you dig a little quieter?",
		},
	} :: { [string]: { string } },

	sell = {
		junk = {
			"A boot? ...Fine. I'll buy your boot.",
			"Is this... a very normal rock?",
			"Who keeps burying socks?!",
			"I'll take the junk. I have a junk problem.",
		},
		huge = {
			"WOW! I need to sit down.",
			"You're going to make me broke!",
			"Now THAT's a treasure!",
			"Is it my birthday?!",
		},
		normal = {
			"Pleasure doing business!",
			"Cha-ching!",
			"Come back with more!",
			"Ooh, shiny. I'll take it.",
		},
	},

	-- %s = the new shovel / bag's name.
	bought = {
		Shovel = {
			"The %s! Swing it with pride!",
			"Ooh, the %s. The dirt won't know what hit it.",
			"Treat the %s nicely. It bites.",
		},
		Bag = {
			"The %s! Room for so much loot.",
			"The %s. Fits treasure AND snacks.",
		},
	},
	broke = {
		"Come back with more coins, friend!",
		"Window shopping, eh?",
	},
}

return table.freeze(Chatter)
