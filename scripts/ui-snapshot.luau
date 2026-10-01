-- Exports the real HUD and menus as JSON for scripts/preview/render-ui.mjs.
-- Boots the server and the client headless (like the client smoke test),
-- walks a new player through a few moments and opens every menu.
-- Usage: lune run scripts/ui-snapshot.luau build.rbxl out.json

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local H = require("../tests/runtime/Harness")
H.experienceEvents = {
	{
		Id = "evt-1",
		Title = "Admin Abuse Hour",
		DisplayTitle = "Admin Abuse Hour",
		StartTime = { Year = 2026, Month = 10, Day = 10, Hour = 18, Minute = 0, Second = 0 },
		HasStarted = false,
		HasEnded = false,
		UserRsvpStatus = "None",
	},
	{
		Id = "evt-2",
		Title = "Double Treasure Weekend",
		DisplayTitle = "Double Treasure Weekend",
		StartTime = { Year = 2026, Month = 10, Day = 17, Hour = 16, Minute = 0, Second = 0 },
		HasStarted = false,
		HasEnded = false,
		UserRsvpStatus = "Going",
	},
}

local game = H.load(process.args[1] or "build.rbxl")
local V3 = roblox.Vector3.new

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

table.insert(H.require(Shared.Config.Admin).userIds, 7001)
local player = H.addPlayer("Kid", 7001)
local playerGui
do
	local gui = roblox.Instance.new("PlayerGui")
	gui.Parent = H.unwrap(player)
	playerGui = H.wrap(gui)
end
H.waitFor(function()
	return PlayerData.get(player) ~= nil and player.Character ~= nil
end, 5, "server profile")
local data = PlayerData.get(player)

H.isClient = true
H.localPlayer = player
H.onFireServer = function(remote: string, ...)
	H.fireServer(player, remote, ...)
end
local running = true
task.spawn(function()
	local RunService = H.unwrap(game:GetService("RunService"))
	while running do
		local dt = task.wait(1 / 30)
		H.signal(H.wrap(RunService), "RenderStepped"):Fire(dt)
		H.signal(H.wrap(RunService), "Heartbeat"):Fire(dt)
	end
end)
H.runScript(game:GetService("StarterPlayer").StarterPlayerScripts.Client)
task.wait(0.5)

---------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------

local function get(inst: any, prop: string): any
	local ok, value = pcall(function()
		return inst[prop]
	end)
	return if ok then value else nil
end

local function udim2(v: any): { number }?
	if not v then
		return nil
	end
	return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
end
local function udim(v: any): { number }?
	return if v then { v.Scale, v.Offset } else nil
end
local function color(v: any): { number }?
	return if v then { v.R, v.G, v.B } else nil
end
local function enum(v: any): string?
	return if v then v.Name else nil
end
local function vec2(v: any): { number }?
	return if v then { v.X, v.Y } else nil
end

local GUI = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
	ViewportFrame = true,
	CanvasGroup = true,
}

local function serialize(inst: any): { [string]: any }?
	local class = inst.ClassName
	local node: { [string]: any } = { class = class, name = inst.Name }
	if GUI[class] then
		node.visible = get(inst, "Visible") ~= false
		node.position = udim2(get(inst, "Position"))
		node.size = udim2(get(inst, "Size"))
		node.anchor = vec2(get(inst, "AnchorPoint"))
		node.bg = color(get(inst, "BackgroundColor3"))
		node.bgT = get(inst, "BackgroundTransparency")
		node.z = get(inst, "ZIndex")
		node.order = get(inst, "LayoutOrder")
		node.autoSize = enum(get(inst, "AutomaticSize"))
		node.clips = get(inst, "ClipsDescendants")
		node.rotation = get(inst, "Rotation")
		if class == "TextLabel" or class == "TextButton" then
			node.text = get(inst, "Text")
			node.textColor = color(get(inst, "TextColor3"))
			node.textScaled = get(inst, "TextScaled")
			node.textSize = get(inst, "TextSize")
			node.font = enum(get(inst, "Font"))
			node.xAlign = enum(get(inst, "TextXAlignment"))
			node.yAlign = enum(get(inst, "TextYAlignment"))
			node.wrapped = get(inst, "TextWrapped")
			node.textT = get(inst, "TextTransparency")
			node.lineHeight = get(inst, "LineHeight")
		end
		if class == "ViewportFrame" then
			node.imageColor = color(get(inst, "ImageColor3"))
		end
		if class == "ScrollingFrame" then
			node.clips = true
		end
	elseif class == "UICorner" then
		node.radius = udim(get(inst, "CornerRadius"))
	elseif class == "UIStroke" then
		node.thickness = get(inst, "Thickness")
		node.color = color(get(inst, "Color"))
		node.transparency = get(inst, "Transparency")
		node.mode = enum(get(inst, "ApplyStrokeMode"))
	elseif class == "UIGradient" then
		local seq = get(inst, "Color")
		local keys = {}
		if seq then
			for _, k in seq.Keypoints do
				table.insert(keys, { k.Time, k.Value.R, k.Value.G, k.Value.B })
			end
		end
		node.keys = keys
		node.rotation = get(inst, "Rotation")
	elseif class == "UIPadding" then
		node.padding = {
			udim(get(inst, "PaddingTop")),
			udim(get(inst, "PaddingRight")),
			udim(get(inst, "PaddingBottom")),
			udim(get(inst, "PaddingLeft")),
		}
	elseif class == "UIListLayout" then
		node.direction = enum(get(inst, "FillDirection"))
		node.padding = udim(get(inst, "Padding"))
		node.hAlign = enum(get(inst, "HorizontalAlignment"))
		node.vAlign = enum(get(inst, "VerticalAlignment"))
	elseif class == "UIGridLayout" then
		node.cellSize = udim2(get(inst, "CellSize"))
		node.cellPadding = udim2(get(inst, "CellPadding"))
		node.hAlign = enum(get(inst, "HorizontalAlignment"))
	elseif class == "UITextSizeConstraint" then
		node.maxTextSize = get(inst, "MaxTextSize")
	elseif class == "UIScale" then
		node.scale = get(inst, "Scale")
	elseif class == "UISizeConstraint" then
		node.maxSize = vec2(get(inst, "MaxSize"))
		node.minSize = vec2(get(inst, "MinSize"))
	elseif class == "ScreenGui" then
		node.ignoreInset = get(inst, "IgnoreGuiInset")
	else
		return nil
	end
	local children = {}
	for _, child in inst:GetChildren() do
		local c = serialize(child)
		if c then
			table.insert(children, c)
		end
	end
	node.children = children
	return node
end

local scenes = {}
local function snap(name: string)
	task.wait(0.6)
	local hud = H.unwrap(playerGui):FindFirstChild("Hud")
	scenes[name] = serialize(hud)
	print("snapshot " .. name)
end

local hud = playerGui:FindFirstChild("Hud")
local root = hud:FindFirstChild("Root")

snap("hud")

-- Walk up to the nearest beach spot: the DIG button and the DIG step.
local nearest, best = nil, math.huge
local spawnPos = player.Character.HumanoidRootPart.Position
for _, spot in H.workspace.DigSpots:GetChildren() do
	if spot:GetAttribute("AreaId") == "Beach" and not spot:GetAttribute("Vip") then
		local d = (spot.PrimaryPart.Position - spawnPos).Magnitude
		if d < best then
			nearest, best = spot, d
		end
	end
end
H.moveTo(player, nearest.PrimaryPart.Position + V3(2, 0, 0))
snap("dig")

-- Some cash: the shop and the upgrade step.
data.cash = 400
H.fireServer(player, "RequestSync")
local deck = H.workspace.Base:FindFirstChild("Deck")
local deckTop = deck.Position.Y + deck.Size.Y / 2
H.moveTo(player, V3(MapLayout.shovelStation.x, deckTop, MapLayout.shovelStation.z))
snap("shop")
H.moveTo(player, V3(MapLayout.spawn.x, deckTop, MapLayout.spawn.z))
task.wait(0.4)

for _, entry in
	{ { "CollectionButton", "collection" }, { "DailyButton", "daily" }, { "TopButton", "leaderboards" } }
do
	H.signal(root.TopButtons:FindFirstChild(entry[1]), "Activated"):Fire({})
	snap(entry[2])
end
H.signal(root.TopButtons:FindFirstChild("TopButton"), "Activated"):Fire({})

H.moveTo(player, H.workspace.Base:FindFirstChild("RebirthPad").Position)
snap("rebirth")
H.moveTo(player, V3(MapLayout.spawn.x, deckTop, MapLayout.spawn.z))
task.wait(0.4)

H.signal(root.TopButtons:FindFirstChild("SettingsButton"), "Activated"):Fire({})
snap("settings")
H.signal(root.TopButtons:FindFirstChild("SettingsButton"), "Activated"):Fire({})
H.signal(root.TopButtons:FindFirstChild("GuideButton"), "Activated"):Fire({})
snap("guide_map")
H.signal(root.IslandGuide:FindFirstChild("HowTo", true), "Activated"):Fire({})
snap("guide_howto")
H.signal(root.IslandGuide:FindFirstChild("Events", true), "Activated"):Fire({})
snap("guide_events")
H.signal(root.TopButtons:FindFirstChild("GuideButton"), "Activated"):Fire({})
H.signal(root.TopButtons:FindFirstChild("AdminButton"), "Activated"):Fire({})
snap("admin_player")
H.signal(root.Admin:FindFirstChild("Events", true), "Activated"):Fire({})
snap("admin_events")
H.signal(root.Admin:FindFirstChild("World", true), "Activated"):Fire({})
snap("admin_world")
H.signal(root.TopButtons:FindFirstChild("AdminButton"), "Activated"):Fire({})
-- A message to every server: the admin's speech bubble.
H.fireServer(
	player,
	"AdminAction",
	"GlobalMessage",
	nil,
	"ADMIN ABUSE starts in 5 minutes! Get to the beach!"
)
task.wait(1.6)
snap("message")
task.wait(7)

-- The Auto Dig offer: a player without the pass holds DIG.
data.onboarding.guideDone = true
H.fireServer(player, "RequestSync")
H.moveTo(player, nearest.PrimaryPart.Position + V3(2, 0, 0))
task.wait(0.4)
local finger = { UserInputType = roblox.Enum.UserInputType.Touch, KeyCode = roblox.Enum.KeyCode.Unknown }
H.signal(root.DigButton, "InputBegan"):Fire(finger)
task.wait(1)
snap("autodig")
local UserInputService = H.wrap(H.unwrap(game:GetService("UserInputService")))
H.signal(UserInputService, "InputEnded"):Fire(finger)

-- The shop, on each tab (as a player who owns Auto Dig and Auto Sell).
data.passes.AutoDig = true
data.passes.AutoSell = true
data.ownedCosmetics.Pirate = true
data.equippedSkin = "Pirate"
H.fireServer(player, "RequestSync")
task.wait(0.3)
H.signal(root.ShopButton, "Activated"):Fire({})
snap("shop_passes")
for _, tab in { "Boosts", "Cash", "Skins" } do
	H.signal(root.Shop:FindFirstChild(tab, true), "Activated"):Fire({})
	snap("shop_" .. string.lower(tab))
end
H.signal(root.ShopButton, "Activated"):Fire({})
-- The Tiki Bar menu, with one drink running.
data.cash = 9000
data.activeBoosts.SpeedSoda = os.time() + 200
H.fireServer(player, "RequestSync")
H.moveTo(player, H.workspace.Decor:FindFirstChild("TikiPad", true).Position + V3(0, 0.5, 0))
task.wait(0.6)
snap("tiki")
H.moveTo(player, V3(MapLayout.spawn.x, deckTop, MapLayout.spawn.z))
task.wait(0.5)
table.insert(data.bagContents, { id = "Shell", v = 12 })
H.fireServer(player, "RequestSync")
snap("hud_owner")

-- The Mega Dig: an open site, then the winner draw.
local MegaDigService = H.require(game:GetService("ServerScriptService").Server.Services.MegaDigService)
local here = player.Character.HumanoidRootPart.Position
MegaDigService.start(here + V3(10, 0, 0))
task.wait(0.4)
snap("megadig")
local site
for _, spot in H.workspace.DigSpots:GetChildren() do
	if spot:GetAttribute("Mega") then
		site = spot
	end
end
for _ = 1, 2000 do
	H.clockOffset += 1
	H.fireServer(player, "DigHit", site:GetAttribute("SpotId"))
	if not MegaDigService.isActive() then
		break
	end
end
task.wait(5.6)
snap("megadraw")

-- The Frost Portal at Rebirth 3: the "being built" window.
task.wait(3)
data.rebirths = 3
H.fireServer(player, "RequestSync")
task.wait(4)
H.clockOffset += 10
H.moveTo(player, H.workspace.FrostPortal:GetAttribute("Center"))
task.wait(0.8)
snap("portal")

running = false
fs.writeFile(process.args[2] or "ui.json", serde.encode("json", scenes))
print("wrote UI snapshots")
process.exit(0)
