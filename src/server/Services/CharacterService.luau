--!strict
-- Spawns characters once the profile is loaded (CharacterAutoLoads is off so
-- nobody plays before their save is ready), respawns them, keeps the current
-- shovel (with its rebirth tint or equipped skin) in their hand, and shows
-- the rebirth rank title above their head for everyone (VIPs get a gold
-- name with a crown above it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local Perks = require(ReplicatedStorage.Shared.Logic.Perks)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local ShovelBuilder = require(ReplicatedStorage.Shared.Builders.ShovelBuilder)
local PlayerData = require(script.Parent.PlayerData)

local RESPAWN_DELAY = 2

local CharacterService = {}

function CharacterService.refreshShovel(player: Player)
	local data = PlayerData.get(player)
	local character = player.Character
	if data and character then
		local skinId = Perks.equippedSkin(data)
		local skin = if skinId then (Monetization.Skins :: any)[skinId] else nil
		ShovelBuilder.attach(character, data.shovelLevel, Rebirth.tint(data.rebirths), skin)
		-- Lets every client play this shovel's impact effect (ImpactFx).
		character:SetAttribute("ShovelLevel", data.shovelLevel)
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
	local vip = Perks.enabled(data, "VIP")
	-- VIPs show their name in gold (instead of Roblox's own name tag).
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = if vip
			then Enum.HumanoidDisplayDistanceType.None
			else Enum.HumanoidDisplayDistanceType.Viewer
	end
	if title == "" and not vip then
		return
	end
	local rows = (if title ~= "" then 1 else 0) + (if vip then 1 else 0)
	local gui = Instance.new("BillboardGui")
	gui.Name = "RankTitle"
	-- Sized in studs (not pixels), so it stays small on screen up close.
	gui.Size = UDim2.fromScale(5, 0.8 * rows)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2 + (rows - 1) * 0.4, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Adornee = head
	local function line(text: string, color: Color3, row: number)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, (row - 1) / rows)
		label.Size = UDim2.fromScale(1, 1 / rows)
		label.Font = Enum.Font.LuckiestGuy
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = color
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(40, 25, 10)
		stroke.Parent = label
	end
	if vip then
		line("👑 " .. player.DisplayName, Color3.fromRGB(255, 210, 74), 1)
	end
	if title ~= "" then
		line(title, Color3.fromHex(Rebirth.tint(data.rebirths) or "#FFFFFF"), rows)
	end
	gui.Parent = head
end

-- Is the character holding its shovel (welded to a hand it still has)?
local function holdingShovel(character: Model): boolean
	local shovel = character:FindFirstChild("Shovel") :: Model?
	local handle = shovel and shovel.PrimaryPart
	local weld = handle and handle:FindFirstChild("HandWeld") :: Weld?
	local hand = weld and weld.Part0
	return hand ~= nil and hand.Parent == character
end

local function onCharacterAdded(player: Player, character: Model)
	-- The avatar's appearance can replace the hands after spawning, taking
	-- the shovel welded to the old one with it: attach again to the new one.
	character.ChildAdded:Connect(function(child)
		if child.Name == "RightHand" or child.Name == "Right Arm" then
			task.delay(0.1, function()
				if player.Character == character and not holdingShovel(character) then
					CharacterService.refreshShovel(player)
				end
			end)
		end
	end)
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
		humanoid.WalkSpeed = Movement.walkSpeed
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
	local starterPlayer = game:GetService("StarterPlayer") :: StarterPlayer
	starterPlayer.CharacterWalkSpeed = Movement.walkSpeed
	PlayerData.Loaded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		-- Avatar bundles can swap the body parts once the appearance loads,
		-- taking a shovel welded to the old hand with them: attach again.
		player.CharacterAppearanceLoaded:Connect(function(character)
			if character.Parent then
				CharacterService.refreshShovel(player)
				CharacterService.refreshTitle(player)
			end
		end)
		player:LoadCharacter()
	end)
	-- Safety net: anyone alive without their shovel in hand gets it back.
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if
					character
					and humanoid
					and humanoid.Health > 0
					and PlayerData.get(player)
					and not holdingShovel(character)
				then
					CharacterService.refreshShovel(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			player.Character:Destroy()
		end
	end)
end

return CharacterService
