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
		if spot:GetAttribute("AreaId") == area then
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

local finds = {}
for i = 1, Progression.bagCapacity(1) do
	local list = spotList("Beach")
	local find, reason = digSpot(player, list[1])
	if not find then
		check(false, "dig " .. i .. " finished (" .. tostring(reason) .. ")")
		break
	end
	table.insert(finds, find)
end
check(#finds == 10, "dug 10 treasures")
check(#data.bagContents == 10, "bag has 10 items")
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
check(data.onboarding.guideDone, "new-player guide finished after the first upgrade")

H.moveTo(player, V3(MapLayout.bagStation.x, deckTop, MapLayout.bagStation.z))
H.fireServer(player, "BuyUpgrade", "Bag")
task.wait(0.05)
check(data.bagLevel == 2, "bag upgraded")

---------------------------------------------------------------------------
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

---------------------------------------------------------------------------
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
