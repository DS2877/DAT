--!strict
-- The one-time new-player guide: a beam and a bobbing marker pointing to the
-- nearest dig spot (until the first find), then to the sell pad when the bag
-- is full (until the first sale), then to the shovel shop once the first
-- upgrade is affordable. It disappears for good after the first upgrade.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Effects = require(script.Parent.Parent.Effects)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local StationController = require(script.Parent.StationController)

local player = Players.LocalPlayer

local GuideController = {}

local anchor: Part
local targetAttachment: Attachment
local beam: Beam
local marker: BillboardGui
local markerText: TextLabel
local finished = false

local function nearestSpot(from: Vector3): BasePart?
	local folder = workspace:FindFirstChild("DigSpots")
	if not folder then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, spot in folder:GetChildren() do
		local mound = spot:IsA("Model") and spot.PrimaryPart
		if mound and spot:GetAttribute("AreaId") == "Beach" then
			local d = (mound.Position - from).Magnitude
			if d < bestDistance then
				best, bestDistance = mound, d
			end
		end
	end
	return best
end

-- Returns the guide target position and label, or nil to hide the guide.
local function currentTarget(root: BasePart): (Vector3?, string?)
	local data = ClientState.data
	if not data then
		return nil, nil
	end
	if data.guideDone or data.shovelLevel > 1 then
		finished = true
		return nil, nil
	end
	if data.finds == 0 then
		local spot = nearestSpot(root.Position)
		return spot and spot.Position, "DIG HERE!"
	end
	if data.sales == 0 then
		if ClientState.isBagFull() then
			local base = workspace:FindFirstChild("Base")
			local pad = base and base:FindFirstChild("SellPad") :: BasePart?
			return pad and pad.Position, "SELL HERE!"
		end
		return nil, nil
	end
	local nextShovel = Progression.nextUpgrade("Shovel", data.shovelLevel)
	if nextShovel and data.cash >= nextShovel.cost then
		local pad = StationController.padFor("Shovel")
		return pad and pad.Position, "UPGRADE!"
	end
	return nil, nil
end

local function build()
	anchor = Instance.new("Part")
	anchor.Name = "GuideAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = Effects.folder()
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = anchor

	beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(Ui.Colors.Gold)
	beam.Transparency = NumberSequence.new(0.25)
	beam.Width0 = 0.7
	beam.Width1 = 0.7
	beam.FaceCamera = true
	beam.LightEmission = 0.6
	beam.Segments = 1
	beam.Attachment1 = targetAttachment
	beam.Enabled = false
	beam.Parent = anchor

	marker = Ui.new("BillboardGui", {
		Adornee = anchor,
		Size = UDim2.fromOffset(200, 110),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		Parent = anchor,
	})
	markerText = Ui.label({
		Size = UDim2.new(1, 0, 0, 44),
		Font = Ui.TitleFont,
		TextColor3 = Ui.Colors.Gold,
		Parent = marker,
	})
	Ui.label({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 64),
		Font = Ui.TitleFont,
		Text = "▼",
		TextColor3 = Ui.Colors.Gold,
		Parent = marker,
	})
end

local function characterAttachment(): Attachment?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local existing = root:FindFirstChild("GuideAttachment") :: Attachment?
	if existing then
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "GuideAttachment"
	attachment.Position = Vector3.new(0, -1.5, 0)
	attachment.Parent = root
	return attachment
end

function GuideController.init()
	build()
	local accumulator = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		local bob = math.sin(os.clock() * 4) * 0.6
		marker.StudsOffsetWorldSpace = Vector3.new(0, 5 + bob, 0)
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local position, text = nil, nil
		if root then
			position, text = currentTarget(root)
		end
		if finished then
			anchor:Destroy()
			connection:Disconnect()
			return
		end
		local show = position ~= nil
		beam.Enabled = show
		marker.Enabled = show
		if position then
			anchor.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
			markerText.Text = text or ""
			beam.Attachment0 = characterAttachment()
		end
	end)
end

return GuideController
