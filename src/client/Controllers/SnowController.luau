--!strict
-- Snowfall in Frostbite Peaks: a wide, invisible box above the camera that
-- follows it around and lets snow drift down (nothing on the island).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)

local SnowController = {}

local AREA = 140 -- studs across
local HEIGHT = 45 -- above the camera

function SnowController.init()
	if not CurrentWorld.isFrost() then
		return
	end
	local cloud = Instance.new("Part")
	cloud.Name = "Snowfall"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.CastShadow = false
	cloud.Transparency = 1
	cloud.Size = Vector3.new(AREA, 1, AREA)

	local flakes = Instance.new("ParticleEmitter")
	flakes.Name = "Flakes"
	flakes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	flakes.Color = ColorSequence.new(Color3.new(1, 1, 1))
	flakes.LightEmission = 0.4
	flakes.Rate = 160
	flakes.Lifetime = NumberRange.new(9, 12)
	flakes.Speed = NumberRange.new(4, 7)
	flakes.SpreadAngle = Vector2.new(25, 25)
	flakes.EmissionDirection = Enum.NormalId.Bottom
	flakes.Acceleration = Vector3.new(1.2, -0.4, 0.6)
	flakes.Drag = 0.4
	flakes.Size = NumberSequence.new(0.28)
	flakes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.15),
		NumberSequenceKeypoint.new(0.85, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	flakes.RotSpeed = NumberRange.new(-60, 60)
	flakes.Parent = cloud
	cloud.Parent = workspace

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			local at = camera.CFrame.Position
			cloud.CFrame = CFrame.new(at.X, at.Y + HEIGHT, at.Z)
		end
	end)
end

return SnowController
