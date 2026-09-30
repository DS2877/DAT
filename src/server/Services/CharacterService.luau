--!strict
-- Spawns characters once the profile is loaded (CharacterAutoLoads is off so
-- nobody plays before their save is ready), respawns them, keeps the current
-- shovel (with its rebirth tint) in their hand, and shows the rebirth rank
-- title above their head for everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local ShovelBuilder = require(ReplicatedStorage.Shared.Builders.ShovelBuilder)
local PlayerData = require(script.Parent.PlayerData)

local RESPAWN_DELAY = 2

local CharacterService = {}

function CharacterService.refreshShovel(player: Player)
	local data = PlayerData.get(player)
	local character = player.Character
	if data and character then
		ShovelBuilder.attach(character, data.shovelLevel, Rebirth.tint(data.rebirths))
	end
end

function CharacterService.refreshTitle(player: Player)
	local data = PlayerData.get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not data or not head then
		return
	end
	local existing = head:FindFirstChild("RankTitle")
	if existing then
		existing:Destroy()
	end
	local title = Rebirth.title(data.rebirths)
	if title == "" then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "RankTitle"
	gui.Size = UDim2.fromOffset(220, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.Text = title
	label.TextScaled = true
	label.TextColor3 = Color3.fromHex(Rebirth.tint(data.rebirths) or "#FFFFFF")
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(40, 25, 10)
	stroke.Parent = label
	gui.Parent = head
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
		CharacterService.refreshTitle(player)
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
