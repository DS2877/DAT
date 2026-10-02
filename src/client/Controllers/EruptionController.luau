--!strict
-- The volcano eruption on this client (EruptionService on the server): the
-- ground rumbles and the camera shakes, then the sky turns red and
-- fireballs arc out of the crater onto the island (comets in Frostbite
-- Peaks). A HUD line counts down the last minutes before an eruption.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)
local Eruption = require(ReplicatedStorage.Shared.Config.Eruption)
local Effects = require(script.Parent.Parent.Effects)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)

local EruptionController = {}

local frost = CurrentWorld.isFrost()
local color = Color3.fromHex(if frost then Eruption.frostColor else Eruption.color)
local label: TextLabel
local tint: ColorCorrectionEffect? = nil
local flying = 0

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function setTint(on: boolean)
	if on and not tint then
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "EruptionTint"
		effect.TintColor = Color3.new(1, 1, 1)
		effect.Parent = Lighting
		tint = effect
		TweenService:Create(effect, TweenInfo.new(2), {
			TintColor = if frost then Color3.fromRGB(200, 235, 255) else Color3.fromRGB(255, 190, 160),
			Saturation = 0.15,
		}):Play()
	elseif not on and tint then
		local effect = tint
		tint = nil
		TweenService:Create(effect, TweenInfo.new(2), { TintColor = Color3.new(1, 1, 1), Saturation = 0 })
			:Play()
		task.delay(2.1, function()
			effect:Destroy()
		end)
	end
end

local function onPhase()
	local phase = workspace:GetAttribute("Eruption")
	if phase == "Rumble" then
		Sound.play("Rumble")
		HudController.bigText(
			if frost then "❄️ THE PEAK IS CRACKING!" else "🌋 THE VOLCANO IS RUMBLING!",
			color,
			2.6
		)
		task.spawn(function()
			for _ = 1, 12 do
				if workspace:GetAttribute("Eruption") ~= "Rumble" then
					break
				end
				Effects.cameraNudge(0.35)
				task.wait(2)
			end
		end)
	elseif phase == "Erupt" then
		setTint(true)
		Sound.play("Rumble", 1.3)
		HudController.bigText(if frost then "☄️ COMET SHOWER!" else "🌋 ERUPTION!", color, 2.6)
		HudController.toast("Dig the glowing meteor spots for big treasure!", color, 4)
	else
		task.delay(Eruption.linger / 4, function()
			if workspace:GetAttribute("Eruption") == nil then
				setTint(false)
			end
		end)
	end
end

-- A fireball (comet) flying from `from` to `to` in `flight` seconds.
local function meteor(from: Vector3, to: Vector3, flight: number)
	flying += 1
	local ball = Instance.new("Part")
	ball.Name = "Fireball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(4, 4, 4)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.CFrame = CFrame.new(from)
	ball.Parent = Effects.folder()
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 12
	fire.Color = color
	fire.SecondaryColor = if frost then Color3.new(1, 1, 1) else Color3.fromRGB(255, 220, 90)
	fire.Parent = ball
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 30
	light.Brightness = 3
	light.Parent = ball
	local height = math.max(60, (from - to).Magnitude * 0.35)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local t = math.min(1, (os.clock() - started) / flight)
		local p = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * height, 0)
		ball.CFrame = CFrame.new(p)
		if t >= 1 then
			connection:Disconnect()
			ball:Destroy()
			flying -= 1
			Effects.dirtBurst(
				to,
				14,
				if frost then Color3.fromRGB(220, 240, 255) else Color3.fromRGB(70, 50, 40)
			)
			Effects.sparkles(to + Vector3.new(0, 2, 0), color, 30)
			local here = rootPosition()
			if here and (here - to).Magnitude < 80 then
				Sound.play("DigBurst", 1.2, 0.7)
				Effects.cameraNudge(0.5)
			end
		end
	end)
end

function EruptionController.init()
	label = Ui.label({
		Name = "EruptionTimer",
		Position = UDim2.fromOffset(16, 230),
		Size = UDim2.fromOffset(240, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Visible = false,
		Parent = HudController.root(),
	})
	workspace:GetAttributeChangedSignal("Eruption"):Connect(onPhase)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Meteor") :: RemoteEvent
	remote.OnClientEvent:Connect(meteor)
	-- The countdown: only the last 5 minutes, and while it happens.
	task.spawn(function()
		while true do
			local phase = workspace:GetAttribute("Eruption")
			local nextAt = workspace:GetAttribute("EruptionNext")
			local icon = if frost then "☄️" else "🌋"
			if phase ~= nil then
				label.Visible = true
				label.Text = icon .. (if frost then " COMET SHOWER!" else " ERUPTION!")
				label.TextColor3 = color
			elseif type(nextAt) == "number" then
				local left = nextAt - workspace:GetServerTimeNow()
				label.Visible = left > 0 and left <= 300
				label.Text = string.format(
					"%s %s in %d:%02d",
					icon,
					if frost then "Comets" else "Eruption",
					left // 60,
					math.floor(left) % 60
				)
				label.TextColor3 = Color3.new(1, 1, 1)
			else
				label.Visible = false
			end
			task.wait(0.5)
		end
	end)
end

-- Fireballs in the air right now (tests).
function EruptionController.flying(): number
	return flying
end

return EruptionController
