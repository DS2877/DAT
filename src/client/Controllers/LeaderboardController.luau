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

local function build()
	panel = Ui.new("Frame", {
		Name = "Leaderboards",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(860, 460),
		BackgroundColor3 = Color3.fromRGB(35, 30, 40),
		Visible = false,
		ZIndex = 20,
		Parent = HudController.root(),
	}, { Ui.corner(UDim.new(0, 24)), Ui.stroke(5) })
	Ui.label({
		Position = UDim2.fromOffset(24, 10),
		Size = UDim2.new(0, 360, 0, 44),
		Font = Ui.TitleFont,
		Text = "LEADERBOARDS",
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	modeButton = Ui.new("TextButton", {
		Position = UDim2.fromOffset(400, 14),
		Size = UDim2.fromOffset(200, 40),
		BackgroundColor3 = C.Blue,
		Font = Ui.TitleFont,
		TextScaled = true,
		TextColor3 = C.White,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(3), Ui.textStroke(2) })
	modeButton.Activated:Connect(function()
		showWeekly = not showWeekly
		drawPanel()
	end)
	local close = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = C.Red,
		Font = Ui.TitleFont,
		Text = "X",
		TextScaled = true,
		TextColor3 = C.White,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(4), Ui.textStroke(2) })
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	HudController.registerModal(panel)
	for i, board in BOARDS do
		local x = 20 + (i - 1) * 280
		Ui.label({
			Position = UDim2.fromOffset(x, 70),
			Size = UDim2.fromOffset(260, 32),
			Font = Ui.TitleFont,
			Text = TITLES[board],
			TextColor3 = C.Gold,
			Parent = panel,
		})
		columns[board] = Ui.label({
			Position = UDim2.fromOffset(x, 108),
			Size = UDim2.fromOffset(260, 330),
			TextScaled = false,
			TextSize = 18,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = panel,
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
