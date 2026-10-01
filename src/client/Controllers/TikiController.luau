--!strict
-- The Tiki Bar menu: walking onto the bar's pad opens a card per drink
-- (what it does, how long, its cash price, and the time left if it's
-- running). Buying is validated on the server (BuyDrink).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local DrinkPrice = require(ReplicatedStorage.Shared.Logic.DrinkPrice)
local Drinks = require(ReplicatedStorage.Shared.Config.Drinks)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors
local player = Players.LocalPlayer

local TikiController = {}

type Card = { id: string, price: TextButton, timer: TextLabel }

local panel: Frame
local cards: { Card } = {}
local pad: BasePart? = nil
local inside = false
local buyDrink: RemoteEvent

local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function order(): { string }
	local ids = {}
	for id in Drinks.Defs do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Drinks.Defs[a].order < Drinks.Defs[b].order
	end)
	return ids
end

local function refresh()
	local data = ClientState.data
	if not data or not panel.Visible then
		return
	end
	local now = os.time()
	for _, card in cards do
		local drink = Drinks.Defs[card.id]
		local price = DrinkPrice.of(drink, data :: any)
		local affordable = data.cash >= price
		card.price.Text = if price == 0 then "FREE!" else Format.cash(price)
		Ui.setButtonColor(card.price, if affordable then C.Green else C.Grey)
		local left = Boosts.secondsLeft(data.activeBoosts, drink.boost, now)
		card.timer.Text = if left > 0
			then "Active " .. clock(math.floor(left)) .. " · buy = +5 min"
			else string.format("Lasts %d min", drink.seconds // 60)
		card.timer.TextColor3 = if left > 0 then C.Green else Color3.fromRGB(120, 95, 70)
	end
end

local function build()
	local p = Ui.panel({
		name = "TikiBar",
		title = "TIKI BAR",
		icon = "🍹",
		accent = C.Orange,
		width = 640,
		height = 560,
		parent = HudController.root(),
	})
	panel = p.root
	HudController.registerModal(panel)
	local grid = Ui.new("Frame", {
		Name = "Grid",
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
		Parent = p.body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -8, 0.5, -8),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, id in order() do
		local drink = Drinks.Defs[id]
		local frame = Ui.new("Frame", {
			Name = id,
			LayoutOrder = i,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.1,
			Parent = grid,
		}, { Ui.corner(UDim.new(0, 18)), Ui.stroke(3) })
		Ui.label({
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(56, 56),
			Text = drink.emoji,
			Parent = frame,
		})
		Ui.plainLabel({
			Position = UDim2.fromOffset(74, 12),
			Size = UDim2.new(1, -84, 0, 28),
			Font = Ui.TitleFont,
			Text = drink.name,
			TextColor3 = C.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local blurb = Ui.plainLabel({
			Position = UDim2.fromOffset(74, 42),
			Size = UDim2.new(1, -84, 0, 44),
			Text = drink.blurb,
			TextColor3 = Color3.fromRGB(90, 70, 50),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = frame,
		})
		Ui.maxText(20).Parent = blurb
		local timer = Ui.plainLabel({
			Name = "Timer",
			Position = UDim2.new(0, 12, 1, -86),
			Size = UDim2.new(1, -24, 0, 22),
			Text = "",
			Parent = frame,
		})
		local price = Ui.button({
			Name = "Buy",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -24, 0, 48),
			Text = "",
			Parent = frame,
		}, C.Green)
		price.Activated:Connect(function()
			Sound.play("UiClick")
			buyDrink:FireServer(id)
		end)
		table.insert(cards, { id = id, price = price, timer = timer })
	end
	Ui.plainLabel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "Paid with Cash. Prices follow your next shovel.",
		TextColor3 = Color3.fromRGB(120, 95, 70),
		Parent = p.body,
	})
end

local function findPad(): BasePart?
	local decor = workspace:FindFirstChild("Decor")
	local found = decor and decor:FindFirstChild("TikiPad", true)
	return if found and found:IsA("BasePart") then found else nil
end

function TikiController.init()
	buyDrink = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyDrink") :: RemoteEvent
	build()
	ClientState.Changed:Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(0.25)
			pad = pad or findPad()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local onPad = false
			if pad and root then
				local offset = root.Position - (pad :: BasePart).Position
				onPad = Vector3.new(offset.X, 0, offset.Z).Magnitude <= Drinks.stationRadius
					and math.abs(offset.Y) < 8
			end
			if onPad ~= inside then
				inside = onPad
				panel.Visible = onPad
				if onPad then
					Sound.play("UiClick")
				end
			end
			refresh()
		end
	end)
end

return TikiController
