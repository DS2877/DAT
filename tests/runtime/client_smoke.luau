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

-- The Mega Dig runs on the real clock: keep its schedule out of the way
-- (the Mega Dig checks start one themselves).
do
	local MegaDigService = H.require(game:GetService("ServerScriptService").Server.Services.MegaDigService)
	MegaDigService.setScheduled(false)
	MegaDigService.cancel()
end

-- A player with a PlayerGui, joined on the server.
table.insert(H.require(Shared.Config.Admin).userIds, 7001) -- this player is an admin
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
-- One upcoming Roblox event (for the Island Guide's sign-up list).
H.experienceEvents = {
	{
		Id = "evt-1",
		Title = "Admin Abuse Hour",
		DisplayTitle = "Admin Abuse Hour",
		StartTime = { Year = 2026, Month = 10, Day = 10, Hour = 18, Minute = 0, Second = 0, Millisecond = 0 },
		HasStarted = false,
		HasEnded = false,
		UserRsvpStatus = "None",
	},
}
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
do
	-- The dig animation: the right shoulder moves off its rest pose mid-dig
	-- and settles back after.
	local Effects = H.require(clientScript.Effects)
	local character = player.Character
	local shoulder = character:FindFirstChild("RightShoulder", true)
		or character:FindFirstChild("Right Shoulder", true)
	local rest = shoulder.C0
	Effects.swing(character, 0.4)
	task.wait(0.18)
	local moved = shoulder.C0 ~= rest
	check(Effects.isDigging(character) and moved, "digging plays the dig animation")
	task.wait(0.4)
	check(not Effects.isDigging(character) and shoulder.C0 == rest, "and the body goes back to rest after")

	-- A rig with the newer joints (AnimationConstraint instead of Motor6D).
	local rig = roblox.Instance.new("Model")
	rig.Name = "ConstraintRig"
	local function limb(name: string): any
		local p = roblox.Instance.new("Part")
		p.Name = name
		p.Parent = rig
		return p
	end
	local torso, arm = limb("UpperTorso"), limb("RightUpperArm")
	local a0 = roblox.Instance.new("Attachment")
	a0.Name = "RightShoulderRigAttachment"
	a0.Parent = torso
	local a1 = roblox.Instance.new("Attachment")
	a1.Name = "RightShoulderRigAttachment"
	a1.Parent = arm
	local joint = roblox.Instance.new("AnimationConstraint")
	joint.Name = "RightShoulder"
	joint.Attachment0 = a0
	joint.Attachment1 = a1
	joint.Parent = arm
	rig.Parent = H.unwrap(H.workspace)
	local wrappedRig = H.wrap(rig)
	local attachment = H.wrap(a0)
	local restAttachment = attachment.CFrame
	Effects.swing(wrappedRig, 0.4)
	task.wait(0.18)
	check(attachment.CFrame ~= restAttachment, "the dig animation also works on rigs with the newer joints")
	task.wait(0.4)
	check(attachment.CFrame == restAttachment, "and they go back to rest too")
	rig:Destroy()
end
task.wait(2.5) -- reveal + fly to bag
check(root.Bag.Value.Text:find("1/5") ~= nil, "bag counter ticked to 1 (" .. root.Bag.Value.Text .. ")")

print("\n== Shops, panels ==")
data.cash = 400
H.fireServer(player, "RequestSync")
-- The tutorial re-reads the data a few times a second: wait for it.
H.waitFor(function()
	return tutorialText():find("BAGS shop") ~= nil
end, 3, "tutorial bag step")
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
do
	-- The canyon wall west of the Jungle gate's ramp.
	local gate = MapLayout.gates.Jungle
	local canyon = nil
	for _, wall in H.workspace.Walls:GetChildren() do
		if
			wall:GetAttribute("OneWay")
			and wall:GetAttribute("InsideX") == -1
			and wall:GetAttribute("PlaneX") < gate.x
		then
			if math.abs(wall:GetAttribute("PlaneX") - gate.x) < 30 then
				canyon = wall
			end
		end
	end
	check(canyon ~= nil, "the canyon walls beside the gate ramps are one-way too")
	if canyon then
		local px, pz = canyon:GetAttribute("PlaneX"), canyon:GetAttribute("PlaneZ")
		H.moveTo(player, V3(px + 4, MapLayout.plateauHeight, pz))
		task.wait(0.3)
		check(canyon.CanCollide, "from the ramp you can't climb out sideways")
		H.moveTo(player, V3(px - 10, MapLayout.plateauHeight + 3, pz))
		task.wait(0.3)
		check(not canyon.CanCollide, "from the Jungle beside it you can jump down onto the ramp")
		H.moveTo(player, V3(px + 2, MapLayout.plateauHeight, pz))
		task.wait(0.3)
		check(not canyon.CanCollide, "and it stays open while you drop through")
	end
end
check(H.workspace.Base:FindFirstChild("VipRunway") ~= nil, "a red carpet leads to the VIP dig site")

print("\n== Island Guide ==")
check(H.workspace.Base:FindFirstChild("InfoBoard") ~= nil, "the wooden guide board stands at the base")
local boardGui = playerGui:FindFirstChild("EventsBoard")
check(boardGui ~= nil and boardGui:FindFirstChild("Event", true) ~= nil, "the board lists upcoming events")
H.signal(root.TopButtons.GuideButton, "Activated"):Fire({})
task.wait(0.2)
local guide = root:FindFirstChild("IslandGuide")
check(guide and guide.Visible, "the Guide button opens the island guide")
check(guide:FindFirstChild("IslandMap", true) ~= nil, "it shows the island map")
H.signal(guide:FindFirstChild("Events", true), "Activated"):Fire({})
task.wait(0.3)
local signUp = guide:FindFirstChild("SignUp", true)
check(signUp and signUp.Text == "SIGN UP", "events can be signed up for")
H.signal(signUp, "Activated"):Fire({})
task.wait(0.3)
check(#H.rsvps == 1 and H.rsvps[1] == "evt-1", "SIGN UP opens Roblox's RSVP for that event")
local signedUp = guide:FindFirstChild("SignUp", true)
check(signedUp and signedUp.Text:find("SIGNED UP") ~= nil, "and shows it's signed up")
H.signal(root.TopButtons.GuideButton, "Activated"):Fire({})
task.wait(0.1)

print("\n== Admin panel ==")
local adminButton = root.TopButtons:FindFirstChild("AdminButton")
check(adminButton ~= nil, "admins get the admin button")
if adminButton then
	H.signal(adminButton, "Activated"):Fire({})
	task.wait(0.2)
	local adminPanel = root:FindFirstChild("Admin")
	check(adminPanel and adminPanel.Visible, "it opens the admin panel")
	local cashBefore = data.cash
	H.signal(adminPanel:FindFirstChild("AddCash", true), "Activated"):Fire({})
	task.wait(0.3)
	check(data.cash > cashBefore, "an admin button gives cash")
	H.signal(adminPanel:FindFirstChild("Events", true), "Activated"):Fire({})
	H.signal(adminPanel:FindFirstChild("Abuse", true), "Activated"):Fire({})
	task.wait(1.2)
	local chips = root:FindFirstChild("Chips")
	local abuseChip = false
	for _, chip in chips:GetChildren() do
		abuseChip = abuseChip or (chip:IsA("TextLabel") and chip.Text:find("ADMIN ABUSE") ~= nil)
	end
	check(abuseChip, "ADMIN ABUSE shows a countdown chip")
	local Lighting = game:GetService("Lighting")
	local function partyParts(): number
		local n = 0
		for _, d in H.workspace:GetDescendants() do
			if d.Name == "DiscoBeam" or d.Name == "Confetti" then
				n += 1
			end
		end
		return n
	end
	check(
		Lighting:FindFirstChild("PartyTint") ~= nil and partyParts() > 0,
		"ADMIN ABUSE throws a party in the sky (" .. partyParts() .. " beams)"
	)
	H.fireServer(player, "AdminAction", "Abuse", nil, 0)
	task.wait(0.3)
	check(
		Lighting:FindFirstChild("PartyTint") == nil and partyParts() == 0,
		"the sky goes back to normal after"
	)
	H.signal(adminButton, "Activated"):Fire({})
	task.wait(0.1)
end

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

print("\n== Mega Dig ==")
do
	local MegaDigService = H.require(game:GetService("ServerScriptService").Server.Services.MegaDigService)
	local face = H.workspace.Base.MegaClock.ClockBox:FindFirstChildOfClass("SurfaceGui")
	local timeText = face and face.Dial.Time.Text
	check(
		timeText and timeText:match("^%d+:%d%d$") ~= nil,
		"the clock tower counts down (" .. tostring(timeText) .. ")"
	)
	check(
		root.MegaDig.Text:find("Mega Dig in") ~= nil,
		"the HUD shows the next Mega Dig (" .. root.MegaDig.Text .. ")"
	)
	local here = player.Character.HumanoidRootPart.Position
	check(MegaDigService.start(here + V3(12, 0, 0)), "an admin can open a site anywhere")
	task.wait(0.5)
	check(face.Dial.Title.Text == "DIG NOW!", "the clock says DIG NOW!")
	check(
		root.MegaDig.Text:find("MEGA DIG NOW") ~= nil,
		"the HUD shows the open site (" .. root.MegaDig.Text .. ")"
	)
	local sign = playerGui:FindFirstChild("MegaDigSign")
	check(sign ~= nil, "a progress sign floats over the site")
	check(sign and not sign.Enabled, "it hides while you dig there (the HUD shows the progress)")
	check(digButton.Visible, "DIG works from the edge of the big site")
	local site
	for _, spot in spots:GetChildren() do
		if spot:GetAttribute("Mega") then
			site = spot
		end
	end
	local id = site:GetAttribute("SpotId")
	local megaPanel = root:FindFirstChild("MegaDigPanel")
	check(megaPanel and megaPanel.Visible, "the Mega Dig panel shows at the top of the screen")
	for _ = 1, 5 do
		H.clockOffset += 1
		H.fireServer(player, "DigHit", id)
	end
	task.wait(0.5)
	local info = megaPanel.Info.Text
	check(info:find("your hits: 5") ~= nil, "it shows your hits and win chance (" .. info .. ")")
	check(megaPanel.Percent.Text ~= "0%", "and the progress (" .. megaPanel.Percent.Text .. ")")
	local searchlights = 0
	for _, d in H.workspace:GetDescendants() do
		searchlights += if d.Name == "Searchlight" then 1 else 0
	end
	check(searchlights == 4, "a party at the site: searchlights sweep the sky (" .. searchlights .. ")")
	local inAir = {}
	for _, d in H.workspace:GetDescendants() do
		inAir[d.Name] = (inAir[d.Name] or 0) + 1
	end
	check(
		inAir.DiscoBall == 1 and (inAir.DiscoRay or 0) == 8 and (inAir.SkyOrb or 0) == 10,
		"lights up in the air: a disco ball with its rays, and glowing orbs"
	)
	local Audio = H.require(clientScript.Controllers.AudioController)
	check(
		Audio.currentMusic() == "MegaDig",
		"the diggers get the Mega Dig party music (" .. Audio.currentMusic() .. ")"
	)
	local site0 = nil
	for _, spot in spots:GetChildren() do
		if spot:GetAttribute("Mega") then
			site0 = spot
		end
	end
	check(site0 and site0:FindFirstChild("Bunting") ~= nil, "and bunting hangs on the fence")
	for _ = 1, 2000 do
		H.clockOffset += 1
		H.fireServer(player, "DigHit", id)
		if not MegaDigService.isActive() then
			break
		end
	end
	task.wait(0.4)
	check(not megaPanel.Visible, "the panel makes way for the draw")
	local drawFrame = root:FindFirstChild("MegaDraw")
	check(drawFrame ~= nil, "the winner draw spins on screen")
	task.wait(H.require(Shared.Config.MegaDig).drawSeconds + 0.5)
	check(
		drawFrame and drawFrame.Parent == nil and root:FindFirstChild("MegaDraw") == nil,
		"for the winner the draw clears away so the treasure reveal is in view"
	)
end

print("\n== Admin: messages and reset ==")
do
	H.signal(adminButton, "Activated"):Fire({})
	task.wait(0.2)
	local adminPanel = root:FindFirstChild("Admin")
	H.signal(adminPanel:FindFirstChild("Events", true), "Activated"):Fire({})
	local box = adminPanel:FindFirstChild("GlobalMessageText", true)
	check(box ~= nil, "the Events tab has a box for messages to every server")
	box.Text = "Mega Dig in 5 minutes, see you there!"
	H.signal(box.Parent:FindFirstChild("Send"), "Activated"):Fire({})
	task.wait(1.5)
	local bubble = root:FindFirstChild("GlobalMessage")
	check(bubble ~= nil, "the message drops in at the top of the screen")
	if bubble then
		check(bubble.Avatar.Image:find(tostring(player.UserId)) ~= nil, "with the admin's avatar")
		check(
			bubble.Bubble.Text.Text == "Mega Dig in 5 minutes, see you there!",
			"in a speech bubble (" .. bubble.Bubble.Text.Text .. ")"
		)
	end
	H.signal(adminPanel:FindFirstChild("Player", true), "Activated"):Fire({})
	local reset = adminPanel:FindFirstChild("MyResetProgress", true)
	check(reset ~= nil, "the Player tab has RESET MY PROGRESS")
	data.rebirths = 0
	data.onboarding.guideDone = true
	data.shovelLevel = 3
	H.signal(reset, "Activated"):Fire({})
	task.wait(0.3)
	check(data.shovelLevel == 3 and reset.Text == "TAP AGAIN!", "the first tap only asks to tap again")
	H.signal(reset, "Activated"):Fire({})
	task.wait(0.8)
	check(data.shovelLevel == 1 and data.onboarding.guideDone == false, "the second tap resets your progress")
	check(player:GetAttribute("Pass_AutoDig") == true, "your purchases stay")
	H.signal(adminButton, "Activated"):Fire({})
	task.wait(0.8)
	check(root.Tutorial.Visible, "the tutorial starts over right away")
end

print("\n== Frost Portal ==")
do
	local portalModel = H.workspace:FindFirstChild("FrostPortal")
	local function litSeals(): number
		local n = 0
		for _, child in portalModel:GetChildren() do
			if child:GetAttribute("Seal") and child.Material == roblox.Enum.Material.Neon then
				n += 1
			end
		end
		return n
	end
	data.rebirths = 1
	H.fireServer(player, "RequestSync")
	task.wait(0.4)
	check(litSeals() == 1, "one seal lit at Rebirth 1 (" .. litSeals() .. ")")
	local sign =
		portalModel:FindFirstChild("SignBoardSmall", true):FindFirstChildOfClass("SurfaceGui").TextLabel
	check(sign.Text:find("You: 1/3") ~= nil, "the sign shows your progress (" .. sign.Text .. ")")
	check(portalModel.IceSheet.Transparency < 1, "a sheet of ice seals the portal until Rebirth 3")
	data.rebirths = 3
	H.fireServer(player, "RequestSync")
	task.wait(0.6)
	check(litSeals() == 3 and sign.Text:find("OPEN") ~= nil, "all three seals light at Rebirth 3")
	check(
		portalModel.IceSheet.Transparency == 1 and portalModel.PortalCore.SnowWind.Enabled,
		"the ice is gone and snow blows out of the open portal"
	)
	-- Open: stepping in starts the trip to Frostbite Peaks.
	local Worlds = H.require(game:GetService("ReplicatedStorage").Shared.Config.Worlds)
	H.clockOffset += 10
	H.moveTo(player, portalModel:GetAttribute("Center"))
	task.wait(0.6)
	local fade = root:FindFirstChild("PortalFade")
	check(
		fade ~= nil and H.teleports[#H.teleports] ~= nil,
		"stepping in starts the trip (the screen fades to white)"
	)
	-- Closed: the 'being built' window with the launch sign-up.
	Worlds.next.open = false
	H.clockOffset += 10
	H.moveTo(player, portalModel:GetAttribute("Center"))
	task.wait(0.6)
	Worlds.next.open = true
	local soon = root:FindFirstChild("WorldPortal")
	check(soon and soon.Visible, "while it's closed, stepping in shows the 'being built' window")
	H.signal(soon:FindFirstChild("Notify", true), "Activated"):Fire({})
	task.wait(0.3)
	check(not soon.Visible and root.IslandGuide.Visible, "GET NOTIFIED opens the events sign-up")
	H.signal(root.TopButtons.GuideButton, "Activated"):Fire({})
end

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
