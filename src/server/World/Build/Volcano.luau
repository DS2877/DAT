--!strict
-- The Volcano: a huge cone with a glowing crater, a smoke plume and lava
-- falls down its face; a basalt highland with lava rivers (a stone bridge
-- where the path crosses), a lava lake, a giant skull rock with burning
-- eyes, basalt column formations, glowing crystal clusters, obsidian
-- spikes, charred trees, steam vents, falling ash and rising embers.

local Kit = require(script.Parent.Kit)
local TerrainBuilder = require(script.Parent.Terrain)

local L = Kit.L
local part, hex = Kit.part, Kit.hex

local Volcano = {}

local LAVA = hex("#FF6A1A")
local DARK = hex("#2A2224")

local level = L.highlandHeight

local function at(x: number, z: number): Vector3?
	return Kit.onLevel(x, z, level, 4)
end

local function steamVent(parent: Instance, base: Vector3)
	local vent = part(parent, {
		name = "SteamVent",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.6, 3.4, 3.4),
		cframe = CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = DARK,
		material = Enum.Material.Basalt,
	})
	local glow = part(parent, {
		name = "VentGlow",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, 2, 2),
		cframe = CFrame.new(base + Vector3.new(0, 1.35, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = LAVA,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(220, 214, 208)
	smoke.Opacity = 0.22
	smoke.RiseVelocity = 9
	smoke.Size = 5
	smoke.Parent = glow
	Kit.addObstacle(base, 3.5)
	local _ = vent
end

local function spike(parent: Instance, base: Vector3, rng: Random)
	local h = rng:NextNumber(5, 12)
	part(parent, {
		name = "Obsidian",
		className = "WedgePart",
		size = Vector3.new(rng:NextNumber(1.8, 3), h, rng:NextNumber(2, 3.4)),
		cframe = CFrame.new(base + Vector3.new(0, h / 2 - 0.8, 0))
			* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)),
		color = hex("#1C1A24"),
		material = Enum.Material.Glass,
		reflectance = 0.2,
	})
	Kit.addObstacle(base, 2.6)
end

local function crystals(parent: Instance, base: Vector3, rng: Random)
	local color = if rng:NextNumber() < 0.5 then hex("#FF8A3D") else hex("#C77DFF")
	for _ = 1, rng:NextInteger(4, 7) do
		local h = rng:NextNumber(3, 8)
		part(parent, {
			name = "Crystal",
			size = Vector3.new(1.2, h, 1.2),
			cframe = CFrame.new(
				base + Vector3.new(rng:NextNumber(-2, 2), h / 2 - 0.6, rng:NextNumber(-2, 2))
			)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
			color = color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
	end
	local anchor = Kit.volume(parent, "CrystalLight", CFrame.new(base + Vector3.new(0, 3, 0)), Vector3.one)
	Kit.light(anchor, color, 16, 1.4)
	Kit.addObstacle(base, 4)
end

local function basaltColumns(parent: Instance, center: Vector3, rng: Random)
	for _ = 1, 22 do
		local h = rng:NextNumber(4, 18)
		local p = center + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-10, 10))
		part(parent, {
			name = "BasaltColumn",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(h, 3.4, 3.4),
			cframe = CFrame.new(p + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			color = hex("#3A3336"):Lerp(hex("#4E4548"), rng:NextNumber()),
			material = Enum.Material.Basalt,
		})
	end
	Kit.addObstacle(center, 15)
end

local function deadTree(parent: Instance, base: Vector3, rng: Random)
	local h = rng:NextNumber(9, 14)
	part(parent, {
		name = "DeadTrunk",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(h, 1.2, 1.2),
		cframe = CFrame.new(base + Vector3.new(0, h / 2 - 0.5, 0))
			* CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, math.rad(90)),
		color = hex("#2B2422"),
		material = Enum.Material.Wood,
	})
	for _ = 1, 3 do
		local y = rng:NextNumber(h * 0.5, h * 0.9)
		local a = rng:NextNumber(0, 6.28)
		local from = base + Vector3.new(0, y, 0)
		local to = from + Vector3.new(math.cos(a) * 4, rng:NextNumber(1.5, 3.5), math.sin(a) * 4)
		part(parent, {
			name = "DeadBranch",
			size = Vector3.new(0.6, 0.6, (to - from).Magnitude),
			cframe = CFrame.lookAt((from + to) / 2, to),
			color = hex("#2B2422"),
			material = Enum.Material.Wood,
			canCollide = false,
		})
	end
	Kit.addObstacle(base, 2)
end

local function skullRock(parent: Instance, base: Vector3)
	local model = Instance.new("Model")
	model.Name = "SkullRock"
	local bone = hex("#5A5050")
	Kit.ellipsoid(model, {
		name = "Skull",
		size = Vector3.new(36, 30, 32),
		cframe = CFrame.new(base + Vector3.new(0, 12, 0)),
		color = bone,
		material = Enum.Material.Basalt,
	})
	Kit.ellipsoid(model, {
		name = "Jaw",
		size = Vector3.new(26, 10, 22),
		cframe = CFrame.new(base + Vector3.new(0, 1, 6)),
		color = bone:Lerp(Color3.new(0, 0, 0), 0.15),
		material = Enum.Material.Basalt,
	})
	for _, x in { -7.5, 7.5 } do
		Kit.ellipsoid(model, {
			name = "EyeSocket",
			size = Vector3.new(9, 9, 6),
			cframe = CFrame.new(base + Vector3.new(x, 15, 14.2)),
			color = hex("#140F10"),
			material = Enum.Material.Basalt,
		})
		local eye = part(model, {
			name = "Eye",
			shape = Enum.PartType.Ball,
			size = Vector3.new(3.4, 3.4, 3.4),
			cframe = CFrame.new(base + Vector3.new(x, 15, 16.6)),
			color = LAVA,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		Kit.light(eye, LAVA, 26, 2.4)
		local fire = Kit.volume(model, "EyeFire", CFrame.new(base + Vector3.new(x, 17, 16)), Vector3.one)
		Kit.fire(fire, 4, LAVA)
	end
	part(model, {
		name = "Nose",
		className = "WedgePart",
		size = Vector3.new(5, 5, 3),
		cframe = CFrame.new(base + Vector3.new(0, 8.5, 15.6)) * CFrame.Angles(0, math.rad(180), 0),
		color = hex("#140F10"),
		material = Enum.Material.Basalt,
	})
	for i = -3, 3 do
		part(model, {
			name = "Tooth",
			size = Vector3.new(2.6, 3.4, 1.6),
			cframe = CFrame.new(base + Vector3.new(i * 3, 4, 16.4)),
			color = hex("#D8D0C0"),
			material = Enum.Material.Limestone,
		})
	end
	-- Lava pooling from the mouth.
	local lava = part(model, {
		name = "MouthLava",
		size = Vector3.new(18, 0.4, 10),
		cframe = CFrame.new(base + Vector3.new(0, 0.3, 22)),
		color = LAVA,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	Kit.light(lava, LAVA, 24, 2)
	model.Parent = parent
	Kit.addObstacle(base + Vector3.new(0, 0, 6), 24)
end

-- Glow along the lava streams painted down the cone (see Terrain.luau).
local function lavaFallLights(parent: Instance, angle: number)
	local v = L.volcano
	local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
	for r = 30, v.radius - 10, 36 do
		local x, z = v.x + dir.X * r, v.z + dir.Z * r
		local y = Kit.groundY(x, z)
		if y then
			local anchor = Kit.volume(parent, "LavaFallLight", CFrame.new(x, y + 3, z), Vector3.one)
			Kit.light(anchor, LAVA, 30, 1.8)
		end
	end
end

function Volcano.build(rng: Random)
	local decor = Kit.folder("Volcano", workspace:FindFirstChild("Decor") or Kit.folder("Decor", workspace))
	level = Kit.medianGround({
		Vector2.new(0, -290),
		Vector2.new(-120, -300),
		Vector2.new(120, -330),
		Vector2.new(-60, -380),
		Vector2.new(160, -380),
		Vector2.new(-180, -300),
	}, L.highlandHeight)
	local v = L.volcano

	-- Crater glow, smoke plume, embers.
	local peakY = (Kit.groundY(v.x, v.z) or (level + v.height - 14)) + 1
	local glow = part(decor, {
		name = "CraterGlow",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1, 28, 28),
		cframe = CFrame.new(v.x, peakY, v.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = LAVA,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	Kit.light(glow, LAVA, 60, 3)
	local plume = Instance.new("Smoke")
	plume.Color = Color3.fromRGB(80, 74, 74)
	plume.Opacity = 0.4
	plume.RiseVelocity = 14
	plume.Size = 40
	plume.TimeScale = 0.5
	plume.Parent = glow
	local embers = Instance.new("Fire")
	embers.Size = 24
	embers.Heat = 25
	embers.Color = LAVA
	embers.SecondaryColor = hex("#FFD54A")
	embers.Parent = glow
	for _, a in { math.rad(-25), math.rad(18), math.rad(48) } do
		lavaFallLights(decor, a)
	end

	-- Warm light and smoke along the lava rivers; a bridge where the path
	-- crosses one.
	for _, river in L.lavaRivers do
		for i, q in TerrainBuilder.along(river, 16) do
			local anchor = Kit.volume(decor, "LavaLight", CFrame.new(q.X, level + 2, q.Y), Vector3.one)
			Kit.light(anchor, LAVA, 22, 1.6)
			if i % 2 == 0 then
				local heat =
					Kit.volume(decor, "LavaHeat", CFrame.new(q.X, level + 1, q.Y), Vector3.new(5, 1, 5))
				Kit.emitter(heat, {
					color = hex("#FF9A4A"),
					color2 = hex("#FFD54A"),
					rate = 3,
					lifetime = NumberRange.new(1.5, 2.5),
					size = NumberSequence.new(0.3, 0),
					speed = NumberRange.new(3, 6),
					lightEmission = 1,
					spread = Vector2.new(25, 25),
				})
			end
			Kit.addObstacle(Vector3.new(q.X, level, q.Y), 6)
		end
	end
	local crossing = Vector2.new(47, -320)
	local bridgeY = Kit.groundOr(crossing.X + 9, crossing.Y, level)
	part(decor, {
		name = "LavaBridge",
		size = Vector3.new(18, 1.4, 10),
		cframe = CFrame.new(crossing.X, bridgeY + 0.4, crossing.Y),
		color = hex("#5A4E4C"),
		material = Enum.Material.Cobblestone,
	})
	for _, dz in { -4.6, 4.6 } do
		part(decor, {
			name = "LavaBridgeRail",
			size = Vector3.new(18, 1.4, 0.8),
			cframe = CFrame.new(crossing.X, bridgeY + 1.6, crossing.Y + dz),
			color = hex("#3A3336"),
			material = Enum.Material.Cobblestone,
		})
	end

	-- The lava lake.
	local lake = L.lavaLake
	local lakeGlow = Kit.volume(decor, "LakeGlow", CFrame.new(lake.x, level + 3, lake.z), Vector3.one)
	Kit.light(lakeGlow, LAVA, 50, 2.5)
	local bubbles = Kit.volume(
		decor,
		"LavaBubbles",
		CFrame.new(lake.x, level, lake.z),
		Vector3.new(lake.radius * 1.4, 1, lake.radius * 1.4)
	)
	Kit.emitter(bubbles, {
		color = hex("#FFB04A"),
		rate = 6,
		lifetime = NumberRange.new(0.6, 1),
		size = NumberSequence.new(1.6, 0),
		speed = NumberRange.new(1, 3),
		lightEmission = 1,
	})
	Kit.addObstacle(Vector3.new(lake.x, level, lake.z), lake.radius + 6)

	local skull = L.skullRock
	skullRock(decor, Vector3.new(skull.x, Kit.groundOr(skull.x, skull.z, level) - 2, skull.z))

	for _, c in { { 168, -332 }, { -200, -290 } } do
		local p = at(c[1], c[2])
		if p then
			basaltColumns(decor, p, rng)
		end
	end
	for _, c in { { -40, -270 }, { 30, -296 }, { 150, -280 }, { -150, -330 }, { 100, -380 }, { -110, -280 } } do
		local p = at(c[1], c[2])
		if p then
			steamVent(decor, p)
		end
	end

	-- Scatter: boulders, obsidian spikes, crystal clusters, dead trees.
	for _ = 1, 90 do
		local x, z = rng:NextNumber(-230, 230), rng:NextNumber(-405, -262)
		local p = at(x, z)
		if p and Kit.clearOfObstacles(x, z, 3) and math.abs(z + 324) > 8 then
			local roll = rng:NextNumber()
			if roll < 0.35 then
				Kit.rock(decor, p, rng:NextNumber(0.9, 2.2), rng, hex("#3A3232"), Enum.Material.Basalt)
			elseif roll < 0.6 then
				spike(decor, p, rng)
			elseif roll < 0.78 then
				crystals(decor, p, rng)
			else
				deadTree(decor, p, rng)
			end
		end
	end

	-- Path markers: braziers.
	for _, line in L.paths.Volcano do
		for i, q in TerrainBuilder.along(line, 26) do
			if i > 1 then
				local p = at(q.X, q.Y + (if i % 2 == 0 then 6 else -6))
				if p then
					Kit.torch(decor, p)
				end
			end
		end
	end

	-- Falling ash and rising embers over the whole highland.
	local ash = Kit.volume(decor, "Ash", CFrame.new(0, level + 45, -335), Vector3.new(460, 4, 170))
	Kit.emitter(ash, {
		color = hex("#8A8282"),
		color2 = hex("#5A5252"),
		rate = 26,
		lifetime = NumberRange.new(8, 12),
		size = NumberSequence.new(0.35, 0.25),
		speed = NumberRange.new(1, 2),
		acceleration = Vector3.new(0.5, -3, 0),
		rotSpeed = NumberRange.new(-60, 60),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0.2),
			NumberSequenceKeypoint.new(1, 0.5),
		}),
		direction = Enum.NormalId.Bottom,
	})
	local rising = Kit.volume(decor, "Embers", CFrame.new(0, level + 2, -335), Vector3.new(460, 2, 170))
	Kit.emitter(rising, {
		color = hex("#FF8A3D"),
		color2 = hex("#FFD54A"),
		rate = 22,
		lifetime = NumberRange.new(3, 5),
		size = NumberSequence.new(0.3, 0),
		speed = NumberRange.new(3, 6),
		lightEmission = 1,
		acceleration = Vector3.new(0.6, 1, 0),
		spread = Vector2.new(20, 20),
	})
end

return Volcano
