--!strict
-- Plays other players' dig swings and dirt locally, driven by the DigHits
-- counter the server bumps on their characters for each accepted hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DigAnimation = require(ReplicatedStorage.Shared.Config.DigAnimation)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Effects = require(script.Parent.Parent.Effects)
local ImpactFx = require(script.Parent.Parent.ImpactFx)

local OtherPlayersController = {}

local function watchCharacter(character: Model)
	character:GetAttributeChangedSignal("DigHits"):Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = workspace.CurrentCamera
		if not root or not camera or (camera.CFrame.Position - root.Position).Magnitude > 150 then
			return
		end
		local swing = DigAnimation.minDuration
		Effects.swingOther(character, swing)
		task.delay(swing * DigAnimation.impact, function()
			local at = root.Position + root.CFrame.LookVector * 3 - Vector3.new(0, 2.5, 0)
			Effects.dirtBurst(at, 4)
			local level = character:GetAttribute("ShovelLevel")
			if type(level) == "number" then
				ImpactFx.play(Progression.getShovel(level).impact, at)
			end
		end)
	end)
end

local function watchPlayer(player: Player)
	if player == Players.LocalPlayer then
		return
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

function OtherPlayersController.init()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return OtherPlayersController
