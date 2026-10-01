--!strict
-- Local visual effects: the dig animation, dirt chunks, camera nudge, sparkles.
-- Dirt chunks are pooled parts; everything here is client-only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Effects = {}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalFx"
fxFolder.Parent = workspace

---------------------------------------------------------------------------
-- The dig (procedural, whole body)
---------------------------------------------------------------------------
-- One dig: wind up (shovel raised, leaning back), drive it down into the
-- ground (leaning in, knees bent), scoop and toss the dirt to the side,
-- then back to the start. Joints are posed on top of the running
-- animations (walk, idle) by offsetting each Motor6D's C0.

type Pose = { [string]: Vector3 } -- joint -> (pitch, yaw, roll) degrees
type Key = { at: number, pose: Pose, style: Enum.EasingStyle, direction: Enum.EasingDirection }

local REST: Pose = {}
-- R15: +pitch swings a limb forward (arms up, thighs forward), tilts the
-- torso / head back; knees bend with -pitch.
local DIG_R15: { Key } = {
	{ at = 0, pose = REST, style = Enum.EasingStyle.Linear, direction = Enum.EasingDirection.In },
	{
		at = 0.3,
		style = Enum.EasingStyle.Quad,
		direction = Enum.EasingDirection.Out,
		pose = {
			Waist = Vector3.new(8, -12, 0), -- twisted right, shovel up
			Neck = Vector3.new(6, 0, 0),
			RightShoulder = Vector3.new(135, 0, 0),
			RightElbow = Vector3.new(35, 0, 0),
			LeftShoulder = Vector3.new(100, 0, 10),
			LeftElbow = Vector3.new(50, 0, 0),
		},
	},
	{
		at = 0.55,
		style = Enum.EasingStyle.Quad,
		direction = Enum.EasingDirection.In,
		pose = {
			Waist = Vector3.new(-30, 0, 0),
			Neck = Vector3.new(-15, 0, 0),
			RightShoulder = Vector3.new(25, 0, 0),
			RightElbow = Vector3.new(8, 0, 0),
			LeftShoulder = Vector3.new(50, 0, 15),
			LeftElbow = Vector3.new(25, 0, 0),
			RightHip = Vector3.new(20, 0, 0),
			LeftHip = Vector3.new(14, 0, 0),
			RightKnee = Vector3.new(-28, 0, 0),
			LeftKnee = Vector3.new(-22, 0, 0),
		},
	},
	{
		at = 0.8,
		style = Enum.EasingStyle.Quad,
		direction = Enum.EasingDirection.Out,
		pose = {
			Waist = Vector3.new(-12, 22, 0), -- the dirt goes over to the left
			Neck = Vector3.new(-6, -10, 0),
			RightShoulder = Vector3.new(70, 0, 0),
			RightElbow = Vector3.new(30, 0, 0),
			LeftShoulder = Vector3.new(65, 0, 15),
			LeftElbow = Vector3.new(40, 0, 0),
			RightHip = Vector3.new(8, 0, 0),
			LeftHip = Vector3.new(6, 0, 0),
			RightKnee = Vector3.new(-10, 0, 0),
			LeftKnee = Vector3.new(-8, 0, 0),
		},
	},
	{ at = 1, pose = REST, style = Enum.EasingStyle.Quad, direction = Enum.EasingDirection.InOut },
}
-- R6 has fewer joints, each with its own axes: shoulders turn on Z (right
-- +, left -), the root joint pitches the whole body on X.
local DIG_R6: { Key } = {
	{ at = 0, pose = REST, style = Enum.EasingStyle.Linear, direction = Enum.EasingDirection.In },
	{
		at = 0.3,
		style = Enum.EasingStyle.Quad,
		direction = Enum.EasingDirection.Out,
		pose = {
			["Right Shoulder"] = Vector3.new(0, 0, 135),
			["Left Shoulder"] = Vector3.new(0, 0, -100),
			RootJoint = Vector3.new(-6, 0, 0),
		},
	},
	{
		at = 0.55,
		style = Enum.EasingStyle.Quad,
		direction = Enum.EasingDirection.In,
		pose = {
			["Right Shoulder"] = Vector3.new(0, 0, 25),
			["Left Shoulder"] = Vector3.new(0, 0, -50),
			RootJoint = Vector3.new(22, 0, 0),
		},
	},
	{
		at = 0.8,
		style = Enum.EasingStyle.Quad,
		direction = Enum.EasingDirection.Out,
		pose = {
			["Right Shoulder"] = Vector3.new(0, 0, 70),
			["Left Shoulder"] = Vector3.new(0, 0, -65),
			RootJoint = Vector3.new(8, 0, 18),
		},
	},
	{ at = 1, pose = REST, style = Enum.EasingStyle.Quad, direction = Enum.EasingDirection.InOut },
}

type Dig = {
	started: number,
	duration: number,
	keys: { Key },
	motors: { [string]: Motor6D },
	rest: { [Motor6D]: CFrame },
}

local digs: { [Model]: Dig } = {}
local restC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function motorsOf(character: Model): ({ [string]: Motor6D }, boolean)
	local motors: { [string]: Motor6D } = {}
	local isR15 = character:FindFirstChild("UpperTorso") ~= nil
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	return motors, isR15
end

local function angles(v: Vector3): CFrame
	return CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
end

local function apply(d: Dig, t: number)
	-- Find the two keys around t and blend between them.
	local keys = d.keys
	local i = 1
	while i < #keys - 1 and t > keys[i + 1].at do
		i += 1
	end
	local a, b = keys[i], keys[i + 1]
	local span = math.max(1e-3, b.at - a.at)
	local alpha = TweenService:GetValue(math.clamp((t - a.at) / span, 0, 1), b.style, b.direction)
	for name, motor in d.motors do
		local from = a.pose[name] or Vector3.zero
		local to = b.pose[name] or Vector3.zero
		local rest = d.rest[motor]
		if rest and (from ~= Vector3.zero or to ~= Vector3.zero) then
			motor.C0 = rest * angles(from:Lerp(to, alpha))
		elseif rest then
			motor.C0 = rest
		end
	end
end

local function finish(character: Model, d: Dig)
	for _, motor in d.motors do
		local rest = d.rest[motor]
		if rest and motor.Parent then
			motor.C0 = rest
		end
	end
	digs[character] = nil
end

-- Plays one dig on `character` over `duration` seconds. A dig already
-- playing finishes first (fast shovels just dig back to back).
function Effects.swing(character: Model, duration: number)
	if digs[character] then
		return
	end
	local motors, isR15 = motorsOf(character)
	local keys = if isR15 then DIG_R15 else DIG_R6
	local used: { [string]: Motor6D } = {}
	local rest: { [Motor6D]: CFrame } = {}
	for _, key in keys do
		for name in key.pose do
			local motor = motors[name]
			if motor and not used[name] then
				used[name] = motor
				restC0[motor] = restC0[motor] or motor.C0
				rest[motor] = restC0[motor]
			end
		end
	end
	if next(used) == nil then
		return
	end
	digs[character] = {
		started = os.clock(),
		duration = math.max(0.12, duration),
		keys = keys,
		motors = used,
		rest = rest,
	}
end

-- Is a dig playing on `character` (tests)?
function Effects.isDigging(character: Model): boolean
	return digs[character] ~= nil
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for character, d in digs do
		if not character.Parent then
			digs[character] = nil
		else
			local t = (now - d.started) / d.duration
			if t >= 1 then
				finish(character, d)
			else
				apply(d, t)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Dirt chunks
---------------------------------------------------------------------------

local chunkPool: { Part } = {}
local MAX_LIVE_CHUNKS = 40
local liveChunks = 0
local rng = Random.new()

local function getChunk(): Part
	local chunk = table.remove(chunkPool)
	if chunk then
		return chunk
	end
	local part = Instance.new("Part")
	part.Name = "Dirt"
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Ground
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

function Effects.dirtBurst(position: Vector3, count: number?, color: Color3?)
	for _ = 1, count or 6 do
		if liveChunks >= MAX_LIVE_CHUNKS then
			return
		end
		liveChunks += 1
		local chunk = getChunk()
		local size = rng:NextNumber(0.35, 0.75)
		chunk.Size = Vector3.new(size, size, size)
		chunk.Color = (color or Color3.fromRGB(150, 98, 52)):Lerp(
			Color3.new(0, 0, 0),
			rng:NextNumber(0, 0.25)
		)
		chunk.Anchored = false
		chunk.CFrame = CFrame.new(
			position + Vector3.new(rng:NextNumber(-0.8, 0.8), 0.6, rng:NextNumber(-0.8, 0.8))
		) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		chunk.Parent = fxFolder
		chunk.AssemblyLinearVelocity =
			Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(14, 22), rng:NextNumber(-9, 9))
		chunk.AssemblyAngularVelocity =
			Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
		task.delay(0.7, function()
			chunk.Anchored = true
			chunk.Parent = nil
			liveChunks -= 1
			table.insert(chunkPool, chunk)
		end)
	end
end

---------------------------------------------------------------------------
-- Camera nudge (mild)
---------------------------------------------------------------------------

local nudging = false

function Effects.cameraNudge(strength: number?)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or nudging then
		return
	end
	nudging = true
	local amount = strength or 0.18
	local down =
		TweenService:Create(humanoid, TweenInfo.new(0.05), { CameraOffset = Vector3.new(0, -amount, 0) })
	down:Play()
	down.Completed:Once(function()
		local back = TweenService:Create(humanoid, TweenInfo.new(0.12), { CameraOffset = Vector3.zero })
		back:Play()
		back.Completed:Once(function()
			nudging = false
		end)
	end)
end

---------------------------------------------------------------------------
-- Sparkle burst (default particle texture, tinted)
---------------------------------------------------------------------------

function Effects.sparkles(position: Vector3, color: Color3, amount: number?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = fxFolder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 0.8
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Drag = 3
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter:Emit(amount or 25)
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

function Effects.folder(): Folder
	return fxFolder
end

return Effects
