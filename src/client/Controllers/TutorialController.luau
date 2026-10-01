--!strict
-- The new-player tutorial: short steps shown in a banner at the bottom,
-- with a golden beam and a bobbing marker to where to go next.
--
--   1 FIND     walk to a dig spot            (arrow to the nearest spot)
--   2 DIG      tap DIG! until it pops out    (pulsing ring on the button)
--   3 FILL     dig more treasure             (arrow to the nearest spot)
--   4 SELL     walk onto the SELL pad        (arrow to the sell pad)
--   5 BAG      buy the Satchel               (arrow to the bag shop)
--   6 UPGRADE  buy the Stone Shovel          (arrow to the shovel shop)
--   7 TIKI     grab a free drink             (arrow to the Tiki Bar)
--
-- Steps follow the player's real state (finds, bag, cash), so it never gets
-- stuck and loops FILL -> SELL until the next buy is affordable. The server
-- marks it done once the bag, the shovel and the drink are bought
-- (Logic/Tutorial).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Effects = require(script.Parent.Parent.Effects)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local DigController = require(script.Parent.DigController)
local HudController = require(script.Parent.HudController)
local StationController = require(script.Parent.StationController)

local C = Ui.Colors
local player = Players.LocalPlayer

local TutorialController = {}

local STEPS = { "FIND", "DIG", "FILL", "SELL", "BAG", "UPGRADE", "TIKI" }

local anchor: Part
local ring: Part
local targetAttachment: Attachment
local beam: Beam
local marker: BillboardGui
local markerText: TextLabel
local banner: Frame
local stepNumber: TextLabel
local stepText: TextLabel
local digPointer: Frame? = nil
local currentStep = ""

local function nearestSpot(from: Vector3): BasePart?
	local folder = workspace:FindFirstChild("DigSpots")
	if not folder then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, spot in folder:GetChildren() do
		local mound = spot:IsA("Model") and spot.PrimaryPart
		if
			mound
			and spot:GetAttribute("AreaId") == "Beach"
			and not spot:GetAttribute("Vip")
			and not spot:GetAttribute("Mega")
		then
			local d = (mound.Position - from).Magnitude
			if d < bestDistance then
				best, bestDistance = mound, d
			end
		end
	end
	return best
end

local function sellPad(): BasePart?
	local base = workspace:FindFirstChild("Base")
	return base and base:FindFirstChild("SellPad") :: BasePart?
end

-- The current step, where to point, the marker text and the banner text.
local function evaluate(root: BasePart): (string?, Vector3?, string, string, string)
	local data = ClientState.data
	if not data then
		return nil, nil, "", "", ""
	end
	if data.guideDone or data.rebirths > 0 then
		return "DONE", nil, "", "", ""
	end
	-- What to buy next: the bag first (cheap), then the shovel.
	local buyKind = if data.bagLevel <= 1 then "Bag" elseif data.shovelLevel <= 1 then "Shovel" else nil
	local nextItem: any = if buyKind
		then Progression.nextUpgrade(buyKind, if buyKind == "Bag" then data.bagLevel else data.shovelLevel)
		else nil
	local cost = if nextItem then nextItem.cost else 0
	local name = if nextItem then nextItem.name else ""
	local bagValue = ClientState.bagValue()
	local tapWord = if UserInputService.TouchEnabled then "Tap" else "Click"

	if data.finds == 0 then
		if DigController.hasTarget() then
			return "DIG", nil, "", "Dig it up!", tapWord .. " DIG! until the treasure pops out"
		end
		local spot = nearestSpot(root.Position)
		return "FIND",
			spot and spot.Position,
			"DIG HERE!",
			"Find treasure!",
			"Follow the golden arrow to a dig spot"
	end
	if not buyKind then
		-- Bag and shovel bought: the free drink at the Tiki Bar.
		local base = workspace:FindFirstChild("Decor")
		local pad = base and base:FindFirstChild("TikiPad", true) :: BasePart?
		return "TIKI",
			pad and pad.Position,
			"FREE DRINK!",
			"Visit the Tiki Bar!",
			"Grab a free drink at the Tiki Bar: drinks give 5-minute boosts"
	end
	if data.cash >= cost then
		local pad = StationController.padFor(buyKind)
		if buyKind == "Bag" then
			return "BAG",
				pad and pad.Position,
				"BUY HERE!",
				"Buy the " .. name .. "!",
				string.format("Buy the %s at the BAGS shop: room for %d treasures", name, nextItem.capacity)
		end
		return "UPGRADE",
			pad and pad.Position,
			"BUY HERE!",
			"Buy the " .. name .. "!",
			"Buy the " .. name .. " at the SHOVELS shop"
	end
	if ClientState.isBagFull() or (data.cash + bagValue >= cost and #data.bag > 0) then
		local pad = sellPad()
		return "SELL",
			pad and pad.Position,
			"SELL HERE!",
			"Sell your treasure!",
			"Bring your treasure to the golden SELL pad"
	end
	local spot = nearestSpot(root.Position)
	return "FILL",
		spot and spot.Position,
		"DIG HERE!",
		"Dig more treasure!",
		string.format(
			"Dig more: %s / %s for the %s",
			Format.cash(data.cash + bagValue),
			Format.cash(cost),
			name
		)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function buildWorldGuide()
	anchor = Instance.new("Part")
	anchor.Name = "TutorialAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = Effects.folder()
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = anchor

	ring = Instance.new("Part")
	ring.Name = "TutorialRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = C.Gold
	ring.Transparency = 1
	ring.Size = Vector3.new(0.2, 8, 8)
	ring.Parent = Effects.folder()

	beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(C.Gold, Color3.fromRGB(255, 240, 160))
	beam.Transparency = NumberSequence.new(0.15, 0.5)
	beam.Width0 = 1
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 0.8
	beam.Segments = 1
	beam.Attachment1 = targetAttachment
	beam.Enabled = false
	beam.Parent = anchor

	marker = Ui.new("BillboardGui", {
		Adornee = anchor,
		Size = UDim2.fromOffset(150, 84),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		Parent = anchor,
	})
	markerText = Ui.label({
		Size = UDim2.new(1, 0, 0, 32),
		Font = Ui.TitleFont,
		TextColor3 = C.Gold,
		Parent = marker,
	})
	Ui.label({
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 50),
		Font = Ui.TitleFont,
		Text = "▼",
		TextColor3 = C.Gold,
		Parent = marker,
	})
end

-- A slim strip at the bottom center (between the thumbstick and the jump
-- button), out of the way of the action.
local function buildBanner()
	banner = Ui.new("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(500, 50),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = HudController.root(),
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.stroke(3),
		Ui.gradient(Color3.fromRGB(255, 252, 240), Color3.fromRGB(255, 236, 196)),
	})
	local badge = Ui.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 5, 0.5, 0),
		Size = UDim2.fromOffset(62, 40),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = banner,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(2), Ui.gradient(Color3.fromRGB(255, 214, 90), C.Orange) })
	stepNumber = Ui.label({
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		Font = Ui.TitleFont,
		Text = "1/5",
		Parent = badge,
	})
	stepText = Ui.plainLabel({
		Position = UDim2.fromOffset(76, 10),
		Size = UDim2.new(1, -92, 1, -20),
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = banner,
	})
	Ui.maxText(24).Parent = stepText
end

-- A pulsing ring and "TAP!" hand around the DIG button.
local function setDigPointer(on: boolean)
	local button = DigController.button()
	if on and not digPointer and button then
		local holder = Ui.new("Frame", {
			Name = "TutorialPointer",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 40, 1, 40),
			BackgroundTransparency = 1,
			ZIndex = 0,
			Parent = button,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(6, C.White), Ui.new("UIScale") })
		Ui.label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(0, -6, 0.5, 0),
			Size = UDim2.fromOffset(150, 60),
			Font = Ui.TitleFont,
			Text = "TAP! 👉",
			TextColor3 = C.Gold,
			Parent = holder,
		})
		digPointer = holder
	elseif not on and digPointer then
		digPointer:Destroy()
		digPointer = nil
	end
end

local function characterAttachment(): Attachment?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local existing = root:FindFirstChild("TutorialAttachment") :: Attachment?
	if existing then
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "TutorialAttachment"
	attachment.Position = Vector3.new(0, -1.5, 0)
	attachment.Parent = root
	return attachment
end

local function sheetOpen(): boolean
	local root = HudController.root()
	for _, name in { "UpgradePanel", "RebirthPanel", "TikiBar" } do
		local sheet = root:FindFirstChild(name)
		if sheet and (sheet :: GuiObject).Visible then
			return true
		end
	end
	return false
end

local function showStep(step: string, text: string)
	local index = table.find(STEPS, step) or 1
	if step ~= currentStep then
		local first = currentStep == ""
		currentStep = step
		stepNumber.Text = string.format("%d/%d", index, #STEPS)
		Ui.pop(banner, 0.1)
		if not first then
			Sound.play("Streak", 0.8, 1.25)
		end
	end
	-- Shop panels show their own instructions; step aside for them.
	banner.Visible = not sheetOpen()
	stepText.Text = text
	HudController.suppressBagFull(true)
	setDigPointer(step == "DIG")
end

local function finish(celebrate: boolean)
	if banner then
		banner.Visible = false
	end
	setDigPointer(false)
	HudController.suppressBagFull(false)
	if anchor then
		anchor:Destroy()
	end
	if ring then
		ring:Destroy()
	end
	if celebrate then
		HudController.bigText("TUTORIAL COMPLETE!", C.Green, 2.5)
		task.delay(2.6, function()
			HudController.toast("Next: the Iron Shovel opens the Jungle!", C.Gold, 4)
		end)
	end
end

function TutorialController.init()
	buildWorldGuide()
	buildBanner()
	local accumulator = 0
	local seenActive = false
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		local t = os.clock()
		marker.StudsOffsetWorldSpace = Vector3.new(0, 5 + math.sin(t * 4) * 0.6, 0)
		if ring.Transparency < 1 then
			local pulse = 7 + math.sin(t * 5) * 1.2
			ring.Size = Vector3.new(0.2, pulse, pulse)
		end
		if digPointer then
			local scale = digPointer:FindFirstChildOfClass("UIScale") :: UIScale
			scale.Scale = 1 + math.abs(math.sin(t * 4)) * 0.12
		end
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not ClientState.data then
			return
		end
		local step, position, markerLabel, title, text = evaluate(root)
		if step == "DONE" then
			finish(seenActive)
			connection:Disconnect()
			return
		end
		if not step then
			return
		end
		seenActive = true
		local _ = title
		showStep(step, text)
		local show = position ~= nil
		beam.Enabled = show
		marker.Enabled = show
		ring.Transparency = if show then 0.35 else 1
		if position then
			anchor.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
			ring.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
			markerText.Text = markerLabel
			beam.Attachment0 = characterAttachment()
		end
	end)
end

return TutorialController
