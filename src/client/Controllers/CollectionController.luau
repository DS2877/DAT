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
	name: TextLabel,
	marks: TextLabel,
}

local panel: Frame
local summary: TextLabel
local cards: { [string]: Card } = {}
local setHeaders: { [string]: TextLabel } = {}
local built = false

local function buildCard(parent: Instance, def: Treasures.TreasureDef, order: number): Card
	local rarityColor = Color3.fromHex(Rarities.Info[def.rarity].color)
	local frame = Ui.new("Frame", {
		Name = def.id,
		LayoutOrder = order,
		BackgroundColor3 = Color3.fromRGB(255, 252, 240),
		Parent = parent,
	}, { Ui.corner(UDim.new(0, 12)), Ui.stroke(4, rarityColor) })

	local viewport = Ui.new("ViewportFrame", {
		Size = UDim2.new(1, 0, 0, 96),
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

	local name = Ui.label({
		Position = UDim2.new(0, 4, 0, 96),
		Size = UDim2.new(1, -8, 0, 26),
		TextColor3 = C.Ink,
		Parent = frame,
	})
	local outline = name:FindFirstChildOfClass("UIStroke")
	if outline then
		outline:Destroy()
	end
	local marks = Ui.label({
		Position = UDim2.new(0, 4, 0, 122),
		Size = UDim2.new(1, -8, 0, 22),
		Parent = frame,
	})
	return { frame = frame, viewport = viewport, name = name, marks = marks }
end

local function build()
	panel = Ui.new("Frame", {
		Name = "Collection",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(800, 540),
		BackgroundColor3 = C.Cream,
		Visible = false,
		ZIndex = 20,
		Parent = HudController.root(),
	}, { Ui.corner(UDim.new(0, 24)), Ui.stroke(5) })

	Ui.label({
		Position = UDim2.fromOffset(24, 10),
		Size = UDim2.new(0, 300, 0, 44),
		Font = Ui.TitleFont,
		Text = "COLLECTION",
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	summary = Ui.label({
		Position = UDim2.fromOffset(24, 54),
		Size = UDim2.new(1, -110, 0, 28),
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local summaryOutline = summary:FindFirstChildOfClass("UIStroke")
	if summaryOutline then
		summaryOutline:Destroy()
	end

	local close = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = C.Red,
		Font = Ui.TitleFont,
		Text = "X",
		TextScaled = true,
		TextColor3 = C.White,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(4), Ui.textStroke(2) })
	close.Activated:Connect(function()
		CollectionController.setOpen(false)
	end)

	local scroll = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 92),
		Size = UDim2.new(1, -32, 1, -108),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 10,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- One section per area set, then the rebirth-only Secrets.
	local order = 0
	local function section(headerKey: string, filter: (Treasures.TreasureDef) -> boolean)
		order += 1
		setHeaders[headerKey] = Ui.label({
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 34),
			Font = Ui.TitleFont,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = scroll,
		})
		order += 1
		local grid = Ui.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = scroll,
		}, {
			Ui.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(136, 148),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
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
	setHeaders.Rebirth.Text = "REBIRTH SECRETS - a new one every 5 rebirths"
	setHeaders.Rebirth.TextColor3 = C.Purple
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
	summary.Text = string.format(
		"%d / %d discovered   ✦ Shiny %d/%d   ★ Golden %d/%d   Set bonus: +%d%% cash",
		normal,
		total,
		shiny,
		total,
		golden,
		total,
		bonus
	)

	local setPercent = math.floor(CollectionConfig.setBonus * 100 + 0.5)
	for _, areaId in Areas.Order do
		local found, count = Collection.setProgress(discovered, areaId)
		local header = setHeaders[areaId]
		local name = string.upper(Areas.Defs[areaId].displayName)
		if found >= count then
			header.Text = string.format("%s  %d/%d  - COMPLETE! +%d%% cash", name, found, count, setPercent)
			header.TextColor3 = C.Green
		else
			header.Text =
				string.format("%s  %d/%d  - complete it for +%d%% cash", name, found, count, setPercent)
			header.TextColor3 = C.Orange
		end
	end

	for id, card in cards do
		local def = Treasures.ById[id]
		local entry = discovered[id]
		local rarityColor = Color3.fromHex(Rarities.Info[def.rarity].color)
		if entry then
			card.viewport.ImageColor3 = Color3.new(1, 1, 1)
			card.name.Text = def.name
			local marks = {}
			if entry.shiny then
				table.insert(marks, "✦ Shiny")
			end
			if entry.golden then
				table.insert(marks, "★ Golden")
			end
			card.marks.Text = if #marks > 0
				then table.concat(marks, "  ")
				else Rarities.Info[def.rarity].displayName
			card.marks.TextColor3 = if entry.golden then C.Gold else rarityColor
		else
			-- Silhouette: the model rendered pure black.
			card.viewport.ImageColor3 = Color3.new(0, 0, 0)
			card.name.Text = "???"
			card.marks.Text = Rarities.Info[def.rarity].displayName
			card.marks.TextColor3 = rarityColor
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
		Ui.pop(panel, 0.06)
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
