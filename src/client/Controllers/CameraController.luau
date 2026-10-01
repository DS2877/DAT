--!strict
-- Starts each life with the camera pulled back (Config/Movement.spawnZoom)
-- so the plaza and the island are in view, instead of Roblox's close
-- default. Players can zoom in and out freely afterwards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movement = require(ReplicatedStorage.Shared.Config.Movement)

local player = Players.LocalPlayer

local CameraController = {}

local function zoomOut()
	-- Raising the minimum zoom pushes the camera out to it; restoring the
	-- old minimum a moment later keeps that distance but frees zooming.
	local previousMin = player.CameraMinZoomDistance
	local target = math.min(Movement.spawnZoom, player.CameraMaxZoomDistance)
	player.CameraMinZoomDistance = target
	task.delay(0.3, function()
		player.CameraMinZoomDistance = previousMin
	end)
end

function CameraController.init()
	player.CharacterAdded:Connect(function()
		task.defer(zoomOut)
	end)
	if player.Character then
		task.defer(zoomOut)
	end
end

return CameraController
