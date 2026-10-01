-- Server smoke test: loads the built place and plays a scripted session
-- against the real server code. Usage:
--   rojo build default.project.json -o build.rbxl
--   lune run tests/runtime/server_smoke.luau build.rbxl

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local H = require("./Harness")

local placePath = process.args[1] or "build.rbxl"
local game = H.load(placePath)
local V3 = roblox.Vector3.new

local failures = 0
local function check(condition: any, message: string)
	if condition then
		print("ok    " .. message)
	else
		failures += 1
		print("FAIL  " .. message)
	end
end

---------------------------------------------------------------------------
print("\n== Server start ==")
local started = os.clock()
H.runScript(game:GetService("ServerScriptService").Server)
print(string.format("server script finished in %.2fs", os.clock() - started))

local workspace = H.workspace

-- The Mega Dig runs on the real clock: keep its schedule out of the way
-- (the Mega Dig checks start one themselves).
do
	local MegaDigService = H.require(game:GetService("ServerScriptService").Server.Services.MegaDigService)
	MegaDigService.setScheduled(false)
	MegaDigService.cancel()
end
local spots = workspace:FindFirstChild("DigSpots")
check(workspace:FindFirstChild("Base") ~= nil, "base built")
check(workspace:FindFirstChild("Gates") ~= nil, "gates built")
check(spots ~= nil, "dig spot folder exists")

local byArea: { [string]: number } = {}
for _, spot in spots:GetChildren() do
	local area = spot:GetAttribute("AreaId")
	byArea[area] = (byArea[area] or 0) + 1
end
for _, area in { "Beach", "Jungle", "Ruins", "Volcano" } do
	check((byArea[area] or 0) >= 18, string.format("%s has dig spots (%d)", area, byArea[area] or 0))
end

-- Shared modules (same instances the server uses).
local Shared = game:GetService("ReplicatedStorage").Shared
local Services = game:GetService("ServerScriptService").Server.Services
local PlayerData = H.require(Services.PlayerData)
local Progression = H.require(Shared.Logic.Progression)
local Rarities = H.require(Shared.Config.Rarities)
local MapLayout = H.require(Shared.Config.MapLayout)

-- World placement: terrain in Roblox sits above its fill heights (the
-- harness copies that), so the base and gates must measure the real ground.
local base = workspace.Base
local deck = base:FindFirstChild("Deck")
local deckTop = deck.Position.Y + deck.Size.Y / 2
local sand = H.terrainTop(MapLayout.base.minX - 10, (MapLayout.base.minZ + MapLayout.base.maxZ) / 2, 500)
check(sand ~= nil and deckTop > sand + 0.5 and deckTop < sand + 2, "deck stands just above the real sand")
check(base:FindFirstChild("SellPad").Position.Y > deckTop, "sell pad is on top of the deck")
for _, gateModel in workspace.Gates:GetChildren() do
	local barrier = gateModel:FindFirstChild("Barrier")
	local ramp = gateModel:FindFirstChild("Ramp")
	local foot = H.terrainTop(barrier.Position.X, barrier.Position.Z + 6, 500)
	check(ramp ~= nil, gateModel.Name .. " has a ramp")
	check(
		foot ~= nil and barrier.Position.Y - barrier.Size.Y / 2 < foot + 0.5,
		gateModel.Name .. " barrier reaches the ground"
	)
end

---------------------------------------------------------------------------
print("\n== Join ==")
local player = H.addPlayer("Tester", 5001)
H.waitFor(function()
	return PlayerData.get(player) ~= nil and player.Character ~= nil
end, 5, "profile + character")
local data = PlayerData.get(player)
check(data ~= nil, "profile loaded")
check(player.Character ~= nil, "character spawned after load")
check(player.Character and player.Character:FindFirstChild("Shovel") ~= nil, "shovel in hand")
do
	-- The avatar's appearance loading swaps the hand (taking the shovel).
	local character = player.Character
	local oldHand = character:FindFirstChild("RightHand")
	local newHand = oldHand:Clone()
	oldHand:Destroy()
	character:FindFirstChild("Shovel"):Destroy()
	newHand.Parent = character
	task.wait(0.5)
	local shovel = character:FindFirstChild("Shovel")
	local weld = shovel and shovel.PrimaryPart and shovel.PrimaryPart:FindFirstChild("HandWeld")
	check(weld and weld.Part0 == newHand, "the shovel comes back when the avatar swaps the hand")
end
check(player:FindFirstChild("leaderstats") ~= nil, "leaderstats created")
task.wait(0.1)
check(H.lastClientEvent("DataSync", player) ~= nil, "client got a data snapshot")
local snapshot = H.lastClientEvent("DataSync", player)
check(snapshot and snapshot[1].goldenX ~= nil, "snapshot has today's Golden X")
check(snapshot and snapshot[1].dailyCanClaim == true, "daily reward claimable on first join")

---------------------------------------------------------------------------
print("\n== Dig ==")
local function spotList(area: string)
	local list = {}
	for _, spot in spots:GetChildren() do
		if spot:GetAttribute("AreaId") == area and not spot:GetAttribute("Vip") then
			table.insert(list, spot)
		end
	end
	return list
end

-- Digs one spot to completion; returns the find (or the rejection reason).
local function digSpot(p, spot): (any, string?)
	local id = spot:GetAttribute("SpotId")
	local position = spot.PrimaryPart.Position
	H.moveTo(p, position + V3(2, 0, 0))
	for _ = 1, 12 do
		H.clockOffset += 1
		H.fireServer(p, "DigHit", id)
		task.wait()
		local result = H.lastClientEvent("DigResult", p)
		if result then
			local r = result[1]
			if r.spotId == id and r.rejected then
				return nil, r.rejected
			end
			if r.spotId == id and r.done then
				return r.find, nil
			end
		end
	end
	return nil, "never finished"
end

-- Ten digs (the first Rare is guaranteed within them): two bags' worth,
-- keeping the first bag to sell below.
local finds = {}
local startCapacity = Progression.bagCapacity(1)
local firstBag = nil
for i = 1, 10 do
	local list = spotList("Beach")
	local find, reason = digSpot(player, list[1])
	if not find then
		check(false, "dig " .. i .. " finished (" .. tostring(reason) .. ")")
		break
	end
	table.insert(finds, find)
	if i == startCapacity then
		check(#data.bagContents == startCapacity, "bag full after " .. startCapacity .. " digs")
		local _, reason2 = digSpot(player, spotList("Beach")[1])
		check(reason2 == "BagFull", "a full bag refuses more digs")
		firstBag = data.bagContents
		data.bagContents = {}
	end
end
data.bagContents = firstBag or data.bagContents
check(#finds == 10, "dug 10 treasures")
check(#data.bagContents == startCapacity, "bag is full")
local bestRank = 0
for _, find in finds do
	bestRank = math.max(bestRank, Rarities.rank(find.rarity))
end
check(bestRank >= Rarities.rank("Rare"), "guaranteed Rare within the first 10 digs")
check(finds[1].isNew and finds[1].firstFindBonus, "first find flagged NEW with the x2 bonus")
check(data.stats.digs == 10, "dig stat counted")

local _, fullReason = digSpot(player, spotList("Beach")[1])
check(fullReason == "BagFull", "digging with a full bag is rejected (" .. tostring(fullReason) .. ")")

---------------------------------------------------------------------------
print("\n== Sell ==")
local bagValue = 0
for _, item in data.bagContents do
	bagValue += item.v
end
H.moveTo(player, V3(MapLayout.sellPad.x, deckTop, MapLayout.sellPad.z))
H.waitFor(function()
	return #data.bagContents == 0
end, 2, "auto-sell")
check(#data.bagContents == 0, "bag emptied at the sell pad")
check(data.cash == bagValue, string.format("cash = bag value (%d)", bagValue))
local sold = H.lastClientEvent("Sold", player)
check(sold and sold[1].total == bagValue, "client got the sale popup data")
check(player.leaderstats.Cash.Value == data.cash, "leaderstats cash updated")

---------------------------------------------------------------------------
print("\n== Upgrade ==")
H.fireServer(player, "BuyUpgrade", "Shovel")
task.wait(0.05)
local result = H.lastClientEvent("UpgradeResult", player)
check(
	result and result[1].ok == false and result[1].reason == "TooFar",
	"buying away from the shop is rejected"
)

H.moveTo(player, V3(MapLayout.shovelStation.x, deckTop, MapLayout.shovelStation.z))
data.cash = 100
H.fireServer(player, "BuyUpgrade", "Shovel")
task.wait(0.05)
result = H.lastClientEvent("UpgradeResult", player)
check(
	result and result[1].reason == "NotEnoughCash" and result[1].missing == 150,
	"not enough cash: exact missing amount"
)

data.cash = 10000
H.fireServer(player, "BuyUpgrade", "Shovel")
task.wait(0.05)
check(data.shovelLevel == 2, "shovel upgraded to Stone")
check(data.cash == 9750, "upgrade cost deducted")
check(not data.onboarding.guideDone, "the tutorial goes on after the shovel (bag and drink next)")

H.moveTo(player, V3(MapLayout.bagStation.x, deckTop, MapLayout.bagStation.z))
H.fireServer(player, "BuyUpgrade", "Bag")
task.wait(0.05)
check(data.bagLevel == 2, "bag upgraded")

---------------------------------------------------------------------------
print("\n== Settings ==")
check(data.settings.music == true and data.settings.sounds == true, "settings default to on")
H.fireServer(player, "SetSetting", "music", false)
task.wait(0.05)
check(data.settings.music == false, "music setting saved")
H.fireServer(player, "SetSetting", "cash", true)
H.fireServer(player, "SetSetting", "sounds", "yes")
task.wait(0.05)
check(data.settings.cash == nil and data.settings.sounds == true, "malformed settings ignored")
H.fireServer(player, "SetSetting", "music", true)

print("\n== Shop: passes ==")
local Monetization = H.require(Shared.Config.Monetization)
local Perks = H.require(Shared.Logic.Perks)
local Bonuses = H.require(Shared.Logic.Bonuses)
local MarketplaceService = game:GetService("MarketplaceService")
local Passes, Products = Monetization.Passes, Monetization.Products
H.ownedPasses["8801:" .. Passes.AutoDig.id] = true
local owner = H.addPlayer("PassOwner", 8801)
local buyer = H.addPlayer("PassBuyer", 8802)
H.waitFor(function()
	return owner:GetAttribute("Pass_AutoDig") == true
		and PlayerData.get(buyer) ~= nil
		and buyer.Character ~= nil
end, 5, "pass owner detected")
local ownerData, buyerData = PlayerData.get(owner), PlayerData.get(buyer)
check(ownerData.passes.AutoDig == true, "a pass owned on Roblox is detected on join")
check(not Perks.has(buyerData, "AutoDig"), "a player without the pass doesn't have it")
H.signal(MarketplaceService, "PromptGamePassPurchaseFinished"):Fire(buyer, Passes.VIP.id, false)
H.signal(MarketplaceService, "PromptGamePassPurchaseFinished"):Fire(buyer, 999, true)
task.wait(0.05)
check(not Perks.has(buyerData, "VIP"), "a declined or unknown purchase grants nothing")
H.signal(MarketplaceService, "PromptGamePassPurchaseFinished"):Fire(buyer, Passes.VIP.id, true)
H.signal(MarketplaceService, "PromptGamePassPurchaseFinished"):Fire(buyer, Passes.VIP.id, true)
task.wait(0.1)
check(Perks.has(buyerData, "VIP") and buyer:GetAttribute("VIP") == true, "buying VIP grants it at once")
check(
	Perks.has(buyerData, "AutoDig") and Perks.has(buyerData, "AutoSell"),
	"VIP includes Auto Dig and Auto Sell"
)
check(buyerData.equippedSkin == "VIPGold", "VIP puts on the VIP Gold shovel")
local title = buyer.Character.Head:FindFirstChild("RankTitle")
check(
	title ~= nil and title:FindFirstChildOfClass("TextLabel").Text:find("PassBuyer") ~= nil,
	"VIP shows a gold name"
)
local unlocks = 0
for _, event in H.clientEvents("Notify", buyer) do
	if tostring(event[1]):find("VIP UNLOCKED") then
		unlocks += 1
	end
end
check(unlocks == 1, "one unlock message for a repeated purchase event (" .. unlocks .. ")")
H.fireServer(buyer, "SetSetting", "autoSell", false)
task.wait(0.05)
check(
	Perks.has(buyerData, "AutoSell") and not Perks.enabled(buyerData, "AutoSell"),
	"Auto Sell can be switched off"
)
H.fireServer(buyer, "SetSetting", "autoSell", true)
task.wait(0.05)
check(Perks.enabled(buyerData, "AutoSell"), "and back on")
H.fireServer(buyer, "SetSetting", "vip", false)
task.wait(0.05)
check(
	buyer:GetAttribute("VIP") == nil and not Perks.enabled(buyerData, "AutoSell"),
	"switching VIP off removes the tag and its included perks"
)
H.fireServer(buyer, "SetSetting", "vip", true)
task.wait(0.05)
check(buyer:GetAttribute("VIP") == true, "and back on")
ownerData.passes.BigBag = true
check(
	Perks.bagCapacity(ownerData) == math.ceil(Progression.bagCapacity(ownerData.bagLevel) * 1.5),
	"+50% Bag"
)
ownerData.passes.BigBag = nil

print("\n== Shop: developer products ==")
local cashBefore = buyerData.cash
local expected = Bonuses.rewardCash(Products.CashSmall.grant, buyerData)
check(
	H.processReceipt(8802, Products.CashSmall.id, "receipt-1") == "PurchaseGranted",
	"cash pack receipt granted"
)
check(buyerData.cash == cashBefore + expected, "cash pack added " .. expected)
check(
	H.processReceipt(8802, Products.CashSmall.id, "receipt-1") == "PurchaseGranted",
	"a retried receipt is acknowledged"
)
check(buyerData.cash == cashBefore + expected, "a retried receipt is never granted twice")
check(
	table.find(buyerData.processedPurchaseIds, "receipt-1") ~= nil,
	"the purchase id is recorded in the profile"
)
table.insert(H.allowedWarnings, "receipt for an unknown product")
check(H.processReceipt(8802, 123, "receipt-x") == "NotProcessedYet", "an unknown product is not granted")
check(
	H.processReceipt(99999, Products.CashSmall.id, "receipt-y") == "NotProcessedYet",
	"a player not in the server is retried later"
)
H.processReceipt(8802, Products.BoostCash.id)
check((buyerData.activeBoosts.Cash2x or 0) > os.time() + 800, "2x Cash boost: 15 minutes")
H.processReceipt(8802, Products.StarterPack.id)
check(
	buyerData.starterPackBought and buyerData.ownedCosmetics.Explorer and buyerData.equippedSkin == "Explorer",
	"Starter Pack: one-time flag, Explorer skin owned and worn"
)
H.processReceipt(8802, Products.SkinPirate.id)
check(buyerData.ownedCosmetics.Pirate == true, "skin bought")
H.fireServer(buyer, "EquipSkin", "Lava")
task.wait(0.05)
check(buyerData.equippedSkin == "Pirate", "can't equip a skin you don't own")
H.fireServer(buyer, "EquipSkin", "")
task.wait(0.05)
check(buyerData.equippedSkin == "", "skin taken off")
H.processReceipt(8802, Products.ServerBoost.id)
task.wait(0.05)
check(
	(workspace:GetAttribute("ServerBoostUntil") or 0) > workspace:GetServerTimeNow() + 500
		and workspace:GetAttribute("ServerBoostBy") == "PassBuyer",
	"server boost runs for everyone, credited to the buyer"
)
local thanked = false
for _, event in H.clientEvents("Notify", player) do
	thanked = thanked or tostring(event[1]):find("BOOSTED THE SERVER") ~= nil
end
check(thanked, "everyone sees who boosted the server")
H.processReceipt(8802, Products.InstantDeepDig.id)
task.wait(0.1)
check(buyerData.instantDeepDigs == 1, "Instant Deep Dig with no Deep Dig running is saved for later")

print("\n== Shop: perks in play ==")
-- Auto Sell: the bag sells itself the moment it fills.
local capacity = Perks.bagCapacity(buyerData)
buyerData.bagContents = {}
for _ = 1, capacity - 1 do
	table.insert(buyerData.bagContents, { id = "Shell", v = 5 })
end
local salesBefore = buyerData.stats.sales
local autoFind = digSpot(buyer, spotList("Beach")[1])
check(autoFind ~= nil, "dug the last treasure that fills the bag")
H.waitFor(function()
	return #buyerData.bagContents == 0
end, 3, "auto sell")
check(#buyerData.bagContents == 0 and buyerData.stats.sales == salesBefore + 1, "Auto Sell sold the full bag")
local sold = H.lastClientEvent("Sold", buyer)
check(sold and sold[1].source == "AutoSell", "the sale is marked as an auto sale")
-- SELL button anywhere (Auto Sell owners only).
table.insert(buyerData.bagContents, { id = "Shell", v = 5 })
table.insert(ownerData.bagContents, { id = "Shell", v = 5 })
H.fireServer(buyer, "SellAnywhere")
H.fireServer(owner, "SellAnywhere")
task.wait(0.05)
check(#buyerData.bagContents == 0, "SELL anywhere works with Auto Sell")
check(#ownerData.bagContents == 1, "SELL anywhere is refused without Auto Sell")
-- The VIP dig spot.
local vipSpot = nil
for _, spot in spots:GetChildren() do
	if spot:GetAttribute("Vip") then
		vipSpot = spot
	end
end
check(vipSpot ~= nil, "the VIP dig spot exists")
if vipSpot then
	check(
		math.abs(vipSpot.PrimaryPart.Position.X - MapLayout.vipSite.x) < 1,
		"the VIP spot is at the VIP site"
	)
	local _, reason = digSpot(owner, vipSpot)
	check(reason == "VipOnly", "the VIP spot refuses non-VIPs (" .. tostring(reason) .. ")")
	local vipFind = digSpot(buyer, vipSpot)
	check(vipFind ~= nil, "a VIP digs the VIP spot")
end
H.removePlayer(owner)
H.removePlayer(buyer)
workspace:SetAttribute("ServerBoostUntil", nil)

print("\n== Tiki Bar ==")
do
	local Drinks = H.require(Shared.Config.Drinks)
	local DrinkPrice = H.require(Shared.Logic.DrinkPrice)
	local tikiPad = workspace.Decor:FindFirstChild("TikiPad", true)
	check(tikiPad ~= nil, "the Tiki Bar has a drinks pad")
	local soda = Drinks.Defs.SpeedSoda
	-- The tutorial's first drink is free and finishes the tutorial.
	check(
		not data.onboarding.guideDone and DrinkPrice.isFree(data),
		"the first drink is free during the tutorial"
	)
	H.moveTo(player, tikiPad.Position + V3(0, 0.5, 0))
	task.wait(0.05)
	local cashBefore = data.cash
	H.fireServer(player, "BuyDrink", "JumpJuice")
	task.wait(0.1)
	check(
		data.cash == cashBefore
			and (data.activeBoosts.JumpJuice or 0) > os.time()
			and data.onboarding.freeDrinkUsed,
		"free first drink served"
	)
	check(data.onboarding.guideDone, "bag + shovel + drink complete the tutorial")
	local price = DrinkPrice.of(soda, data)
	check(price > 0, "after that drinks cost cash")
	data.cash = price + 10
	H.moveTo(player, V3(0, deckTop, 200))
	H.fireServer(player, "BuyDrink", "SpeedSoda")
	task.wait(0.05)
	check(data.cash == price + 10, "can't order away from the bar")
	H.moveTo(player, tikiPad.Position + V3(0, 0.5, 0))
	task.wait(0.05)
	H.fireServer(player, "BuyDrink", "SpeedSoda")
	H.fireServer(player, "BuyDrink", "Nope")
	task.wait(0.6)
	check(data.cash == 10, "Speed Soda costs " .. price)
	check((data.activeBoosts.SpeedSoda or 0) > os.time() + 250, "Speed Soda runs for 5 minutes")
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	check(humanoid.WalkSpeed > 25, "Speed Soda makes you faster (" .. humanoid.WalkSpeed .. ")")
	H.fireServer(player, "BuyDrink", "LuckyLemonade")
	task.wait(0.05)
	check(data.activeBoosts.LuckyLemonade == nil and data.cash == 10, "not enough cash: no drink")
	H.fireServer(player, "PauseBoost", "SpeedSoda", true)
	task.wait(0.6)
	check(
		data.activeBoosts.SpeedSoda == nil
			and (data.pausedBoosts.SpeedSoda or 0) > 250
			and humanoid.WalkSpeed < 25,
		"a drink can be paused (time kept, speed back to normal)"
	)
	H.fireServer(player, "PauseBoost", "SpeedSoda", false)
	task.wait(0.6)
	check(humanoid.WalkSpeed > 25 and data.pausedBoosts.SpeedSoda == nil, "and resumed")
	data.activeBoosts.SpeedSoda = nil
	task.wait(0.6)
	check(humanoid.WalkSpeed < 25, "speed back to normal when it runs out")
end

print("\n== Admin ==")
do
	local Admin = H.require(Shared.Config.Admin)
	local intruder = H.addPlayer("NotAdmin", 8899)
	H.waitFor(function()
		return PlayerData.get(intruder) ~= nil
	end, 5, "second player")
	local intruderData = PlayerData.get(intruder)
	local before = intruderData.cash
	H.fireServer(intruder, "AdminAction", "AddCash", nil, 1000000)
	H.fireServer(intruder, "AdminAction", "Abuse", nil, 10)
	task.wait(0.1)
	check(
		intruderData.cash == before and workspace:GetAttribute("AdminAbuseUntil") == nil,
		"non-admins can't use admin actions"
	)
	table.insert(Admin.userIds, 5001)
	local cash = data.cash
	H.fireServer(player, "AdminAction", "AddCash", nil, 1000)
	task.wait(0.1)
	check(data.cash == cash + 1000, "admin: +1K cash")
	H.fireServer(player, "AdminAction", "AddCash", 8899, 500)
	task.wait(0.1)
	check(intruderData.cash == before + 500, "admin: give cash to another player")
	H.fireServer(player, "AdminAction", "Treasure", nil, "Mythic")
	task.wait(0.1)
	local last = data.bagContents[#data.bagContents]
	check(
		last ~= nil and H.require(Shared.Config.Treasures).ById[last.id].rarity == "Mythic",
		"admin: give a Mythic"
	)
	table.remove(data.bagContents)
	H.fireServer(player, "AdminAction", "Abuse", nil, 10)
	task.wait(0.1)
	check(
		(workspace:GetAttribute("AdminAbuseUntil") or 0) > workspace:GetServerTimeNow()
			and (workspace:GetAttribute("RushUntil") or 0) > workspace:GetServerTimeNow()
			and (workspace:GetAttribute("ServerBoostUntil") or 0) > workspace:GetServerTimeNow(),
		"admin: ADMIN ABUSE turns on rush and 2x cash for everyone"
	)
	H.fireServer(player, "AdminAction", "Abuse", nil, 0)
	task.wait(0.1)
	check(workspace:GetAttribute("AdminAbuseUntil") == nil, "admin: ADMIN ABUSE can be stopped")
	H.fireServer(player, "AdminAction", "Kick", 8899)
	task.wait(0.2)
	check(H.kicked[8899] ~= nil, "admin: kick")
	table.remove(Admin.userIds)
end

print("\n== Bad client input ==")
local errorsBefore = #H.errors
for _, args in
	{ { "DigHit", "abc" }, { "DigHit", nil }, { "DigHit", 0 / 0 }, { "DigHit", 1.5 }, { "DigHit", 99999 } }
do
	H.fireServer(player, args[1], args[2])
end
H.fireServer(player, "BuyUpgrade", 123)
H.fireServer(player, "BuyUpgrade", "Hat")
H.fireServer(player, "ClaimGift", "x")
H.fireServer(player, "ClaimGift", 99)
H.fireServer(player, "ClaimGift", 1) -- too early
H.fireServer(player, "Rebirth")
task.wait(0.1)
check(#H.errors == errorsBefore, "malformed / early requests caused no server errors")
check(data.shovelLevel == 2 and data.bagLevel == 2, "malformed requests changed nothing")

---------------------------------------------------------------------------
print("\n== Areas ==")
H.moveTo(player, V3(60, MapLayout.plateauHeight, -60)) -- inside the Ruins, not unlocked
task.wait(0.7)
local root = player.Character.HumanoidRootPart
check(root.Position.Z > MapLayout.beachNorthZ, "sent back out of a locked area")

data.shovelLevel = 3
local jungleFind = digSpot(player, spotList("Jungle")[1])
check(jungleFind ~= nil, "dug in the Jungle with the Iron Shovel")
do
	local DigConfig = H.require(Shared.Config.Dig)
	local result = H.lastClientEvent("DigResult", player)[1]
	local expected = Progression.getShovel(3).hits + DigConfig.areaExtraHits.Jungle
	check(
		result.required == expected or result.deep,
		"Jungle spots take more hits (" .. tostring(result.required) .. " of " .. expected .. ")"
	)
end

---------------------------------------------------------------------------
print("\n== Hidden treasure ==")
do
	local JackpotService = H.require(Services.JackpotService)
	local DigSpotService = H.require(Services.DigSpotService)
	check(JackpotService.hide("Mythic", "Ruins"), "a Mythic was hidden in the Ruins")
	task.wait(0.1)
	local told = false
	for _, event in H.clientEvents("Notify", player) do
		told = told or tostring(event[1]):find("buried somewhere in the ANCIENT RUINS") ~= nil
	end
	check(told, "everyone is told the area, not the spot")
	local entry = JackpotService.list()[1]
	local spot = entry and DigSpotService.get(entry.spotId)
	check(spot ~= nil and spot.model:GetAttribute("Jackpot") == nil, "the spot looks like any other")
	if spot then
		local saved = data.shovelLevel
		data.shovelLevel = 5
		local find = digSpot(player, spot.model)
		check(
			find ~= nil and (find.rarity == "Mythic" or find.rarity == "Secret"),
			"digging it gives the Mythic (" .. tostring(find and find.rarity) .. ")"
		)
		task.wait(0.1)
		local found = false
		for _, event in H.clientEvents("Notify", player) do
			found = found or tostring(event[1]):find("found the hidden") ~= nil
		end
		check(found, "everyone hears who found it")
		check(#JackpotService.list() == 0, "no longer hidden")
		data.shovelLevel = saved
	end
end

print("\n== Mega Dig ==")
do
	local MegaDigService = H.require(Services.MegaDigService)
	local Treasures = H.require(Shared.Config.Treasures)
	local Rarities = H.require(Shared.Config.Rarities)
	check(workspace.Base:FindFirstChild("MegaClock") ~= nil, "the Mega Dig clock tower stands at the base")
	check(
		type(workspace:GetAttribute("MegaDigNext")) == "number",
		"the clock knows when the next Mega Dig starts"
	)
	check(MegaDigService.start(), "a Mega Dig site opens")
	check(not MegaDigService.start(), "only one at a time")
	local site = nil
	for _, spot in spots:GetChildren() do
		if spot:GetAttribute("Mega") then
			site = spot
		end
	end
	check(
		site ~= nil and workspace:GetAttribute("MegaDigActive") == true,
		"the site is in the world and announced"
	)
	if site then
		local id = site:GetAttribute("SpotId")
		H.moveTo(player, site.PrimaryPart.Position + V3(10, 0, 0))
		local bagBefore = #data.bagContents
		local hits = 0
		for _ = 1, 2000 do
			H.clockOffset += 1
			H.fireServer(player, "DigHit", id)
			hits += 1
			if not MegaDigService.isActive() then
				break
			end
		end
		check(hits >= 250, "it takes a lot of digging (" .. hits .. " hits)")
		check(not MegaDigService.isActive() and site.Parent == nil, "dug out")
		local draw = H.lastClientEvent("MegaDigDraw")
		check(draw and draw[1].winnerUserId == player.UserId, "the only helper wins the draw")
		local won = data.bagContents[#data.bagContents]
		local rarity = won and Treasures.ById[won.id].rarity
		check(
			#data.bagContents == bagBefore + 1 and rarity and Rarities.rank(rarity) >= Rarities.rank("Mythic"),
			"the prize is Mythic or better (" .. tostring(rarity) .. ")"
		)
		table.remove(data.bagContents)
	end
end

print("\n== Admin tools ==")
do
	local Admin = H.require(Shared.Config.Admin)
	local Treasures = H.require(Shared.Config.Treasures)
	local PartyService = H.require(Services.PartyService)
	local admin = H.addPlayer("AdminTester", 5002)
	H.waitFor(function()
		return PlayerData.get(admin) ~= nil and admin.Character ~= nil
	end, 5, "admin tester")
	table.insert(Admin.userIds, 5002)
	local adminData = PlayerData.get(admin)
	local function act(...)
		H.fireServer(admin, "AdminAction", ...)
		task.wait(0.15)
	end

	-- Spawn a Mythic spot in front of you and dig it.
	local beachSpot = spotList("Beach")[1]
	H.moveTo(admin, beachSpot.PrimaryPart.Position + V3(0, 0, 30))
	local here = admin.Character.HumanoidRootPart.Position
	local function spotsNear(radius: number): { any }
		local list = {}
		for _, spot in spots:GetChildren() do
			local p = spot.PrimaryPart.Position
			if V3(p.X - here.X, 0, p.Z - here.Z).Magnitude <= radius then
				table.insert(list, spot)
			end
		end
		return list
	end
	local nearBefore = #spotsNear(Admin.spawn.spotDistance + 1)
	act("SpawnSpot", nil, "Mythic")
	local spawned
	for _, spot in spotsNear(Admin.spawn.spotDistance + 1) do
		if spot:GetAttribute("Clue") then
			spawned = spot
		end
	end
	check(
		#spotsNear(Admin.spawn.spotDistance + 1) == nearBefore + 1 and spawned ~= nil,
		"admin: spawn a treasure spot in front of you"
	)
	if spawned then
		table.clear(adminData.bagContents)
		local find = digSpot(admin, spawned)
		check(
			find and Treasures.ById[find.id].rarity == "Mythic",
			"the spawned spot holds a Mythic (" .. tostring(find and find.rarity) .. ")"
		)
		check(spawned.Parent == nil, "it doesn't come back after digging")
	end
	H.moveTo(admin, here)
	local ringBefore = #spotsNear(Admin.spawn.ringRadius + 1)
	act("SpawnRing")
	local ringAfter = #spotsNear(Admin.spawn.ringRadius + 1)
	check(
		ringAfter == ringBefore + Admin.spawn.ringCount,
		"admin: a ring of clue spots (" .. ringAfter - ringBefore .. ")"
	)

	-- Money rain: coins fall; running into one pays.
	local dropSeconds = Admin.moneyRain.dropSeconds
	Admin.moneyRain.dropSeconds = 0.1
	act("MoneyRain")
	task.wait(0.3)
	check(PartyService.coinCount() == Admin.moneyRain.coins, "admin: money rain drops coins")
	check(H.lastClientEvent("Fireworks") ~= nil, "money rain starts with fireworks")
	local coin = workspace.MoneyRain:GetChildren()[1]
	local cash = adminData.cash
	H.moveTo(admin, coin.Position)
	task.wait(0.3)
	check(adminData.cash > cash, "grabbing a coin pays cash")
	check(H.lastClientEvent("CoinPicked", admin) ~= nil, "the coin pops on screen")
	Admin.moneyRain.dropSeconds = dropSeconds

	-- Mega Dig where you stand.
	act("MegaDig", nil, "Here")
	local MegaDigService = H.require(Services.MegaDigService)
	check(MegaDigService.isActive(), "admin: start a Mega Dig")
	act("MegaDig", nil, "Stop")
	check(not MegaDigService.isActive(), "admin: close a Mega Dig")

	-- Messages to every server.
	local published = #H.published
	act("GlobalMessage", nil, "Hello everyone!")
	task.wait(0.2)
	check(#H.published == published + 1, "admin: message published to every server")
	local shown = 0
	for _, args in H.clientEvents("GlobalMessage", player) do
		if args[1].text == "Hello everyone!" then
			shown += 1
		end
	end
	check(shown == 1, "it shows once in this server too (" .. shown .. "x)")
	local message = H.lastClientEvent("GlobalMessage", player)[1]
	check(message.userId == 5002 and message.name ~= nil, "with the admin's id for the avatar")
	H.clockOffset += 10
	H.filterFails = true
	act("GlobalMessage", nil, "Unfiltered")
	H.filterFails = false
	check(#H.published == published + 1, "nothing is sent if the text filter fails")

	-- Reset my progress (keeps purchases), then a brand new player.
	adminData.rebirths = 2
	adminData.shovelLevel = 4
	adminData.onboarding.guideDone = true
	adminData.passes.AutoDig = true
	admin:SetAttribute("Pass_AutoDig", true)
	act("ResetProgress")
	check(
		adminData.rebirths == 0 and adminData.shovelLevel == 1 and adminData.onboarding.guideDone == false,
		"admin: reset my progress"
	)
	check(adminData.passes.AutoDig == true, "a progress reset keeps purchases")
	act("ResetAll")
	check(
		adminData.passes.AutoDig == nil and admin:GetAttribute("Pass_AutoDig") == nil,
		"brand new player: test passes removed too"
	)
	table.remove(Admin.userIds)
	admin:Kick("done")
end

print("\n== Frost Portal ==")
do
	local Worlds = H.require(Shared.Config.Worlds)
	local portalModel = workspace:FindFirstChild("FrostPortal")
	check(portalModel ~= nil, "the Frost Portal stands on the beach")
	local center = portalModel:GetAttribute("Center")
	local explorer = H.addPlayer("Explorer", 5003)
	H.waitFor(function()
		return PlayerData.get(explorer) ~= nil and explorer.Character ~= nil
	end, 5, "explorer")
	local explorerData = PlayerData.get(explorer)
	explorerData.rebirths = 1
	H.moveTo(explorer, center)
	task.wait(0.5)
	local locked = H.lastClientEvent("Portal", explorer)
	check(locked and locked[1] == "Locked" and locked[2].have == 1, "below Rebirth 3 the portal stays shut")
	local pos = explorer.Character.HumanoidRootPart.Position
	check(
		V3(pos.X - center.X, 0, pos.Z - center.Z).Magnitude > Worlds.portal.triggerRadius,
		"and pushes you back out"
	)
	check(explorerData.worldUnlocks.Frost == nil, "not unlocked yet")

	explorerData.rebirths = Worlds.next.requiredRebirths
	task.wait(0.5)
	check(type(explorerData.worldUnlocks.Frost) == "number", "Rebirth 3 opens the portal for you")
	local attuned = false
	for _, args in H.clientEvents("Portal", explorer) do
		attuned = attuned or args[1] == "Attuned"
	end
	check(attuned, "with a fanfare")
	check(H.ordered["FirstExplorers_Frost"]["u5003"] ~= nil, "and your name goes on the First Explorers list")
	H.clockOffset += Worlds.portal.cooldown + 1
	H.moveTo(explorer, center)
	task.wait(0.5)
	local soon = H.lastClientEvent("Portal", explorer)
	check(soon and soon[1] == "ComingSoon", "stepping in shows that the world is being built")
	task.wait(1.5)
	local list = portalModel:FindFirstChild("List", true)
	check(
		list and list.Text:find("1%.") ~= nil,
		"the board lists the first explorers (" .. tostring(list and list.Text) .. ")"
	)
	-- Once the world exists (a placeId), the portal takes you there.
	Worlds.next.placeId = 123456
	H.clockOffset += Worlds.portal.cooldown + 1
	H.moveTo(explorer, center)
	task.wait(0.5)
	local trip = H.teleports[#H.teleports]
	check(
		trip and trip.placeId == 123456 and trip.players[1] == explorer,
		"with a world built, it teleports you there"
	)
	Worlds.next.placeId = nil
	explorer:Kick("done")
end

print("\n== Golden X ==")
H.fireServer(player, "RequestSync")
task.wait(0.1)
snapshot = H.lastClientEvent("DataSync", player)[1]
local golden = snapshot.goldenX
check(golden ~= nil, "Golden X available")
if golden then
	H.moveTo(player, golden.position + V3(2, 0, 0))
	local goldenFind
	for _ = 1, 6 do
		H.clockOffset += 1
		H.fireServer(player, "DigHit", -1)
		task.wait()
		local r = H.lastClientEvent("DigResult", player)[1]
		if r.spotId == -1 and r.done then
			goldenFind = r.find
			break
		end
	end
	check(
		goldenFind and Rarities.rank(goldenFind.rarity) >= Rarities.rank("Epic"),
		"Golden X gave Epic or better"
	)
	H.fireServer(player, "RequestSync")
	task.wait(0.1)
	check(H.lastClientEvent("DataSync", player)[1].goldenX == nil, "Golden X gone after digging it")
end

---------------------------------------------------------------------------
print("\n== Rewards ==")
local cashBefore = data.cash
H.fireServer(player, "ClaimDaily")
task.wait(0.05)
check(data.dailyState.streak == 1 and data.cash > cashBefore, "daily day 1 claimed")
H.fireServer(player, "ClaimDaily")
task.wait(0.05)
check(data.dailyState.streak == 1, "daily can't be claimed twice")

H.clockOffset += 5 * 60 + 5
cashBefore = data.cash
H.fireServer(player, "ClaimGift", 1)
task.wait(0.05)
check(data.cash > cashBefore, "5-minute playtime gift claimed")

---------------------------------------------------------------------------
print("\n== Rebirth ==")
data.shovelLevel = 8
data.cash = 5e6
H.moveTo(player, base:FindFirstChild("RebirthPad").Position)
H.fireServer(player, "Rebirth")
task.wait(0.1)
check(data.rebirths == 1, "rebirthed")
check(data.shovelLevel == 1 and data.cash == 0 and data.bagLevel == 1, "run reset")
check(next(data.discovered) ~= nil, "collection kept")
local head = player.Character:FindFirstChild("Head")
check(head and head:FindFirstChild("RankTitle") ~= nil, "rank title shown above head")

---------------------------------------------------------------------------
print("\n== Second player, shelf, leaderboards ==")
local friend = H.addPlayer("Friend", 5002)
H.waitFor(function()
	return PlayerData.get(friend) ~= nil
end, 5, "second profile")
local trophies = 0
for _, child in workspace.Base:GetChildren() do
	if string.sub(child.Name, 1, 7) == "Trophy_" then
		trophies += 1
	end
end
check(trophies == 2, "trophy shelf shows both players (" .. trophies .. ")")
task.wait(5.5) -- the rebirth requested an immediate leaderboard write
local rebirthBoard = nil
for name, board in H.ordered do
	if string.find(name, "LB_Rebirths_All") then
		rebirthBoard = board
	end
end
check(rebirthBoard and rebirthBoard["u5001"] == 1, "rebirth written to the leaderboard store")
local Leaderboards = H.require(Services.LeaderboardService)
Leaderboards.refresh()
local lbValue = game:GetService("ReplicatedStorage"):FindFirstChild("LeaderboardData")
check(lbValue and string.find(lbValue.Value, "User5001") ~= nil, "leaderboards published with display names")

---------------------------------------------------------------------------
print("\n== Leave and rejoin ==")
local rebirths = data.rebirths
H.removePlayer(player)
task.wait(0.3)
local stored = H.stores["DigForCash_Profiles_v1"]["Player_5001"]
check(stored and stored.data and stored.data.rebirths == rebirths, "profile saved on leave")
check(stored and stored.lock == nil, "session lock released")

local again = H.addPlayer("Tester", 5001)
H.waitFor(function()
	return PlayerData.get(again) ~= nil
end, 5, "rejoin")
local data2 = PlayerData.get(again)
check(data2 and data2.rebirths == rebirths and data2.dailyState.streak == 1, "progress intact after rejoin")

---------------------------------------------------------------------------
print("\n== Shutdown ==")
for _, fn in H.bindToClose do
	fn()
end
local stored2 = H.stores["DigForCash_Profiles_v1"]["Player_5002"]
check(stored2 and stored2.lock == nil, "BindToClose saved and released everyone")

---------------------------------------------------------------------------
print("")
for _, message in H.errors do
	print("RUNTIME ERROR: " .. message)
end
local unexpectedWarnings = 0
for _, message in H.warnings do
	unexpectedWarnings += 1
	print("WARNING: " .. message)
end
print(
	string.format(
		"\n%d check(s) failed, %d runtime error(s), %d warning(s)",
		failures,
		#H.errors,
		unexpectedWarnings
	)
)
process.exit(if failures == 0 and #H.errors == 0 and unexpectedWarnings == 0 then 0 else 1)
