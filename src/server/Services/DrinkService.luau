--!strict
-- The Tiki Bar: drinks bought with Cash at the bar's pad (Config/Drinks).
-- Each adds a timed boost; this service also applies the movement ones
-- (Speed Soda: walk speed, Jump Juice: jump height) to characters while
-- they run. The cash and luck drinks are read by Bonuses / LootService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local DrinkPrice = require(ReplicatedStorage.Shared.Logic.DrinkPrice)
local Drinks = require(ReplicatedStorage.Shared.Config.Drinks)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local Analytics = require(script.Parent.Analytics)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.Parent.World.World)

local DrinkService = {}

local baseJumpHeight = 7.2
local baseJumpPower = 50

-- Sets walk speed and jump from the player's running drinks.
local function applyMovement(player: Player)
	local data = PlayerData.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	local now = os.time()
	local speed = Movement.walkSpeed * Boosts.multiplier(data.activeBoosts, "SpeedSoda", now)
	local jump = Boosts.multiplier(data.activeBoosts, "JumpJuice", now)
	if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
		humanoid.WalkSpeed = speed
	end
	local height = baseJumpHeight * jump
	if math.abs(humanoid.JumpHeight - height) > 0.01 then
		humanoid.JumpHeight = height
		-- Jump height grows with the square of the jump speed.
		humanoid.JumpPower = baseJumpPower * math.sqrt(jump)
	end
end

local function onBuyDrink(player: Player, drinkId: any)
	if type(drinkId) ~= "string" then
		return
	end
	local drink = Drinks.Defs[drinkId]
	local data = PlayerData.get(player)
	local station = World.get().stations.Drinks
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not drink or not data or not station or not root then
		return
	end
	local offset = root.Position - station.position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > station.radius + 4 then
		Net.fire("Notify", player, "Step onto the Tiki Bar pad to order!", "Denied")
		return
	end
	local price = DrinkPrice.of(drink, data)
	if not EconomyService.spendCash(player, data, price, "Shop", "Drink_" .. drinkId) then
		Net.fire("Notify", player, "You need " .. Format.cash(price - data.cash) .. " more!", "Denied")
		return
	end
	Boosts.add(data.activeBoosts, drink.boost, drink.seconds, os.time())
	Analytics.custom(player, "Drink_" .. drinkId, price)
	Net.fire(
		"Notify",
		player,
		string.format(
			"%s %s! %s for %d min",
			drink.emoji,
			string.upper(drink.name),
			drink.blurb,
			drink.seconds // 60
		),
		"Reward"
	)
	PlayerData.changed(player)
	applyMovement(player)
end

function DrinkService.init()
	baseJumpHeight = StarterPlayer.CharacterJumpHeight
	baseJumpPower = StarterPlayer.CharacterJumpPower
	Net.on("BuyDrink", 3, 5, onBuyDrink)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				applyMovement(player)
			end
		end
	end)
end

return DrinkService
