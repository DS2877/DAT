-- Builds the dig animation (src/shared/Config/DigAnimation.luau) as Roblox
-- animations: one KeyframeSequence for R15 rigs and one for R6, saved as
-- .rbxm files for the "Upload animations" workflow.
-- Usage: lune run scripts/build-dig-animation.luau [outDir]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance, CFrame, Enum = roblox.Instance, roblox.CFrame, roblox.Enum

local outDir = process.args[1] or "animations"

-- The config uses Roblox's Vector3: give it Lune's.
local env = setmetatable({ Vector3 = roblox.Vector3 }, { __index = getfenv() })
local DigAnimation = luau.load(
	fs.readFile("src/shared/Config/DigAnimation.luau"),
	{ debugName = "DigAnimation", environment = env }
)()

-- Each rig's joint tree: a Pose per part, nested like the rig.
local TREES = {
	R15 = {
		HumanoidRootPart = {
			LowerTorso = {
				UpperTorso = {
					Head = {},
					RightUpperArm = { RightLowerArm = { RightHand = {} } },
					LeftUpperArm = { LeftLowerArm = { LeftHand = {} } },
				},
				RightUpperLeg = { RightLowerLeg = { RightFoot = {} } },
				LeftUpperLeg = { LeftLowerLeg = { LeftFoot = {} } },
			},
		},
	},
	R6 = {
		HumanoidRootPart = {
			Torso = {
				Head = {},
				["Right Arm"] = {},
				["Left Arm"] = {},
				["Right Leg"] = {},
				["Left Leg"] = {},
			},
		},
	},
}

local function angles(v: any): any
	return CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
end

-- How a pose eases into the next keyframe. Roblox's (legacy) Cubic pose
-- easing has In and Out swapped compared to tweens, so they're swapped back.
local FLIP = { In = "Out", Out = "In", InOut = "InOut" }
local function easing(ease: string): (any, any)
	if ease == "Linear" then
		return Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In
	end
	return Enum.PoseEasingStyle.Cubic, (Enum.PoseEasingDirection :: any)[FLIP[ease]]
end

local function build(rig: string): any
	local keys = DigAnimation[rig]
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = "Dig" .. rig
	sequence.Loop = false
	sequence.Priority = Enum.AnimationPriority.Action
	for i, key in keys do
		local nextKey = keys[i + 1]
		local style, direction = easing(if nextKey then nextKey.ease else "Linear")
		local keyframe = Instance.new("Keyframe")
		keyframe.Name = "Keyframe"
		keyframe.Time = key.at * DigAnimation.length
		local function addPoses(tree: { [string]: any }, parent: any)
			for name, children in tree do
				local pose = Instance.new("Pose")
				pose.Name = name
				local v = key.pose[name]
				pose.CFrame = if v then angles(v) else CFrame.identity
				pose.Weight = if name == "HumanoidRootPart" then 0 else 1
				pose.EasingStyle = style
				pose.EasingDirection = direction
				pose.Parent = parent
				addPoses(children, pose)
			end
		end
		addPoses(TREES[rig], keyframe)
		keyframe.Parent = sequence
	end
	return sequence
end

if not fs.isDir(outDir) then
	fs.writeDir(outDir)
end
for _, rig in { "R15", "R6" } do
	local sequence = build(rig)
	local path = string.format("%s/dig-%s.rbxm", outDir, string.lower(rig))
	fs.writeFile(path, roblox.serializeModel({ sequence }))
	print(string.format("wrote %s (%d keyframes)", path, #sequence:GetChildren()))
end
