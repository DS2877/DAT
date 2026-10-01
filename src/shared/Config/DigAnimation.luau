--!strict
-- The dig animation, as keyframes. One dig: wind up (shovel raised,
-- twisted right), drive it into the ground (leaning in, knees bent), scoop
-- and toss the dirt over to the left, then back to the start.
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
	-- the torso / head back; knees bend with -pitch.
	R15 = {
		{ at = 0, ease = "Linear", pose = REST },
		{
			at = 0.3,
			ease = "Out",
			pose = {
				UpperTorso = Vector3.new(8, -12, 0), -- twisted right, shovel up
				Head = Vector3.new(6, 0, 0),
				RightUpperArm = Vector3.new(135, 0, 0),
				RightLowerArm = Vector3.new(35, 0, 0),
				LeftUpperArm = Vector3.new(100, 0, 10),
				LeftLowerArm = Vector3.new(50, 0, 0),
			},
		},
		{
			at = 0.55,
			ease = "In",
			pose = {
				UpperTorso = Vector3.new(-30, 0, 0),
				Head = Vector3.new(-15, 0, 0),
				RightUpperArm = Vector3.new(25, 0, 0),
				RightLowerArm = Vector3.new(8, 0, 0),
				LeftUpperArm = Vector3.new(50, 0, 15),
				LeftLowerArm = Vector3.new(25, 0, 0),
				RightUpperLeg = Vector3.new(20, 0, 0),
				LeftUpperLeg = Vector3.new(14, 0, 0),
				RightLowerLeg = Vector3.new(-28, 0, 0),
				LeftLowerLeg = Vector3.new(-22, 0, 0),
			},
		},
		{
			at = 0.8,
			ease = "Out",
			pose = {
				UpperTorso = Vector3.new(-12, 22, 0), -- the dirt goes over to the left
				Head = Vector3.new(-6, -10, 0),
				RightUpperArm = Vector3.new(70, 0, 0),
				RightLowerArm = Vector3.new(30, 0, 0),
				LeftUpperArm = Vector3.new(65, 0, 15),
				LeftLowerArm = Vector3.new(40, 0, 0),
				RightUpperLeg = Vector3.new(8, 0, 0),
				LeftUpperLeg = Vector3.new(6, 0, 0),
				RightLowerLeg = Vector3.new(-10, 0, 0),
				LeftLowerLeg = Vector3.new(-8, 0, 0),
			},
		},
		{ at = 1, ease = "InOut", pose = REST },
	} :: { Key },

	-- R6 joints have their own axes: the shoulders turn on Z (right +,
	-- left -) and the root joint (Torso) pitches the whole body on X.
	R6 = {
		{ at = 0, ease = "Linear", pose = REST },
		{
			at = 0.3,
			ease = "Out",
			pose = {
				["Right Arm"] = Vector3.new(0, 0, 135),
				["Left Arm"] = Vector3.new(0, 0, -100),
				Torso = Vector3.new(-6, 0, 0),
			},
		},
		{
			at = 0.55,
			ease = "In",
			pose = {
				["Right Arm"] = Vector3.new(0, 0, 25),
				["Left Arm"] = Vector3.new(0, 0, -50),
				Torso = Vector3.new(22, 0, 0),
			},
		},
		{
			at = 0.8,
			ease = "Out",
			pose = {
				["Right Arm"] = Vector3.new(0, 0, 70),
				["Left Arm"] = Vector3.new(0, 0, -65),
				Torso = Vector3.new(8, 0, 18),
			},
		},
		{ at = 1, ease = "InOut", pose = REST },
	} :: { Key },

	-- The dig's length when played as an uploaded animation (it's sped up
	-- to fit each dig).
	length = 1,
	-- When the shovel hits the ground (fraction of the dig): dirt and sound.
	impact = 0.5,
}

return table.freeze(DigAnimation)
