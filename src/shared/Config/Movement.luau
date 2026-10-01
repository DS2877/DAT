--!strict
-- Character movement. The island is large, so players walk a little faster
-- than Roblox's default 16.

local Movement = {
	walkSpeed = 20,
	-- Camera distance (studs) right after spawning, so players see the
	-- plaza and the island around them. They can still zoom freely.
	spawnZoom = 26,
}

return table.freeze(Movement)
