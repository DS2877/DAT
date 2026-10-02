--!strict
-- What a shovel does where it hits the ground (its `impact` in
-- Config/Upgrades): a puff of dust for the Wooden Shovel, sparks for Iron,
-- popping coins for Golden, a rainbow ring for Rainbow, embers for Magma, a
-- cosmic shockwave for the Legendary... Upgrades you can see, not only
-- faster numbers. Short-lived local parts and particle bursts.

local TweenService = game:GetService("TweenService")

local Effects = require(script.Parent.Effects)

local ImpactFx = {}

local rng = Random.new()

local function cleanup(item: Instance, after: number)
	task.delay(after, function()
		item:Destroy()
	end)
end
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function anchorAt(position: Vector3): Part
	local p = Instance.new("Part")
	p.Name = "ImpactFx"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(position)
	p.Parent = Effects.folder()
	return p
end

-- A one-off particle burst.
local function burst(
	position: Vector3,
	colors: { Color3 },
	count: number,
	props: {
		speed: NumberRange?,
		size: NumberSequence?,
		life: NumberRange?,
		gravity: number?,
		light: number?,
	}
)
	local host = anchorAt(position)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	if #colors == 1 then
		e.Color = ColorSequence.new(colors[1])
	else
		local keys = {}
		for i, c in colors do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
		end
		e.Color = ColorSequence.new(keys)
	end
	e.Rate = 0
	e.Speed = props.speed or NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(70, 70)
	e.EmissionDirection = Enum.NormalId.Top
	e.Lifetime = props.life or NumberRange.new(0.4, 0.8)
	e.Size = props.size or NumberSequence.new(0.5, 0)
	e.Acceleration = Vector3.new(0, -(props.gravity or 30), 0)
	e.LightEmission = props.light or 0.8
	e.Drag = 2
	e.Parent = host
	e:Emit(count)
	cleanup(host, 1.3)
end

-- A flat ring growing out from the hit and fading.
local function ring(position: Vector3, color: Color3, size: number, duration: number, neon: boolean?)
	local p = Instance.new("Part")
	p.Name = "ImpactRing"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = 0.25
	p.Size = Vector3.new(0.15, 1, 1)
	p.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = Effects.folder()
	TweenService:Create(
		p,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, size, size), Transparency = 1 }
	):Play()
	cleanup(p, duration + 0.1)
	return p
end

-- Little things that pop out of the hit, tumble and vanish (coins, shards).
local function pops(position: Vector3, count: number, make: (i: number) -> BasePart)
	for i = 1, count do
		local p = make(i)
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = CFrame.new(
			position + Vector3.new(rng:NextNumber(-0.5, 0.5), 0.8, rng:NextNumber(-0.5, 0.5))
		) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		p.Parent = Effects.folder()
		p.AssemblyLinearVelocity =
			Vector3.new(rng:NextNumber(-7, 7), rng:NextNumber(16, 24), rng:NextNumber(-7, 7))
		p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(-14, 14), 0)
		TweenService
			:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), {
				Transparency = 1,
			})
			:Play()
		cleanup(p, 1.1)
	end
end

local function flash(position: Vector3, color: Color3, range: number)
	local host = anchorAt(position + Vector3.new(0, 1, 0))
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 3
	light.Parent = host
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	cleanup(host, 0.6)
end

local KINDS: { [string]: (Vector3) -> () } = {
	Dust = function(at)
		ring(at, Color3.fromRGB(214, 190, 150), 4, 0.4)
	end,
	Pebbles = function(at)
		Effects.dirtBurst(at, 4, Color3.fromRGB(120, 124, 132))
		ring(at, Color3.fromRGB(170, 170, 170), 4.5, 0.4)
	end,
	Sparks = function(at)
		burst(at, { Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 140, 40) }, 16, {
			speed = NumberRange.new(14, 24),
			size = NumberSequence.new(0.3, 0),
			life = NumberRange.new(0.25, 0.5),
			gravity = 50,
		})
		flash(at, Color3.fromRGB(255, 200, 120), 8)
	end,
	Coins = function(at)
		pops(at, 4, function()
			local coin = Instance.new("Part")
			coin.Name = "ImpactCoin"
			coin.Shape = Enum.PartType.Cylinder
			coin.Size = Vector3.new(0.15, 0.7, 0.7)
			coin.Material = Enum.Material.Metal
			coin.Color = Color3.fromRGB(255, 201, 51)
			coin.Reflectance = 0.2
			return coin
		end)
		burst(at, { Color3.fromRGB(255, 220, 90) }, 8, { size = NumberSequence.new(0.35, 0) })
	end,
	Sparkle = function(at)
		burst(at, { Color3.fromRGB(190, 250, 255), Color3.fromRGB(127, 243, 255) }, 18, {
			speed = NumberRange.new(6, 12),
			life = NumberRange.new(0.5, 0.9),
			gravity = 6,
		})
		pops(at, 2, function()
			local shard = Instance.new("Part")
			shard.Name = "ImpactCrystal"
			shard.Size = Vector3.new(0.3, 0.7, 0.3)
			shard.Material = Enum.Material.Glass
			shard.Color = Color3.fromRGB(150, 240, 255)
			shard.Transparency = 0.2
			return shard
		end)
	end,
	Rainbow = function(at)
		local colors = {
			Color3.fromRGB(255, 80, 80),
			Color3.fromRGB(255, 200, 60),
			Color3.fromRGB(90, 230, 90),
			Color3.fromRGB(70, 170, 255),
			Color3.fromRGB(190, 90, 255),
		}
		for i, c in colors do
			task.delay((i - 1) * 0.05, function()
				ring(at, c, 4 + i * 1.3, 0.5, true)
			end)
		end
		burst(at, colors, 20, { size = NumberSequence.new(0.45, 0), gravity = 12 })
	end,
	Lava = function(at)
		burst(at, { Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 90, 20) }, 20, {
			speed = NumberRange.new(10, 18),
			size = NumberSequence.new(0.45, 0.1),
			life = NumberRange.new(0.5, 1),
			gravity = 22,
			light = 1,
		})
		ring(at, Color3.fromRGB(255, 100, 30), 6, 0.45, true)
		flash(at, Color3.fromRGB(255, 120, 40), 12)
	end,
	Cosmic = function(at)
		ring(at, Color3.fromRGB(190, 110, 255), 12, 0.6, true)
		task.delay(0.08, function()
			ring(at, Color3.fromRGB(255, 220, 120), 8, 0.5, true)
		end)
		burst(at, { Color3.fromRGB(255, 240, 160), Color3.fromRGB(180, 100, 255) }, 26, {
			speed = NumberRange.new(10, 20),
			size = NumberSequence.new(0.5, 0),
			life = NumberRange.new(0.6, 1.1),
			gravity = 4,
			light = 1,
		})
		flash(at, Color3.fromRGB(190, 120, 255), 14)
	end,
	Snow = function(at)
		burst(at, { Color3.new(1, 1, 1) }, 18, {
			speed = NumberRange.new(5, 10),
			size = NumberSequence.new(0.5, 0.2),
			life = NumberRange.new(0.6, 1.1),
			gravity = 8,
			light = 0.2,
		})
		ring(at, Color3.fromRGB(240, 248, 255), 5, 0.45)
	end,
	Shards = function(at)
		pops(at, 4, function()
			local shard = Instance.new("Part")
			shard.Name = "ImpactShard"
			shard.Size = Vector3.new(0.25, rng:NextNumber(0.5, 0.9), 0.25)
			shard.Material = Enum.Material.Ice
			shard.Color = Color3.fromRGB(170, 230, 255)
			shard.Transparency = 0.15
			return shard
		end)
		burst(at, { Color3.fromRGB(200, 240, 255) }, 10, { size = NumberSequence.new(0.35, 0), gravity = 10 })
	end,
	Aurora = function(at)
		local colors =
			{ Color3.fromRGB(108, 255, 196), Color3.fromRGB(120, 140, 255), Color3.fromRGB(220, 110, 255) }
		for i, c in colors do
			task.delay((i - 1) * 0.07, function()
				ring(at, c, 5 + i * 2, 0.6, true)
			end)
		end
		burst(
			at,
			colors,
			18,
			{ size = NumberSequence.new(0.45, 0), gravity = 5, life = NumberRange.new(0.6, 1) }
		)
	end,
}

-- Plays a shovel's impact at `position` (nothing for an unknown kind).
function ImpactFx.play(kind: string?, position: Vector3)
	local fn = kind and KINDS[kind]
	if fn then
		fn(position)
	end
end

-- Every kind (tests).
function ImpactFx.kinds(): { string }
	local list = {}
	for kind in KINDS do
		table.insert(list, kind)
	end
	return list
end

return ImpactFx
