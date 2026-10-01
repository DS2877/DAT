--!strict
-- Party effects on this client:
--   * the ADMIN ABUSE party sky: night falls, the sky and light cycle
--     through the rainbow, disco beams sweep the sky, fireworks go off and
--     confetti falls, until it ends (then everything goes back)
--   * fireworks the admin spawns (the "Fireworks" remote)
--   * party pieces others use (the Mega Dig): confetti cannons, a fountain
--     of gold coins, and the big finale with all of it at once
--   * money-rain coins: a ding and "+$X" where a coin was grabbed

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Admin = require(ReplicatedStorage.Shared.Config.Admin)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Effects = require(script.Parent.Parent.Effects)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)

local C = Ui.Colors
local player = Players.LocalPlayer
local rng = Random.new()

local PartyController = {}

local function quietPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = Effects.folder()
	return p
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

---------------------------------------------------------------------------
-- Fireworks
---------------------------------------------------------------------------

-- One firework: a rocket climbs to `at`, then bursts into a ball of sparks.
local function burst(at: Vector3, color: Color3?)
	local hue = rng:NextNumber()
	local main = color or Color3.fromHSV(hue, 0.85, 1)
	local second = Color3.fromHSV((hue + 0.15) % 1, 0.7, 1)
	local from = at - Vector3.new(rng:NextNumber(-6, 6), 45, rng:NextNumber(-6, 6))
	local rocket = quietPart({
		Name = "Rocket",
		Size = Vector3.new(0.5, 2.4, 0.5),
		Color = main,
		CFrame = CFrame.new(from),
	})
	local climb = 0.7
	TweenService:Create(rocket, TweenInfo.new(climb, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(at),
	}):Play()
	task.delay(climb, function()
		rocket:Destroy()
		local flash = quietPart({
			Name = "Flash",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			Color = main,
			Transparency = 0.2,
			CFrame = CFrame.new(at),
		})
		local light = Instance.new("PointLight")
		light.Color = main
		light.Range = 60
		light.Brightness = 4
		light.Parent = flash
		TweenService:Create(flash, TweenInfo.new(0.5), { Size = Vector3.new(12, 12, 12), Transparency = 1 })
			:Play()
		TweenService:Create(light, TweenInfo.new(0.9), { Brightness = 0 }):Play()
		task.delay(1, function()
			flash:Destroy()
		end)
		local sparks = 26
		for i = 1, sparks do
			-- Evenly around a sphere (golden-angle spiral).
			local y = 1 - (i - 0.5) / sparks * 2
			local r = math.sqrt(1 - y * y)
			local a = i * 2.39996
			local direction = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
			local spark = quietPart({
				Name = "Spark",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.9, 0.9, 0.9),
				Color = if i % 3 == 0 then second else main,
				CFrame = CFrame.new(at),
			})
			local reach = rng:NextNumber(14, 20)
			TweenService:Create(spark, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(at + direction * reach - Vector3.new(0, 6, 0)),
				Size = Vector3.new(0.2, 0.2, 0.2),
				Transparency = 1,
			}):Play()
			task.delay(1.6, function()
				spark:Destroy()
			end)
		end
		Sound.play("RevealCommon", 0.9, rng:NextNumber(0.45, 0.6))
	end)
end

-- `count` fireworks over `center`, one after another.
function PartyController.fireworks(center: Vector3, count: number)
	for i = 1, count do
		task.delay((i - 1) * 0.35, function()
			burst(
				center + Vector3.new(rng:NextNumber(-30, 30), rng:NextNumber(45, 75), rng:NextNumber(-30, 30))
			)
		end)
	end
end

-- A rainbow confetti emitter on `parent`.
function PartyController.confettiEmitter(parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Confetti"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
	})
	emitter.Size = NumberSequence.new(0.35)
	emitter.Rate = 60
	emitter.Lifetime = NumberRange.new(5, 7)
	emitter.Speed = NumberRange.new(2, 6)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Acceleration = Vector3.new(0, -4, 0)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.LightEmission = 0.4
	emitter.Parent = parent
	return emitter
end

-- A confetti cannon going off at `at`.
function PartyController.confetti(at: Vector3, amount: number)
	local host = quietPart({
		Name = "ConfettiCannon",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CFrame = CFrame.new(at),
	})
	local emitter = PartyController.confettiEmitter(host)
	emitter.Enabled = false
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Speed = NumberRange.new(20, 34)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, -16, 0)
	emitter.Drag = 1.2
	emitter.Lifetime = NumberRange.new(3, 4.5)
	emitter.Size = NumberSequence.new(0.5)
	emitter:Emit(amount)
	task.delay(5, function()
		host:Destroy()
	end)
end

-- Gold coins spraying up out of `at` and raining down around it.
function PartyController.coinFountain(at: Vector3, count: number)
	for i = 1, count do
		task.delay(i * 0.035, function()
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(6, 18)
			local spin = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
			local coin = quietPart({
				Name = "FountainCoin",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 1.6, 1.6),
				Color = Color3.fromRGB(255, 201, 51),
				Material = Enum.Material.Metal,
				Reflectance = 0.3,
				CFrame = CFrame.new(at) * spin,
			})
			local peak = at
				+ Vector3.new(math.cos(a) * d * 0.45, rng:NextNumber(10, 18), math.sin(a) * d * 0.45)
			local land = at + Vector3.new(math.cos(a) * d, -3, math.sin(a) * d)
			local up = rng:NextNumber(0.45, 0.6)
			TweenService:Create(coin, TweenInfo.new(up, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(peak) * spin * CFrame.Angles(3, 0, 0),
			}):Play()
			task.delay(up, function()
				TweenService
					:Create(coin, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						CFrame = CFrame.new(land) * spin * CFrame.Angles(6, 0, 0),
					})
					:Play()
			end)
			task.delay(up + 1.4, function()
				coin:Destroy()
			end)
			if i % 5 == 0 then
				Sound.play("BagTick", 0.6, rng:NextNumber(1.2, 1.6))
			end
		end)
	end
end

-- The big finale over `at`: a barrage of fireworks, confetti cannons on
-- four sides and a fountain of gold coins.
function PartyController.celebrate(at: Vector3, radius: number)
	for i = 1, 5 do
		task.delay((i - 1) * 1.1, function()
			PartyController.fireworks(at, 5)
		end)
	end
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		PartyController.confetti(at + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius), 140)
	end
	task.delay(0.9, function()
		PartyController.confetti(at + Vector3.new(0, 4, 0), 220)
	end)
	PartyController.coinFountain(at + Vector3.new(0, 4, 0), 70)
end

---------------------------------------------------------------------------
-- The ADMIN ABUSE party sky
---------------------------------------------------------------------------

type Saved = {
	clockTime: number,
	outdoorAmbient: Color3,
	atmosphereColor: Color3?,
	atmosphereDecay: Color3?,
}

local saved: Saved? = nil
local tint: ColorCorrectionEffect? = nil
local beams: { Part } = {}
local confetti: Part? = nil
local nextFirework = 0

local function abuseActive(): boolean
	local untilTime = workspace:GetAttribute("AdminAbuseUntil")
	return type(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

local function startParty()
	local cfg = Admin.abuse
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	saved = {
		clockTime = Lighting.ClockTime,
		outdoorAmbient = Lighting.OutdoorAmbient,
		atmosphereColor = atmosphere and atmosphere.Color,
		atmosphereDecay = atmosphere and atmosphere.Decay,
	}
	TweenService:Create(Lighting, TweenInfo.new(2.5), { ClockTime = cfg.skyClockTime }):Play()
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "PartyTint"
	effect.Saturation = 0.25
	effect.Parent = Lighting
	tint = effect
	for i = 1, cfg.discoBeams do
		table.insert(
			beams,
			quietPart({
				Name = "DiscoBeam",
				Size = Vector3.new(3, 260, 3),
				Transparency = 0.55,
				Color = Color3.fromHSV(i / cfg.discoBeams, 0.8, 1),
			})
		)
	end
	local sky = quietPart({
		Name = "Confetti",
		Size = Vector3.new(90, 1, 90),
		Transparency = 1,
	})
	PartyController.confettiEmitter(sky)
	confetti = sky
	burst((rootPosition() or Vector3.zero) + Vector3.new(0, 60, -30))
end

local function updateParty(t: number)
	local cfg = Admin.abuse
	local hue = (t / cfg.hueCycleSeconds) % 1
	if tint then
		tint.TintColor = Color3.fromHSV(hue, 0.18, 1)
	end
	Lighting.OutdoorAmbient = Color3.fromHSV(hue, 0.55, 0.8)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Color = Color3.fromHSV(hue, 0.5, 1)
		atmosphere.Decay = Color3.fromHSV((hue + 0.5) % 1, 0.6, 0.8)
	end
	local center = rootPosition()
	if not center then
		return
	end
	-- Disco beams stand in a ring around the player and sweep the sky.
	for i, beam in beams do
		local a = i / #beams * math.pi * 2
		local base = center + Vector3.new(math.cos(a) * 70, -6, math.sin(a) * 70)
		local tilt = math.rad(25) * math.sin(t * 1.3 + i)
		local spin = t * 0.8 + a
		beam.CFrame = CFrame.new(base)
			* CFrame.Angles(0, spin, 0)
			* CFrame.Angles(tilt, 0, 0)
			* CFrame.new(0, beam.Size.Y / 2, 0)
		beam.Color = Color3.fromHSV((hue + i / #beams) % 1, 0.8, 1)
	end
	if confetti then
		confetti.CFrame = CFrame.new(center + Vector3.new(0, 35, 0))
	end
	if t >= nextFirework then
		nextFirework = t + cfg.fireworksEvery * rng:NextNumber(0.6, 1.4)
		burst(center + Vector3.new(rng:NextNumber(-90, 90), rng:NextNumber(55, 110), rng:NextNumber(-90, 90)))
	end
end

local function stopParty()
	local s = saved
	saved = nil
	if s then
		TweenService:Create(Lighting, TweenInfo.new(2.5), { ClockTime = s.clockTime }):Play()
		Lighting.OutdoorAmbient = s.outdoorAmbient
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere and s.atmosphereColor and s.atmosphereDecay then
			atmosphere.Color = s.atmosphereColor
			atmosphere.Decay = s.atmosphereDecay
		end
	end
	if tint then
		tint:Destroy()
		tint = nil
	end
	for _, beam in beams do
		beam:Destroy()
	end
	table.clear(beams)
	if confetti then
		confetti:Destroy()
		confetti = nil
	end
end

-- Is the party sky on (tests)?
function PartyController.isPartying(): boolean
	return saved ~= nil
end

---------------------------------------------------------------------------
-- Money rain
---------------------------------------------------------------------------

local function coinPicked(amount: number, position: Vector3)
	Sound.play("BagTick", 1, rng:NextNumber(1.1, 1.3))
	Effects.sparkles(position, C.Gold, 12)
	local anchor = quietPart({ Name = "CoinPop", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
	anchor.CFrame = CFrame.new(position)
	local gui = Ui.new("BillboardGui", {
		Size = UDim2.fromOffset(160, 40),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = anchor,
	})
	Ui.label({
		Size = UDim2.fromScale(1, 1),
		Font = Ui.TitleFont,
		Text = "+" .. Format.cash(amount),
		TextColor3 = C.Gold,
		Parent = gui,
	})
	TweenService:Create(anchor, TweenInfo.new(1), { CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) })
		:Play()
	task.delay(1, function()
		anchor:Destroy()
	end)
end

function PartyController.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local fireworksRemote = remotes:WaitForChild("Fireworks") :: RemoteEvent
	fireworksRemote.OnClientEvent:Connect(function(center: Vector3, count: number?)
		PartyController.fireworks(center, math.clamp(count or 6, 1, 20))
	end)
	local coinRemote = remotes:WaitForChild("CoinPicked") :: RemoteEvent
	coinRemote.OnClientEvent:Connect(coinPicked)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 30 then
			return
		end
		accumulator = 0
		local active = abuseActive()
		if active and not saved then
			startParty()
		elseif not active and saved then
			stopParty()
		end
		if saved then
			updateParty(os.clock())
		end
	end)
end

return PartyController
