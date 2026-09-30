--!strict
-- Spawns characters once the profile is loaded (CharacterAutoLoads is off so
-- nobody plays before their save is ready), respawns them, and keeps the
-- current shovel model in their hand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShovelBuilder = require(ReplicatedStorage.Shared.Builders.ShovelBuilder)
local PlayerData = require(script.Parent.PlayerData)

local RESPAWN_DELAY = 2

local CharacterService = {}

function CharacterService.refreshShovel(player: Player)
	local data = PlayerData.get(player)
	local character = player.Character
	if data and character then
		ShovelBuilder.attach(character, data.shovelLevel)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	character:WaitForChild("HumanoidRootPart", 10)
	-- Wait for the hand to exist (R15 parts stream in after the root).
	if not character:FindFirstChild("RightHand") and not character:FindFirstChild("Right Arm") then
		local waited = 0
		while
			waited < 5
			and not character:FindFirstChild("RightHand")
			and not character:FindFirstChild("Right Arm")
		do
			waited += task.wait(0.1)
		end
	end
	if character.Parent then
		CharacterService.refreshShovel(player)
	end
	if humanoid then
		humanoid.Died:Connect(function()
			task.delay(RESPAWN_DELAY, function()
				if player.Parent and player.Character == character then
					player:LoadCharacter()
				end
			end)
		end)
	end
end

function CharacterService.init()
	PlayerData.Loaded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		player:LoadCharacter()
	end)
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			player.Character:Destroy()
		end
	end)
end

return CharacterService
