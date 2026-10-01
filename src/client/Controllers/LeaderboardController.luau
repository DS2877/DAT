--!strict
-- Leaderboards on the client: fills the physical boards at the base (they
-- alternate between ALL TIME and THIS WEEK) and a small panel behind the
-- 🏆 button. Data comes from ReplicatedStorage.LeaderboardData (JSON).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors

local LeaderboardController = {}

local BOARDS = { "Richest", "Rebirths", "Rarest" }
local TITLES = { Richest = "RICHEST", Rebirths = "MOST REBIRTHS", Rarest = "RAREST FIND" }

local data: { [string]: { { [string]: any } } } = {}
local showWeekly = false
local panel: Frame
local columns: { [string]: TextLabel } = {}
local modeButton: TextButton

local function formatValue(board: string, row: { [string]: any }): string
	if board == "Richest" then
		return Format.cash(row.value)
	elseif board == "Rebirths" then
		return tostring(row.value)
	end
	local def = row.treasureId and Treasures.ById[row.treasureId]
	if not def then
		return "?"
	end
	local prefix = if row.mutation == "Golden"
		then "GOLDEN "
		elseif row.mutation == "Shiny" then "Shiny "
		else ""
	return prefix .. def.name
end

local function rowsText(board: string, weekly: boolean): string
	local rows = data[board .. (if weekly then "_Week" else "_All")] or {}
	if #rows == 0 then
		return "No entries yet - be the first!"
	end
	local lines = {}
	for i, row in rows do
		table.insert(lines, string.format("%d. %s  -  %s", i, row.name or "Player", formatValue(board, row)))
	end
	return table.concat(lines, "\n")
end

local function drawBoards(weekly: boolean)
	local base = workspace:FindFirstChild("Base")
	if not base then
		return
	end
	for _, board in BOARDS do
		local panelPart = base:FindFirstChild("Board_" .. board)
		local gui = panelPart and panelPart:FindFirstChild("Board")
		if gui then
			(gui:FindFirstChild("Mode") :: TextLabel).Text = if weekly then "THIS WEEK" else "ALL TIME";
			(gui:FindFirstChild("Rows") :: TextLabel).Text = rowsText(board, weekly)
		end
	end
end

local function drawPanel()
	if not panel or not panel.Visible then
		return
	end
	modeButton.Text = if showWeekly then "THIS WEEK" else "ALL TIME"
	for _, board in BOARDS do
		columns[board].Text = rowsText(board, showWeekly)
	end
end

local BOARD_COLORS = {
	Richest = Color3.fromRGB(255, 190, 50),
	Rebirths = Color3.fromRGB(180, 92, 255),
	Rarest = Color3.fromRGB(63, 169, 255),
}
local BOARD_ICONS = { Richest = "💰", Rebirths = "✨", Rarest = "💎" }

local function build()
	local p = Ui.panel({
		name = "Leaderboards",
		title = "LEADERBOARDS",
		icon = "🏆",
		accent = C.Gold,
		width = 900,
		height = 500,
		parent = HudController.root(),
		dim = true,
	})
	panel = p.root
	modeButton = Ui.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -66, 0.5, 0),
		Size = UDim2.fromOffset(190, 44),
		Parent = p.header,
	}, C.Blue)
	modeButton.Activated:Connect(function()
		showWeekly = not showWeekly
		drawPanel()
	end)
	HudController.registerModal(panel)
	local row = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = p.body,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, board in BOARDS do
		local color = BOARD_COLORS[board]
		local column = Ui.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(0.33, -8, 1, -4),
			BackgroundColor3 = Color3.fromRGB(40, 32, 48),
			Parent = row,
		}, { Ui.corner(UDim.new(0, 18)), Ui.stroke(4) })
		local top = Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = column,
		}, { Ui.corner(UDim.new(0, 18)), Ui.gradient(Ui.lighten(color, 0.25), Ui.darken(color, 0.1)) })
		Ui.label({
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -16),
			Font = Ui.TitleFont,
			Text = BOARD_ICONS[board] .. " " .. TITLES[board],
			Parent = top,
		})
		columns[board] = Ui.label({
			Position = UDim2.fromOffset(14, 62),
			Size = UDim2.new(1, -28, 1, -72),
			TextScaled = false,
			TextSize = 20,
			TextWrapped = true,
			LineHeight = 1.15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = column,
		})
	end
end

local function load(json: string)
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if ok and type(decoded) == "table" then
		data = decoded
	end
	drawPanel()
end

function LeaderboardController.init()
	build()
	local button = HudController.addTopButton("TopButton", "🏆", "Top", C.Gold, 3)
	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
		drawPanel()
	end)

	local value = ReplicatedStorage:WaitForChild("LeaderboardData") :: StringValue
	load(value.Value)
	value.Changed:Connect(function()
		load(value.Value)
	end)

	-- The physical boards alternate between all-time and weekly.
	task.spawn(function()
		local weekly = false
		while true do
			drawBoards(weekly)
			task.wait(8)
			weekly = not weekly
		end
	end)
end

return LeaderboardController
