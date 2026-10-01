--!strict
-- The Mega Dig excavation (MegaDigService drives it):
--   * a big layered mound of the area's own ground, dug away layer by layer
--   * a giant treasure chest buried inside that rises out as it's dug out,
--     glowing brighter and brighter
--   * spoil heaps around the pit that grow with every hit
--   * a rope fence on posts with lanterns, pickaxes, crates and a sign
--   * a soft golden beam of light into the sky (seen across the island)
-- `update(progress)` moves everything to a progress (0..1); `reveal()` is
-- the dug-out moment; `remove(collapsed)` fades the site away.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MegaDig = require(ReplicatedStorage.Shared.Config.MegaDig)
local TreasureBuilder = require(ReplicatedStorage.Shared.Builders.TreasureBuilder)
local Kit = require(script.Parent.Kit)

local part, hex = Kit.part, Kit.hex

local MegaDigSite = {}

-- The ground the mound is made of, per area.
local SOIL: { [string]: { color: string, dark: string, material: Enum.Material } } = {
	Beach = { color = "#D9B97A", dark = "#B8945A", material = Enum.Material.Sand },
	Jungle = { color = "#7A5232", dark = "#5A3A22", material = Enum.Material.Ground },
	Ruins = { color = "#C9A66E", dark = "#A8854F", material = Enum.Material.Sandstone },
	Volcano = { color = "#5A4842", dark = "#3E302C", material = Enum.Material.Basalt },
}
local WOOD = hex("#7A5230")
local WOOD_DARK = hex("#5B3A22")
local GOLD = hex("#FFC933")
local ROPE = hex("#C9A46A")

export type Handle = {
	model: Model,
	center: BasePart,
	update: (progress: number) -> (),
	reveal: () -> (),
	remove: (collapsed: boolean) -> (),
}

local function tween(instance: Instance, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(
			instance,
			TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			goals
		)
		:Play()
end

function MegaDigSite.build(position: Vector3, areaId: string): Handle
	local r = MegaDig.radius
	local soil = SOIL[areaId] or SOIL.Beach
	local dirt, dirtDark = hex(soil.color), hex(soil.dark)
	local model = Instance.new("Model")
	model.Name = "MegaDigSite"
	local rng = Random.new()

	-- The anchor everything is measured from (and what clients aim at).
	local center = part(model, {
		name = "Center",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(position),
		transparency = 1,
		canCollide = false,
		castShadow = false,
	})
	model.PrimaryPart = center

	-- The pit floor: dark churned ground around the mound.
	Kit.ellipsoid(model, {
		name = "PitFloor",
		size = Vector3.new(2 * r + 8, 1.2, 2 * r + 8),
		cframe = CFrame.new(position + Vector3.new(0, -0.35, 0)),
		color = dirtDark,
		material = soil.material,
		canCollide = false,
	})

	-- The mound: three layers, each dug away in turn, plus lumps.
	local layers: { { part: BasePart, home: CFrame, size: Vector3, goneAt: number } } = {}
	local function layer(name: string, size: Vector3, height: number, untilProgress: number)
		local cframe = CFrame.new(position + Vector3.new(0, height, 0))
		local p = Kit.ellipsoid(model, {
			name = name,
			size = size,
			cframe = cframe,
			color = dirt,
			material = soil.material,
		})
		table.insert(layers, { part = p, home = cframe, size = size, goneAt = untilProgress })
	end
	layer("Layer1", Vector3.new(2 * r, 7.5, 2 * r), 0.8, 1)
	layer("Layer2", Vector3.new(1.5 * r, 7.5, 1.5 * r), 3.6, 0.66)
	layer("Layer3", Vector3.new(0.95 * r, 6.5, 0.95 * r), 6.4, 0.33)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local d = r * rng:NextNumber(0.4, 0.75)
		local s = rng:NextNumber(3.2, 4.6)
		local cframe =
			CFrame.new(position + Vector3.new(math.cos(a) * d, rng:NextNumber(2.4, 4.2), math.sin(a) * d))
		local lump = Kit.ellipsoid(model, {
			name = "Lump",
			size = Vector3.new(s * 1.3, s * 0.8, s),
			cframe = cframe * CFrame.Angles(0, a, 0),
			color = if i % 2 == 0 then dirt else dirtDark,
			material = soil.material,
		})
		table.insert(layers, {
			part = lump,
			home = lump.CFrame,
			size = lump.Size,
			goneAt = if i % 3 == 0 then 0.33 elseif i % 3 == 1 then 0.66 else 1,
		})
	end

	-- The treasure chest, buried in the middle.
	local chest = TreasureBuilder.build("PirateTreasureChest")
	chest.Name = "MegaChest"
	TreasureBuilder.scaleTo(chest, 6)
	for _, d in chest:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local chestRoot = chest.PrimaryPart :: BasePart
	local buried = CFrame.new(position + Vector3.new(0, -3.6, 0))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	chest:PivotTo(buried)
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Range = 18
	glow.Brightness = 0.4
	glow.Parent = chestRoot
	chest.Parent = model

	-- Spoil heaps around the pit: the dug-out dirt piles up here.
	local heaps: { { part: BasePart, base: Vector3, scale: number } } = {}
	for i = 1, 6 do
		local a = (i + 0.5) / 6 * math.pi * 2
		for j = 1, 2 do
			local d = r + 4 + j * 1.6
			local side = (j - 1.5) * 0.18
			local at = position + Vector3.new(math.cos(a + side) * d, 0, math.sin(a + side) * d)
			local heap = Kit.ellipsoid(model, {
				name = "Heap",
				size = Vector3.new(2.5, 1, 2.5),
				cframe = CFrame.new(at),
				color = if (i + j) % 2 == 0 then dirt else dirtDark,
				material = soil.material,
				canCollide = false,
			})
			table.insert(heaps, { part = heap, base = at, scale = if j == 1 then 1.25 else 0.85 })
		end
	end

	-- The fence: posts with lanterns and ropes between them.
	local posts = 8
	local postTops = {}
	for i = 1, posts do
		local a = i / posts * math.pi * 2
		local at = position + Vector3.new(math.cos(a) * (r + 10), 0, math.sin(a) * (r + 10))
		part(model, {
			name = "Post",
			size = Vector3.new(0.7, 6, 0.7),
			cframe = CFrame.new(at + Vector3.new(0, 2.4, 0)),
			color = WOOD_DARK,
			material = Enum.Material.Wood,
		})
		local lantern = part(model, {
			name = "Lantern",
			size = Vector3.new(0.9, 1.1, 0.9),
			cframe = CFrame.new(at + Vector3.new(0, 5.9, 0)),
			color = hex("#FFB347"),
			material = Enum.Material.Neon,
			canCollide = false,
			castShadow = false,
		})
		Kit.light(lantern, hex("#FFB347"), 14, 1.2)
		table.insert(postTops, at + Vector3.new(0, 4.4, 0))
	end
	for i = 1, posts do
		local a, b = postTops[i], postTops[i % posts + 1]
		local mid = (a + b) / 2 - Vector3.new(0, 0.5, 0)
		local along = (b - a).Unit
		part(model, {
			name = "Rope",
			size = Vector3.new((b - a).Magnitude, 0.25, 0.25),
			cframe = CFrame.fromMatrix(mid, along, Vector3.new(0, 1, 0)),
			color = ROPE,
			material = Enum.Material.Fabric,
			canCollide = false,
			castShadow = false,
		})
	end

	-- Props: pickaxes stuck in the heaps, crates by the fence.
	for i = 1, 3 do
		local heap = heaps[i * 4 - 1].base
		local tilt =
			CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), rng:NextNumber(0, math.pi), math.rad(18))
		local handle = CFrame.new(heap + Vector3.new(0, 1.8, 0)) * tilt
		part(model, {
			name = "PickHandle",
			size = Vector3.new(0.3, 4, 0.3),
			cframe = handle,
			color = WOOD,
			material = Enum.Material.Wood,
			canCollide = false,
		})
		part(model, {
			name = "PickHead",
			size = Vector3.new(2.4, 0.35, 0.35),
			cframe = handle * CFrame.new(0, 1.9, 0),
			color = hex("#8D99A6"),
			material = Enum.Material.Metal,
			canCollide = false,
		})
	end
	for i = 1, 2 do
		local a = (i * 3 + 0.5) / posts * math.pi * 2
		local at = position + Vector3.new(math.cos(a) * (r + 12), 0, math.sin(a) * (r + 12))
		part(model, {
			name = "Crate",
			size = Vector3.new(2.4, 2.4, 2.4),
			cframe = CFrame.new(at + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, a, 0),
			color = hex("#A0703C"),
			material = Enum.Material.WoodPlanks,
		})
	end

	-- A soft beam of golden light, and sparkles rising out of the pit.
	local base = Instance.new("Attachment")
	base.Name = "BeamBase"
	base.Parent = center
	local top = Instance.new("Attachment")
	top.Name = "BeamTop"
	top.Position = Vector3.new(0, 240, 0)
	top.Parent = center
	local beam = Instance.new("Beam")
	beam.Attachment0 = base
	beam.Attachment1 = top
	beam.Width0 = 7
	beam.Width1 = 2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Color = ColorSequence.new(hex("#FFE08A"), hex("#FFF6D8"))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.6, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = center
	local sparkles =
		Kit.volume(model, "Sparkles", CFrame.new(position + Vector3.new(0, 1, 0)), Vector3.new(r, 1, r))
	local rising = Kit.emitter(sparkles, {
		color = GOLD,
		color2 = Color3.new(1, 1, 1),
		rate = 6,
		lifetime = NumberRange.new(2, 3.5),
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		speed = NumberRange.new(3, 6),
		lightEmission = 1,
		spread = Vector2.new(12, 12),
	})

	Kit.standingSign(
		model,
		position + Vector3.new(r + 14, 0, 0),
		Vector3.new(1, 0, 0),
		"⛏️ MEGA DIG",
		"Everyone dig! Mythic+ inside",
		GOLD,
		10
	)

	model:SetAttribute("Mega", true)
	model:SetAttribute("Range", MegaDig.digRange)
	model:SetAttribute("Soil", soil.color)

	local shown = -1
	local function update(progress: number)
		-- Move in steps (a tween per hit would be wasteful).
		local step = math.floor(progress * 50) / 50
		if step == shown then
			return
		end
		shown = step
		for _, l in layers do
			if step >= l.goneAt then
				-- This layer is dug away: it sinks into the pit.
				tween(l.part, 1.2, {
					CFrame = l.home - Vector3.new(0, l.size.Y + 1.5, 0),
					Size = l.size * Vector3.new(0.6, 0.4, 0.6),
				})
			end
		end
		for i, h in heaps do
			local grow = (0.2 + step * (0.9 + (i % 3) * 0.15)) * h.scale
			local size = Vector3.new(2.5 + 3.6 * grow, 0.8 + 2.6 * grow, 2.5 + 3.2 * grow)
			tween(h.part, 0.4, { Size = size, CFrame = CFrame.new(h.base + Vector3.new(0, size.Y * 0.3, 0)) })
		end
		-- The chest comes up as the ground around it goes.
		local rise = math.pow(step, 0.8)
		chest:PivotTo(buried + Vector3.new(0, rise * 6.2, 0))
		glow.Brightness = 0.4 + step * 2.6
		rising.Rate = 6 + step * 30
	end

	local function reveal()
		-- Dug out: the chest bursts up and blazes with light.
		chest:PivotTo(buried + Vector3.new(0, 9.5, 0))
		glow.Brightness = 6
		glow.Range = 40
		rising.Rate = 80
		beam.Width0 = 12
	end

	local function remove(collapsed: boolean)
		local fade = if collapsed then 1.5 else 2.5
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				tween(d, fade, { Transparency = 1 })
			elseif d:IsA("ParticleEmitter") or d:IsA("Beam") then
				(d :: any).Enabled = false
			end
		end
		if collapsed then
			chest:PivotTo(buried)
		end
		task.delay(fade + 0.2, function()
			model:Destroy()
		end)
	end

	return { model = model, center = center, update = update, reveal = reveal, remove = remove }
end

return MegaDigSite
