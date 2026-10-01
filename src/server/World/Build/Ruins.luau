--!strict
-- The Ancient Ruins: a desert plateau with a grand stepped pyramid (stairs,
-- banners, braziers, a glowing gem on top), a paved plaza, an avenue of
-- columns with giant stone heads, an oasis with palms, obelisks with
-- glowing glyphs, arches, broken walls, fallen pillars, cacti, a sunken
-- treasure chamber, drifting sand and dust.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TreasureBuilder = require(ReplicatedStorage.Shared.Builders.TreasureBuilder)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local TerrainBuilder = require(script.Parent.Terrain)

local L = Kit.L
local part, hex = Kit.part, Kit.hex

local Ruins = {}

local STONE = hex("#D2BC8E")
local STONE_DARK = hex("#B09A6E")
local GLYPH = hex("#4FD1C5")

local level = L.plateauHeight

local function at(x: number, z: number): Vector3?
	return Kit.onLevel(x, z, level, 4)
end

local function distanceToPaths(x: number, z: number): number
	local best = math.huge
	local p = Vector2.new(x, z)
	for _, line in L.paths.Ruins do
		for i = 1, #line - 1 do
			local a, b = Vector2.new(line[i][1], line[i][2]), Vector2.new(line[i + 1][1], line[i + 1][2])
			local ab = b - a
			local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
			best = math.min(best, (a + ab * t - p).Magnitude)
		end
	end
	return best
end

local function pyramid(parent: Instance, center: Vector3, size: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Temple"
	local tiers = 6
	local tierH = 7
	for i = 0, tiers - 1 do
		local s = size - i * (size - 18) / tiers
		part(model, {
			name = "TempleTier",
			size = Vector3.new(s, tierH, s),
			cframe = CFrame.new(center + Vector3.new(0, tierH / 2 + i * tierH - 1, 0)),
			color = STONE:Lerp(STONE_DARK, (i % 2) * 0.5),
			material = Enum.Material.Sandstone,
		})
		-- A band of glowing glyphs on every other tier (south face).
		if i % 2 == 1 then
			for k = -2, 2 do
				part(model, {
					name = "TempleGlyph",
					size = Vector3.new(1.4, 1.4, 0.3),
					cframe = CFrame.new(
						center + Vector3.new(k * s / 6, tierH / 2 + i * tierH - 1, s / 2 + 0.1)
					) * CFrame.Angles(0, 0, math.rad(45)),
					color = GLYPH,
					material = Enum.Material.Neon,
					canCollide = false,
					castShadow = false,
				})
			end
		end
	end
	local topY = center.Y + tiers * tierH - 1
	-- Grand stairway up the south face: steep steps that follow the tiers
	-- up to the top platform.
	local rise = topY - center.Y
	local stepH = 1.4
	local count = math.ceil(rise / stepH)
	local topFrontZ = center.Z + (size - (tiers - 1) * (size - 18) / tiers) / 2
	local run = (center.Z + size / 2 + 4 - topFrontZ) / count
	for i = 1, count do
		local h = math.min(i * stepH, rise)
		part(model, {
			name = "TempleStep",
			size = Vector3.new(12, h, run + 0.05),
			cframe = CFrame.new(center.X, center.Y - 1 + h / 2, topFrontZ + (count - i + 0.5) * run),
			color = if i % 2 == 0 then STONE_DARK else STONE_DARK:Lerp(STONE, 0.3),
			material = Enum.Material.Sandstone,
		})
	end
	local stairFoot = topFrontZ + count * run
	for _, side in { -1, 1 } do
		local a = Vector3.new(center.X + side * 7, center.Y + 1, stairFoot)
		local b = Vector3.new(center.X + side * 7, topY + 1, topFrontZ)
		local mid = (a + b) / 2
		part(model, {
			name = "StairRail",
			size = Vector3.new(2, 2, (b - a).Magnitude),
			cframe = CFrame.lookAt(mid, b),
			color = STONE,
			material = Enum.Material.Sandstone,
		})
	end
	-- Shrine on top with the gem.
	for _, c in { { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } } do
		part(model, {
			name = "TopPillar",
			size = Vector3.new(2.2, 10, 2.2),
			cframe = CFrame.new(center + Vector3.new(c[1], topY - center.Y + 5, c[2])),
			color = STONE,
			material = Enum.Material.Sandstone,
		})
	end
	part(model, {
		name = "TopRoof",
		size = Vector3.new(16, 2, 16),
		cframe = CFrame.new(center + Vector3.new(0, topY - center.Y + 11, 0)),
		color = STONE_DARK,
		material = Enum.Material.Sandstone,
	})
	local gem = part(model, {
		name = "TempleGem",
		size = Vector3.new(5, 5, 5),
		cframe = CFrame.new(center + Vector3.new(0, topY - center.Y + 18, 0))
			* CFrame.Angles(math.rad(45), 0, math.rad(45)),
		color = GLYPH,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	gem:SetAttribute("Ambient", "Spin")
	Kit.light(gem, GLYPH, 40, 3)
	-- Braziers on the corners of every second tier.
	for i = 1, tiers - 1, 2 do
		local s = size - i * (size - 18) / tiers
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local bowl = part(model, {
				name = "Brazier",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(1.4, 2.6, 2.6),
				cframe = CFrame.new(
					center + Vector3.new(c[1] * (s / 2 - 2), i * tierH + tierH - 0.3, c[2] * (s / 2 - 2))
				) * CFrame.Angles(0, 0, math.rad(90)),
				color = hex("#3B2A1A"),
				material = Enum.Material.Metal,
			})
			Kit.fire(bowl, 3.4)
			if c[2] > 0 then
				Kit.light(bowl, Color3.fromRGB(255, 160, 70), 18, 1.2)
			end
		end
	end
	-- Banners hanging on the third tier's south face, beside the stairs.
	local bannerTier = 2
	local face = (size - bannerTier * (size - 18) / tiers) / 2 + 0.15
	local bannerY = bannerTier * tierH + tierH / 2 - 1
	for _, x in { -15, 15 } do
		part(model, {
			name = "Banner",
			size = Vector3.new(4.4, tierH - 1, 0.2),
			cframe = CFrame.new(center + Vector3.new(x, bannerY, face)),
			color = if x < 0 then hex("#B5482E") else hex("#2E6FB5"),
			material = Enum.Material.Fabric,
			canCollide = false,
		})
		part(model, {
			name = "BannerSun",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.2, 2.6, 2.6),
			cframe = CFrame.new(center + Vector3.new(x, bannerY + 0.5, face + 0.15))
				* CFrame.Angles(0, math.rad(90), 0),
			color = hex("#FFC933"),
			material = Enum.Material.Metal,
			canCollide = false,
		})
	end
	-- Guardian statues at the foot of the stairs.
	for _, dx in { -14, 14 } do
		local statue = TreasureBuilder.build(if Theme.frost then "FrostKnightStatue" else "AncientStatue")
		TreasureBuilder.scaleTo(statue, 4)
		statue:PivotTo(
			CFrame.new(center + Vector3.new(dx, 4.4, size / 2 + 12)) * CFrame.Angles(0, math.rad(180), 0)
		)
		for _, d in statue:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = STONE_DARK
				d.Material = Enum.Material.Sandstone
				d.CanCollide = d.Transparency < 1
			end
		end
		statue.Parent = model
	end
	local _ = rng
	model.Parent = parent
	Kit.addObstacle(center, size / 2 + 6)
	Kit.addObstacle(Vector3.new(center.X, center.Y, center.Z + size / 2 + 8), 10)
end

-- A giant stone head (moai-like) facing `yaw`.
local function stoneHead(parent: Instance, base: Vector3, yaw: number)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	part(parent, {
		name = "HeadNeck",
		size = Vector3.new(7, 4, 6),
		cframe = cf * CFrame.new(0, 1.5, 0),
		color = STONE_DARK,
		material = Enum.Material.Sandstone,
	})
	part(parent, {
		name = "Head",
		size = Vector3.new(6, 11, 5.4),
		cframe = cf * CFrame.new(0, 8.5, 0),
		color = STONE,
		material = Enum.Material.Sandstone,
	})
	part(parent, {
		name = "Brow",
		size = Vector3.new(6.4, 1.6, 2),
		cframe = cf * CFrame.new(0, 10.6, -2.4),
		color = STONE_DARK,
		material = Enum.Material.Sandstone,
	})
	part(parent, {
		name = "Nose",
		className = "WedgePart",
		size = Vector3.new(1.6, 4, 1.8),
		cframe = cf * CFrame.new(0, 8, -3.4) * CFrame.Angles(0, math.rad(180), 0),
		color = STONE,
		material = Enum.Material.Sandstone,
	})
	for _, x in { -1.6, 1.6 } do
		part(parent, {
			name = "Eye",
			size = Vector3.new(1.2, 0.6, 0.3),
			cframe = cf * CFrame.new(x, 9.4, -2.8),
			color = GLYPH,
			material = Enum.Material.Neon,
			canCollide = false,
		})
	end
	part(parent, {
		name = "Mouth",
		size = Vector3.new(3, 0.5, 0.3),
		cframe = cf * CFrame.new(0, 5.4, -2.75),
		color = STONE_DARK,
		material = Enum.Material.Sandstone,
		canCollide = false,
	})
	Kit.addObstacle(base, 5)
end

local function column(parent: Instance, base: Vector3, height: number, broken: boolean)
	part(parent, {
		name = "ColumnBase",
		size = Vector3.new(4, 1.4, 4),
		cframe = CFrame.new(base + Vector3.new(0, 0.3, 0)),
		color = STONE_DARK,
		material = Enum.Material.Sandstone,
	})
	part(parent, {
		name = "Column",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height, 2.8, 2.8),
		cframe = CFrame.new(base + Vector3.new(0, height / 2 + 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#E0CFA6"),
		material = Enum.Material.Sandstone,
	})
	if not broken then
		part(parent, {
			name = "ColumnCap",
			size = Vector3.new(4, 1.2, 4),
			cframe = CFrame.new(base + Vector3.new(0, height + 1.4, 0)),
			color = STONE_DARK,
			material = Enum.Material.Sandstone,
		})
	end
	Kit.addObstacle(base, 3)
end

local function arch(parent: Instance, base: Vector3, yaw: number)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	for _, dx in { -6, 6 } do
		part(parent, {
			name = "ArchPillar",
			size = Vector3.new(3, 15, 3),
			cframe = cf * CFrame.new(dx, 7, 0),
			color = STONE,
			material = Enum.Material.Sandstone,
		})
	end
	part(parent, {
		name = "ArchTop",
		size = Vector3.new(16, 3, 3.4),
		cframe = cf * CFrame.new(0, 15.6, 0),
		color = STONE_DARK,
		material = Enum.Material.Sandstone,
	})
	part(parent, {
		name = "ArchGlyph",
		size = Vector3.new(1.8, 1.8, 0.3),
		cframe = cf * CFrame.new(0, 15.6, -1.8) * CFrame.Angles(0, 0, math.rad(45)),
		color = GLYPH,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	Kit.addObstacle(cf * Vector3.new(-6, 0, 0), 3)
	Kit.addObstacle(cf * Vector3.new(6, 0, 0), 3)
end

local function brokenWall(parent: Instance, from: Vector3, to: Vector3, rng: Random)
	local dir = (to - from).Unit
	local length = (to - from).Magnitude
	local count = math.floor(length / 3.4)
	for i = 0, count do
		if rng:NextNumber() > 0.22 then
			local p = from + dir * (i * 3.4)
			local ground = Kit.groundY(p.X, p.Z)
			if ground then
				local h = rng:NextNumber(2.5, 8)
				local c = Vector3.new(p.X, ground + h / 2 - 0.5, p.Z)
				part(parent, {
					name = "WallBlock",
					size = Vector3.new(3.4, h, 2.6),
					cframe = CFrame.lookAt(c, c + dir)
						* CFrame.Angles(0, math.rad(90), rng:NextNumber(-0.04, 0.04)),
					color = if i % 3 == 0 then STONE_DARK else STONE,
					material = Enum.Material.Sandstone,
				})
				Kit.addObstacle(p, 2.6)
			end
		end
	end
end

local function obelisk(parent: Instance, base: Vector3)
	part(parent, {
		name = "ObeliskBase",
		size = Vector3.new(5, 2, 5),
		cframe = CFrame.new(base + Vector3.new(0, 0.6, 0)),
		color = STONE_DARK,
		material = Enum.Material.Sandstone,
	})
	part(parent, {
		name = "Obelisk",
		size = Vector3.new(3, 18, 3),
		cframe = CFrame.new(base + Vector3.new(0, 10.5, 0)),
		color = STONE,
		material = Enum.Material.Sandstone,
	})
	part(parent, {
		name = "ObeliskTip",
		size = Vector3.new(2, 2, 2),
		cframe = CFrame.new(base + Vector3.new(0, 20, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		color = hex("#FFC933"),
		material = Enum.Material.Metal,
	})
	for k = 0, 2 do
		local glyph = part(parent, {
			name = "ObeliskGlyph",
			size = Vector3.new(1.4, 1.4, 3.2),
			cframe = CFrame.new(base + Vector3.new(0, 7 + k * 3.5, 0)),
			color = GLYPH,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		if k == 1 then
			Kit.light(glyph, GLYPH, 14, 1)
		end
	end
	Kit.addObstacle(base, 4)
end

local function cactus(parent: Instance, base: Vector3, rng: Random)
	local h = rng:NextNumber(6, 10)
	local green = hex("#4E9A4A")
	part(parent, {
		name = "Cactus",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(h, 1.8, 1.8),
		cframe = CFrame.new(base + Vector3.new(0, h / 2 - 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = green,
		material = Enum.Material.Grass,
	})
	for _, side in { -1, 1 } do
		if rng:NextNumber() < 0.75 then
			local armY = rng:NextNumber(h * 0.35, h * 0.6)
			part(parent, {
				name = "CactusArm",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(2.2, 1.2, 1.2),
				cframe = CFrame.new(base + Vector3.new(side * 1.5, armY, 0)),
				color = green,
				material = Enum.Material.Grass,
			})
			part(parent, {
				name = "CactusArm",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(3.4, 1.2, 1.2),
				cframe = CFrame.new(base + Vector3.new(side * 2.4, armY + 1.6, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				color = green,
				material = Enum.Material.Grass,
			})
		end
	end
	if rng:NextNumber() < 0.4 then
		part(parent, {
			name = "CactusFlower",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1, 1, 1),
			cframe = CFrame.new(base + Vector3.new(0, h - 0.2, 0)),
			color = hex("#FF6FAE"),
			canCollide = false,
		})
	end
	Kit.addObstacle(base, 3)
end

local function oasis(parent: Instance, rng: Random)
	local o = L.oasis
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local r = o.radius + rng:NextNumber(4, 8)
		local x, z = o.x + math.cos(a) * r, o.z + math.sin(a) * r
		local y = Kit.groundY(x, z)
		if y then
			Kit.palm(parent, Vector3.new(x, y, z), rng, rng:NextInteger(7, 9))
		end
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.3
		local x, z = o.x + math.cos(a) * o.radius * 0.6, o.z + math.sin(a) * o.radius * 0.6
		local y = Kit.surface(x, z) or level
		Kit.ellipsoid(parent, {
			name = "LilyPad",
			size = Vector3.new(3, 0.2, 3),
			cframe = CFrame.new(x, y + 0.1, z),
			color = hex("#4EA84A"),
			canCollide = false,
			castShadow = false,
		})
	end
	Kit.addObstacle(Vector3.new(o.x, 0, o.z), o.radius + 6)
end

-- A sunken treasure chamber: a stone frame around a glowing pit.
local function chamber(parent: Instance, base: Vector3)
	for _, c in { { 0, -7, 16, 2 }, { 0, 7, 16, 2 }, { -7, 0, 2, 16 }, { 7, 0, 2, 16 } } do
		part(parent, {
			name = "ChamberWall",
			size = Vector3.new(c[3], 2.4, c[4]),
			cframe = CFrame.new(base + Vector3.new(c[1], 0.6, c[2])),
			color = STONE_DARK,
			material = Enum.Material.Sandstone,
		})
	end
	local glow = part(parent, {
		name = "ChamberGlow",
		size = Vector3.new(12, 0.4, 12),
		cframe = CFrame.new(base + Vector3.new(0, -0.1, 0)),
		color = hex("#FFC933"),
		material = Enum.Material.Neon,
		transparency = 0.25,
		canCollide = false,
	})
	Kit.light(glow, hex("#FFC933"), 20, 2)
	local sparkle = Kit.volume(
		parent,
		"ChamberSparkle",
		CFrame.new(base + Vector3.new(0, 1.5, 0)),
		Vector3.new(10, 2, 10)
	)
	Kit.emitter(sparkle, {
		color = hex("#FFE27A"),
		rate = 10,
		lifetime = NumberRange.new(1, 2),
		size = NumberSequence.new(0.5, 0),
		speed = NumberRange.new(2, 4),
		lightEmission = 1,
		spread = Vector2.new(20, 20),
	})
	Kit.addObstacle(base, 11)
end

function Ruins.build(rng: Random)
	local decor = Kit.folder("Ruins", workspace:FindFirstChild("Decor") or Kit.folder("Decor", workspace))
	level = Kit.medianGround({
		Vector2.new(60, -60),
		Vector2.new(120, -90),
		Vector2.new(60, -150),
		Vector2.new(220, -150),
		Vector2.new(60, -220),
		Vector2.new(200, -220),
	}, L.plateauHeight)

	local t = L.temple
	local templeBase = Vector3.new(
		t.x,
		Kit.medianGround({
			Vector2.new(t.x - t.size / 2, t.z),
			Vector2.new(t.x + t.size / 2, t.z),
			Vector2.new(t.x, t.z - t.size / 2),
			Vector2.new(t.x, t.z + t.size / 2),
		}, level),
		t.z
	)
	pyramid(decor, templeBase, t.size, rng)

	-- Avenue of columns and stone heads along the path to the temple.
	local avenue = { L.paths.Ruins[1][2], L.paths.Ruins[1][3], L.paths.Ruins[1][4] }
	for _, q in TerrainBuilder.along(avenue, 12) do
		for _, side in { -1, 1 } do
			local p = at(q.X + side * 9, q.Y + side * 2)
			if p then
				column(decor, p, rng:NextNumber(10, 15), rng:NextNumber() < 0.25)
			end
		end
	end
	for _, c in { { 92, -130, math.rad(70) }, { 128, -84, math.rad(200) }, { 64, -110, math.rad(100) } } do
		local p = at(c[1], c[2])
		if p then
			stoneHead(decor, p, c[3])
		end
	end

	oasis(decor, rng)
	local ch = at(64, -206)
	if ch then
		chamber(decor, ch)
	end

	for _, a in
		{
			{ 70, -60, 0 },
			{ 230, -140, math.rad(80) },
			{ 200, -232, math.rad(20) },
			{ 36, -170, math.rad(90) },
		}
	do
		local p = at(a[1], a[2])
		if p then
			arch(decor, p, a[3])
		end
	end
	brokenWall(decor, Vector3.new(30, 0, -60), Vector3.new(30, 0, -130), rng)
	brokenWall(decor, Vector3.new(40, 0, -236), Vector3.new(96, 0, -240), rng)
	brokenWall(decor, Vector3.new(248, 0, -60), Vector3.new(252, 0, -120), rng)
	brokenWall(decor, Vector3.new(200, 0, -40), Vector3.new(240, 0, -48), rng)
	for _, c in { { 46, -40 }, { 150, -50 }, { 40, -140 }, { 240, -190 }, { 120, -236 }, { 250, -100 } } do
		local p = at(c[1], c[2])
		if p then
			obelisk(decor, p)
		end
	end

	-- Fallen and standing pillars, cacti and desert rocks.
	for _ = 1, 26 do
		local x, z = rng:NextNumber(20, 266), rng:NextNumber(-244, -36)
		local p = at(x, z)
		if p and distanceToPaths(x, z) > 7 and Kit.clearOfObstacles(x, z, 2) then
			local fallen = rng:NextNumber() < 0.6
			local height = rng:NextNumber(8, 16)
			part(decor, {
				name = if fallen then "FallenPillar" else "Pillar",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(height, 3, 3),
				cframe = if fallen
					then CFrame.new(p + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
					else CFrame.new(p + Vector3.new(0, height / 2 - 0.5, 0)) * CFrame.Angles(
						0,
						0,
						math.rad(90)
					),
				color = hex("#E0CFA6"),
				material = Enum.Material.Sandstone,
			})
			Kit.addObstacle(p, if fallen then height / 2 + 1 else 3)
		end
	end
	for _ = 1, 40 do
		local x, z = rng:NextNumber(20, 268), rng:NextNumber(-244, -36)
		local p = at(x, z)
		if p and distanceToPaths(x, z) > 6 and Kit.clearOfObstacles(x, z, 2) then
			if rng:NextNumber() < 0.6 then
				cactus(decor, p, rng)
			else
				Kit.rock(decor, p, rng:NextNumber(0.9, 2), rng, hex("#C2A574"), Enum.Material.Sandstone)
			end
		end
	end

	-- Path braziers.
	for _, line in L.paths.Ruins do
		for i, q in TerrainBuilder.along(line, 28) do
			if i > 1 then
				local p = at(q.X + (if i % 2 == 0 then 7 else -7), q.Y)
				if p then
					Kit.torch(decor, p)
				end
			end
		end
	end

	-- Drifting sand and glints of dust in the air.
	local sand = Kit.volume(decor, "BlowingSand", CFrame.new(140, level + 3, -140), Vector3.new(250, 4, 210))
	Kit.emitter(sand, {
		color = hex("#E8D3A4"),
		rate = 14,
		lifetime = NumberRange.new(4, 7),
		size = NumberSequence.new(3, 6),
		speed = NumberRange.new(4, 8),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		}),
		direction = Enum.NormalId.Right,
		spread = Vector2.new(10, 10),
	})
	local dust = Kit.volume(decor, "DustGlints", CFrame.new(140, level + 8, -140), Vector3.new(250, 12, 210))
	Kit.emitter(dust, {
		color = hex("#FFE9B0"),
		rate = 18,
		lifetime = NumberRange.new(3, 5),
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(1, 0),
		}),
		speed = NumberRange.new(0.3, 1),
		lightEmission = 0.8,
		transparency = NumberSequence.new(0.2),
	})
end

return Ruins
