--!strict
-- Rebirth perk cards (RebirthService on the server): after a rebirth (and
-- for older saves, on joining) three perk cards appear; tap one to keep it.
-- Picking a perk you have levels it up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PerkConfig = require(ReplicatedStorage.Shared.Config.RebirthPerks)
local RebirthPerks = require(ReplicatedStorage.Shared.Logic.RebirthPerks)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors

local PerkController = {}

local panel: Frame
local subtitle: TextLabel
local cardRow: Frame
local chooseRemote: RemoteEvent
local shownFor = "" -- the card set on screen (ids joined)
local chosen = false

local function roman(n: number): string
	return ({ "I", "II", "III", "IV", "V", "VI" })[n] or tostring(n)
end

local function card(id: string, order: number)
	local perk = RebirthPerks.byId[id]
	local data = ClientState.data :: any
	local level = RebirthPerks.level(data, id)
	local button = Ui.new("TextButton", {
		Name = "Card_" .. id,
		LayoutOrder = order,
		Size = UDim2.new(1 / PerkConfig.choices, -12, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = true,
		Text = "",
		Parent = cardRow,
	}, {
		Ui.corner(UDim.new(0, 20)),
		Ui.stroke(4),
		Ui.gradient(Color3.fromRGB(255, 252, 240), Color3.fromRGB(240, 222, 255)),
	})
	Ui.plainLabel({
		Name = "Icon",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 60),
		Text = perk.icon,
		TextScaled = true,
		Parent = button,
	})
	Ui.plainLabel({
		Name = "Name",
		Position = UDim2.fromOffset(6, 72),
		Size = UDim2.new(1, -12, 0, 30),
		Font = Ui.TitleFont,
		Text = string.upper(perk.name),
		TextColor3 = C.Purple,
		Parent = button,
	})
	Ui.plainLabel({
		Name = "Level",
		Position = UDim2.fromOffset(6, 102),
		Size = UDim2.new(1, -12, 0, 22),
		Text = if level == 0 then "NEW!" else string.format("Level %s -> %s", roman(level), roman(level + 1)),
		TextColor3 = if level == 0 then C.Green else C.Ink,
		Parent = button,
	})
	local text = Ui.plainLabel({
		Name = "Text",
		Position = UDim2.fromOffset(10, 128),
		Size = UDim2.new(1, -20, 1, -136),
		Text = RebirthPerks.describe(id, level + 1),
		TextColor3 = C.Ink,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = button,
	})
	Ui.maxText(26).Parent = text
	button.Activated:Connect(function()
		if chosen then
			return
		end
		chosen = true
		Sound.play("Upgrade")
		Ui.pop(button, 0.15)
		chooseRemote:FireServer(id)
		task.delay(0.35, function()
			panel.Visible = false
		end)
	end)
end

local function refresh()
	local data = ClientState.data :: any
	local set = data and data.perkChoice
	if type(set) ~= "table" or #set == 0 then
		panel.Visible = false
		shownFor = ""
		return
	end
	local key = table.concat(set, ",")
	if key == shownFor and panel.Visible then
		return
	end
	shownFor = key
	chosen = false
	for _, child in cardRow:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	for i, id in set do
		if RebirthPerks.byId[id] then
			card(id, i)
		end
	end
	local waiting = data.perkChoicesWaiting or 1
	subtitle.Text = if waiting > 1
		then string.format("Pick one to keep forever (%d picks waiting)", waiting)
		else "Pick one to keep forever. Pick it again later to level it up!"
	panel.Visible = true
	Ui.pop(panel, 0.12)
	Sound.play("Reward")
end

local function build()
	local p = Ui.panel({
		name = "PerkPicker",
		title = "REBIRTH PERK",
		icon = "✨",
		accent = C.Purple,
		width = 640,
		height = 400,
		parent = HudController.root(),
		dim = true,
	})
	panel = p.root
	p.close.Visible = false -- a perk must be picked (it's free!)
	subtitle = Ui.plainLabel({
		Name = "Subtitle",
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = C.Ink,
		Parent = p.body,
	})
	cardRow = Ui.new("Frame", {
		Name = "Cards",
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 1, -36),
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
	HudController.registerModal(panel)
end

function PerkController.init()
	build()
	chooseRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ChoosePerk") :: RemoteEvent
	ClientState.Changed:Connect(refresh)
	refresh()
end

-- The perks the player has, for the rebirth altar ("🍀 Lucky Charm II, ...").
function PerkController.summary(): string
	local data = ClientState.data :: any
	local parts = {}
	for _, perk in PerkConfig.list do
		local level = data and RebirthPerks.level(data, perk.id) or 0
		if level > 0 then
			table.insert(parts, perk.icon .. " " .. perk.name .. " " .. roman(level))
		end
	end
	return table.concat(parts, ", ")
end

return PerkController
