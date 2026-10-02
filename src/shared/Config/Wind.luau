--!strict
-- The wind on the island (WindController, on each client): palms bend and
-- their fronds flutter, jungle canopies sway, grass, ferns and bamboo leaves
-- flutter, flags, sails and banners flap. One wind for the whole island,
-- with gusts that roll across it. Angles are in degrees.

local Wind = {
	-- The worlds it blows in (Frostbite Peaks stays still and snowy).
	worlds = { Island = true },
	-- The way it blows (flattened and normalized).
	direction = Vector3.new(0.8, 0, -0.6),
	speed = 1.15, -- the base sway rhythm (radians per second)
	-- Gusts: every `gustEvery` seconds a gust rolls across the island
	-- (`gustSpeed` studs/s), adding up to `gustStrength` x the sway.
	gustEvery = 11,
	gustStrength = 0.9,
	gustSpeed = 60,

	palmBend = 3.2, -- how far a palm's top leans
	frondFlutter = 7, -- palm fronds flapping up and down
	canopySway = 1.6, -- jungle tree canopies
	grassSway = 9, -- grass, ferns, bamboo leaves
	flagFlap = 12, -- flags, sails, banners

	radius = 170, -- only things this close to the camera move
	rate = 30, -- updates per second
}

return table.freeze(Wind)
