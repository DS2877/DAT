--!strict
-- Shows server-wide announcements as a short feed under the cash / bag
-- pills and in chat. A Secret find also plays a world moment for everyone:
-- a giant rainbow pillar where it was dug, a flash and big text.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Effects = require(script.Parent.Parent.Effects)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)

local MAX_VISIBLE = 3
local SHOW_SECONDS = 6

local AnnouncementController = {}

local feed: Frame
local order = 0

type Announcement = { text: string, color: string, secret: boolean, position: Vector3? }

local function toChat(text: string, color: Color3)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral") :: TextChannel?
		if general then
			general:DisplaySystemMessage(string.format('<font color="#%s">%s</font>', color:ToHex(), text))
		end
	end)
end

local function secretMoment(position: Vector3)
	Sound.play("SecretWorld", 1)
	HudController.bigText("A SECRET WAS FOUND!", Color3.new(1, 1, 1), 3)
	local flash = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 45,
		Parent = HudController.screenGui(),
	})
	Ui.tween(flash, 0.8, { BackgroundTransparency = 1 })
	task.delay(0.85, function()
		flash:Destroy()
	end)

	local pillar = Instance.new("Part")
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Size = Vector3.new(400, 10, 10)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, 200, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Transparency = 0.2
	pillar.Parent = Effects.folder()
	local t0 = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		pillar.Color = Color3.fromHSV(((os.clock() - t0) * 0.4) % 1, 0.8, 1)
	end)
	Ui.tween(pillar, 6, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(6.1, function()
		connection:Disconnect()
		pillar:Destroy()
	end)
end

local function show(announcement: Announcement)
	local color = Color3.fromHex(announcement.color)
	order += 1
	local label = Ui.label({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 36),
		Text = announcement.text,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = feed,
	})
	Ui.pop(label, 0.15)
	Sound.play("Announce", 0.35, 1.2)
	toChat(announcement.text, color)

	-- Keep only the newest few.
	local labels = {}
	for _, child in feed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #labels - MAX_VISIBLE do
		labels[i]:Destroy()
	end

	task.delay(SHOW_SECONDS, function()
		if label.Parent then
			Ui.tween(label, 0.4, { TextTransparency = 1 })
			Ui.tween(label:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.4, { Transparency = 1 })
			task.wait(0.45)
			label:Destroy()
		end
	end)

	if announcement.secret and announcement.position then
		secretMoment(announcement.position)
	end
end

function AnnouncementController.init()
	feed = Ui.new("Frame", {
		Name = "Announcements",
		Position = UDim2.fromOffset(12, 192),
		Size = UDim2.fromOffset(460, 3 * 40),
		BackgroundTransparency = 1,
		Parent = HudController.root(),
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Announce") :: RemoteEvent
	remote.OnClientEvent:Connect(show)
end

return AnnouncementController
