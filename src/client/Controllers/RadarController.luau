--!strict
-- Treasure Radar (game pass): a soft blue beam from the player to the
-- nearest clue spot in an area they can dig, with a 🧭 marker above it.
-- Switched on/off with the "radar" setting. Hidden during the tutorial
-- (which has its own golden arrow).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Effects = require(script.Parent.Parent.Effects)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer
local RADAR_COLOR = Color3.fromRGB(110, 220, 255)
local MAX_DISTANCE = 600

local RadarController = {}

local anchor: Part
local target: Attachment
local beam: Beam
local marker: BillboardGui

local function build()
	anchor = Instance.new("Part")
	anchor.Name = "RadarTarget"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = Effects.folder()
	target = Instance.new("Attachment")
	target.Parent = anchor

	beam = Instance.new("Beam")
	beam.Name = "RadarBeam"
	beam.Color = ColorSequence.new(RADAR_COLOR, Color3.fromRGB(200, 245, 255))
	beam.Transparency = NumberSequence.new(0.35, 0.75)
	beam.Width0 = 0.6
	beam.Width1 = 0.3
	beam.FaceCamera = true
	beam.LightEmission = 0.7
	beam.Segments = 1
	beam.Attachment1 = target
	beam.Enabled = false
	beam.Parent = anchor

	marker = Ui.new("BillboardGui", {
		Name = "RadarMarker",
		Adornee = anchor,
		Size = UDim2.fromOffset(60, 60),
		StudsOffsetWorldSpace = Vector3.new(0, 5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		Parent = anchor,
	})
	Ui.label({ Size = UDim2.fromScale(1, 1), Text = "🧭", Parent = marker })
end

local function rootAttachment(): Attachment?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local existing = root:FindFirstChild("RadarFrom")
	if existing then
		return existing :: Attachment
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "RadarFrom"
	attachment.Parent = root
	return attachment
end

local function nearestClue(from: Vector3, shovelLevel: number): Vector3?
	local spots = workspace:FindFirstChild("DigSpots")
	if not spots then
		return nil
	end
	local best, bestDistance = nil, MAX_DISTANCE
	for _, spot in spots:GetChildren() do
		if
			spot:IsA("Model")
			and spot:GetAttribute("Clue")
			and not spot:GetAttribute("Vip")
			and Progression.isAreaUnlocked((spot:GetAttribute("AreaId") :: string?) or "", shovelLevel)
			and spot.PrimaryPart
		then
			local position = (spot.PrimaryPart :: BasePart).Position
			local distance = (position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = position, distance
			end
		end
	end
	return best
end

local function update()
	local data = ClientState.data
	local from = rootAttachment()
	local on = data ~= nil and data.guideDone and ClientState.perkOn("TreasureRadar") and from ~= nil
	local position = if on and from and data then nearestClue(from.WorldPosition, data.shovelLevel) else nil
	if position and from and (position - from.WorldPosition).Magnitude > 8 then
		anchor.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
		beam.Attachment0 = from
		beam.Enabled = true
		marker.Enabled = true
	else
		beam.Enabled = false
		marker.Enabled = false
	end
end

function RadarController.init()
	build()
	task.spawn(function()
		while true do
			update()
			task.wait(0.4)
		end
	end)
end

return RadarController
