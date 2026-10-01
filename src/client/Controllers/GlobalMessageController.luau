--!strict
-- An admin's message to every server (GlobalMessageService): at the top
-- center of the screen, the admin's avatar drops in and a speech bubble
-- pops out of it, typing the message. Messages queue up one at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Admin = require(ReplicatedStorage.Shared.Config.Admin)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors

local GlobalMessageController = {}

type Message = { text: string, userId: number, name: string }

local queue: { Message } = {}
local showing = false

local AVATAR = 84
local BUBBLE_WIDTH = 440
local CHARS_PER_LINE = 38
local LINE_HEIGHT = 24

local function headshot(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

local function show(message: Message)
	local root = HudController.root()
	local holder = Ui.new("Frame", {
		Name = "GlobalMessage",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -AVATAR - 20),
		Size = UDim2.fromOffset(AVATAR + 18 + BUBBLE_WIDTH, AVATAR + 24),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = root,
	})
	-- The avatar in a gold ring, with an ADMIN tag.
	local avatar = Ui.new("ImageLabel", {
		Name = "Avatar",
		Size = UDim2.fromOffset(AVATAR, AVATAR),
		BackgroundColor3 = Color3.fromRGB(255, 248, 230),
		Image = headshot(message.userId),
		ZIndex = 41,
		Parent = holder,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(4, C.Gold) })
	local tag = Ui.label({
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(78, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Red,
		Font = Ui.TitleFont,
		Text = "ADMIN",
		ZIndex = 42,
		Parent = avatar,
	})
	Ui.corner(UDim.new(1, 0)).Parent = tag
	-- The bubble, with its tail pointing at the avatar's mouth. Its height
	-- fits the text (about CHARS_PER_LINE characters a line).
	local length = utf8.len(message.text) or #message.text
	local lines = math.clamp(math.ceil(length / CHARS_PER_LINE), 1, 5)
	local bubble = Ui.new("Frame", {
		Name = "Bubble",
		Position = UDim2.fromOffset(AVATAR + 18, 6),
		Size = UDim2.fromOffset(BUBBLE_WIDTH, 40 + lines * LINE_HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 41,
		Parent = holder,
	}, { Ui.corner(UDim.new(0, 18)), Ui.stroke(3) })
	local scale = Ui.new("UIScale", { Scale = 0, Parent = bubble })
	Ui.new("Frame", {
		Name = "Tail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(AVATAR + 18, AVATAR / 2 - 4),
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 40,
		Parent = holder,
	}, { Ui.stroke(3) })
	Ui.plainLabel({
		Name = "Name",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 22),
		Font = Ui.TitleFont,
		Text = "🛠️ " .. string.upper(message.name),
		TextColor3 = C.Red,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 42,
		Parent = bubble,
	})
	local body = Ui.plainLabel({
		Name = "Text",
		Position = UDim2.fromOffset(16, 32),
		Size = UDim2.new(1, -32, 0, lines * LINE_HEIGHT),
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		Text = message.text,
		MaxVisibleGraphemes = 0,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 42,
		Parent = bubble,
	})

	-- In: the avatar drops down, the bubble pops, the text types out.
	Sound.play("Announce")
	TweenService:Create(
		holder,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 8) }
	):Play()
	task.wait(0.3)
	TweenService
		:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	for shown = 1, length, 2 do
		body.MaxVisibleGraphemes = shown
		task.wait(0.02)
	end
	body.MaxVisibleGraphemes = -1

	local cfg = Admin.globalMessage
	task.wait(cfg.baseSeconds + length * cfg.secondsPerCharacter)
	TweenService:Create(
		holder,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, 0, 0, -AVATAR - 40) }
	):Play()
	task.wait(0.4)
	holder:Destroy()
end

local function pump()
	if showing then
		return
	end
	showing = true
	task.spawn(function()
		while #queue > 0 do
			local message = table.remove(queue, 1) :: Message
			local ok, err = pcall(show, message)
			if not ok then
				warn("[GlobalMessage] " .. tostring(err))
			end
		end
		showing = false
	end)
end

function GlobalMessageController.init()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GlobalMessage") :: RemoteEvent
	remote.OnClientEvent:Connect(function(message: any)
		if type(message) ~= "table" or type(message.text) ~= "string" then
			return
		end
		table.insert(queue, {
			text = message.text,
			userId = tonumber(message.userId) or 0,
			name = tostring(message.name or "Admin"),
		})
		pump()
	end)
end

return GlobalMessageController
