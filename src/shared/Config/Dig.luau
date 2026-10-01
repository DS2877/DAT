--!strict
-- Dig spot and dig validation tuning.

local Dig = {
	-- Client shows the DIG button when this close to a spot (studs, horizontal).
	promptRange = 11,
	-- Server accepts hits from up to this distance (extra slack for latency).
	serverRange = 16,
	-- A hit is accepted when at least hitInterval * this has passed since the last.
	hitTolerance = 0.75,
	-- Extra hits a normal spot needs in each area (on top of the shovel's
	-- hits): digging gets slower the further into the island you go.
	areaExtraHits = { Beach = 0, Jungle = 2, Ruins = 4, Volcano = 6 } :: { [string]: number },
	-- Progress on a spot is dropped if the player stops hitting it for this long.
	progressTimeout = 8,
	-- Respawn delay after a spot is dug out (seconds).
	respawnMin = 5,
	respawnMax = 10,
	-- Spots never spawn closer than this to each other or to a player.
	minSpotSpacing = 9,
	minPlayerDistance = 7,
	-- Candidate point generation (per area).
	candidateCount = { Beach = 150, Jungle = 160, Ruins = 160, Volcano = 160 },
	-- Candidate points keep at least this far apart.
	minCandidateSpacing = 7,
	-- A candidate must be within this many studs of its area's typical
	-- ground height (keeps spots off slopes, cliffs, dunes and ramps).
	levelTolerance = 3,
	-- Guarantee a few candidate points just in front of the base (distance from
	-- the deck's front edge) so a new player's first dig is seconds away.
	nearSpawnCandidates = 8,
	nearSpawnMin = 16,
	nearSpawnMax = 44,
	-- Keep at least this many active spots on those near-base points.
	minNearBaseSpots = 3,
	-- Max hits per second accepted from one client before rate limiting.
	-- (Room for the fastest shovel with 2x Dig Speed pass + boost.)
	maxHitsPerSecond = 20,
}

return table.freeze(Dig)
