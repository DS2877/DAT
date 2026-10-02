--!strict
-- The victory dance: when someone digs up something Legendary or better (or
-- anything Golden), their character throws its arms up and does a little
-- bouncing, swaying cheer while the treasure rises. Everyone nearby sees it.
-- Same key format as Config/DigAnimation (poses by the body part a joint
-- moves; pitch, yaw, roll in degrees), played in code by Effects.

local DigAnimation = require(script.Parent.DigAnimation)

type Key = DigAnimation.Key

local REST = {}

-- One beat of the cheer for R15: `side` sways the body (1 = right, -1 =
-- left), `up` pumps the arms all the way up (true) or bent (false).
local function beat(side: number, up: boolean): { [string]: Vector3 }
	return {
		UpperTorso = Vector3.new(4, 10 * side, 9 * side),
		Head = Vector3.new(-8, -6 * side, -6 * side),
		RightUpperArm = Vector3.new(if up then 172 else 140, 0, 0),
		RightLowerArm = Vector3.new(if up then 6 else 48, 0, 0),
		LeftUpperArm = Vector3.new(if up then 172 else 140, 0, 0),
		LeftLowerArm = Vector3.new(if up then 6 else 48, 0, 0),
		RightUpperLeg = Vector3.new(if up then 0 else 12, 0, 0),
		LeftUpperLeg = Vector3.new(if up then 0 else 12, 0, 0),
		RightLowerLeg = Vector3.new(if up then 0 else -20, 0, 0),
		LeftLowerLeg = Vector3.new(if up then 0 else -20, 0, 0),
	}
end

local function beatR6(side: number, up: boolean): { [string]: Vector3 }
	return {
		["Right Arm"] = Vector3.new(0, 0, if up then 172 else 140),
		["Left Arm"] = Vector3.new(0, 0, if up then -172 else -140),
		Torso = Vector3.new(-4, 0, 10 * side),
	}
end

local function sequence(make: (number, boolean) -> { [string]: Vector3 }): { Key }
	local keys: { Key } = { { at = 0, ease = "Linear", pose = REST } }
	local beats = 8
	for i = 1, beats do
		table.insert(keys, {
			at = 0.06 + (i - 1) * 0.11,
			ease = if i == 1 then "Out" else "InOut",
			pose = make(if i % 2 == 0 then -1 else 1, i % 2 == 1),
		})
	end
	table.insert(keys, { at = 1, ease = "InOut", pose = REST })
	return keys
end

local DanceAnimation = {
	R15 = sequence(beat),
	R6 = sequence(beatR6),
	length = 2.6, -- seconds
	delay = 0.6, -- after the treasure starts rising
	-- Finds at or above this rarity (and every Golden one) start a dance.
	minRarity = "Legendary",
}

return table.freeze(DanceAnimation)
