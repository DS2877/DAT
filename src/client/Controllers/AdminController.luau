--!strict
-- The 🛠️ admin panel (only for admins: the server sets the "Admin"
-- attribute and checks every action again). Tabs:
--   PLAYER  reset your own progress (to test the game as a new player);
--           cash, shovel, bag, rebirths, passes, boosts, treasures, resets,
--           teleport to / bring / kick (for the selected player)
--   WORLD   teleports, time of day, your own speed and jump, and spawning
--           things where you stand (treasure spots, money rain, fireworks,
--           a Mega Dig)
--   EVENTS  Treasure Rush, server 2x Cash, ADMIN ABUSE, hidden treasures,
--           announcements, messages to every server
--   INFO    uptime, players, hidden treasures right now

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors
local player = Players.LocalPlayer

local AdminController = {}

local panel: Frame
local remote: RemoteEvent
local pages: { [string]: ScrollingFrame } = {}
local tabs: { [string]: TextButton } = {}
local targetRow: Frame
local targetId: number = player.UserId
local infoLabel: TextLabel

-- Actions that need a second tap.
local CONFIRM = { ResetProgress = true, ResetAll = true, Kick = true }

local function sendFor(target: number, action: string, ...: any)
	Sound.play("UiClick")
	remote:FireServer(action, target, ...)
end

local function send(action: string, ...: any)
	sendFor(targetId, action, ...)
end

local function selectTab(name: string)
	for key, page in pages do
		page.Visible = key == name
	end
	for key, button in tabs do
		Ui.setButtonColor(button, if key == name then C.Red else Color3.fromRGB(205, 170, 120))
	end
	if name == "Info" then
		remote:FireServer("Info")
	end
end

local function refreshTargets()
	for _, child in targetRow:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i, other in Players:GetPlayers() do
		local selected = other.UserId == targetId
		local button = Ui.button({
			LayoutOrder = if other == player then 0 else i,
			Size = UDim2.fromOffset(170, 40),
			Text = if other == player then "ME" else other.DisplayName,
			Parent = targetRow,
		}, if selected then C.Red else C.Grey)
		button.Activated:Connect(function()
			targetId = other.UserId
			refreshTargets()
		end)
	end
end

-- A titled group of buttons in a page. opts.self: the buttons act on you
-- (not the selected player); opts.prefix: added to the button names;
-- opts.cell: bigger buttons.
local function section(
	page: ScrollingFrame,
	order: number,
	title: string,
	buttons: { { any } },
	opts: { self: boolean?, prefix: string?, cell: UDim2? }?
)
	local o = opts or {}
	Ui.plainLabel({
		LayoutOrder = order * 2,
		Size = UDim2.new(1, 0, 0, 30),
		Font = Ui.TitleFont,
		Text = title,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = page,
	})
	local grid = Ui.new("Frame", {
		LayoutOrder = order * 2 + 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = page,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = o.cell or UDim2.fromOffset(160, 44),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, b in buttons do
		local button = Ui.button({
			Name = (o.prefix or "") .. b[2],
			LayoutOrder = i,
			Text = b[1],
			Parent = grid,
		}, b[3] or C.Blue)
		local args = table.move(b, 4, #b, 1, {})
		local armedUntil = 0
		button.Activated:Connect(function()
			if CONFIRM[b[2]] and os.clock() > armedUntil then
				-- First tap arms it; a second tap within 3 seconds does it.
				armedUntil = os.clock() + 3
				button.Text = "TAP AGAIN!"
				Sound.play("Denied")
				task.delay(3, function()
					button.Text = b[1]
				end)
				return
			end
			armedUntil = 0
			button.Text = b[1]
			sendFor(if o.self then player.UserId else targetId, b[2], table.unpack(args))
		end)
	end
end

local function page(name: string): ScrollingFrame
	local p = Ui.new("ScrollingFrame", {
		Name = name .. "Page",
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 1, -104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = panel:FindFirstChild("Body", true),
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	pages[name] = p
	return p
end

-- A text box with a send button (announcements, messages).
local function textRow(page: ScrollingFrame, order: number, title: string, action: string, color: Color3)
	Ui.plainLabel({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 30),
		Font = Ui.TitleFont,
		Text = title,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = page,
	})
	local row = Ui.new("Frame", {
		Name = action .. "Row",
		LayoutOrder = order + 1,
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent = page,
	})
	local box = Ui.new("TextBox", {
		Name = action .. "Text",
		Size = UDim2.new(1, -150, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Ui.Font,
		PlaceholderText = "Type a message...",
		Text = "",
		TextSize = 22,
		TextColor3 = C.Ink,
		ClearTextOnFocus = false,
		Parent = row,
	}, { Ui.corner(UDim.new(0, 12)), Ui.stroke(3) })
	local sendButton = Ui.button({
		Name = "Send",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 140, 1, 0),
		Text = "SEND",
		Parent = row,
	}, color)
	sendButton.Activated:Connect(function()
		if box.Text ~= "" then
			send(action, box.Text)
			box.Text = ""
		end
	end)
end

local function build()
	local p = Ui.panel({
		name = "Admin",
		title = "ADMIN",
		icon = "🛠️",
		accent = C.Red,
		width = 900,
		height = 620,
		parent = HudController.root(),
		dim = true,
	})
	panel = p.root
	HudController.registerModal(panel)

	local tabRow = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Parent = p.body,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, name in { "Player", "World", "Events", "Info" } do
		local button = Ui.button({
			Name = name,
			LayoutOrder = i,
			Size = UDim2.fromOffset(150, 46),
			Text = string.upper(name),
			Parent = tabRow,
		}, C.Red)
		button.Activated:Connect(function()
			Sound.play("UiClick")
			selectTab(name)
		end)
		tabs[name] = button
	end
	targetRow = Ui.new("Frame", {
		Name = "Targets",
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		Parent = p.body,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- PLAYER (acts on the selected player; the first row on you).
	local playerPage = page("Player")
	section(playerPage, 0, "🧪 TEST THE GAME AS A NEW PLAYER (you)", {
		{ "RESET MY PROGRESS", "ResetProgress", C.Red },
		{ "BRAND NEW ME", "ResetAll", C.Red },
	}, { self = true, prefix = "My", cell = UDim2.fromOffset(280, 54) })
	Ui.plainLabel({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 24),
		TextScaled = false,
		TextSize = 18,
		Text = "Progress: a new player, keeping Robux purchases. Brand new: removes test passes too. Tap twice.",
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = playerPage,
	})
	section(playerPage, 1, "💰 CASH", {
		{ "+1K", "AddCash", C.Green, 1000 },
		{ "+100K", "AddCash", C.Green, 100000 },
		{ "+10M", "AddCash", C.Green, 10000000 },
		{ "+1B", "AddCash", C.Green, 1000000000 },
		{ "Cash = 0", "SetCash", C.Grey, 0 },
	})
	section(playerPage, 2, "⛏️ PROGRESS", {
		{ "Shovel -", "Shovel", C.Grey, -1 },
		{ "Shovel +", "Shovel", C.Blue, 1 },
		{ "Bag -", "Bag", C.Grey, -1 },
		{ "Bag +", "Bag", C.Blue, 1 },
		{ "Rebirth -", "Rebirths", C.Grey, -1 },
		{ "Rebirth +", "Rebirths", C.Purple, 1 },
		{ "UNLOCK ALL", "UnlockAll", C.Orange },
	})
	local passButtons = {}
	for key, pass in Monetization.Passes do
		table.insert(passButtons, { pass.emoji .. " " .. pass.name, "TogglePass", C.Purple, key })
	end
	table.sort(passButtons, function(a, b)
		return a[1] < b[1]
	end)
	section(playerPage, 3, "🎫 PASSES (toggle, for testing)", passButtons)
	local boostButtons = {}
	for id, def in Retention.boosts do
		table.insert(boostButtons, { def.displayName .. " 15m", "Boost", C.Gold, id, 15 })
	end
	table.sort(boostButtons, function(a, b)
		return a[1] < b[1]
	end)
	table.insert(boostButtons, { "Clear boosts", "ClearBoosts", C.Grey })
	table.insert(boostButtons, { "+1 Instant Deep Dig", "InstantDeepDig", C.Orange })
	section(playerPage, 4, "⚡ BOOSTS", boostButtons)
	section(playerPage, 5, "💎 GIVE A TREASURE", {
		{ "Rare", "Treasure", C.Blue, "Rare" },
		{ "Epic", "Treasure", C.Purple, "Epic" },
		{ "Legendary", "Treasure", C.Orange, "Legendary" },
		{ "Mythic", "Treasure", C.Red, "Mythic" },
		{ "Secret", "Treasure", C.Gold, "Secret" },
	})
	section(playerPage, 6, "🧭 PLAYER", {
		{ "Go to them", "GoTo", C.Blue },
		{ "Bring them", "Bring", C.Blue },
		{ "Reset tutorial", "ResetTutorial", C.Grey },
		{ "KICK", "Kick", C.Red },
	})
	section(playerPage, 7, "🔄 RESET THE SELECTED PLAYER (keeps what they bought with Robux)", {
		{ "RESET PROGRESS", "ResetProgress", C.Red },
	}, { cell = UDim2.fromOffset(280, 54) })

	-- WORLD (you).
	local worldPage = page("World")
	section(worldPage, 1, "📍 TELEPORT", {
		{ "Base", "Teleport", C.Blue, "Base" },
		{ "Beach", "Teleport", C.Blue, "Beach" },
		{ "Jungle", "Teleport", C.Green, "Jungle" },
		{ "Ruins", "Teleport", C.Gold, "Ruins" },
		{ "Volcano", "Teleport", C.Orange, "Volcano" },
		{ "Summit", "Teleport", C.Red, "Summit" },
		{ "VIP site", "Teleport", C.Purple, "VIP" },
		{ "Tiki Bar", "Teleport", C.Orange, "Tiki" },
		{ "❄️ Portal", "Teleport", C.Blue, "Portal" },
		-- To the other world (a real teleport).
		if CurrentWorld.isFrost()
			then { "🏝️ To Island", "Travel", C.Gold, "Island" }
			else { "❄️ To Frostbite", "Travel", C.Blue, "Frost" },
	})
	section(worldPage, 2, "🌅 TIME OF DAY", {
		{ "Morning", "Time", C.Gold, 8 },
		{ "Noon", "Time", C.Gold, 13 },
		{ "Sunset", "Time", C.Orange, 18 },
		{ "Night", "Time", C.Purple, 0 },
	})
	section(worldPage, 3, "🏃 YOU", {
		{ "Speed x1", "Speed", C.Grey, 1 },
		{ "Speed x2", "Speed", C.Blue, 2 },
		{ "Speed x4", "Speed", C.Blue, 4 },
		{ "Jump x1", "Jump", C.Grey, 1 },
		{ "Jump x3", "Jump", C.Blue, 3 },
	})
	section(worldPage, 0, "✨ SPAWN (where you stand)", {
		{ "Legendary spot", "SpawnSpot", C.Orange, "Legendary" },
		{ "Mythic spot", "SpawnSpot", C.Red, "Mythic" },
		{ "Secret spot", "SpawnSpot", C.Gold, "Secret" },
		{ "Clue ring", "SpawnRing", C.Blue },
		{ "💸 Money rain", "MoneyRain", C.Green },
		{ "🎆 Fireworks", "Fireworks", C.Purple },
		{ "⛏️ Mega Dig here", "MegaDig", C.Gold, "Here" },
		{ "Mega Dig (beach)", "MegaDig", C.Orange },
		{ "Close Mega Dig", "MegaDig", C.Grey, "Stop" },
	})

	-- EVENTS (everyone in the server).
	local eventsPage = page("Events")
	section(eventsPage, 1, "🎉 ADMIN ABUSE (2x cash, rush, clue odds, hidden treasures)", {
		{ "10 min", "Abuse", C.Red, 10 },
		{ "30 min", "Abuse", C.Red, 30 },
		{ "60 min", "Abuse", C.Red, 60 },
		{ "Stop", "Abuse", C.Grey, 0 },
	})
	section(eventsPage, 2, "✨ TREASURE RUSH", {
		{ "5 min", "Rush", C.Gold, 5 },
		{ "15 min", "Rush", C.Gold, 15 },
		{ "Stop", "Rush", C.Grey, 0 },
	})
	section(eventsPage, 3, "📣 SERVER 2X CASH", {
		{ "10 min", "ServerBoost", C.Green, 10 },
		{ "30 min", "ServerBoost", C.Green, 30 },
		{ "Stop", "ServerBoost", C.Grey, 0 },
	})
	section(eventsPage, 4, "💎 HIDE A TREASURE (announced by area)", {
		{ "Mythic: Ruins", "Hide", C.Red, "Mythic", "Ruins" },
		{ "Mythic: Volcano", "Hide", C.Red, "Mythic", "Volcano" },
		{ "Secret: Volcano", "Hide", C.Gold, "Secret", "Volcano" },
		{ "Legendary: Jungle", "Hide", C.Orange, "Legendary", "Jungle" },
	})
	textRow(eventsPage, 20, "📢 ANNOUNCE TO THIS SERVER", "Announce", C.Green)
	textRow(
		eventsPage,
		22,
		"🌍 MESSAGE TO ALL SERVERS (a speech bubble from you)",
		"GlobalMessage",
		C.Purple
	)

	-- INFO.
	local infoPage = page("Info")
	infoLabel = Ui.plainLabel({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextSize = 22,
		Text = "Loading...",
		TextColor3 = C.Ink,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = infoPage,
	})
	section(infoPage, 10, "", { { "Refresh", "Info", C.Blue } })
end

local function showInfo(info: { [string]: any })
	local lines = {
		string.format(
			"Server up: %d min · ADMIN ABUSE: %s",
			info.uptime // 60,
			if info.abuse then "ON" else "off"
		),
		"",
		"PLAYERS",
	}
	for _, p in info.players do
		table.insert(
			lines,
			string.format(
				"  %s · %s · shovel %d · bag %d · rebirths %d",
				p.name,
				Format.cash(p.cash),
				p.shovel,
				p.bag,
				p.rebirths
			)
		)
	end
	table.insert(lines, "")
	table.insert(
		lines,
		"HIDDEN TREASURES: " .. (if #info.hidden > 0 then table.concat(info.hidden, ", ") else "none")
	)
	infoLabel.Text = table.concat(lines, "\n")
end

local built = false
local function setup()
	if built or player:GetAttribute("Admin") ~= true then
		return
	end
	built = true
	remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminAction") :: RemoteEvent
	build()
	local button = HudController.addTopButton("AdminButton", "🛠️", "Admin", C.Red, -1)
	button.Activated:Connect(function()
		Sound.play("UiClick")
		panel.Visible = not panel.Visible
		if panel.Visible then
			refreshTargets()
		end
	end)
	Players.PlayerAdded:Connect(refreshTargets)
	Players.PlayerRemoving:Connect(function(other)
		if other.UserId == targetId then
			targetId = player.UserId
		end
		task.defer(refreshTargets)
	end)
	local infoRemote = ReplicatedStorage.Remotes:WaitForChild("AdminInfo") :: RemoteEvent
	infoRemote.OnClientEvent:Connect(showInfo)
	refreshTargets()
	selectTab("Player")
end

function AdminController.init()
	setup()
	player:GetAttributeChangedSignal("Admin"):Connect(setup)
end

return AdminController
