--!strict
-- Economy and pacing knobs.

local Economy = {
	-- Each find is worth base value +/- this fraction.
	valueVariance = 0.10,
	-- After a sale, show "Only $X to go!" when the missing amount is at most
	-- this fraction of the goal's price.
	nearGoalFraction = 0.35,
	-- Hard cap to protect saves from runaway values (bugs or future multipliers).
	maxCash = 1e15,
}

return table.freeze(Economy)
