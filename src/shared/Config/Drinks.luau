--!strict
-- The Tiki Bar on the beach: drinks bought with Cash that give a short boost.
-- Prices scale with the player's next goal (a share of the next shovel, or
-- the rebirth), so a drink costs about the same effort at every stage.
--
-- `boost` is the timed boost it adds (Config/Retention.boosts); buying a
-- drink that's still running adds more time.

export type Drink = {
	name: string,
	emoji: string,
	blurb: string,
	boost: string,
	seconds: number,
	goalPercent: number, -- price = this share of the next goal...
	min: number, -- ...but never less than this
	order: number,
}

local Drinks = {
	Defs = {
		SpeedSoda = {
			name = "Speed Soda",
			emoji = "🥤",
			blurb = "Run 50% faster",
			boost = "SpeedSoda",
			seconds = 300,
			goalPercent = 0.03,
			min = 40,
			order = 1,
		},
		JumpJuice = {
			name = "Jump Juice",
			emoji = "🍹",
			blurb = "Jump twice as high",
			boost = "JumpJuice",
			seconds = 300,
			goalPercent = 0.03,
			min = 40,
			order = 2,
		},
		GoldenCoconut = {
			name = "Golden Coconut",
			emoji = "🥥",
			blurb = "+25% cash for every treasure",
			boost = "CoconutCash",
			seconds = 300,
			goalPercent = 0.08,
			min = 120,
			order = 3,
		},
		LuckyLemonade = {
			name = "Lucky Lemonade",
			emoji = "🍋",
			blurb = "2x chance of Shiny and Golden treasure",
			boost = "LuckyLemonade",
			seconds = 300,
			goalPercent = 0.1,
			min = 150,
			order = 4,
		},
	} :: { [string]: Drink },

	-- Walking onto the bar's pad opens the menu (studs from its center).
	stationRadius = 7,
}

return table.freeze(Drinks)
