--!strict
-- The Frost Portal to the next world (Config/Worlds), on the beach where it
-- rises into view from the spawn: a heavy stone ring rimmed with ice,
-- snow-capped, hung with icicles and flanked by two stone pillars, on a
-- frosted two-step dais in a field of snowdrifts. Inside it a glowing
-- portal pulls sparkles in and blows snow out at you. A keystone on top
-- holds three gems, one per rebirth, and until Rebirth 3 a sheet of ice
-- seals the portal (PortalController lights the gems, and shatters the ice
-- for players who have opened it). A beam of light rises from the top; a
-- sign and the First Explorers board stand in front.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)

local L = Kit.L
local part, hex = Kit.part, Kit.hex

local Portal = {}

local ICE = hex("#A8E6FF")
local ICE_DEEP = hex("#5CC6F2")
local FROST_STONE = hex("#8FA6B8")
local SNOW = hex("#F4FBFF")
local SEAL_OFF = hex("#3B4A5A")
local STONE_LIGHT = hex("#A9BCCB")
local STONE_DARK = hex("#6F8597")

-- A cluster of ice crystals at `base`.
local function crystals(parent: Instance, base: Vector3, rng: Random, scale: number)
	for i = 1, 3 do
		local height = rng:NextNumber(3, 6) * scale
		local tiltX = rng:NextNumber(-0.35, 0.35)
		local tiltZ = rng:NextNumber(-0.35, 0.35)
		local offset = Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2)) * scale
		part(parent, {
			name = "IceCrystal",
			size = Vector3.new(1.1 * scale, height, 1.1 * scale),
			cframe = CFrame.new(base + offset)
				* CFrame.Angles(tiltX, rng:NextNumber(0, math.pi) + i, tiltZ)
				* CFrame.new(0, height / 2 - 0.4, 0),
			color = if i == 1 then ICE_DEEP else ICE,
			material = Enum.Material.Glass,
			transparency = 0.15,
			reflectance = 0.2,
			canCollide = false,
		})
	end
end

export type Built = {
	model: Model,
	center: Vector3, -- the middle of the ring
	ground: number, -- the top of the dais
	normal: Vector3, -- the way the portal faces (toward the spawn)
}

function Portal.build(rng: Random): Built
	local cfg = Worlds.portal
	local p = L.portal
	local R = cfg.ringRadius
	local groundY = Kit.highestGround(p.x, p.z, 12, L.beachHeight)
	local toSpawn = Vector3.new(L.spawn.x - p.x, 0, L.spawn.z - p.z).Unit
	local n = toSpawn
	local up = Vector3.new(0, 1, 0)
	local right = up:Cross(-n).Unit
	local model = Instance.new("Model")
	model.Name = "FrostPortal"

	local rot = CFrame.Angles(0, 0, math.rad(90)) -- cylinders stand on end

	-- Snow on the sand, and a two-step stone dais.
	for i, patch in { { 0, 0, 36, 32 }, { 6, -4, 26, 22 }, { -7, 5, 24, 26 } } do
		Kit.ellipsoid(model, {
			name = "SnowPatch",
			size = Vector3.new(patch[3], 0.9, patch[4]),
			cframe = CFrame.new(p.x + patch[1], groundY - 0.15 + i * 0.02, p.z + patch[2]),
			color = SNOW,
			material = Enum.Material.Snow,
			canCollide = false,
		})
	end
	part(model, {
		name = "DaisLow",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.4, 30, 30),
		cframe = CFrame.new(p.x, groundY + 0.5, p.z) * rot,
		color = STONE_DARK,
		material = Enum.Material.Slate,
	})
	part(model, {
		name = "Dais",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.4, 24, 24),
		cframe = CFrame.new(p.x, groundY + 1.5, p.z) * rot,
		color = FROST_STONE,
		material = Enum.Material.Slate,
	})
	local daisTop = groundY + 2.2
	part(model, {
		name = "DaisSnow",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, 21, 21),
		cframe = CFrame.new(p.x, daisTop + 0.02, p.z) * rot,
		color = SNOW,
		material = Enum.Material.Snow,
		canCollide = false,
	})
	local origin = Vector3.new(p.x, daisTop, p.z)

	-- Snowdrifts around the back and sides (the front stays open).
	for i = 1, 11 do
		local a = i / 11 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local out = right * math.cos(a) + n * math.sin(a)
		if out:Dot(n) < 0.5 then
			local d = rng:NextNumber(14, 18)
			local size = Vector3.new(rng:NextNumber(6, 10), rng:NextNumber(2, 3.6), rng:NextNumber(4, 7))
			Kit.ellipsoid(model, {
				name = "Snowdrift",
				size = size,
				cframe = CFrame.fromMatrix(
					Vector3.new(p.x, groundY + 0.2, p.z) + out * d,
					Vector3.new(-out.Z, 0, out.X),
					up
				),
				color = SNOW,
				material = Enum.Material.Snow,
			})
		end
	end

	-- The stone ring with its ice rim, standing on a cradle.
	local center = origin + up * (R + 1.4)
	local segments = 30
	local segLength = 2 * math.pi * R / segments + 0.45
	local function onRing(a: number, radius: number): (Vector3, Vector3, Vector3)
		local radial = right * math.cos(a) + up * math.sin(a)
		local tangent = -right * math.sin(a) + up * math.cos(a)
		return center + radial * radius, tangent, radial
	end
	for i = 0, segments - 1 do
		local a = (i + 0.5) / segments * math.pi * 2
		local at, tangent, radial = onRing(a, R)
		part(model, {
			name = "Ring",
			size = Vector3.new(segLength, 3, 3.6),
			cframe = CFrame.fromMatrix(at, tangent, radial),
			color = if i % 2 == 0 then FROST_STONE else STONE_LIGHT,
			material = Enum.Material.Slate,
		})
		local rimAt = onRing(a, R - 1.9)
		part(model, {
			name = "IceRim",
			size = Vector3.new(segLength * 0.86, 1, 4),
			cframe = CFrame.fromMatrix(rimAt, tangent, radial),
			color = ICE,
			material = Enum.Material.Glass,
			transparency = 0.1,
			reflectance = 0.25,
		})
		local glowAt = onRing(a, R - 2.5)
		part(model, {
			name = "RimGlow",
			size = Vector3.new(segLength * 0.86, 0.3, 4.1),
			cframe = CFrame.fromMatrix(glowAt, tangent, radial),
			color = ICE_DEEP,
			material = Enum.Material.Neon,
			canCollide = false,
			castShadow = false,
		})
		local degrees = math.deg(a)
		if degrees > 22 and degrees < 158 then
			-- Snow lies on the top of the ring.
			local capAt = onRing(a, R + 1.9)
			part(model, {
				name = "SnowCap",
				size = Vector3.new(segLength, 0.9, 3.9),
				cframe = CFrame.fromMatrix(capAt, tangent, radial),
				color = SNOW,
				material = Enum.Material.Snow,
				canCollide = false,
			})
		end
		if degrees > 48 and degrees < 132 and i % 2 == 0 then
			-- Icicles hang inside the top of the ring.
			local length = rng:NextNumber(1.2, 3)
			local hangAt = onRing(a, R - 2.6)
			part(model, {
				name = "Icicle",
				size = Vector3.new(0.55, length, 0.55),
				cframe = CFrame.new(hangAt - up * (length / 2)) * CFrame.Angles(0, math.rad(45), 0),
				color = ICE,
				material = Enum.Material.Glass,
				transparency = 0.15,
				canCollide = false,
			})
		end
	end
	part(model, {
		name = "Cradle",
		size = Vector3.new(9, 2.4, 5),
		cframe = CFrame.fromMatrix(origin + up * 1.2, right, up),
		color = STONE_DARK,
		material = Enum.Material.Slate,
	})

	-- Two pillars flanking the ring, crowned with ice.
	for _, side in { -1, 1 } do
		local height = R + 4.5
		local base = origin + right * side * (R + 3.4)
		part(model, {
			name = "Pillar",
			size = Vector3.new(3.4, height, 3.4),
			cframe = CFrame.fromMatrix(base + up * (height / 2), right, up),
			color = FROST_STONE,
			material = Enum.Material.Slate,
		})
		part(model, {
			name = "PillarCap",
			size = Vector3.new(4.2, 1, 4.2),
			cframe = CFrame.fromMatrix(base + up * (height + 0.5), right, up),
			color = SNOW,
			material = Enum.Material.Snow,
		})
		part(model, {
			name = "PillarCrystal",
			size = Vector3.new(1.8, 3.2, 1.8),
			cframe = CFrame.new(base + up * (height + 2.4))
				* CFrame.Angles(0, math.rad(45), math.rad(side * 8)),
			color = ICE,
			material = Enum.Material.Glass,
			transparency = 0.1,
			reflectance = 0.3,
		})
		-- A low wall joins each pillar to the ring.
		part(model, {
			name = "Brace",
			size = Vector3.new(3.6, 2.2, 2.6),
			cframe = CFrame.fromMatrix(center + right * side * (R + 1.4), right, up),
			color = STONE_DARK,
			material = Enum.Material.Slate,
		})
	end

	-- The keystone on top, with a gem for each rebirth on its front.
	local keyAt = center + up * (R + 1)
	local keystone = part(model, {
		name = "Keystone",
		size = Vector3.new(8, 4.4, 4.4),
		cframe = CFrame.fromMatrix(keyAt, right, up),
		color = STONE_LIGHT,
		material = Enum.Material.Slate,
	})
	part(model, {
		name = "KeystoneSnow",
		size = Vector3.new(8.4, 0.8, 4.8),
		cframe = CFrame.fromMatrix(keyAt + up * 2.5, right, up),
		color = SNOW,
		material = Enum.Material.Snow,
		canCollide = false,
	})
	local need = Worlds.next.requiredRebirths
	for i = 1, 3 do
		local x = (i - 2) * 2.5
		local gem = part(model, {
			name = "Seal" .. i,
			size = Vector3.new(1.5, 1.5, 0.7),
			cframe = CFrame.fromMatrix(
				keyAt + right * x + n * 2.25 - up * 0.2,
				(right + up).Unit,
				(up - right).Unit
			),
			color = SEAL_OFF,
			material = Enum.Material.Slate,
		})
		gem:SetAttribute("Seal", i)
		gem:SetAttribute("Need", need)
	end
	local _ = keystone

	-- The portal: a glowing core with a shimmer on both sides, the sheet of
	-- ice that seals it, and its particles (the client switches them).
	local disc = R - 2.4
	local facing = CFrame.fromMatrix(center, n, up) -- X = the way it faces
	local core = part(model, {
		name = "PortalCore",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.5, 2 * disc, 2 * disc),
		cframe = facing,
		color = ICE_DEEP,
		material = Enum.Material.Neon,
		transparency = 0.25,
		canCollide = false,
		castShadow = false,
	})
	for _, side in { -1, 1 } do
		part(model, {
			name = "PortalShimmer",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.2, 2 * disc - 0.4, 2 * disc - 0.4),
			cframe = facing * CFrame.new(side * 0.4, 0, 0),
			color = hex("#E8FBFF"),
			material = Enum.Material.ForceField,
			canCollide = false,
			castShadow = false,
		})
	end
	part(model, {
		name = "IceSheet",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1, 2 * disc + 0.6, 2 * disc + 0.6),
		cframe = facing,
		color = hex("#D6F5FF"),
		material = Enum.Material.Ice,
		transparency = 0.15,
		reflectance = 0.2,
		canCollide = false,
		castShadow = false,
	})
	Kit.light(core, ICE_DEEP, 36, 3)
	-- Sparkles pulled into the middle.
	local swirlHost = part(model, {
		name = "SwirlHost",
		size = Vector3.new(1.2, 2 * disc, 2 * disc),
		cframe = facing,
		transparency = 1,
		canCollide = false,
		castShadow = false,
	})
	local swirl = Instance.new("ParticleEmitter")
	swirl.Name = "Swirl"
	swirl.Shape = Enum.ParticleEmitterShape.Sphere
	swirl.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	swirl.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	swirl.Color = ColorSequence.new(Color3.new(1, 1, 1), ICE)
	swirl.LightEmission = 1
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	swirl.Transparency = NumberSequence.new(0.1, 0.6)
	swirl.Lifetime = NumberRange.new(2, 2.6)
	swirl.Speed = NumberRange.new(3.5, 4.5)
	swirl.RotSpeed = NumberRange.new(-120, 120)
	swirl.Rate = 6
	swirl.Parent = swirlHost
	-- Snow blowing out of the other world, toward you.
	local wind = Instance.new("ParticleEmitter")
	wind.Name = "SnowWind"
	wind.EmissionDirection = Enum.NormalId.Right -- the core's X axis = the way it faces
	wind.Color = ColorSequence.new(Color3.new(1, 1, 1))
	wind.LightEmission = 0.4
	wind.Size = NumberSequence.new(0.3)
	wind.Transparency = NumberSequence.new(0, 0.8)
	wind.Lifetime = NumberRange.new(2.5, 3.5)
	wind.Speed = NumberRange.new(6, 11)
	wind.SpreadAngle = Vector2.new(22, 22)
	wind.Acceleration = Vector3.new(0, -1.5, 0)
	wind.Drag = 0.4
	wind.Rate = 14
	wind.Enabled = false
	wind.Parent = core

	-- A beam of light rising from the keystone, seen across the island.
	local beamBase = Instance.new("Attachment")
	beamBase.Name = "BeamBase"
	beamBase.Parent = keystone
	local beamTop = Instance.new("Attachment")
	beamTop.Name = "BeamTop"
	beamTop.Position = Vector3.new(0, 220, 0)
	beamTop.Parent = keystone
	local beam = Instance.new("Beam")
	beam.Attachment0 = beamBase
	beam.Attachment1 = beamTop
	beam.Width0 = 6
	beam.Width1 = 2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(ICE, Color3.new(1, 1, 1))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.7, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = keystone

	-- Ice crystals around the dais, and falling snow.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.3
		local at = Vector3.new(p.x + math.cos(a) * 16, groundY + 1.2, p.z + math.sin(a) * 16)
		if (at - (origin + n * 16)).Magnitude > 8 then
			crystals(model, at, rng, if i % 2 == 0 then 1.2 else 0.8)
		end
	end
	local snow =
		Kit.volume(model, "Snowfall", CFrame.new(center + Vector3.new(0, 18, 0)), Vector3.new(36, 1, 36))
	Kit.emitter(snow, {
		color = SNOW,
		rate = 18,
		lifetime = NumberRange.new(7, 9),
		size = NumberSequence.new(0.35),
		speed = NumberRange.new(2, 3),
		acceleration = Vector3.new(0.4, -0.6, 0),
		direction = Enum.NormalId.Bottom,
		spread = Vector2.new(15, 15),
		transparency = NumberSequence.new(0.1, 0.6),
		lightEmission = 0.3,
	})

	-- The sign (the client writes your progress on its small board) and
	-- the First Explorers board, either side of the step.
	local w = Worlds.next
	local home = Theme.frost -- in Frostbite Peaks it leads back to the island
	Kit.standingSign(
		model,
		origin + n * 16 - right * 11 - Vector3.new(0, 2, 0),
		n,
		if home then "🏝️ ISLAND PORTAL" else "❄️ FROST PORTAL",
		if home
			then "Back to " .. Worlds.home.name
			else string.format("Rebirth %d to enter", w.requiredRebirths),
		hex(if home then Worlds.home.color else w.color),
		11
	)
	local boardFrame =
		CFrame.fromMatrix(origin + n * 15 + right * 12 + Vector3.new(0, 3.5, 0), right, Vector3.yAxis)
	local board = part(model, {
		name = "ExplorersBoard",
		size = Vector3.new(10, 9, 0.6),
		cframe = boardFrame,
		color = hex("#3E5A73"),
		material = Enum.Material.Slate,
	})
	for _, side in { -1, 1 } do
		part(model, {
			name = "BoardLeg",
			size = Vector3.new(0.7, 4, 0.7),
			cframe = boardFrame * CFrame.new(side * 4.4, -6, 0),
			color = FROST_STONE,
			material = Enum.Material.Slate,
		})
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Explorers"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.CanvasSize = Vector2.new(400, 360)
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 64)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.Text = "❄️ FIRST EXPLORERS"
	title.TextScaled = true
	title.TextColor3 = hex(w.color)
	title.Parent = gui
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(20, 70)
	list.Size = UDim2.new(1, -40, 1, -84)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.FredokaOne
	list.Text = "Be the first!\nReach Rebirth " .. w.requiredRebirths
	list.TextScaled = true
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Parent = gui

	model:SetAttribute("Center", center)
	model:SetAttribute("Normal", n)
	model:SetAttribute("Ground", daisTop)
	model.Parent = workspace
	Kit.addObstacle(Vector3.new(p.x, 0, p.z), 28)
	return { model = model, center = center, ground = daisTop, normal = n }
end

return Portal
