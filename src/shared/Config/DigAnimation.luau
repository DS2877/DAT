--!strict
-- The dig animation, as keyframes. One big dig: wind up (shovel high over
-- the right shoulder), chop it into the ground (bent deep at the waist and
-- knees), pry the load up, fling it over the left shoulder, back to rest.
--
-- Poses are keyed by the body part a joint moves (its "Part1": RightUpperArm
-- for the right shoulder, UpperTorso for the waist...), so they work on both
-- Motor6D rigs and the newer AnimationConstraint rigs. Each angle is
-- (pitch, yaw, roll) in degrees, applied at the joint.
--
-- Used two ways: scripts/build-dig-animation.luau turns these into Roblox
-- animations (KeyframeSequences, uploaded to Roblox and played through the
-- Animator), and Effects plays them in code when no uploaded animation is
-- set (Config: AssetIds.Animations).

export type Key = {
	at: number, -- 0..1 through the dig
	ease: "Linear" | "In" | "Out" | "InOut", -- how the move INTO this key eases (quadratic)
	pose: { [string]: Vector3 },
}

local REST = {}

local DigAnimation = {
	-- R15: +pitch swings a limb forward (arms up, thighs forward) and tilts
	-- the torso / head back; knees bend with -pitch. -yaw turns the torso to
	-- the right, +yaw to the left.
	R15 = {
		{ at = 0, ease = "Linear", pose = REST },
		-- Wind up: the shovel high over the right shoulder, leaning back.
		{
			at = 0.34,
			ease = "Out",
			pose = {
				UpperTorso = Vector3.new(14, -38, 0),
				Head = Vector3.new(-4, 22, 0), -- eyes stay on the spot
				RightUpperArm = Vector3.new(168, 0, -12),
				RightLowerArm = Vector3.new(28, 0, 0),
				LeftUpperArm = Vector3.new(150, 0, 18),
				LeftLowerArm = Vector3.new(38, 0, 0),
				RightUpperLeg = Vector3.new(-6, 0, 0),
				LeftUpperLeg = Vector3.new(12, 0, 0),
				LeftLowerLeg = Vector3.new(-12, 0, 0),
			},
		},
		-- Drive it in: a fast chop down, bent deep at the waist and knees.
		{
			at = 0.55,
			ease = "In",
			pose = {
				-- (Arms well forward of the bent torso: hands low, in front.)
				UpperTorso = Vector3.new(-56, 8, 0),
				Head = Vector3.new(12, 0, 0),
				RightUpperArm = Vector3.new(70, 0, -6),
				RightLowerArm = Vector3.new(10, 0, 0),
				LeftUpperArm = Vector3.new(86, 0, 16),
				LeftLowerArm = Vector3.new(18, 0, 0),
				-- (The body's root can't drop, so the knees bend only a little:
				-- more would lift the feet off the ground.)
				RightUpperLeg = Vector3.new(16, 0, 0),
				LeftUpperLeg = Vector3.new(10, 0, 0),
				RightLowerLeg = Vector3.new(-24, 0, 0),
				LeftLowerLeg = Vector3.new(-18, 0, 0),
			},
		},
		-- Scoop: pry the load up out of the hole.
		{
			at = 0.7,
			ease = "Out",
			pose = {
				UpperTorso = Vector3.new(-26, 4, 0),
				Head = Vector3.new(4, 0, 0),
				RightUpperArm = Vector3.new(66, 0, -6),
				RightLowerArm = Vector3.new(42, 0, 0),
				LeftUpperArm = Vector3.new(78, 0, 18),
				LeftLowerArm = Vector3.new(46, 0, 0),
				RightUpperLeg = Vector3.new(10, 0, 0),
				LeftUpperLeg = Vector3.new(8, 0, 0),
				RightLowerLeg = Vector3.new(-14, 0, 0),
				LeftLowerLeg = Vector3.new(-12, 0, 0),
			},
		},
		-- Toss: fling the dirt over the left shoulder.
		{
			at = 0.84,
			ease = "Out",
			pose = {
				UpperTorso = Vector3.new(-4, 48, 0),
				Head = Vector3.new(-4, -24, 0),
				RightUpperArm = Vector3.new(118, 0, 24),
				RightLowerArm = Vector3.new(26, 0, 0),
				LeftUpperArm = Vector3.new(124, 0, 34),
				LeftLowerArm = Vector3.new(30, 0, 0),
				RightUpperLeg = Vector3.new(6, 0, 0),
				LeftUpperLeg = Vector3.new(-6, 0, 0),
				RightLowerLeg = Vector3.new(-8, 0, 0),
			},
		},
		{ at = 1, ease = "InOut", pose = REST },
	} :: { Key },

	-- R6 joints have their own axes: the shoulders turn on Z (right +,
	-- left -) and the root joint (Torso) pitches the whole body on X and
	-- turns it on Z.
	R6 = {
		{ at = 0, ease = "Linear", pose = REST },
		{
			at = 0.34,
			ease = "Out",
			pose = {
				["Right Arm"] = Vector3.new(0, 0, 168),
				["Left Arm"] = Vector3.new(0, 0, -158),
				Torso = Vector3.new(-12, 0, -26),
			},
		},
		{
			at = 0.55,
			ease = "In",
			pose = {
				["Right Arm"] = Vector3.new(0, 0, 62),
				["Left Arm"] = Vector3.new(0, 0, -76),
				Torso = Vector3.new(30, 0, 6),
			},
		},
		{
			at = 0.7,
			ease = "Out",
			pose = {
				["Right Arm"] = Vector3.new(0, 0, 80),
				["Left Arm"] = Vector3.new(0, 0, -92),
				Torso = Vector3.new(16, 0, 0),
			},
		},
		{
			at = 0.84,
			ease = "Out",
			pose = {
				["Right Arm"] = Vector3.new(0, 0, 124),
				["Left Arm"] = Vector3.new(0, 0, -128),
				Torso = Vector3.new(4, 0, 40),
			},
		},
		{ at = 1, ease = "InOut", pose = REST },
	} :: { Key },

	-- The dig's length when played as an uploaded animation (it's sped up
	-- or slowed down to fit each dig).
	length = 1,
	-- When the shovel hits the ground (fraction of the dig): dirt and sound.
	impact = 0.55,
	-- How long one dig takes on screen (seconds). It follows the shovel's
	-- speed but never gets shorter than `minDuration`, so it stays a full,
	-- readable swing: fast shovels land several hits per swing.
	minDuration = 0.6,
	maxDuration = 0.8,
}

return table.freeze(DigAnimation)
