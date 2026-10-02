--!strict
-- Local visual effects: the dig animation, dirt chunks, camera nudge, sparkles.
-- Dirt chunks are pooled parts; everything here is client-only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)
local DanceAnimation = require(ReplicatedStorage.Shared.Config.DanceAnimation)
local DigAnimation = require(ReplicatedStorage.Shared.Config.DigAnimation)

local Effects = {}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalFx"
fxFolder.Parent = workspace

---------------------------------------------------------------------------
-- The dig animation (Config/DigAnimation)
---------------------------------------------------------------------------
-- With an uploaded animation (AssetIds.Animations), it plays through the
-- character's Animator: Roblox's own way, on any rig, and the local
-- player's animation shows for everyone. Otherwise the same keyframes are
-- played here in code, by turning the joints on top of the running walk /
-- idle animations. Both kinds of joints are handled: Motor6D (turn its C0)
-- and the newer AnimationConstraint (turn its Attachment0).

type Joint = { instance: Instance, rest: CFrame }
type Dig = {
	started: number,
	duration: number,
	keys: { DigAnimation.Key },
	joints: { [string]: Joint },
	dance: boolean, -- the victory dance (a new dig cuts it short)
}

local digs: { [Model]: Dig } = {}
local restOf: { [Instance]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local tracks: { [Humanoid]: AnimationTrack } = setmetatable({}, { __mode = "k" }) :: any
local trackEnds: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function isR15(character: Model): boolean
	return character:FindFirstChild("UpperTorso") ~= nil
end

local function animationId(character: Model): string
	local ids = AssetIds.Animations :: any
	return (if isR15(character) then ids.DigR15 else ids.DigR6) or ""
end

-- The character's joints, by the body part each one moves.
local function jointsOf(character: Model): { [string]: Instance }
	local found: { [string]: Instance } = {}
	for _, d in character:GetDescendants() do
		if d:IsA("AnimationConstraint") then
			local a1 = d.Attachment1
			if d.Attachment0 and a1 and a1.Parent then
				found[a1.Parent.Name] = d -- the newer joints win
			end
		elseif d:IsA("Motor6D") then
			local parent = d.Parent
			local moved = d.Part1 or (if parent and parent:IsA("BasePart") then parent else nil)
			if moved and not found[moved.Name] then
				found[moved.Name] = d
			end
		end
	end
	return found
end

local function getJoint(joint: Instance): CFrame
	if joint:IsA("Motor6D") then
		return joint.C0
	end
	local a0 = (joint :: AnimationConstraint).Attachment0
	return if a0 then a0.CFrame else CFrame.identity
end

local function setJoint(joint: Instance, value: CFrame)
	if joint:IsA("Motor6D") then
		joint.C0 = value
	else
		local a0 = (joint :: AnimationConstraint).Attachment0
		if a0 then
			a0.CFrame = value
		end
	end
end

local EASE: { [string]: Enum.EasingDirection } = {
	In = Enum.EasingDirection.In,
	Out = Enum.EasingDirection.Out,
	InOut = Enum.EasingDirection.InOut,
}

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
	local x = math.clamp((t - a.at) / span, 0, 1)
	local alpha = if b.ease == "Linear"
		then x
		else TweenService:GetValue(x, Enum.EasingStyle.Quad, EASE[b.ease])
	for name, joint in d.joints do
		local from = a.pose[name] or Vector3.zero
		local to = b.pose[name] or Vector3.zero
		setJoint(joint.instance, joint.rest * angles(from:Lerp(to, alpha)))
	end
end

local function finish(character: Model, d: Dig)
	for _, joint in d.joints do
		if joint.instance.Parent then
			setJoint(joint.instance, joint.rest)
		end
	end
	digs[character] = nil
end

-- Plays the uploaded dig animation; false if it can't.
local function playTrack(character: Model, duration: number): boolean
	local id = animationId(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if id == "" or not humanoid then
		return false
	end
	local track = tracks[humanoid]
	if not track then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			return false
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, loaded = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if not ok or not loaded then
			return false
		end
		track = loaded
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		tracks[humanoid] = track
	end
	local t = track :: AnimationTrack
	if t.Length <= 0 then
		-- Not loaded (yet, or not allowed): the coded dig plays meanwhile.
		return false
	end
	t:Play(0.05, 1, DigAnimation.length / math.max(0.12, duration))
	trackEnds[character] = os.clock() + duration
	return true
end

-- Starts the coded dig (or the victory dance) on `character`.
local function startCoded(character: Model, duration: number, dance: boolean?)
	if digs[character] then
		return
	end
	local source = if dance then DanceAnimation else DigAnimation
	local keys = if isR15(character) then source.R15 else source.R6
	local all = jointsOf(character)
	local used: { [string]: Joint } = {}
	for _, key in keys do
		for name in key.pose do
			local joint = all[name]
			if joint and not used[name] then
				restOf[joint] = restOf[joint] or getJoint(joint)
				used[name] = { instance = joint, rest = restOf[joint] }
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
		joints = used,
		dance = dance == true,
	}
end

-- Plays one dig on `character` (this player's) over `duration` seconds.
-- A dig already playing finishes first (a fast shovel's hits land during
-- it). True when a new dig started.
function Effects.swing(character: Model, duration: number): boolean
	local current = digs[character]
	if current and current.dance then
		finish(character, current) -- back to digging
	end
	if digs[character] or (trackEnds[character] or 0) > os.clock() then
		return false
	end
	if not playTrack(character, duration) then
		startCoded(character, duration)
		return digs[character] ~= nil
	end
	return true
end

-- Another player's dig: their uploaded animation reaches us through Roblox;
-- if it isn't playing (not loaded, or none uploaded), play the coded one.
function Effects.swingOther(character: Model, duration: number)
	local current = digs[character]
	if current and current.dance then
		finish(character, current)
	end
	local id = animationId(character)
	if id == "" then
		startCoded(character, duration)
		return
	end
	task.delay(0.1, function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				if track.Animation and track.Animation.AnimationId == id and track.Length > 0 then
					return
				end
			end
		end
		startCoded(character, duration - 0.1)
	end)
end

-- Is a dig playing on `character` (tests)?
function Effects.isDigging(character: Model): boolean
	local d = digs[character]
	return (d ~= nil and not d.dance) or (trackEnds[character] or 0) > os.clock()
end

-- The victory dance (Config/DanceAnimation), once any dig has finished.
function Effects.dance(character: Model)
	local current = digs[character]
	if current then
		finish(character, current)
	end
	startCoded(character, DanceAnimation.length, true)
end

-- Is `character` dancing (tests)?
function Effects.isDancing(character: Model): boolean
	local d = digs[character]
	return d ~= nil and d.dance
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
