--!strict
-- The Frost Portal on this client (WorldPortalService on the server):
--   * the three seals on the ring light up with your rebirths
--   * the sign shows your progress ("You: 1/3") or that it's open for you
--   * the glimpse of the snowy world: falling snow and a turning swirl
--   * reactions: unlocked (fanfare), locked (a shake), the "being built"
--     window with the launch sign-up, and the trip when the world exists

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)
local Effects = require(script.Parent.Parent.Effects)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)
local InfoBoardController = require(script.Parent.InfoBoardController)

local C = Ui.Colors
local ICE = Color3.fromRGB(127, 219, 255)
local SEAL_OFF = Color3.fromRGB(59, 74, 90)

local PortalController = {}

local portal: Model? = nil
local panel: Frame
local flakes: { { frame: Frame, speed: number, drift: number } } = {}
local shown = -1

local function rebirths(): number
	local data = ClientState.data
	return if data then data.rebirths else 0
end

-- Seals and sign for the current rebirth count.
local function refresh()
	local model = portal
	if not model then
		return
	end
	local need = Worlds.next.requiredRebirths
	local have = rebirths()
	if have == shown then
		return
	end
	shown = have
	for _, seal in model:GetChildren() do
		local index = seal:GetAttribute("Seal")
		if seal:IsA("BasePart") and type(index) == "number" then
			local lit = have >= index * need / 3
			seal.Color = if lit then ICE else SEAL_OFF
			seal.Material = if lit then Enum.Material.Neon else Enum.Material.Slate
		end
	end
	local sub = model:FindFirstChild("SignBoardSmall", true)
	if sub then
		for _, label in sub:GetDescendants() do
			if label:IsA("TextLabel") then
				label.Text = if have >= need
					then "OPEN FOR YOU! Step in"
					else string.format("Rebirth %d to enter · You: %d/%d", need, have, need)
			end
		end
	end
end

-- Falling snow in both glimpses (added here so the server sends less).
local function addSnow(model: Model)
	local face = model:FindFirstChild("PortalFace")
	if not face then
		return
	end
	local rng = Random.new()
	for _, gui in face:GetChildren() do
		local view = gui:FindFirstChild("View")
		if view then
			for _ = 1, 22 do
				local size = rng:NextInteger(4, 9)
				local flake = Instance.new("Frame")
				flake.Name = "Flake"
				flake.Size = UDim2.fromOffset(size, size)
				flake.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
				flake.BackgroundColor3 = Color3.new(1, 1, 1)
				flake.BorderSizePixel = 0
				flake.ZIndex = 4
				local round = Instance.new("UICorner")
				round.CornerRadius = UDim.new(1, 0)
				round.Parent = flake
				flake.Parent = view
				table.insert(
					flakes,
					{ frame = flake, speed = rng:NextNumber(0.05, 0.12), drift = rng:NextNumber(-0.03, 0.03) }
				)
			end
		end
	end
end

local function animate(dt: number)
	local model = portal
	if not model then
		return
	end
	for _, f in flakes do
		local p = f.frame.Position
		local y = p.Y.Scale + f.speed * dt
		local x = p.X.Scale + f.drift * dt
		if y > 1 then
			y -= 1.05
		end
		f.frame.Position = UDim2.fromScale(x % 1, y)
	end
	local face = model:FindFirstChild("PortalFace")
	if face then
		for _, gui in face:GetChildren() do
			local swirl = gui:FindFirstChild("Swirl", true)
			local gradient = swirl and swirl:FindFirstChildOfClass("UIGradient")
			if gradient then
				gradient.Rotation = (gradient.Rotation + dt * 40) % 360
			end
		end
	end
end

---------------------------------------------------------------------------
-- The "being built" window
---------------------------------------------------------------------------

local function buildPanel()
	local w = Worlds.next
	local p = Ui.panel({
		name = "WorldPortal",
		title = string.upper(w.name),
		icon = "❄️",
		accent = ICE,
		width = 620,
		height = 360,
		parent = HudController.root(),
		dim = true,
	})
	panel = p.root
	HudController.registerModal(panel)
	Ui.plainLabel({
		Name = "Headline",
		Size = UDim2.new(1, 0, 0, 40),
		Font = Ui.TitleFont,
		Text = "YOU OPENED THE FROST PORTAL!",
		TextColor3 = C.Ink,
		Parent = p.body,
	})
	Ui.plainLabel({
		Name = "Text",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 120),
		TextScaled = false,
		TextSize = 22,
		TextWrapped = true,
		Text = string.format(
			"%s, a frozen world with rarer treasure, bigger cash and new shovels, is being built right now. "
				.. "The portal is open for you: the day it's ready, step in and you're there. "
				.. "You can come back to this island any time.",
			w.name
		),
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = p.body,
	})
	local notify = Ui.button({
		Name = "Notify",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.62, -6, 0, 56),
		Text = "🔔 GET NOTIFIED",
		Parent = p.body,
	}, C.Blue)
	notify.Activated:Connect(function()
		Sound.play("UiClick")
		panel.Visible = false
		InfoBoardController.open("Events")
	end)
	local ok = Ui.button({
		Name = "Ok",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.38, -6, 0, 56),
		Text = "OK",
		Parent = p.body,
	}, C.Green)
	ok.Activated:Connect(function()
		Sound.play("UiClick")
		panel.Visible = false
	end)
end

local function onPortal(kind: string, info: { [string]: any }?)
	local w = Worlds.next
	if kind == "Attuned" then
		shown = -1
		refresh()
		Sound.play("AreaUnlocked")
		HudController.bigText("❄️ THE FROST PORTAL IS OPEN!", ICE, 3)
		task.delay(3.2, function()
			HudController.toast("Find it on the beach, ahead and right of the base", ICE, 4)
		end)
		if portal then
			local center = portal:GetAttribute("Center")
			if typeof(center) == "Vector3" then
				Effects.sparkles(center, ICE, 60)
			end
		end
	elseif kind == "Locked" then
		Sound.play("Denied")
		Effects.cameraNudge(0.6)
	elseif kind == "ComingSoon" then
		Sound.play("Reward")
		panel.Visible = true
		Ui.pop(panel, 0.1)
	elseif kind == "Teleporting" then
		Sound.play("SecretWorld")
		HudController.bigText(
			"❄️ TO " .. string.upper(if info and info.name then info.name else w.name) .. "!",
			ICE,
			3
		)
		local fade = Ui.new("Frame", {
			Name = "PortalFade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(230, 248, 255),
			BackgroundTransparency = 1,
			ZIndex = 100,
			Parent = HudController.root(),
		})
		TweenService:Create(fade, TweenInfo.new(1), { BackgroundTransparency = 0 }):Play()
		task.delay(8, function()
			fade:Destroy() -- still here: the trip failed
		end)
	end
end

function PortalController.init()
	buildPanel()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Portal") :: RemoteEvent
	remote.OnClientEvent:Connect(onPortal)
	task.spawn(function()
		local model = workspace:WaitForChild("FrostPortal", 60) :: Model?
		if not model then
			return
		end
		portal = model
		addSnow(model)
		refresh()
	end)
	ClientState.Changed:Connect(refresh)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 1 / 20 then
			animate(accumulator)
			accumulator = 0
		end
	end)
end

return PortalController
