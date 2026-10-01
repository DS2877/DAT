-- Client smoke test: boots the real server, joins a player, then runs the
-- real client scripts for that player in the same process (remotes are
-- looped back). Drives frames, presses the real DIG button, walks onto the
-- shops, and opens every panel, so UI construction and client logic run.
-- Usage: lune run tests/runtime/client_smoke.luau build.rbxl

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local H = require("./Harness")

local game = H.load(process.args[1] or "build.rbxl")
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

H.runScript(game:GetService("ServerScriptService").Server)
local Shared = game:GetService("ReplicatedStorage").Shared
local PlayerData = H.require(game:GetService("ServerScriptService").Server.Services.PlayerData)
local MapLayout = H.require(Shared.Config.MapLayout)

-- A player with a PlayerGui, joined on the server.
local player = H.addPlayer("Kid", 7001)
local playerGui = Instance and nil
do
	local gui = roblox.Instance.new("PlayerGui")
	gui.Parent = H.unwrap(player)
	playerGui = H.wrap(gui)
end
H.waitFor(function()
	return PlayerData.get(player) ~= nil and player.Character ~= nil
end, 5, "server profile")
local data = PlayerData.get(player)

-- Client mode: remotes loop back between the client code and the server.
H.isClient = true
H.localPlayer = player
H.onFireServer = function(remote: string, ...)
	H.fireServer(player, remote, ...)
end

-- Frame driver.
local running = true
task.spawn(function()
	local RunService = H.unwrap(game:GetService("RunService"))
	while running do
		local dt = task.wait(1 / 30)
		H.signal(H.wrap(RunService), "RenderStepped"):Fire(dt)
		H.signal(H.wrap(RunService), "Heartbeat"):Fire(dt)
	end
end)

print("\n== Client start ==")
local clientScript = game:GetService("StarterPlayer").StarterPlayerScripts.Client
H.runScript(clientScript)
task.wait(0.3)

local hud = playerGui:FindFirstChild("Hud")
check(hud ~= nil, "HUD built")
local root = hud and hud:FindFirstChild("Root")
check(
	root and root:FindFirstChild("Cash") and root:FindFirstChild("Bag") and root:FindFirstChild("Goal"),
	"cash, bag and goal bar exist"
)
check(
	root
		and root.TopButtons:FindFirstChild("CollectionButton")
		and root.TopButtons:FindFirstChild("DailyButton"),
	"top buttons exist"
)
local cashText = root and root.Cash.Value.Text
check(cashText == "$0", "cash shows $0 (" .. tostring(cashText) .. ")")
check(root and not root.Loading.Visible, "loading text hidden after data arrived")
local tutorial = root and root:FindFirstChild("Tutorial")
check(tutorial ~= nil and tutorial.Visible, "tutorial banner shows for a new player")
local tutorialTitle = tutorial and tutorial:FindFirstChild("TextLabel", true)
local function tutorialText(): string
	local parts = {}
	for _, d in tutorial:GetDescendants() do
		if d:IsA("TextLabel") then
			table.insert(parts, d.Text)
		end
	end
	return table.concat(parts, " | ")
end
check(
	tutorialTitle ~= nil and tutorialText():find("dig spot") ~= nil,
	"tutorial starts at FIND (" .. tutorialText() .. ")"
)

-- The daily calendar should NOT pop over a brand-new player's first minute.
task.wait(3.5)
check(
	root and root:FindFirstChild("Daily") and not root.Daily.Visible,
	"daily popup waits until the player knows the loop"
)

print("\n== Dig with the DIG button ==")
local spots = H.workspace.DigSpots
local nearest, best = nil, math.huge
local spawnPos = player.Character.HumanoidRootPart.Position
for _, spot in spots:GetChildren() do
	if spot:GetAttribute("AreaId") == "Beach" and not spot:GetAttribute("Vip") then
		local d = (spot.PrimaryPart.Position - spawnPos).Magnitude
		if d < best then
			nearest, best = spot, d
		end
	end
end
print(string.format("nearest spot is %.0f studs from spawn", best))
check(best < 80, "a dig spot is close to spawn")
H.moveTo(player, nearest.PrimaryPart.Position + V3(3, 0, 0))
task.wait(0.3)
local digButton = root.DigButton
check(digButton.Visible, "DIG button appears next to a spot")
local finger = { UserInputType = roblox.Enum.UserInputType.Touch, KeyCode = roblox.Enum.KeyCode.Unknown }
local UserInputService = H.wrap(H.unwrap(game:GetService("UserInputService")))
-- Each tap digs once.
local function tap()
	H.signal(digButton, "InputBegan"):Fire(finger)
	H.signal(UserInputService, "InputEnded"):Fire(finger)
end
for _ = 1, 8 do
	if data.stats.finds >= 1 then
		break
	end
	tap()
	task.wait(0.6)
end
check(data.stats.finds >= 1, "tapping DIG dug the spot out")
task.wait(2.5) -- reveal + fly to bag
check(root.Bag.Value.Text:find("1/5") ~= nil, "bag counter ticked to 1 (" .. root.Bag.Value.Text .. ")")

print("\n== Shops, panels ==")
data.cash = 400
H.fireServer(player, "RequestSync")
task.wait(0.2)
local deck = H.workspace.Base:FindFirstChild("Deck")
local deckTop = deck.Position.Y + deck.Size.Y / 2
local upgradePanel = root:FindFirstChild("UpgradePanel")
check(tutorialText():find("BAGS shop") ~= nil, "tutorial asks for the bag first (" .. tutorialText() .. ")")
H.moveTo(player, V3(MapLayout.bagStation.x, deckTop, MapLayout.bagStation.z))
task.wait(0.5)
check(upgradePanel and upgradePanel.Visible, "bag shop panel opens on the pad")
H.signal(upgradePanel:FindFirstChild("Buy", true), "Activated")
	:Fire({ UserInputType = roblox.Enum.UserInputType.Touch })
task.wait(0.4)
check(data.bagLevel == 2, "BUY button bought the Satchel")
H.moveTo(player, V3(MapLayout.shovelStation.x, deckTop, MapLayout.shovelStation.z))
task.wait(0.5)
check(upgradePanel and upgradePanel.Visible, "shovel shop panel opens on the pad")
check(
	tutorialText():find("SHOVELS shop") ~= nil,
	"tutorial points at the shovel shop (" .. tutorialText() .. ")"
)
H.signal(upgradePanel:FindFirstChild("Buy", true), "Activated")
	:Fire({ UserInputType = roblox.Enum.UserInputType.Touch })
task.wait(0.3)
check(data.shovelLevel == 2, "BUY button bought the Stone Shovel")
task.wait(0.4)
check(
	tutorialText():find("Tiki Bar") ~= nil,
	"then the tutorial sends you to the Tiki Bar (" .. tutorialText() .. ")"
)
check(not data.onboarding.guideDone, "the tutorial isn't over before the drink")
local tikiPadEarly = H.workspace.Decor:FindFirstChild("TikiPad", true)
H.moveTo(player, tikiPadEarly.Position + V3(0, 0.5, 0))
task.wait(0.6)
local tikiPanel = root:FindFirstChild("TikiBar")
check(tikiPanel and tikiPanel.Visible, "the Tiki Bar opens during the tutorial")
local soda = tikiPanel:FindFirstChild("SpeedSoda", true)
check(
	soda and soda.Buy.Text == "FREE!",
	"the first drink is free (" .. tostring(soda and soda.Buy.Text) .. ")"
)
local cashBeforeDrink = data.cash
H.signal(soda.Buy, "Activated"):Fire({})
task.wait(0.5)
check(
	data.cash == cashBeforeDrink and (data.activeBoosts.SpeedSoda or 0) > os.time(),
	"free Speed Soda served"
)
check(data.onboarding.guideDone, "the drink completes the tutorial")
task.wait(0.4)
check(not tutorial.Visible, "tutorial banner gone")
H.moveTo(player, V3(MapLayout.spawn.x, deckTop, MapLayout.spawn.z))
task.wait(0.4)

for _, name in { "CollectionButton", "DailyButton", "TopButton" } do
	local button = root.TopButtons:FindFirstChild(name)
	check(button ~= nil, name .. " exists")
	if button then
		H.signal(button, "Activated"):Fire({})
		task.wait(0.2)
	end
end
check(root:FindFirstChild("Collection") ~= nil, "collection screen built")
check(root:FindFirstChild("Daily") ~= nil, "daily panel built")
check(root:FindFirstChild("Leaderboards") and root.Leaderboards.Visible, "leaderboard panel open")
check(not root.Collection.Visible and not root.Daily.Visible, "only one center panel open at a time")
H.signal(root.TopButtons.CollectionButton, "Activated"):Fire({})
task.wait(0.1)
check(root.Collection.Visible and not root.Leaderboards.Visible, "opening Collection closes Leaderboards")

H.moveTo(player, H.workspace.Base:FindFirstChild("RebirthPad").Position)
task.wait(0.5)
check(root:FindFirstChild("RebirthPanel") and root.RebirthPanel.Visible, "rebirth panel opens at the altar")

print("\n== Sell ==")
H.moveTo(player, V3(MapLayout.sellPad.x, deckTop, MapLayout.sellPad.z))
H.waitFor(function()
	return #data.bagContents == 0
end, 2, "sell")
task.wait(1.5)
check(#data.bagContents == 0, "sold at the pad")

print("\n== Auto Dig pass ==")
local Monetization = H.require(Shared.Config.Monetization)
local autoDigId = Monetization.Passes.AutoDig.id
H.buyPrompts = true
local hits = 0
local forward = H.onFireServer
H.onFireServer = function(remote: string, ...)
	if remote == "DigHit" then
		hits += 1
	end
	forward(remote, ...)
end
local function goToSpot()
	local here = player.Character.HumanoidRootPart.Position
	local pick, distance = nil, math.huge
	for _, spot in spots:GetChildren() do
		if spot:GetAttribute("AreaId") == "Beach" and not spot:GetAttribute("Vip") then
			local d = (spot.PrimaryPart.Position - here).Magnitude
			if d < distance then
				pick, distance = spot, d
			end
		end
	end
	H.moveTo(player, pick.PrimaryPart.Position + V3(3, 0, 0))
	task.wait(0.4)
end
goToSpot()
check(data.onboarding.guideDone, "tutorial done before any offer")
hits = 0
H.signal(digButton, "InputBegan"):Fire(finger)
task.wait(1.5)
check(hits == 1, "without Auto Dig, holding DIG digs once (" .. hits .. " hits)")
local offer = root:FindFirstChild("Offer")
check(offer and offer:GetAttribute("Key") == "AutoDig", "holding DIG shows the Auto Dig offer")
check(#H.passPrompts == 0, "no purchase prompt without a tap")
H.signal(UserInputService, "InputEnded"):Fire(finger)
hits = 0
for _ = 1, 2 do
	H.signal(digButton, "InputBegan"):Fire(finger)
	H.signal(UserInputService, "InputEnded"):Fire(finger)
	task.wait(0.1)
end
task.wait(0.8)
check(hits == 2, "a tap during the swing still lands (" .. hits .. " hits)")
check(offer.Parent ~= nil, "the offer stays up while tapping")
H.signal(offer.Get, "Activated"):Fire({ UserInputType = roblox.Enum.UserInputType.Touch })
H.waitFor(function()
	return player:GetAttribute("Pass_AutoDig") == true
end, 2, "Auto Dig purchase")
check(#H.passPrompts == 1 and H.passPrompts[1].passId == autoDigId, "GET opens the Roblox purchase prompt")
check(player:GetAttribute("Pass_AutoDig") == true, "buying Auto Dig unlocks it right away")
check(offer.Parent == nil, "the offer closes")
task.wait(2.5) -- let the last find's reveal finish
goToSpot()
local findsBefore = data.stats.finds
hits = 0
H.signal(digButton, "InputBegan"):Fire(finger)
H.waitFor(function()
	return data.stats.finds > findsBefore
end, 6, "Auto Dig find")
check(data.stats.finds > findsBefore and hits >= 3, "with Auto Dig, holding DIG digs the spot out")
H.signal(UserInputService, "InputEnded"):Fire(finger)

print("\n== Settings: perk switches ==")
local settingsPanel = root:FindFirstChild("Settings")
H.signal(root.TopButtons.SettingsButton, "Activated"):Fire({})
task.wait(0.1)
local autoDigRow = settingsPanel:FindFirstChild("autoDig", true)
check(autoDigRow and autoDigRow.Visible, "Settings shows the Auto Dig switch once owned")
check(not settingsPanel:FindFirstChild("autoSell", true).Visible, "no switch for perks you don't own")
H.signal(autoDigRow.Toggle, "Activated"):Fire({})
task.wait(0.2)
check(data.settings.autoDig == false, "Auto Dig switched off (saved)")
H.signal(root.TopButtons.SettingsButton, "Activated"):Fire({})
task.wait(2.5)
goToSpot()
hits = 0
H.signal(digButton, "InputBegan"):Fire(finger)
task.wait(1.2)
H.signal(UserInputService, "InputEnded"):Fire(finger)
check(hits == 1, "with Auto Dig off, holding digs once (" .. hits .. " hits)")
check(root:FindFirstChild("Offer") == nil, "no offer for a pass you already own")

print("\n== Tiki Bar ==")
local tikiPad = H.workspace.Decor:FindFirstChild("TikiPad", true)
data.cash += 5000
H.fireServer(player, "RequestSync")
H.moveTo(player, tikiPad.Position + V3(0, 0.5, 0))
task.wait(0.6)
local tiki = root:FindFirstChild("TikiBar")
check(tiki and tiki.Visible, "the drinks menu opens on the Tiki Bar pad")
local jump = tiki and tiki:FindFirstChild("JumpJuice", true)
check(jump and jump.Buy.Text:find("%$") ~= nil, "drinks show a cash price")
H.signal(jump.Buy, "Activated"):Fire({})
task.wait(0.5)
check((data.activeBoosts.JumpJuice or 0) > os.time(), "BUY ordered a Jump Juice")
check(jump.Timer.Text:find("Active") ~= nil, "the card shows the time left (" .. jump.Timer.Text .. ")")
H.moveTo(player, V3(0, deck.Position.Y + 3, 206))
task.wait(0.6)
check(not tiki.Visible, "the menu closes when you walk away")

print("\n== One-way walls ==")
local cliff = nil
for _, wall in H.workspace.Walls:GetChildren() do
	if
		wall:GetAttribute("OneWay")
		and wall:GetAttribute("PlaneZ") == MapLayout.beachNorthZ
		and wall:GetAttribute("PlaneX") < -100
	then
		cliff = wall
	end
end
check(cliff ~= nil and cliff.CanCollide, "cliff walls block players coming from the beach")
if cliff then
	data.shovelLevel = 3 -- the Jungle is open
	H.fireServer(player, "RequestSync")
	local px, pz = cliff:GetAttribute("PlaneX"), cliff:GetAttribute("PlaneZ")
	H.moveTo(player, V3(px, MapLayout.plateauHeight + 3, pz - 10))
	task.wait(0.3)
	check(not cliff.CanCollide, "from inside the Jungle the cliff lets you jump down")
	H.moveTo(player, V3(px, MapLayout.beachHeight + 3, pz + 1.5))
	task.wait(0.3)
	check(not cliff.CanCollide, "it stays open while you pass through")
	H.moveTo(player, V3(px, MapLayout.beachHeight + 3, pz + 12))
	task.wait(0.3)
	check(cliff.CanCollide, "and closes again once you're out")
end
check(H.workspace.Base:FindFirstChild("VipRunway") ~= nil, "a red carpet leads to the VIP dig site")

print("\n== Shop ==")
local shop = root:FindFirstChild("Shop")
H.signal(root.ShopButton, "Activated"):Fire({})
task.wait(0.2)
check(shop and shop.Visible, "SHOP button opens the shop")
local shopGrid = shop:FindFirstChild("Grid", true)
local function cards(): { [string]: any }
	local list = {}
	for _, child in shopGrid:GetChildren() do
		if child:IsA("Frame") then
			list[child.Name] = child
		end
	end
	return list
end
local passCards = cards()
check(passCards.VIP and passCards.AutoSell and passCards.AutoDig, "Passes tab lists the passes")
check(passCards.Luck2x == nil, "2x Luck stays hidden (off by default)")
check(
	passCards.AutoDig.Buy.Text == "OFF",
	"owned Auto Dig shows its switch (" .. passCards.AutoDig.Buy.Text .. ")"
)
check(passCards.VIP.Buy.Text:find("R%$") ~= nil, "VIP shows its price (" .. passCards.VIP.Buy.Text .. ")")
H.signal(passCards.AutoDig.Buy, "Activated"):Fire({})
task.wait(0.2)
check(data.settings.autoDig == true, "the shop card switches Auto Dig back on")
H.signal(shop:FindFirstChild("Cash", true), "Activated"):Fire({})
task.wait(0.1)
local cashCards = cards()
check(cashCards.StarterPack and cashCards.CashMedium, "Cash tab lists the Starter Pack and cash packs")
check(
	cashCards.CashMedium.Amount and cashCards.CashMedium.Amount.Text:find("%$") ~= nil,
	"cash packs show the amount"
)
local cashBefore = data.cash
local promptsBefore = #H.productPrompts
H.signal(cashCards.CashSmall.Buy, "Activated"):Fire({})
H.waitFor(function()
	return data.cash > cashBefore
end, 3, "cash pack purchase")
check(#H.productPrompts == promptsBefore + 1, "BUY opens the Roblox purchase prompt")
check(
	data.cash > cashBefore and H.receipts[#H.receipts].decision == "PurchaseGranted",
	"the cash pack was granted"
)
H.signal(shop:FindFirstChild("Skins", true), "Activated"):Fire({})
task.wait(0.1)
check(cards().VIPGold ~= nil and cards().SkinPirate ~= nil, "Skins tab lists the skins")
H.signal(shop:FindFirstChild("Boosts", true), "Activated"):Fire({})
task.wait(0.1)
check(cards().ServerBoost ~= nil and cards().InstantDeepDig ~= nil, "Boosts tab lists the boosts")
H.signal(root.ShopButton, "Activated"):Fire({})
task.wait(0.1)
check(not shop.Visible, "SHOP button closes the shop")

running = false
task.wait(0.2)

print("")
for _, message in H.errors do
	print("RUNTIME ERROR: " .. message)
end
for _, message in H.warnings do
	print("WARNING: " .. message)
end
print(
	string.format(
		"\n%d check(s) failed, %d runtime error(s), %d warning(s)",
		failures,
		#H.errors,
		#H.warnings
	)
)
process.exit(if failures == 0 and #H.errors == 0 and #H.warnings == 0 then 0 else 1)
