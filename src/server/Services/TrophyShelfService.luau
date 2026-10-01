--!strict
-- The trophy shelf at the base: one slot per player in the server, showing
-- that player's rarest find (with its Shiny / Golden look) and their name.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local TreasureBuilder = require(ReplicatedStorage.Shared.Builders.TreasureBuilder)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.Parent.World.World)

local TrophyShelfService = {}

local slotOwner: { [number]: Player } = {}
local slotOf: { [Player]: number } = {}
local slotModel: { [number]: Model } = {}

local function label(parent: BasePart, title: string, subtitle: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(6, 2.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Adornee = parent
	gui.Parent = parent
	for i, text in { title, subtitle } do
		local line = Instance.new("TextLabel")
		line.BackgroundTransparency = 1
		line.Position = UDim2.fromScale(0, (i - 1) * 0.5)
		line.Size = UDim2.fromScale(1, 0.5)
		line.Font = if i == 1 then Enum.Font.LuckiestGuy else Enum.Font.FredokaOne
		line.Text = text
		line.TextScaled = true
		line.TextColor3 = if i == 1 then Color3.new(1, 1, 1) else color
		line.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(45, 28, 12)
		stroke.Parent = line
	end
end

-- Rebuilds a player's shelf slot from their saved best find.
function TrophyShelfService.refresh(player: Player)
	local slot = slotOf[player]
	local data = PlayerData.get(player)
	if not slot or not data then
		return
	end
	local old = slotModel[slot]
	if old then
		old:Destroy()
	end
	local cframe = World.get().shelfSlots[slot]
	local best = data.bestFind
	local def = best.id and Treasures.ById[best.id]
	local model: Model
	if def then
		model = TreasureBuilder.build(def.id)
		TreasureBuilder.applyMutation(model, best.m)
		TreasureBuilder.scaleTo(model, 1.3)
	else
		model = Instance.new("Model")
		local placeholder = Instance.new("Part")
		placeholder.Name = "Root"
		placeholder.Anchored = true
		placeholder.CanCollide = false
		placeholder.Transparency = 1
		placeholder.Size = Vector3.new(0.5, 0.5, 0.5)
		placeholder.Parent = model
		model.PrimaryPart = placeholder
	end
	model.Name = "Trophy_" .. player.UserId
	model:PivotTo(cframe * CFrame.new(0, 1.8, 0))
	local rarityColor = if def then Color3.fromHex(Rarities.Info[def.rarity].color) else Color3.new(1, 1, 1)
	local what = if def
		then (if best.m == "Golden" then "GOLDEN " elseif best.m == "Shiny" then "Shiny " else "") .. def.name
		else "No treasure yet!"
	label(model.PrimaryPart :: BasePart, player.DisplayName, what, rarityColor)
	model.Parent = workspace:FindFirstChild("Base")
	slotModel[slot] = model
end

local function release(player: Player)
	local slot = slotOf[player]
	if not slot then
		return
	end
	slotOf[player] = nil
	slotOwner[slot] = nil
	local model = slotModel[slot]
	if model then
		model:Destroy()
		slotModel[slot] = nil
	end
end

function TrophyShelfService.init()
	PlayerData.Loaded:Connect(function(player: Player)
		local slots = World.get().shelfSlots
		for i = 1, #slots do
			if not slotOwner[i] then
				slotOwner[i] = player
				slotOf[player] = i
				TrophyShelfService.refresh(player)
				return
			end
		end
	end)
	Players.PlayerRemoving:Connect(release)
end

return TrophyShelfService
