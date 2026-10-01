--!strict
-- The Collection screen: every treasure grouped by area set. Found treasures
-- show their model, name and which Shiny / Golden versions were found;
-- undiscovered ones are black silhouettes with their rarity color, so each
-- missing piece is a clear target. Set headers show progress and the bonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Collection = require(ReplicatedStorage.Shared.Logic.Collection)
local CollectionConfig = require(ReplicatedStorage.Shared.Config.Collection)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local TreasureBuilder = require(ReplicatedStorage.Shared.Builders.TreasureBuilder)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors

local CollectionController = {}

type Card = {
	frame: Frame,
	viewport: ViewportFrame,
	mystery: TextLabel,
	glow: Frame,
	name: TextLabel,
	marks: TextLabel,
}

type SetHeader = { title: TextLabel, count: TextLabel, fill: Frame, reward: TextLabel }

local AREA_COLORS = {
	Beach = Color3.fromRGB(255, 190, 70),
	Jungle = Color3.fromRGB(86, 196, 81),
	Ruins = Color3.fromRGB(79, 209, 197),
	Volcano = Color3.fromRGB(255, 106, 26),
	Rebirth = Color3.fromRGB(180, 92, 255),
}

local panel: Frame
local summaryChips: { [string]: TextLabel } = {}
local cards: { [string]: Card } = {}
local setHeaders: { [string]: SetHeader } = {}
local built = false

local function buildCard(parent: Instance, def: Treasures.TreasureDef, order: number): Card
	local rarityColor = Color3.fromHex(Rarities.Info[def.rarity].color)
	local frame = Ui.new("Frame", {
		Name = def.id,
		LayoutOrder = order,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	}, {
		Ui.corner(UDim.new(0, 16)),
		Ui.stroke(3, Ui.darken(rarityColor, 0.25)),
		Ui.gradient(Color3.fromRGB(255, 255, 255), Ui.lighten(rarityColor, 0.72)),
	})
	-- A soft colored disc behind the model.
	local glow = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(88, 88),
		BackgroundColor3 = rarityColor,
		BackgroundTransparency = 0.7,
		Parent = frame,
	}, { Ui.corner(UDim.new(1, 0)) })
	local viewport = Ui.new("ViewportFrame", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = frame,
	})
	local model = TreasureBuilder.build(def.id)
	model:PivotTo(CFrame.identity)
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(2.6, 1.6, 4.6), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local mystery = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(60, 60),
		Font = Ui.TitleFont,
		Text = "?",
		TextColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	})

	local name = Ui.plainLabel({
		Position = UDim2.new(0, 6, 0, 108),
		Size = UDim2.new(1, -12, 0, 24),
		TextColor3 = C.Ink,
		Parent = frame,
	})
	Ui.maxText(20).Parent = name
	local marks = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 136),
		Size = UDim2.new(1, -16, 0, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = rarityColor,
		Parent = frame,
	})
	Ui.corner(UDim.new(1, 0)).Parent = marks
	return { frame = frame, viewport = viewport, mystery = mystery, glow = glow, name = name, marks = marks }
end

local function buildSetHeader(parent: Instance, key: string, order: number): SetHeader
	local color = AREA_COLORS[key] or C.Gold
	local row = Ui.new("Frame", {
		Name = key .. "Header",
		LayoutOrder = order,
		Size = UDim2.new(1, -14, 0, 50),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	}, {
		Ui.corner(UDim.new(0, 14)),
		Ui.stroke(3),
		Ui.gradient(Ui.lighten(color, 0.2), Ui.darken(color, 0.1)),
	})
	local title = Ui.label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(0.34, 0, 1, -12),
		Font = Ui.TitleFont,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local track = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.36, 0, 0.5, 0),
		Size = UDim2.new(0.3, 0, 0, 18),
		BackgroundColor3 = Color3.fromRGB(45, 35, 40),
		Parent = row,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(2) })
	local fill = Ui.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Gold,
		Parent = track,
	}, { Ui.corner(UDim.new(1, 0)) })
	local count = Ui.label({
		Position = UDim2.new(0.67, 0, 0, 8),
		Size = UDim2.new(0.1, 0, 1, -16),
		Font = Ui.TitleFont,
		Parent = row,
	})
	local reward = Ui.label({
		Position = UDim2.new(0.78, 0, 0, 10),
		Size = UDim2.new(0.21, -6, 1, -20),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	return { title = title, count = count, fill = fill, reward = reward }
end

local function build()
	local p = Ui.panel({
		name = "Collection",
		title = "COLLECTION",
		icon = "📖",
		accent = C.Purple,
		width = 880,
		height = 580,
		parent = HudController.root(),
		dim = true,
	})
	panel = p.root

	-- Summary chips.
	local chips = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = p.body,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, entry in
		{
			{ "Found", C.Ink },
			{ "Shiny", Color3.fromRGB(70, 150, 230) },
			{ "Golden", Color3.fromRGB(215, 150, 20) },
			{ "Bonus", Color3.fromRGB(60, 170, 80) },
		}
	do
		summaryChips[entry[1]] = Ui.chip("", entry[2], { LayoutOrder = i, Parent = chips })
	end

	local scroll = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Ink,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = p.body,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12) }),
	})

	-- One section per area set, then the rebirth-only Secrets.
	local order = 0
	local function section(headerKey: string, filter: (Treasures.TreasureDef) -> boolean)
		order += 1
		setHeaders[headerKey] = buildSetHeader(scroll, headerKey, order)
		order += 1
		local grid = Ui.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -14, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = scroll,
		}, {
			Ui.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(148, 166),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
		})
		local index = 0
		for _, def in Treasures.List do
			if filter(def) then
				index += 1
				cards[def.id] = buildCard(grid, def, Rarities.rank(def.rarity) * 100 + index)
			end
		end
	end
	for _, areaId in Areas.Order do
		section(areaId, function(def)
			return def.area == areaId and def.rebirths == nil
		end)
	end
	section("Rebirth", function(def)
		return def.rebirths ~= nil
	end)
	HudController.registerModal(panel)
	built = true
end

local function refresh()
	local data = ClientState.data
	if not built or not data or not panel.Visible then
		return
	end
	local discovered = data.discovered or {}
	local normal, shiny, golden, total = Collection.totals(discovered)
	local bonus = math.floor((Collection.cashMultiplier(discovered) - 1) * 100 + 0.5)
	summaryChips.Found.Text = string.format("📖 %d / %d found", normal, total)
	summaryChips.Shiny.Text = string.format("✦ Shiny %d", shiny)
	summaryChips.Golden.Text = string.format("★ Golden %d", golden)
	summaryChips.Bonus.Text = string.format("💰 Set bonus +%d%% cash", bonus)

	local setPercent = math.floor(CollectionConfig.setBonus * 100 + 0.5)
	for _, areaId in Areas.Order do
		local found, count = Collection.setProgress(discovered, areaId)
		local header = setHeaders[areaId]
		header.title.Text = string.upper(Areas.Defs[areaId].displayName)
		header.count.Text = string.format("%d/%d", found, count)
		header.fill.Size = UDim2.fromScale(math.clamp(found / math.max(count, 1), 0, 1), 1)
		header.fill.BackgroundColor3 = if found >= count then C.Green else C.Gold
		header.reward.Text = if found >= count
			then string.format("COMPLETE! +%d%% cash", setPercent)
			else string.format("Complete: +%d%% cash", setPercent)
	end
	local rebirthFound, rebirthCount = 0, 0
	for _, def in Treasures.List do
		if def.rebirths ~= nil then
			rebirthCount += 1
			if discovered[def.id] then
				rebirthFound += 1
			end
		end
	end
	local rebirthHeader = setHeaders.Rebirth
	rebirthHeader.title.Text = "REBIRTH SECRETS"
	rebirthHeader.count.Text = string.format("%d/%d", rebirthFound, rebirthCount)
	rebirthHeader.fill.Size = UDim2.fromScale(rebirthFound / math.max(rebirthCount, 1), 1)
	rebirthHeader.reward.Text = "A new one every 5 rebirths"

	for id, card in cards do
		local def = Treasures.ById[id]
		local entry = discovered[id]
		local rarityColor = Color3.fromHex(Rarities.Info[def.rarity].color)
		local rarityName = Rarities.Info[def.rarity].displayName
		if entry then
			card.viewport.ImageColor3 = Color3.new(1, 1, 1)
			card.mystery.Visible = false
			card.glow.BackgroundTransparency = 0.55
			card.name.Text = def.name
			local marks = {}
			if entry.shiny then
				table.insert(marks, "✦")
			end
			if entry.golden then
				table.insert(marks, "★")
			end
			card.marks.Text = if #marks > 0
				then rarityName .. "  " .. table.concat(marks, " ")
				else rarityName
			card.marks.BackgroundColor3 = if entry.golden then C.Gold else rarityColor
		else
			-- Silhouette with a question mark.
			card.viewport.ImageColor3 = Color3.fromRGB(60, 50, 72)
			card.mystery.Visible = true
			card.glow.BackgroundTransparency = 0.85
			card.name.Text = "???"
			card.marks.Text = rarityName
			card.marks.BackgroundColor3 = rarityColor
		end
	end
end

function CollectionController.setOpen(open: boolean)
	if open and not built then
		build()
	end
	if not built then
		return
	end
	panel.Visible = open
	if open then
		Sound.play("UiClick", 0.5)
		refresh()
	end
end

function CollectionController.init()
	local button = HudController.addTopButton("CollectionButton", "📖", "Collection", C.Purple, 1)
	button.Activated:Connect(function()
		CollectionController.setOpen(not (built and panel.Visible))
	end)
	ClientState.Changed:Connect(refresh)
end

return CollectionController
