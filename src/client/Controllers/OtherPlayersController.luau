--!strict
-- Plays other players' dig swings and dirt locally, driven by the DigHits
-- counter the server bumps on their characters for each accepted hit.

local Players = game:GetService("Players")

local Effects = require(script.Parent.Parent.Effects)

local OtherPlayersController = {}

local function watchCharacter(character: Model)
	character:GetAttributeChangedSignal("DigHits"):Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = workspace.CurrentCamera
		if not root or not camera or (camera.CFrame.Position - root.Position).Magnitude > 150 then
			return
		end
		Effects.swing(character, 0.4)
		task.delay(0.2, function()
			Effects.dirtBurst(root.Position + root.CFrame.LookVector * 3 - Vector3.new(0, 2.5, 0), 4)
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
