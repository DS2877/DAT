--!strict
-- Rebirth perks: every rebirth you pick one of three perk cards. Perks are
-- permanent (shared by every world) and level up when picked again, so each
-- player grows their own build. They're small on purpose: a rebirth still
-- means a new run, just a little different every time.
-- `step` is what one level adds; `max` the highest level.

export type Perk = {
	id: string,
	name: string,
	icon: string,
	step: number,
	max: number,
	-- How the total reads ("+10% cash on every treasure"); %s = the amount.
	text: string,
	percent: boolean?, -- show the amount as a percentage
}

local RebirthPerks = {
	choices = 3, -- cards to pick from
	list = {
		{
			id = "Haggler",
			name = "Haggler",
			icon = "💰",
			step = 0.05,
			max = 5,
			percent = true,
			text = "+%s cash on every treasure",
		},
		{ id = "BigPockets", name = "Big Pockets", icon = "🎒", step = 1, max = 5, text = "+%s bag space" },
		{
			id = "Lucky",
			name = "Lucky Charm",
			icon = "🍀",
			step = 0.2,
			max = 5,
			percent = true,
			text = "+%s chance of Shiny and Golden finds",
		},
		{
			id = "TreasureSense",
			name = "Treasure Sense",
			icon = "🔮",
			step = 0.06,
			max = 5,
			percent = true,
			text = "+%s odds for Rare or better",
		},
		{
			id = "DeepDiver",
			name = "Deep Diver",
			icon = "⛏️",
			step = 0.2,
			max = 5,
			percent = true,
			text = "+%s Deep Dig chance",
		},
		{
			id = "Collector",
			name = "Collector",
			icon = "📖",
			step = 0.5,
			max = 4,
			text = "New finds are worth x2 + %s",
		},
		{
			id = "FastFeet",
			name = "Fast Feet",
			icon = "👟",
			step = 0.04,
			max = 5,
			percent = true,
			text = "+%s walk speed",
		},
		{
			id = "Perfectionist",
			name = "Perfectionist",
			icon = "🎯",
			step = 0.25,
			max = 4,
			percent = true,
			text = "+%s wider PERFECT window",
		},
	} :: { Perk },
}

return table.freeze(RebirthPerks)
