--!strict
-- Victory dances: when anyone digs up something Legendary or better (or
-- Golden), the server bumps their character's Celebrate attribute and every
-- client nearby plays the dance on that character (Config/DanceAnimation),
-- with a little burst of sparkles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DanceAnimation = require(ReplicatedStorage.Shared.Config.DanceAnimation)
local Effects = require(script.Parent.Parent.Effects)

local DanceController = {}

local SHOW_DISTANCE = 160
local SPARKLE = Color3.fromRGB(255, 220, 90)

local function watchCharacter(character: Model)
	character:GetAttributeChangedSignal("Celebrate"):Connect(function()
		task.delay(DanceAnimation.delay, function()
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local camera = workspace.CurrentCamera
			if not root or not character.Parent then
				return
			end
			if camera and (camera.CFrame.Position - root.Position).Magnitude > SHOW_DISTANCE then
				return
			end
			Effects.dance(character)
			Effects.sparkles(root.Position + Vector3.new(0, 2, 0), SPARKLE, 30)
		end)
	end)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

function DanceController.init()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return DanceController
