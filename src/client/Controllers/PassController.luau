--!strict
-- Game passes on the client: who owns what, and the small offer bubble.
--
-- The bubble is a hint, not a purchase prompt: it appears beside the DIG
-- button when a player without Auto Dig keeps holding DIG, can be closed,
-- hides by itself, and is rate-limited (Config/Monetization). The Roblox
-- purchase prompt only opens when the player taps GET.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors
local player = Players.LocalPlayer
local Offer = Monetization.AutoDigOffer

local PassController = {}

local bubble: Frame? = nil
local getButton: TextButton
local lastOfferAt = -math.huge
local offersShown = 0
local hideToken = 0
local prices: { [string]: number } = {}

-- True if this player has the pass (or the pass isn't set up yet, which
-- makes the perk free for everyone).
function PassController.owns(name: string): boolean
	local pass = Monetization.Passes[name]
	if not pass then
		return false
	end
	return pass.id == 0 or player:GetAttribute("Pass_" .. name) == true
end

-- Opens the Roblox purchase prompt. Only call this from a player's tap.
function PassController.prompt(name: string)
	local pass = Monetization.Passes[name]
	if not pass or pass.id == 0 or PassController.owns(name) then
		return
	end
	pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	end)
end

-- The pass's real price from Roblox (cached; nil until known).
local function fetchPrice(name: string)
	local pass = Monetization.Passes[name]
	if prices[name] or not pass or pass.id == 0 then
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(pass.id, Enum.InfoType.GamePass)
		end)
		local price = ok and type(info) == "table" and info.PriceInRobux
		if type(price) == "number" then
			prices[name] = price
			if getButton then
				getButton.Text = "GET  " .. price .. " R$"
			end
		end
	end)
end

local function hide()
	hideToken += 1
	if bubble then
		bubble.Visible = false
	end
end

local function build(): Frame
	local pass = Monetization.Passes.AutoDig
	local frame = Ui.new("Frame", {
		Name = "AutoDigOffer",
		AnchorPoint = Vector2.new(1, 1),
		-- Left of the DIG button (which sits at 1,-28 / 1,-190, 150 wide).
		Position = UDim2.new(1, -194, 1, -190),
		Size = UDim2.fromOffset(250, 138),
		BackgroundColor3 = C.Cream,
		Visible = false,
		Parent = HudController.root(),
	}, { Ui.corner(UDim.new(0, 18)), Ui.stroke(4) })
	Ui.plainLabel({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -60, 0, 30),
		Font = Ui.TitleFont,
		Text = pass.icon .. " " .. string.upper(pass.name),
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	Ui.plainLabel({
		Position = UDim2.fromOffset(14, 50),
		Size = UDim2.new(1, -28, 0, 22),
		Text = pass.description,
		TextColor3 = C.Ink,
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
		hide()
	end)
	getButton = Ui.button({
		Name = "Get",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -28, 0, 46),
		Text = "GET",
		Parent = frame,
	}, C.Green)
	getButton.Activated:Connect(function()
		Sound.play("UiClick")
		hide()
		PassController.prompt("AutoDig")
	end)
	-- A little tail pointing at the DIG button.
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 0, 1, -40),
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = C.Cream,
		ZIndex = 0,
		Parent = frame,
	}, { Ui.stroke(4) })
	return frame
end

-- Shows the Auto Dig offer if it's allowed right now. Returns true if shown.
function PassController.offerAutoDig(): boolean
	local data = ClientState.data
	if PassController.owns("AutoDig") or not data or not data.guideDone then
		return false
	end
	local now = os.clock()
	if offersShown >= Offer.maxPerSession or now - lastOfferAt < Offer.cooldown then
		return false
	end
	lastOfferAt = now
	offersShown += 1
	local frame = bubble or build()
	bubble = frame
	fetchPrice("AutoDig")
	if prices.AutoDig then
		getButton.Text = "GET  " .. prices.AutoDig .. " R$"
	end
	frame.Visible = true
	Ui.pop(frame, 0.2)
	hideToken += 1
	local token = hideToken
	task.delay(Offer.visibleSeconds, function()
		if token == hideToken then
			hide()
		end
	end)
	return true
end

function PassController.init()
	-- Bought it: drop the offer.
	player:GetAttributeChangedSignal("Pass_AutoDig"):Connect(function()
		if PassController.owns("AutoDig") then
			hide()
		end
	end)
end

return PassController
