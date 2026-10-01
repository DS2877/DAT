--!strict
-- The worlds beyond this island. Each is reached through a portal that
-- unlocks at a rebirth count and stays open (players travel back and forth
-- freely).
--
-- Frostbite Peaks runs in reserved servers of this same place (the server
-- picks its world when it starts: Server/WorldSelect), on the same map with
-- frost biomes and its own run (Logic/WorldState). Set `open = false` to
-- close it again: unlocked players then see the "being built" screen with
-- the launch event sign-up.

local Worlds = {
	-- The world the beach portal leads to.
	next = {
		id = "Frost",
		name = "Frostbite Peaks",
		requiredRebirths = 3,
		open = true,
		color = "#7FDBFF",
	},
	-- Where the portal in Frostbite Peaks leads back to.
	home = {
		id = "Island",
		name = "the Island",
		color = "#FFD24A",
	},
	portal = {
		ringRadius = 13, -- the portal ring (studs)
		triggerRadius = 6, -- how close to its center counts as stepping in
		pushBack = 18, -- where a locked (or returning) player is put, in front
		cooldown = 5, -- seconds before the portal reacts to the same player again
		explorersShown = 10, -- names on the First Explorers board
		boardRefresh = 120, -- seconds between board reads
	},
	-- Matchmaking for Frostbite Peaks servers (Services/WorldServers).
	servers = {
		roomForFriends = 2, -- a server takes newcomers until this many slots are left
		heartbeat = 20, -- seconds between a server's "I'm here, N players" updates
		expires = 75, -- a server that stops updating drops off the list after this
	},
}

return table.freeze(Worlds)
