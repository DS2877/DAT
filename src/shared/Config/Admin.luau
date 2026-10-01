--!strict
-- Who gets the 🛠️ admin panel. The game's owner (the user who owns the
-- experience, or rank 255 in the owning group) always does; add more
-- Roblox user ids here. In Studio everyone is an admin.

local Admin = {
	userIds = {} :: { number },
	groupMinRank = 255,
	-- ADMIN ABUSE event: everyone gets 2x cash, Treasure Rush odds, every
	-- spot counts as a clue spot, and a hidden treasure every so often.
	abuse = { hiddenTreasureEvery = 60 },
}

return Admin
