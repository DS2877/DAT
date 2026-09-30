--!strict
-- Onboarding funnel steps (logged once per player, in order).

local Analytics = {
	FunnelSteps = {
		"Joined",
		"FirstDig",
		"FirstFind",
		"FirstSale",
		"FirstUpgrade",
		"ReachedJungle",
		"ReachedRuins",
		"ReachedVolcano",
		"FirstRebirth",
	},
	CurrencyName = "Cash",
}

return table.freeze(Analytics)
