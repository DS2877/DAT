--!strict
-- Who gets the 🛠️ admin panel. The game's owner (the user who owns the
-- experience, or rank 255 in the owning group) always does; add more
-- Roblox user ids here. In Studio everyone is an admin.

local Admin = {
	userIds = {} :: { number },
	groupMinRank = 255,
	-- ADMIN ABUSE event: everyone gets 2x cash, Treasure Rush odds, every
	-- spot counts as a clue spot, and a hidden treasure every so often.
	abuse = {
		hiddenTreasureEvery = 60,
		-- The party sky while it runs (clients): night falls, the sky cycles
		-- through colors, disco beams sweep and fireworks go off.
		skyClockTime = 21, -- local time of day during the party
		hueCycleSeconds = 8, -- one full trip around the rainbow
		fireworksEvery = 0.9, -- seconds between bursts (per player)
		discoBeams = 6,
	},
	-- Spawn tools (WORLD tab), placed where the admin stands.
	spawn = {
		ringCount = 8, -- clue spots in a "clue ring"
		ringRadius = 11,
		spotDistance = 7, -- a treasure spot this far in front of you
		megaDistance = 18, -- a Mega Dig site this far in front of you
	},
	-- Money rain: coins fall around the admin; anyone who runs into one
	-- gets cash (a share of their next goal, so it's fair at every level).
	moneyRain = {
		coins = 45,
		radius = 26,
		dropSeconds = 6, -- coins keep falling for this long
		lifetime = 45, -- uncollected coins vanish after this
		pickupRange = 4.5,
		coinReward = { goalPercent = 0.01, min = 20 },
	},
	-- Messages to every server: shown as a speech bubble from the admin's
	-- avatar at the top of everyone's screen.
	globalMessage = {
		maxLength = 150,
		cooldown = 5, -- seconds between messages
		baseSeconds = 6, -- on screen for this long...
		secondsPerCharacter = 0.05, -- ...plus this per character
	},
}

return Admin
