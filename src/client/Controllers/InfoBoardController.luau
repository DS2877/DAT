--!strict
-- The Island Guide board at the base, and its full-screen version.
--
--   * The board's EVENTS panel lists the game's upcoming Roblox events
--     (created in the Creator Hub / Roblox app) with a SIGN UP button each:
--     that's a real Roblox RSVP (SocialService), so players get Roblox's own
--     notification when the event starts.
--   * Its prompt (or the 🗺️ Guide button) opens the guide full screen: the
--     map with a live "you" dot, how to play, and the same events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local IslandMap = require(ReplicatedStorage.Shared.Builders.IslandMap)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors
local player = Players.LocalPlayer

local InfoBoardController = {}

type Event = { id: string, title: string, when: string, going: boolean }

local events: { Event } = {}
local loaded = false
local listeners: { () -> () } = {}

local HOW_TO = {
	"⛏️  DIG: walk to a dirt spot and tap DIG. Sparkly spots hide better treasure.",
	"💰  SELL: bring your bag to the golden SELL pad at the base.",
	"🛒  UPGRADE: better shovels dig faster and open new areas; bigger bags carry more.",
	"🗺️  EXPLORE: Jungle (Iron Shovel), Ancient Ruins (Diamond), Volcano (Magma).",
	"🍹  TIKI BAR: drinks give 5-minute boosts (speed, jump, cash, luck).",
	"🌋  DEEP DIGS and HIDDEN TREASURES hide the best loot. Listen for the announcements!",
	"🔮  REBIRTH at the temple: +25% cash and +10% speed forever.",
}

local function formatWhen(t: any): string
	if type(t) ~= "table" then
		return ""
	end
	local ok, text = pcall(function()
		local date =
			DateTime.fromUniversalTime(t.Year, t.Month, t.Day, t.Hour or 0, t.Minute or 0, t.Second or 0)
		return date:FormatLocalTime("ddd D MMM, HH:mm", "en-us")
	end)
	return if ok then text else string.format("%d-%02d-%02d", t.Year or 0, t.Month or 0, t.Day or 0)
end

local function isGoing(status: any): boolean
	return status ~= nil
		and string.find(tostring(status), "Going", 1, true) ~= nil
		and not string.find(tostring(status), "NotGoing", 1, true)
end

local function notify()
	for _, listener in listeners do
		task.spawn(listener)
	end
end

local function loadEvents()
	local ok, result = pcall(function()
		return SocialService:GetUpcomingExperienceEventsAsync()
	end)
	loaded = true
	if not ok or type(result) ~= "table" then
		events = {}
		notify()
		return
	end
	local list = {}
	for _, e in result do
		if type(e) == "table" and type(e.Id) == "string" and not e.HasEnded then
			table.insert(list, {
				id = e.Id,
				title = (e.DisplayTitle ~= "" and e.DisplayTitle) or e.Title or "Event",
				when = if e.HasStarted then "LIVE NOW!" else formatWhen(e.StartTime),
				going = isGoing(e.UserRsvpStatus),
			})
		end
	end
	events = list
	notify()
end

local function rsvp(event: Event)
	Sound.play("UiClick")
	task.spawn(function()
		local ok, status = pcall(function()
			return SocialService:PromptRsvpToEventAsync(event.id)
		end)
		if ok then
			event.going = isGoing(status)
			if event.going then
				HudController.toast("📅 You're signed up! Roblox will remind you.", C.Green, 3)
			end
			notify()
		else
			HudController.toast("Couldn't sign up right now, try again soon.", C.Red, 3)
		end
	end)
end

-- Fills `list` (with a UIListLayout) with event rows; `compact` for the board.
local function renderEvents(list: Frame, compact: boolean)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if not loaded then
		Ui.plainLabel({
			Size = UDim2.new(1, 0, 0, 40),
			Text = "Loading events...",
			TextColor3 = C.Ink,
			Parent = list,
		})
		return
	end
	if #events == 0 then
		Ui.plainLabel({
			Size = UDim2.new(1, 0, 0, if compact then 90 else 60),
			Text = "No events planned right now.\nCheck back soon!",
			TextColor3 = C.Ink,
			Parent = list,
		})
		return
	end
	for i, event in events do
		if compact and i > 3 then
			break
		end
		local row = Ui.new("Frame", {
			Name = "Event",
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, if compact then 62 else 76),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.25,
			Parent = list,
		}, { Ui.corner(UDim.new(0, 12)), Ui.stroke(2) })
		Ui.plainLabel({
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -170, 0.55, -2),
			Font = Ui.TitleFont,
			Text = event.title,
			TextColor3 = C.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Ui.plainLabel({
			Position = UDim2.new(0, 10, 0.55, 0),
			Size = UDim2.new(1, -170, 0.45, -4),
			Text = event.when,
			TextColor3 = Color3.fromRGB(110, 80, 50),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local button = Ui.button({
			Name = "SignUp",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0, 150, 1, -14),
			Text = if event.going then "SIGNED UP ✓" else "SIGN UP",
			Parent = row,
		}, if event.going then C.Grey else C.Green)
		button.Activated:Connect(function()
			rsvp(event)
		end)
	end
end

---------------------------------------------------------------------------
-- The board's events panel (an interactive SurfaceGui for this player)
---------------------------------------------------------------------------

local function buildBoard(panelPart: BasePart)
	local existing = panelPart:FindFirstChild("Board")
	if existing and existing:IsA("SurfaceGui") then
		existing.Enabled = false -- replaced by the live list below
	end
	local gui = Ui.new("SurfaceGui", {
		Name = "EventsBoard",
		Adornee = panelPart,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Ui.plainLabel({
		Size = UDim2.new(1, -20, 0, 52),
		Position = UDim2.fromOffset(10, 4),
		Font = Ui.TitleFont,
		Text = "📅 EVENTS",
		TextColor3 = Color3.fromRGB(70, 40, 15),
		Parent = gui,
	})
	local list = Ui.new("Frame", {
		Name = "List",
		Position = UDim2.fromOffset(10, 60),
		Size = UDim2.new(1, -20, 1, -66),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local function refresh()
		renderEvents(list, true)
	end
	table.insert(listeners, refresh)
	refresh()
end

---------------------------------------------------------------------------
-- The full-screen guide
---------------------------------------------------------------------------

local panel: Frame
local pages: { [string]: Frame } = {}
local tabs: { [string]: TextButton } = {}
local youDot: Frame

local function selectTab(name: string)
	for key, page in pages do
		page.Visible = key == name
	end
	for key, button in tabs do
		Ui.setButtonColor(button, if key == name then C.Orange else Color3.fromRGB(205, 170, 120))
	end
	if name == "Events" then
		task.spawn(loadEvents)
	end
end

local function buildGuide()
	local p = Ui.panel({
		name = "IslandGuide",
		title = "ISLAND GUIDE",
		icon = "🗺️",
		accent = C.Blue,
		width = 760,
		height = 600,
		parent = HudController.root(),
		dim = true,
	})
	panel = p.root
	HudController.registerModal(panel)
	local tabRow = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent = p.body,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, entry in { { "Map", "🗺️ MAP" }, { "HowTo", "❓ HOW TO PLAY" }, { "Events", "📅 EVENTS" } } do
		local button = Ui.button({
			Name = entry[1],
			LayoutOrder = i,
			Size = UDim2.fromOffset(220, 48),
			Text = entry[2],
			Parent = tabRow,
		}, C.Orange)
		button.Activated:Connect(function()
			Sound.play("UiClick")
			selectTab(entry[1])
		end)
		tabs[entry[1]] = button
	end
	local function page(name: string): Frame
		local f = Ui.new("Frame", {
			Name = name .. "Page",
			Position = UDim2.fromOffset(0, 60),
			Size = UDim2.new(1, 0, 1, -60),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = p.body,
		})
		pages[name] = f
		return f
	end

	-- Map, kept undistorted, with this player's live position.
	local mapHolder = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = page("Map"),
	}, { Ui.new("UIAspectRatioConstraint", { AspectRatio = IslandMap.aspect }) })
	local map = IslandMap.build(mapHolder)
	youDot = Ui.new("Frame", {
		Name = "You",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.fromRGB(255, 60, 60),
		ZIndex = 9,
		Parent = map,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(3, C.White) })

	local howTo = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = page("HowTo"),
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, line in HOW_TO do
		local l = Ui.plainLabel({
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 54),
			Text = line,
			TextColor3 = C.Ink,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = howTo,
		})
		Ui.maxText(24).Parent = l
	end

	local eventsPage = page("Events")
	Ui.plainLabel({
		Size = UDim2.new(1, 0, 0, 30),
		Text = "Sign up and Roblox reminds you when the event starts!",
		TextColor3 = Color3.fromRGB(110, 80, 50),
		Parent = eventsPage,
	})
	local list = Ui.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 1, -38),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = eventsPage,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	table.insert(listeners, function()
		renderEvents(list, false)
	end)
	selectTab("Map")
end

-- Opens the guide on a tab.
function InfoBoardController.open(tab: string?)
	panel.Visible = true
	selectTab(tab or "Map")
end

function InfoBoardController.init()
	buildGuide()
	local button = HudController.addTopButton("GuideButton", "🗺️", "Guide", C.Blue, 0)
	button.Activated:Connect(function()
		Sound.play("UiClick")
		if panel.Visible then
			panel.Visible = false
		else
			InfoBoardController.open()
		end
	end)

	task.spawn(function()
		local base = workspace:WaitForChild("Base", 30)
		local board = base and base:WaitForChild("InfoBoard", 30)
		if not board then
			return
		end
		local eventsPanel = board:FindFirstChild("EventsPanel") :: BasePart?
		if eventsPanel then
			buildBoard(eventsPanel)
		end
		local prompt = board:FindFirstChild("GuidePrompt", true) :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function()
				InfoBoardController.open()
			end)
		end
	end)

	-- The live "you" dot, and events refreshed now and then.
	task.spawn(function()
		while true do
			if panel.Visible and pages.Map.Visible then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local at = IslandMap.project(root.Position.X, root.Position.Z)
					youDot.Position = UDim2.fromScale(at.X, at.Y)
				end
			end
			task.wait(0.3)
		end
	end)
	task.spawn(function()
		while true do
			loadEvents()
			task.wait(120)
		end
	end)
end

return InfoBoardController
