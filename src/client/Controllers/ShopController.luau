--!strict
-- The Shop (🛒 button on the left): tabs for Passes, Boosts, Cash and Skins.
-- Every card says in plain words what it does; owned passes show OWNED, or
-- an ON/OFF switch for perks that have one; skins can be equipped.
--
-- Also here:
--   * contextual offers: a small, closeable bubble at the right moment
--     (holding DIG without Auto Dig, bag full far from base, Treasure Rush,
--     a Deep Dig, the VIP dig spot). At most one every few minutes, never
--     during the tutorial, and it never opens a purchase prompt by itself.
--   * Auto Sell's SELL button beside the bag.
--
-- The Roblox purchase prompt opens ONLY from a tap on a buy button.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Perks = require(ReplicatedStorage.Shared.Logic.Perks)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)
local SettingsController = require(script.Parent.SettingsController)

local C = Ui.Colors
local player = Players.LocalPlayer
local Offers = Monetization.Offers

local ShopController = {}

type Kind = "pass" | "product"
type Item = { kind: Kind, key: string, def: any }

local TABS = { "Passes", "Boosts", "Cash", "Skins" }
local TAB_ICONS = { Passes = "🎫", Boosts = "⚡", Cash = "💰", Skins = "⛏️" }

local panel: Frame
local grid: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Passes"
local prices: { [string]: number } = {}
local priceRequested: { [string]: boolean } = {}
local remotes: Folder

---------------------------------------------------------------------------
-- Catalog
---------------------------------------------------------------------------

local function catalogItem(key: string): Item?
	local pass = Monetization.Passes[key]
	if pass then
		return { kind = "pass", key = key, def = pass }
	end
	local product = Monetization.Products[key]
	if product then
		return { kind = "product", key = key, def = product }
	end
	return nil
end

local function forSale(item: Item): boolean
	local def = item.def
	if def.id == 0 or def.enabled == false then
		return false
	end
	local data = ClientState.data
	if item.key == "Luck2x" and (not data or data.paidRandomRestricted ~= false) then
		return false
	end
	return true
end

local function itemsFor(tab: string): { Item }
	local items: { Item } = {}
	if tab == "Passes" then
		for key, pass in Monetization.Passes do
			table.insert(items, { kind = "pass", key = key, def = pass })
		end
	else
		for key, product in Monetization.Products do
			if product.tab == tab then
				table.insert(items, { kind = "product", key = key, def = product })
			end
		end
	end
	local visible = {}
	for _, item in items do
		if forSale(item) then
			table.insert(visible, item)
		end
	end
	table.sort(visible, function(a, b)
		return a.def.order < b.def.order
	end)
	return visible
end

-- True if buying this again makes no sense (owned pass, bought one-time item).
local function owned(item: Item): boolean
	local data = ClientState.data
	if not data then
		return false
	end
	if item.kind == "pass" then
		return ClientState.hasPass(item.key)
	end
	if item.key == "StarterPack" then
		return data.starterPackBought == true
	end
	local grant = item.def.grant
	if grant.kind == "Skin" then
		return Perks.ownsSkin(data :: any, grant.skin)
	end
	return false
end

---------------------------------------------------------------------------
-- Prices and prompts
---------------------------------------------------------------------------

local function priceText(item: Item): string
	return (prices[item.key] or item.def.price) .. " R$"
end

-- Reads the price Roblox shows this player (it can differ with price
-- optimization); the config price is shown until it arrives.
local function fetchPrice(item: Item, onDone: () -> ())
	if priceRequested[item.key] then
		return
	end
	priceRequested[item.key] = true
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(
				item.def.id,
				if item.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
			)
		end)
		local price = ok and type(info) == "table" and info.PriceInRobux
		if type(price) == "number" and price ~= prices[item.key] then
			prices[item.key] = price
			onDone()
		end
	end)
end

local function shopEvent(event: string, key: string?)
	local remote = remotes:FindFirstChild("ShopEvent") :: RemoteEvent?
	if remote then
		remote:FireServer(event, key)
	end
end

-- Opens Roblox's purchase prompt. Only ever called from a player's tap.
function ShopController.prompt(key: string)
	local item = catalogItem(key)
	if not item or not forSale(item) or owned(item) then
		return
	end
	shopEvent("PurchasePrompted", key)
	pcall(function()
		if item.kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, item.def.id)
		else
			MarketplaceService:PromptProductPurchase(player, item.def.id)
		end
	end)
end

---------------------------------------------------------------------------
-- Shop panel
---------------------------------------------------------------------------

local function cashPreview(item: Item): string?
	local data = ClientState.data
	local grant = item.def.grant
	if not data or not grant then
		return nil
	end
	if grant.kind == "Cash" then
		return "+" .. Format.cash(Bonuses.rewardCash(grant, data :: any))
	elseif grant.kind == "Bundle" then
		for _, part in grant.items do
			if part.kind == "Cash" then
				return "+" .. Format.cash(Bonuses.rewardCash(part, data :: any))
			end
		end
	end
	return nil
end

local function card(item: Item, order: number)
	local def = item.def
	local featured = item.key == "StarterPack" or item.key == "VIP"
	local frame = Ui.new("Frame", {
		Name = item.key,
		LayoutOrder = order,
		BackgroundColor3 = if featured then Color3.fromRGB(255, 240, 190) else Color3.new(1, 1, 1),
		BackgroundTransparency = 0.1,
		Parent = grid,
	}, { Ui.corner(UDim.new(0, 18)), Ui.stroke(3, if featured then Color3.fromRGB(190, 130, 0) else C.Ink) })

	local badge = Ui.new("Frame", {
		Name = "IconBg",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.stroke(3),
		Ui.gradient(Ui.lighten(C.Gold, 0.35), C.Orange),
	})
	Ui.label({ Size = UDim2.fromScale(1, 1), Text = def.emoji, Parent = badge })
	Ui.plainLabel({
		Name = "Name",
		Position = UDim2.fromOffset(8, 80),
		Size = UDim2.new(1, -16, 0, 28),
		Font = Ui.TitleFont,
		Text = def.name,
		TextColor3 = C.Ink,
		Parent = frame,
	})
	local preview = cashPreview(item)
	if preview then
		Ui.label({
			Name = "Amount",
			Position = UDim2.fromOffset(8, 108),
			Size = UDim2.new(1, -16, 0, 30),
			Font = Ui.TitleFont,
			Text = preview,
			TextColor3 = C.Green,
			Parent = frame,
		})
	end
	local blurb = Ui.plainLabel({
		Name = "Blurb",
		Position = UDim2.fromOffset(12, if preview then 140 else 110),
		Size = UDim2.new(1, -24, 0, if preview then 46 else 76),
		Text = def.blurb,
		TextColor3 = Color3.fromRGB(90, 70, 50),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
	Ui.maxText(20).Parent = blurb

	local button = Ui.button({
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -24, 0, 48),
		Text = priceText(item),
		Parent = frame,
	}, C.Green)

	local data = ClientState.data
	local grant = def.grant
	if item.kind == "pass" and owned(item) then
		local toggle = def.toggle
		if toggle then
			local on = SettingsController.current(toggle)
			button.Text = if on then "ON" else "OFF"
			Ui.setButtonColor(button, if on then C.Green else C.Grey)
			button.Activated:Connect(function()
				SettingsController.set(toggle, not SettingsController.current(toggle))
			end)
		else
			button.Text = "OWNED ✓"
			Ui.setButtonColor(button, C.Grey)
			button.AutoButtonColor = false
		end
		local via = if data and not (data.passes or {})[item.key] then Perks.includedBy(item.key) else nil
		Ui.chip(if via then "In " .. via else "Owned", if via then C.Gold else C.Green, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(0, 24),
			TextSize = 15,
			Parent = frame,
		})
	elseif grant and grant.kind == "Skin" and owned(item) then
		local equipped = data and data.equippedSkin == grant.skin
		button.Text = if equipped then "EQUIPPED" else "EQUIP"
		Ui.setButtonColor(button, if equipped then C.Grey else C.Blue)
		button.Activated:Connect(function()
			Sound.play("UiClick")
			local remote = remotes:FindFirstChild("EquipSkin") :: RemoteEvent
			remote:FireServer(if equipped then "" else grant.skin)
		end)
	elseif owned(item) then
		button.Text = "OWNED ✓"
		Ui.setButtonColor(button, C.Grey)
		button.AutoButtonColor = false
	else
		if item.kind == "pass" and Perks.includedBy(item.key) then
			Ui.chip("Also in VIP", C.Gold, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 8),
				Size = UDim2.fromOffset(0, 24),
				TextSize = 15,
				Parent = frame,
			})
		end
		button.Activated:Connect(function()
			Sound.play("UiClick")
			ShopController.prompt(item.key)
		end)
		fetchPrice(item, function()
			if button.Parent then
				button.Text = priceText(item)
			end
		end)
	end
end

-- The VIP Gold skin (from the VIP pass) as a card in the Skins tab.
local function vipSkinCard(order: number)
	local data = ClientState.data
	local frame = Ui.new("Frame", {
		Name = "VIPGold",
		LayoutOrder = order,
		BackgroundColor3 = Color3.fromRGB(255, 240, 190),
		BackgroundTransparency = 0.1,
		Parent = grid,
	}, { Ui.corner(UDim.new(0, 18)), Ui.stroke(3, Color3.fromRGB(190, 130, 0)) })
	local badge = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(3), Ui.gradient(Ui.lighten(C.Gold, 0.35), C.Orange) })
	Ui.label({ Size = UDim2.fromScale(1, 1), Text = "👑", Parent = badge })
	Ui.plainLabel({
		Position = UDim2.fromOffset(8, 80),
		Size = UDim2.new(1, -16, 0, 28),
		Font = Ui.TitleFont,
		Text = "VIP Gold Shovel",
		TextColor3 = C.Ink,
		Parent = frame,
	})
	local blurb = Ui.plainLabel({
		Position = UDim2.fromOffset(12, 110),
		Size = UDim2.new(1, -24, 0, 76),
		Text = "Glowing gold. Comes with VIP. Looks only.",
		TextColor3 = Color3.fromRGB(90, 70, 50),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
	Ui.maxText(20).Parent = blurb
	local button = Ui.button({
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -24, 0, 48),
		Text = "GET VIP",
		Parent = frame,
	}, C.Gold)
	if data and Perks.ownsSkin(data :: any, "VIPGold") then
		local equipped = data.equippedSkin == "VIPGold"
		button.Text = if equipped then "EQUIPPED" else "EQUIP"
		Ui.setButtonColor(button, if equipped then C.Grey else C.Blue)
		button.Activated:Connect(function()
			Sound.play("UiClick")
			local remote = remotes:FindFirstChild("EquipSkin") :: RemoteEvent
			remote:FireServer(if equipped then "" else "VIPGold")
		end)
	else
		button.Activated:Connect(function()
			Sound.play("UiClick")
			ShopController.prompt("VIP")
		end)
	end
end

local function refresh()
	if not panel or not panel.Visible then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, item in itemsFor(currentTab) do
		if currentTab == "Cash" and item.key == "StarterPack" and owned(item) then
			continue -- one time only
		end
		card(item, item.def.order)
	end
	if currentTab == "Skins" and Monetization.Passes.VIP.id ~= 0 then
		vipSkinCard(0)
	end
	for name, button in tabButtons do
		Ui.setButtonColor(button, if name == currentTab then C.Orange else Color3.fromRGB(205, 170, 120))
	end
end

local function selectTab(name: string)
	currentTab = name
	grid.CanvasPosition = Vector2.zero
	refresh()
end

local function build()
	local p = Ui.panel({
		name = "Shop",
		title = "SHOP",
		icon = "🛒",
		accent = C.Gold,
		width = 860,
		height = 610,
		parent = HudController.root(),
		dim = true,
	})
	panel = p.root
	HudController.registerModal(panel)

	local tabRow = Ui.new("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 50),
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
	for i, name in TABS do
		local button = Ui.button({
			Name = name,
			LayoutOrder = i,
			Size = UDim2.fromOffset(180, 50),
			Text = TAB_ICONS[name] .. " " .. string.upper(name),
			Parent = tabRow,
		}, C.Orange)
		button.Activated:Connect(function()
			Sound.play("UiClick")
			selectTab(name)
		end)
		tabButtons[name] = button
	end

	grid = Ui.new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 1, -92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = p.body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -12, 0, 260),
			CellPadding = UDim2.fromOffset(12, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }),
	})

	Ui.plainLabel({
		Name = "Note",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "Everything here is optional: every area and treasure can be reached for free.",
		TextColor3 = Color3.fromRGB(120, 95, 70),
		Parent = p.body,
	})

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			shopEvent("ShopOpened", nil)
			refresh()
		end
	end)
end

-- Opens the shop on a tab.
function ShopController.open(tab: string?)
	currentTab = tab or currentTab
	if panel.Visible then
		refresh()
	else
		panel.Visible = true
	end
end

---------------------------------------------------------------------------
-- Contextual offers
---------------------------------------------------------------------------

local bubble: Frame? = nil
local lastOfferAt = -math.huge
local offerCounts: { [string]: number } = {}
local hideToken = 0

local function hideOffer()
	hideToken += 1
	if bubble then
		bubble:Destroy()
		bubble = nil
	end
end

-- Where a bubble sits: "dig" = left of the DIG button, "left" = right of
-- the cash / bag pills.
local ANCHORS = {
	dig = {
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -194, 1, -190),
		tail = UDim2.new(1, 0, 1, -40),
	},
	left = {
		anchor = Vector2.new(0, 0),
		position = UDim2.fromOffset(226, 60),
		tail = UDim2.fromOffset(0, 30),
	},
}

-- Shows a small offer bubble for a pass / product, if allowed right now.
-- `force` skips the cooldown (the player just tapped something that needs
-- it, e.g. the VIP dig spot). Returns true if shown.
function ShopController.offer(key: string, where: string, force: boolean?): boolean
	local item = catalogItem(key)
	local data = ClientState.data
	if not item or not data or not data.guideDone or not forSale(item) or owned(item) then
		return false
	end
	if not panel or panel.Visible then
		return false
	end
	local now = os.clock()
	if not force then
		if now - lastOfferAt < Offers.offerCooldown or (offerCounts[key] or 0) >= Offers.maxPerSession then
			return false
		end
	end
	lastOfferAt = now
	offerCounts[key] = (offerCounts[key] or 0) + 1
	hideOffer()

	local spot = ANCHORS[where] or ANCHORS.dig
	local def = item.def
	local frame = Ui.new("Frame", {
		Name = "Offer",
		AnchorPoint = spot.anchor,
		Position = spot.position,
		Size = UDim2.fromOffset(260, 138),
		BackgroundColor3 = C.Cream,
		Parent = HudController.root(),
	}, { Ui.corner(UDim.new(0, 18)), Ui.stroke(4) })
	frame:SetAttribute("Key", key)
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = spot.tail,
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = C.Cream,
		ZIndex = 0,
		Parent = frame,
	}, { Ui.stroke(4) })
	Ui.plainLabel({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -60, 0, 30),
		Font = Ui.TitleFont,
		Text = def.emoji .. " " .. string.upper(def.name),
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	Ui.plainLabel({
		Position = UDim2.fromOffset(14, 46),
		Size = UDim2.new(1, -28, 0, 30),
		Text = def.blurb,
		TextColor3 = C.Ink,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local close = Ui.button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(34, 34),
		Text = "X",
		Parent = frame,
	}, C.Red)
	close.Activated:Connect(function()
		Sound.play("UiClick")
		hideOffer()
	end)
	local get = Ui.button({
		Name = "Get",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -28, 0, 46),
		Text = "GET  " .. priceText(item),
		Parent = frame,
	}, C.Green)
	get.Activated:Connect(function()
		Sound.play("UiClick")
		hideOffer()
		ShopController.prompt(key)
	end)
	fetchPrice(item, function()
		if get.Parent then
			get.Text = "GET  " .. priceText(item)
		end
	end)
	bubble = frame
	Ui.pop(frame, 0.2)
	shopEvent("OfferShown", key)
	hideToken += 1
	local token = hideToken
	task.delay(Offers.visibleSeconds, function()
		if token == hideToken then
			hideOffer()
		end
	end)
	return true
end

---------------------------------------------------------------------------
-- Auto Sell: SELL button beside the bag, and the bag-full offer
---------------------------------------------------------------------------

local sellButton: TextButton

local function sellPadDistance(): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local base = workspace:FindFirstChild("Base")
	local pad = base and base:FindFirstChild("SellPad") :: BasePart?
	if not root or not pad then
		return 0
	end
	return (root.Position - pad.Position).Magnitude
end

local function onDataChanged(data: ClientState.Snapshot, previous: ClientState.Snapshot?)
	sellButton.Visible = ClientState.hasPass("AutoSell") and #data.bag > 0
	local capacity = ClientState.bagCapacity()
	local wasFull = previous ~= nil and #previous.bag >= capacity
	if
		#data.bag >= capacity
		and not wasFull
		and not ClientState.hasPass("AutoSell")
		and sellPadDistance() > Offers.autoSellMinDistance
	then
		ShopController.offer("AutoSell", "left")
	end
	if bubble and owned(catalogItem(bubble:GetAttribute("Key") :: string) :: Item) then
		hideOffer() -- just bought it
	end
	refresh()
end

local function buildSellButton()
	local bag = HudController.root():WaitForChild("Bag") :: Frame
	sellButton = Ui.button({
		Name = "SellAnywhere",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 8, 0.5, 0),
		Size = UDim2.fromOffset(86, 42),
		Text = "SELL",
		Visible = false,
		Parent = bag,
	}, C.Green)
	sellButton.Activated:Connect(function()
		Sound.play("UiClick")
		local remote = remotes:FindFirstChild("SellAnywhere") :: RemoteEvent
		remote:FireServer()
	end)
end

---------------------------------------------------------------------------

function ShopController.init()
	remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	build()
	buildSellButton()

	local shopButton = Ui.new("TextButton", {
		Name = "ShopButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 10),
		Size = UDim2.fromOffset(86, 86),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = HudController.root(),
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.stroke(4),
		Ui.gradient(Ui.lighten(C.Gold, 0.35), C.Orange),
	})
	Ui.label({
		Name = "Icon",
		Position = UDim2.fromScale(0, 0.08),
		Size = UDim2.fromScale(1, 0.55),
		Text = "🛒",
		Parent = shopButton,
	})
	Ui.label({
		Name = "Caption",
		Position = UDim2.fromScale(0.05, 0.62),
		Size = UDim2.fromScale(0.9, 0.3),
		Font = Ui.TitleFont,
		Text = "SHOP",
		Parent = shopButton,
	})
	shopButton.Activated:Connect(function()
		Sound.play("UiClick")
		if panel.Visible then
			panel.Visible = false
		else
			ShopController.open()
		end
	end)

	ClientState.Changed:Connect(onDataChanged)
	SettingsController.Changed:Connect(function()
		refresh()
	end)
end

return ShopController
