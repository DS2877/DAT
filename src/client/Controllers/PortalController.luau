--!strict
-- The Frost Portal on this client (WorldPortalService on the server):
--   * the three gems on the keystone light up with your rebirths
--   * the sign shows your progress ("You: 1/3") or that it's open for you
--   * locked: a sheet of ice seals the portal and it barely stirs; open:
--     the ice is gone, sparkles swirl in and snow blows out at you (the
--     moment it opens, the ice shatters)
--   * reactions: unlocked (fanfare), locked (a shake), the "being built"
--     window with the launch sign-up, and the trip
--   * in Frostbite Peaks it's the way back to the island: always open

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)
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
local fade: Frame? = nil
local shown = -1
local inFrost = CurrentWorld.isFrost()

local function rebirths(): number
	if inFrost then
		return Worlds.next.requiredRebirths -- the way home is open for everyone
	end
	local data = ClientState.data
	return if data then data.rebirths else 0
end

-- Frozen shut, or open and alive.
local function setOpen(model: Model, open: boolean)
	local sheet = model:FindFirstChild("IceSheet") :: BasePart?
	if sheet then
		sheet.Transparency = if open then 1 else 0.15
	end
	local core = model:FindFirstChild("PortalCore") :: BasePart?
	if core then
		core.Transparency = if open then 0.2 else 0.55
		local wind = core:FindFirstChild("SnowWind") :: ParticleEmitter?
		if wind then
			wind.Enabled = open
		end
	end
	local host = model:FindFirstChild("SwirlHost")
	local swirl = host and host:FindFirstChild("Swirl") :: ParticleEmitter?
	if swirl then
		swirl.Rate = if open then 45 else 5
	end
end

-- The ice sheet breaks apart: shards burst out and fall.
local function shatter(model: Model)
	local sheet = model:FindFirstChild("IceSheet") :: BasePart?
	if not sheet or sheet.Transparency >= 1 then
		return
	end
	local rng = Random.new()
	local frame = sheet.CFrame -- X = the way the portal faces
	local radius = sheet.Size.Y / 2
	for _ = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = math.sqrt(rng:NextNumber()) * radius * 0.9
		local start = frame * CFrame.new(0, math.sin(a) * d, math.cos(a) * d)
		local size = rng:NextNumber(0.8, 2.2)
		local shard = Instance.new("Part")
		shard.Name = "IceShard"
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		shard.Material = Enum.Material.Glass
		shard.Color = Color3.fromRGB(214, 245, 255)
		shard.Transparency = 0.1
		shard.Size = Vector3.new(size * 0.4, size, size * 0.7)
		shard.CFrame = start * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		shard.Parent = Effects.folder()
		local out = frame.XVector * rng:NextNumber(4, 12) * (if rng:NextNumber() < 0.5 then 1 else -1)
		local landing = start.Position + out + (start.Position - frame.Position) * 0.6 - Vector3.new(0, 8, 0)
		TweenService:Create(shard, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(landing) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Transparency = 1,
		}):Play()
		task.delay(1.2, function()
			shard:Destroy()
		end)
	end
	Effects.sparkles(frame.Position, ICE, 80)
	Sound.play("DigBurst", 1, 1.5)
end

-- Gems, sign and the ice for the current rebirth count.
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
	-- Opening right now (not just loading in already open): break the ice.
	if shown >= 0 and shown < need and have >= need then
		shatter(model)
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
				label.Text = if inFrost
					then "Step in to go back to " .. Worlds.home.name
					elseif have >= need then "OPEN FOR YOU! Step in"
					else string.format("Rebirth %d to enter · You: %d/%d", need, have, need)
			end
		end
	end
	setOpen(model, have >= need)
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
		if portal then
			shatter(portal)
		end
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
			(if inFrost then "🏝️ TO " else "❄️ TO ")
				.. string.upper(if info and info.name then info.name else w.name)
				.. "!",
			ICE,
			3
		)
		if fade then
			fade:Destroy()
		end
		local cover = Ui.new("Frame", {
			Name = "PortalFade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(230, 248, 255),
			BackgroundTransparency = 1,
			ZIndex = 100,
			Parent = HudController.root(),
		})
		fade = cover
		TweenService:Create(cover, TweenInfo.new(1), { BackgroundTransparency = 0 }):Play()
		task.delay(12, function()
			cover:Destroy() -- still here: the trip failed
		end)
	elseif kind == "TripFailed" then
		if fade then
			fade:Destroy()
			fade = nil
		end
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
		refresh()
	end)
	ClientState.Changed:Connect(refresh)
end

return PortalController
