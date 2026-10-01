--!strict
-- The worlds beyond this island. Each is reached through a portal that
-- unlocks at a rebirth count and stays open (players travel back and forth
-- freely). A world that isn't built yet has no placeId: unlocked players
-- who step in see a "being built" screen and can sign up for its launch
-- event in the Island Guide. Set placeId (a place in this experience) when
-- the world ships and the portal starts teleporting.

local Worlds = {
	-- The world the beach portal leads to.
	next = {
		id = "Frost",
		name = "Frostbite Peaks",
		requiredRebirths = 3,
		placeId = nil :: number?,
		color = "#7FDBFF",
	},
	portal = {
		ringRadius = 13, -- the portal ring (studs)
		triggerRadius = 6, -- how close to its center counts as stepping in
		pushBack = 18, -- where a locked (or returning) player is put, in front
		cooldown = 5, -- seconds before the portal reacts to the same player again
		explorersShown = 10, -- names on the First Explorers board
		boardRefresh = 120, -- seconds between board reads
	},
}

return table.freeze(Worlds)
