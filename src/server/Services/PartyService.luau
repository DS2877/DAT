--!strict
-- Admin spawn toys (Config/Admin):
--   * money rain: gold coins fall around a point; anyone who runs into one
--     gets cash (a share of their own next goal)
--   * fireworks: every client draws them over a point

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Admin = require(ReplicatedStorage.Shared.Config.Admin)
local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local PartyService = {}

type Coin = { part: BasePart, expires: number }

local coins: { Coin } = {}
local folder: Folder? = nil
local rng = Random.new()

local function coinFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "MoneyRain"
	created.Parent = workspace
	folder = created
	return created
end

-- The ground under (x, z), near the height `aroundY` (ignores characters,
-- coins and dig spots).
function PartyService.groundAt(x: number, z: number, aroundY: number): Vector3
	local exclude: { Instance } = { coinFolder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local spots = workspace:FindFirstChild("DigSpots")
	if spots then
		table.insert(exclude, spots)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(Vector3.new(x, aroundY + 40, z), Vector3.new(0, -120, 0), params)
	return Vector3.new(x, if hit then hit.Position.Y else aroundY - 3, z)
end

local function dropCoin(center: Vector3)
	local cfg = Admin.moneyRain
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(rng:NextNumber()) * cfg.radius
	local ground = PartyService.groundAt(
		center.X + math.cos(angle) * distance,
		center.Z + math.sin(angle) * distance,
		center.Y
	)
	local turn = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.45, 2.6, 2.6)
	coin.Color = Color3.fromRGB(255, 201, 51)
	coin.Material = Enum.Material.Metal
	coin.Reflectance = 0.2
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CanTouch = false
	coin.CFrame = CFrame.new(ground + Vector3.new(0, 50, 0)) * turn
	coin.Parent = coinFolder()
	TweenService:Create(
		coin,
		TweenInfo.new(rng:NextNumber(1.8, 2.8), Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(ground + Vector3.new(0, 1.5, 0)) * turn }
	):Play()
	table.insert(coins, { part = coin, expires = os.clock() + cfg.lifetime })
end

-- Coins fall around `center` for a few seconds.
function PartyService.moneyRain(center: Vector3)
	local cfg = Admin.moneyRain
	for _ = 1, cfg.coins do
		task.delay(rng:NextNumber(0, cfg.dropSeconds), dropCoin, center)
	end
	Net.fireAll("Notify", "💸 MONEY RAIN! Grab the coins!", "Big")
	Net.fireAll("Fireworks", center, 3)
end

function PartyService.fireworks(center: Vector3, count: number?)
	Net.fireAll("Fireworks", center, count or 8)
end

-- How many coins are lying around (tests).
function PartyService.coinCount(): number
	return #coins
end

local function collect()
	local cfg = Admin.moneyRain
	local now = os.clock()
	for i = #coins, 1, -1 do
		local coin = coins[i]
		local taken = now > coin.expires
		if not taken then
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local data = PlayerData.get(player)
				if root and data and (root.Position - coin.part.Position).Magnitude <= cfg.pickupRange then
					local amount = Bonuses.rewardCash(cfg.coinReward, data)
					EconomyService.addCash(player, data, amount, "Gameplay", "MoneyRain")
					Net.fire("CoinPicked", player, amount, coin.part.Position)
					taken = true
					break
				end
			end
		end
		if taken then
			coin.part:Destroy()
			table.remove(coins, i)
		end
	end
end

function PartyService.init()
	task.spawn(function()
		while true do
			task.wait(0.1)
			if #coins > 0 then
				collect()
			end
		end
	end)
end

return PartyService
