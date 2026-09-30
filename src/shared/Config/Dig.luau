--!strict
-- Dig spot and dig validation tuning.

local Dig = {
	-- Client shows the DIG button when this close to a spot (studs, horizontal).
	promptRange = 11,
	-- Server accepts hits from up to this distance (extra slack for latency).
	serverRange = 16,
	-- A hit is accepted when at least hitInterval * this has passed since the last.
	hitTolerance = 0.75,
	-- Progress on a spot is dropped if the player stops hitting it for this long.
	progressTimeout = 8,
	-- Respawn delay after a spot is dug out (seconds).
	respawnMin = 5,
	respawnMax = 10,
	-- Spots never spawn closer than this to each other or to a player.
	minSpotSpacing = 9,
	minPlayerDistance = 7,
	-- Candidate point generation (per area).
	candidateCount = { Beach = 90, Jungle = 70, Ruins = 70, Volcano = 60 },
	-- Guarantee a few candidate points just in front of the base (distance from
	-- the deck's front edge) so a new player's first dig is seconds away.
	nearSpawnCandidates = 8,
	nearSpawnMin = 10,
	nearSpawnMax = 36,
	-- Keep at least this many active spots on those near-base points.
	minNearBaseSpots = 3,
	-- Max hits per second accepted from one client before rate limiting.
	maxHitsPerSecond = 8,
}

return table.freeze(Dig)
