--!strict
-- Cash in: selling the bag at the sell pad. Also owns the leaderstats display.
-- Selling happens automatically when a player stands in the sell zone
-- (checked on the server a few times per second; never trusted from clients).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bag = require(ReplicatedStorage.Shared.Logic.Bag)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Goals = require(ReplicatedStorage.Shared.Logic.Goals)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local Analytics = require(script.Parent.Analytics)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.Parent.World.World)

local SELL_CHECK_INTERVAL = 0.25

local EconomyService = {}

-- Fired (player, data, total) after every sale (the Bounty Board listens).
EconomyService.Sold = Signal.new()

local function updateLeaderstats(player: Player, data: { [string]: any })
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash") :: IntValue?
	if cash then
		cash.Value = data.cash
	end
end

-- Adds cash from any source. Returns the new balance.
function EconomyService.addCash(
	player: Player,
	data: { [string]: any },
	amount: number,
	transactionType: string,
	sku: string
): number
	amount = math.max(0, math.floor(amount))
	data.cash = math.min(data.cash + amount, Economy.maxCash)
	data.stats.cashEarned += amount
	data.weekly.cashEarned += amount
	Analytics.economy(player, "Source", amount, data.cash, transactionType, sku)
	updateLeaderstats(player, data)
	PlayerData.changed(player)
	return data.cash
end

-- Removes cash if the player has enough. Returns true when spent.
function EconomyService.spendCash(
	player: Player,
	data: { [string]: any },
	amount: number,
	transactionType: string,
	sku: string
): boolean
	if amount < 0 or data.cash < amount then
		return false
	end
	data.cash -= amount
	data.stats.cashSpent += amount
	Analytics.economy(player, "Sink", amount, data.cash, transactionType, sku)
	updateLeaderstats(player, data)
	PlayerData.changed(player)
	return true
end

-- `source`: "Pad" (the sell zone, default), "AutoSell" (bag filled with
-- Auto Sell on) or "Anywhere" (Auto Sell's SELL button).
function EconomyService.sellAll(player: Player, source: string?): boolean
	local data = PlayerData.get(player)
	if not data or #data.bagContents == 0 then
		return false
	end
	local count = Bag.count(data.bagContents)
	local total = Bag.totalValue(data.bagContents)
	-- What was in it (the merchant comments on junk and big finds).
	local junk, bestRank = 0, 0
	for _, item in data.bagContents do
		local def = Treasures.ById[item.id]
		if def then
			if def.set == "Junk" then
				junk += 1
			end
			bestRank = math.max(bestRank, Rarities.rank(def.rarity))
		end
	end
	data.bagContents = {}
	data.stats.sales += 1
	EconomyService.addCash(player, data, total, "Gameplay", "SellTreasure")
	Analytics.funnel(player, data, "FirstSale")

	local goal = Goals.current(data)
	Net.fire("Sold", player, {
		total = total,
		count = count,
		cash = data.cash,
		goal = goal,
		nearGoal = Goals.isNear(goal),
		source = source or "Pad",
		junk = junk,
		best = Rarities.Order[bestRank],
	})
	EconomyService.Sold:Fire(player, data, total)
	return true
end

local function inSellZone(position: Vector3): boolean
	local zone = World.get().sellZone
	local localPos = zone.cframe:PointToObjectSpace(position)
	local half = zone.size / 2
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

function EconomyService.init()
	PlayerData.Loaded:Connect(function(player: Player, data)
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = data.cash
		cash.Parent = stats
		stats.Parent = player
	end)
end

function EconomyService.start()
	task.spawn(function()
		while true do
			task.wait(SELL_CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if data and root and #data.bagContents > 0 and inSellZone(root.Position) then
					EconomyService.sellAll(player)
				end
			end
		end
	end)
end

return EconomyService
