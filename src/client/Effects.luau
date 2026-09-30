--!strict
-- Local visual effects: shovel swing, dirt chunks, camera nudge, sparkles.
-- Dirt chunks are pooled parts; everything here is client-only.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Effects = {}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalFx"
fxFolder.Parent = workspace

---------------------------------------------------------------------------
-- Shovel swing (procedural; replace with an animation via AssetIds later)
---------------------------------------------------------------------------

local swinging: { [Model]: boolean } = {}

local function shoulderOf(character: Model): (Motor6D?, boolean)
	local upperArm = character:FindFirstChild("RightUpperArm")
	local motor = upperArm and upperArm:FindFirstChild("RightShoulder")
	if motor and motor:IsA("Motor6D") then
		return motor, true
	end
	local torso = character:FindFirstChild("Torso")
	motor = torso and torso:FindFirstChild("Right Shoulder")
	if motor and motor:IsA("Motor6D") then
		return motor, false
	end
	return nil, false
end

-- Raises the arm and strikes down. R15 rotates on X, R6 on Z (joint frames differ).
function Effects.swing(character: Model, duration: number)
	if swinging[character] then
		return
	end
	local motor, isR15 = shoulderOf(character)
	if not motor then
		return
	end
	swinging[character] = true
	local original = motor.C0
	local function pose(angleDeg: number): CFrame
		local a = math.rad(angleDeg)
		return original * (if isR15 then CFrame.Angles(a, 0, 0) else CFrame.Angles(0, 0, a))
	end
	local up = duration * 0.4
	local down = duration * 0.35
	local back = duration * 0.25
	local m = motor :: Motor6D
	TweenService
		:Create(m, TweenInfo.new(up, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = pose(75) })
		:Play()
	task.delay(up, function()
		TweenService
			:Create(
				m,
				TweenInfo.new(down, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ C0 = pose(-15) }
			)
			:Play()
		task.delay(down, function()
			TweenService:Create(
				m,
				TweenInfo.new(back, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ C0 = original }
			):Play()
			task.delay(back, function()
				swinging[character] = nil
			end)
		end)
	end)
end

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
