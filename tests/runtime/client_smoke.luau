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
	if spot:GetAttribute("AreaId") == "Beach" then
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
H.signal(digButton, "InputBegan"):Fire(finger)
H.waitFor(function()
	return data.stats.finds >= 1
end, 6, "first find via the DIG button")
check(data.stats.finds >= 1, "holding DIG dug the spot out")
task.wait(2.5) -- reveal + fly to bag
local UserInputService = H.wrap(H.unwrap(game:GetService("UserInputService")))
H.signal(UserInputService, "InputEnded"):Fire(finger)
check(root.Bag.Value.Text:find("1/10") ~= nil, "bag counter ticked to 1 (" .. root.Bag.Value.Text .. ")")

print("\n== Shops, panels ==")
data.cash = 400
H.fireServer(player, "RequestSync")
task.wait(0.2)
local deckTop = MapLayout.beachHeight + MapLayout.base.deckHeight
H.moveTo(player, V3(MapLayout.shovelStation.x, deckTop, MapLayout.shovelStation.z))
task.wait(0.5)
local upgradePanel = root:FindFirstChild("UpgradePanel")
check(upgradePanel and upgradePanel.Visible, "shovel shop panel opens on the pad")
H.signal(upgradePanel.Buy, "Activated"):Fire({ UserInputType = roblox.Enum.UserInputType.Touch })
task.wait(0.3)
check(data.shovelLevel == 2, "BUY button bought the Stone Shovel")

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

H.moveTo(player, V3(MapLayout.rebirthAltar.x, MapLayout.beachHeight, MapLayout.rebirthAltar.z))
task.wait(0.5)
check(root:FindFirstChild("RebirthPanel") and root.RebirthPanel.Visible, "rebirth panel opens at the altar")

print("\n== Sell ==")
H.moveTo(player, V3(MapLayout.sellPad.x, deckTop, MapLayout.sellPad.z))
H.waitFor(function()
	return #data.bagContents == 0
end, 2, "sell")
task.wait(1.5)
check(#data.bagContents == 0, "sold at the pad")

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
