-- Frostbite Peaks smoke test: boots the built place as a reserved server
-- (which makes it a Frostbite Peaks server) and plays a traveller's visit
-- against the real server code. Usage:
--   rojo build default.project.json -o build.rbxl
--   lune run tests/runtime/frost_smoke.luau build.rbxl

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

-- A traveller arriving from the island: their profile has the island run
-- (rebirth 3, top shovel) and an earlier Frostbite Peaks run.
local STORE = "DigForCash_Profiles_v1"
local USER = 7001
H.stores[STORE] = {
	["Player_" .. USER] = {
		data = {
			schemaVersion = 2,
			cash = 5000,
			shovelLevel = 8,
			bagLevel = 8,
			bagContents = { { id = "Pearl", v = 150 } },
			rebirths = 3,
			discovered = { Pearl = { normal = true } },
			worldUnlocks = { Frost = 1 },
			worldSaves = { Frost = { cash = 777, shovelLevel = 2, bagLevel = 1, bagContents = {} } },
			onboarding = { guideDone = true, firstRareFound = true, firstEpicFound = true },
		},
	},
}
H.joinData[USER] = { world = "Frost", code = "code-frost" }

---------------------------------------------------------------------------
print("\n== Frost server start ==")
H.privateServerId = "frost-server-1"
H.runScript(game:GetService("ServerScriptService").Server)
local workspace = H.workspace
do
	local MegaDigService = H.require(game:GetService("ServerScriptService").Server.Services.MegaDigService)
	MegaDigService.setScheduled(false)
	MegaDigService.cancel()
end

local Shared = game:GetService("ReplicatedStorage").Shared
local Services = game:GetService("ServerScriptService").Server.Services
local PlayerData = H.require(Services.PlayerData)
local Areas = H.require(Shared.Config.Areas)
local Treasures = H.require(Shared.Config.Treasures)
local Upgrades = H.require(Shared.Config.Upgrades)
local MapLayout = H.require(Shared.Config.MapLayout)

check(workspace:GetAttribute("WorldId") == "Frost", "a reserved server is Frostbite Peaks")
check(Upgrades.Shovels[1].name == "Frostbite Shovel", "with its own shovels")
check(Upgrades.Bags[1].name == "Fur Pouch", "and bags")
check(Areas.Defs.Beach.displayName == "Frost Shore", "the beach is the Frost Shore")
local frostOnly = #Treasures.List > 0
for _, def in Treasures.List do
	frostOnly = frostOnly and def.world == "Frost"
end
check(frostOnly, "only frost treasures drop here")

-- Same layout, frost biomes.
local _, beachMaterial = H.terrainTop(MapLayout.spawn.x - 60, MapLayout.spawn.z + 40, 500)
check(tostring(beachMaterial):find("Snow") ~= nil, "the beach is snow (" .. tostring(beachMaterial) .. ")")
local pines, palms = 0, 0
for _, item in workspace:GetDescendants() do
	if item.Name == "Pine" then
		pines += 1
	elseif item.Name == "Palm" then
		palms += 1
	end
end
check(pines > 20 and palms == 0, string.format("palms grow as snowy pines (%d)", pines))
local base = workspace:FindFirstChild("Base")
check(base ~= nil and base:FindFirstChild("SellPad") ~= nil, "the base is built at the same place")
local snowyBase = false
for _, item in base:GetDescendants() do
	-- (The shovel shop's display shovel is this world's: it may be snowy.)
	local display = item:FindFirstAncestor("Shovel") ~= nil
	if item:IsA("BasePart") and not display and item.Material == roblox.Enum.Material.Snow then
		snowyBase = true
		print("  snowy base part: " .. item:GetFullName())
	end
end
check(not snowyBase, "the base buildings are the island's (not dressed in snow)")
local sign = workspace:FindFirstChild("FrostPortal")
	and workspace.FrostPortal:FindFirstChild("StandingSign", true)
local signText = ""
if sign then
	for _, label in sign:GetDescendants() do
		if label:IsA("TextLabel") then
			signText ..= label.Text .. " "
		end
	end
end
check(signText:find("ISLAND") ~= nil, "the portal here leads back to the island (" .. signText .. ")")

---------------------------------------------------------------------------
print("\n== A traveller arrives ==")
local player = H.addPlayer("Traveller", USER)
H.waitFor(function()
	return PlayerData.get(player) ~= nil and player.Character ~= nil
end, 5, "profile + character")
local data = PlayerData.get(player)
check(data and data.cash == 777 and data.shovelLevel == 2, "their Frostbite Peaks run is loaded")
check(data and #data.bagContents == 0, "with its own (empty) bag")
check(data and data.rebirths == 3, "rebirths are shared")
check(data and data.discovered.Pearl ~= nil, "and so is the collection")
H.waitFor(function()
	return H.memory["WorldServers_Frost"] and H.memory["WorldServers_Frost"]["frost-server-1"] ~= nil
end, 2, "server listing")
local listed = H.memory["WorldServers_Frost"] and H.memory["WorldServers_Frost"]["frost-server-1"]
check(
	listed and listed.code == "code-frost" and listed.players == 1,
	"the server lists itself for travellers (" .. tostring(listed and listed.players) .. " player)"
)

-- Dig on the Frost Shore.
local spot = nil
for _, s in workspace.DigSpots:GetChildren() do
	if s:GetAttribute("AreaId") == "Beach" and not s:GetAttribute("Vip") then
		spot = s
		break
	end
end
local find = nil
if spot then
	local id = spot:GetAttribute("SpotId")
	H.moveTo(player, spot.PrimaryPart.Position + V3(2, 0, 0))
	for _ = 1, 12 do
		H.clockOffset += 1
		H.fireServer(player, "DigHit", id)
		task.wait()
		local result = H.lastClientEvent("DigResult", player)
		if result and result[1].spotId == id and result[1].done then
			find = result[1].find
			break
		end
	end
end
check(
	find and string.sub(find.id, 1, 5) == "Frost",
	"digging finds frost treasures (" .. tostring(find and find.id) .. ")"
)

-- Saving keeps the island run apart.
data.cash = 1234
check(PlayerData.saveNow(player), "the profile saves")
local stored = H.stores[STORE]["Player_" .. USER].data
check(stored.cash == 5000 and stored.shovelLevel == 8, "the island run is stored untouched")
check(stored.bagContents[1] and stored.bagContents[1].id == "Pearl", "with the island bag")
local frostRun = stored.worldSaves and stored.worldSaves.Frost
check(
	frostRun and frostRun.cash == 1234 and frostRun.shovelLevel == 2,
	"and the Frostbite Peaks run beside it"
)
check(frostRun and #frostRun.bagContents == 1, "including what's in the frost bag")
check(stored.worldSaves.Island == nil, "nothing extra is stored")

-- No rebirths here.
H.fireServer(player, "Rebirth")
task.wait(0.1)
local notified = false
for _, args in H.clientEvents("Notify", player) do
	notified = notified or tostring(args[1]):find("island") ~= nil
end
check(notified and data.rebirths == 3, "rebirths happen on the island")

-- The portal takes you home.
local portal = workspace.FrostPortal:GetAttribute("Center")
local before = #H.teleports
H.moveTo(player, portal)
task.wait(0.5)
local trip = H.teleports[#H.teleports]
check(
	#H.teleports > before
		and trip.placeId == H.placeId
		and (trip.code or "") == ""
		and trip.data.world == "Island",
	"the portal takes you back to the island"
)

---------------------------------------------------------------------------
print("\n== The traveller's client ==")
do
	local gui = roblox.Instance.new("PlayerGui")
	gui.Parent = H.unwrap(player)
	local playerGui = H.wrap(gui)
	H.isClient = true
	H.localPlayer = player
	H.onFireServer = function(remote: string, ...)
		H.fireServer(player, remote, ...)
	end
	local running = true
	task.spawn(function()
		local RunService = game:GetService("RunService")
		while running do
			local dt = task.wait(1 / 30)
			H.signal(H.wrap(RunService), "RenderStepped"):Fire(dt)
			H.signal(H.wrap(RunService), "Heartbeat"):Fire(dt)
		end
	end)
	H.runScript(game:GetService("StarterPlayer").StarterPlayerScripts.Client)
	task.wait(0.5)
	local hud = playerGui:FindFirstChild("Hud")
	local root = hud and hud:FindFirstChild("Root")
	local cashText = root and root.Cash.Value.Text or ""
	check(cashText:find("1") ~= nil, "the HUD shows the Frostbite Peaks cash (" .. cashText .. ")")
	check(workspace:FindFirstChild("Snowfall") ~= nil, "snow falls")
	local small = workspace.FrostPortal:FindFirstChild("SignBoardSmall", true)
	local label = small and small:FindFirstChildOfClass("SurfaceGui")
	local text = label
		and label:FindFirstChildOfClass("TextLabel")
		and label:FindFirstChildOfClass("TextLabel").Text
	check(text and text:find("back") ~= nil, "the portal sign points home (" .. tostring(text) .. ")")
	check(workspace.FrostPortal.IceSheet.Transparency == 1, "and the way home is open")
	running = false
	task.wait(0.1)
end

player:Kick("done")
task.wait(0.3)
local after = H.stores[STORE]["Player_" .. USER]
check(after.lock == nil and after.data.cash == 5000, "leaving saves and releases the profile")

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
