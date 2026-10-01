--!strict
-- The Jungle: a dense forest of tall kapok trees, round-canopy trees,
-- jungle palms and bamboo, ferns, bushes and huge flowers; a river with a
-- rope bridge that falls off the cliff onto the beach; a giant ancient tree
-- as the landmark; a mossy shrine with a stone idol; giant glowing
-- mushrooms; vines; falling leaves, fireflies and mist.

local Kit = require(script.Parent.Kit)
local TerrainBuilder = require(script.Parent.Terrain)

local L = Kit.L
local part, hex = Kit.part, Kit.hex

local Jungle = {}

local LEAF = { hex("#2F8F3A"), hex("#3AA845"), hex("#277A33"), hex("#46B54E") }
local TRUNK = hex("#6B4A2B")
local MOSS = hex("#6E8F4E")
local FLOWER = { hex("#FF6FAE"), hex("#FFD54A"), hex("#FF8A3D"), hex("#B45CFF"), hex("#FF4A4A") }

local level = L.plateauHeight

local function distanceToLine(x: number, z: number, line: { { number } }): number
	local best = math.huge
	local p = Vector2.new(x, z)
	for i = 1, #line - 1 do
		local a, b = Vector2.new(line[i][1], line[i][2]), Vector2.new(line[i + 1][1], line[i + 1][2])
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		best = math.min(best, (a + ab * t - p).Magnitude)
	end
	return best
end

local function nearPathOrRiver(x: number, z: number, margin: number): boolean
	for _, line in L.paths.Jungle do
		if distanceToLine(x, z, line) < margin then
			return true
		end
	end
	return distanceToLine(x, z, L.river) < margin + 6
end

local function at(x: number, z: number): Vector3?
	return Kit.onLevel(x, z, level, 4)
end

local function vines(parent: Instance, center: Vector3, spread: number, count: number, rng: Random)
	for _ = 1, count do
		local length = rng:NextNumber(5, 12)
		part(parent, {
			name = "Vine",
			size = Vector3.new(0.35, length, 0.35),
			cframe = CFrame.new(
				center
					+ Vector3.new(
						rng:NextNumber(-spread, spread),
						-length / 2,
						rng:NextNumber(-spread, spread)
					)
			),
			color = hex("#2F7A34"),
			material = Enum.Material.Grass,
			canCollide = false,
			castShadow = false,
		})
	end
end

-- A tall kapok: straight trunk, buttress roots, a wide layered crown.
local function kapok(parent: Instance, base: Vector3, rng: Random, scale: number)
	local height = rng:NextNumber(28, 40) * scale
	local trunk = 2.6 * scale
	part(parent, {
		name = "JungleTrunk",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height + 3, trunk, trunk),
		cframe = CFrame.new(base + Vector3.new(0, height / 2 - 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = TRUNK,
		material = Enum.Material.Wood,
	})
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		part(parent, {
			name = "Buttress",
			className = "WedgePart",
			size = Vector3.new(0.8 * scale, 5 * scale, 4 * scale),
			cframe = CFrame.new(
				base
					+ Vector3.new(
						math.cos(a) * (trunk / 2 + 1.6 * scale),
						2.5 * scale - 1,
						math.sin(a) * (trunk / 2 + 1.6 * scale)
					)
			) * CFrame.Angles(0, -a + math.rad(90), 0),
			color = TRUNK,
			material = Enum.Material.Wood,
		})
	end
	local crownY = base.Y + height
	for i = 1, 4 do
		local w = rng:NextNumber(16, 24) * scale
		Kit.ellipsoid(parent, {
			name = "Canopy",
			size = Vector3.new(w, w * 0.42, w * rng:NextNumber(0.8, 1)),
			cframe = CFrame.new(
				base.X + rng:NextNumber(-4, 4) * scale,
				crownY + rng:NextNumber(-2, 3) * scale,
				base.Z + rng:NextNumber(-4, 4) * scale
			) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			color = LEAF[(i % #LEAF) + 1],
			material = Enum.Material.Grass,
			canCollide = false,
		})
	end
	if rng:NextNumber() < 0.7 then
		vines(parent, Vector3.new(base.X, crownY - 2, base.Z), 7 * scale, 4, rng)
	end
	Kit.addObstacle(base, trunk + 2)
end

-- A round-canopy tree with a few blob layers.
local function roundTree(parent: Instance, base: Vector3, rng: Random, scale: number)
	local height = rng:NextNumber(14, 20) * scale
	local lean = rng:NextNumber(-0.12, 0.12)
	part(parent, {
		name = "JungleTrunk",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height + 2, 1.8 * scale, 1.8 * scale),
		cframe = CFrame.new(base + Vector3.new(0, height / 2 - 1, 0)) * CFrame.Angles(lean, 0, math.rad(90)),
		color = hex("#7A5634"),
		material = Enum.Material.Wood,
	})
	for i = 1, 3 do
		local s = rng:NextNumber(9, 13) * scale
		Kit.ellipsoid(parent, {
			name = "Canopy",
			size = Vector3.new(s, s * 0.8, s),
			cframe = CFrame.new(
				base
					+ Vector3.new(
						rng:NextNumber(-3, 3) * scale,
						height + rng:NextNumber(-1, 3) * scale,
						rng:NextNumber(-3, 3) * scale
					)
			),
			color = LEAF[((i + 1) % #LEAF) + 1],
			material = Enum.Material.Grass,
			canCollide = false,
		})
	end
	if rng:NextNumber() < 0.35 then
		-- Hanging fruit.
		for _ = 1, 3 do
			part(parent, {
				name = "Fruit",
				shape = Enum.PartType.Ball,
				size = Vector3.new(0.9, 0.9, 0.9),
				cframe = CFrame.new(
					base + Vector3.new(rng:NextNumber(-4, 4), height - 2.5, rng:NextNumber(-4, 4))
				),
				color = FLOWER[rng:NextInteger(1, #FLOWER)],
				canCollide = false,
				castShadow = false,
			})
		end
	end
	Kit.addObstacle(base, 2.2 * scale)
end

local function bamboo(parent: Instance, base: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(5, 8) do
		local h = rng:NextNumber(12, 20)
		local offset = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		local tilt = CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
		part(parent, {
			name = "Bamboo",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(h, 0.7, 0.7),
			cframe = CFrame.new(base + offset + Vector3.new(0, h / 2 - 0.5, 0))
				* tilt
				* CFrame.Angles(0, 0, math.rad(90)),
			color = hex("#9CC452"),
			material = Enum.Material.SmoothPlastic,
		})
		part(parent, {
			name = "BambooLeaf",
			className = "WedgePart",
			size = Vector3.new(0.15, 1.2, 3),
			cframe = CFrame.new(base + offset + Vector3.new(0, h - 1, 0))
				* tilt
				* CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(70)),
			color = hex("#6FB043"),
			material = Enum.Material.Grass,
			canCollide = false,
			castShadow = false,
		})
	end
	Kit.addObstacle(base, 3.5)
end

local function fern(parent: Instance, base: Vector3, rng: Random)
	local color = if rng:NextNumber() < 0.5 then hex("#3FAE49") else hex("#2F8F3A")
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		part(parent, {
			name = "Fern",
			className = "WedgePart",
			size = Vector3.new(0.15, 1.6, 4),
			cframe = CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(
				math.rad(25),
				0,
				0
			) * CFrame.new(0, 0, -1.8) * CFrame.Angles(0, 0, math.rad(90)),
			color = color,
			material = Enum.Material.Grass,
			canCollide = false,
			castShadow = false,
		})
	end
end

local function bush(parent: Instance, base: Vector3, rng: Random)
	local s = rng:NextNumber(4.5, 8)
	Kit.ellipsoid(parent, {
		name = "Bush",
		size = Vector3.new(s, s * 0.65, s * rng:NextNumber(0.8, 1.1)),
		cframe = CFrame.new(base + Vector3.new(0, s * 0.18, 0)),
		color = LEAF[rng:NextInteger(1, #LEAF)],
		material = Enum.Material.Grass,
		canCollide = false,
	})
	if rng:NextNumber() < 0.55 then
		for _ = 1, 3 do
			part(parent, {
				name = "Flower",
				shape = Enum.PartType.Ball,
				size = Vector3.new(0.9, 0.9, 0.9),
				cframe = CFrame.new(
					base + Vector3.new(rng:NextNumber(-s / 3, s / 3), s * 0.45, rng:NextNumber(-s / 3, s / 3))
				),
				color = FLOWER[rng:NextInteger(1, #FLOWER)],
				material = Enum.Material.Neon,
				canCollide = false,
				castShadow = false,
			})
		end
	end
	Kit.addObstacle(base, s / 2.4)
end

-- A huge tropical flower (rafflesia-like) on the forest floor.
local function bigFlower(parent: Instance, base: Vector3, rng: Random)
	local color = FLOWER[rng:NextInteger(1, #FLOWER)]
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		Kit.ellipsoid(parent, {
			name = "Petal",
			size = Vector3.new(2.6, 0.6, 3.6),
			cframe = CFrame.new(base + Vector3.new(math.cos(a) * 1.9, 0.4, math.sin(a) * 1.9))
				* CFrame.Angles(0, -a + math.rad(90), 0),
			color = color,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
		})
	end
	part(parent, {
		name = "FlowerHeart",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.6, 1.6, 1.6),
		cframe = CFrame.new(base + Vector3.new(0, 0.7, 0)),
		color = hex("#FFE27A"),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	Kit.addObstacle(base, 3.5)
end

local function mushroom(parent: Instance, base: Vector3, rng: Random, scale: number)
	local h = 7 * scale
	part(parent, {
		name = "MushroomStem",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(h, 1.8 * scale, 1.8 * scale),
		cframe = CFrame.new(base + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#F2E8D2"),
	})
	local capColor = if rng:NextNumber() < 0.5 then hex("#E2423A") else hex("#9B5CFF")
	local cap = Kit.ellipsoid(parent, {
		name = "MushroomCap",
		size = Vector3.new(8 * scale, 3.6 * scale, 8 * scale),
		cframe = CFrame.new(base + Vector3.new(0, h, 0)),
		color = capColor,
		material = Enum.Material.SmoothPlastic,
	})
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		part(parent, {
			name = "MushroomDot",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1, 1, 1) * scale,
			cframe = CFrame.new(
				base + Vector3.new(math.cos(a) * 2.6 * scale, h + 1.2 * scale, math.sin(a) * 2.6 * scale)
			),
			color = Color3.new(1, 1, 1),
			canCollide = false,
			castShadow = false,
		})
	end
	Kit.light(cap, capColor, 14 * scale, 0.8)
	Kit.addObstacle(base, 4.5 * scale)
end

local function ancientTree(parent: Instance, base: Vector3)
	local model = Instance.new("Model")
	model.Name = "AncientTree"
	local trunkColor = hex("#5A3D24")
	local h = 64
	part(model, {
		name = "AncientTrunk",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(h, 11, 11),
		cframe = CFrame.new(base + Vector3.new(0, h / 2 - 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = trunkColor,
		material = Enum.Material.Wood,
	})
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		part(model, {
			name = "Root",
			className = "WedgePart",
			size = Vector3.new(2, 12, 11),
			cframe = CFrame.new(base + Vector3.new(math.cos(a) * 9, 4.5, math.sin(a) * 9))
				* CFrame.Angles(0, -a + math.rad(90), 0),
			color = trunkColor,
			material = Enum.Material.Wood,
		})
	end
	-- Big branches.
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + 0.3
		local from = base + Vector3.new(0, h - 14 + i * 1.5, 0)
		local to = from + Vector3.new(math.cos(a) * 22, 10, math.sin(a) * 22)
		part(model, {
			name = "Branch",
			size = Vector3.new(3.4, 3.4, (to - from).Magnitude),
			cframe = CFrame.lookAt((from + to) / 2, to),
			color = trunkColor,
			material = Enum.Material.Wood,
		})
		Kit.ellipsoid(model, {
			name = "AncientCanopy",
			size = Vector3.new(30, 14, 28),
			cframe = CFrame.new(to + Vector3.new(0, 4, 0)),
			color = if i % 2 == 0 then hex("#2F8F3A") else hex("#3AA845"),
			material = Enum.Material.Grass,
			canCollide = false,
		})
	end
	Kit.ellipsoid(model, {
		name = "AncientCanopy",
		size = Vector3.new(46, 20, 44),
		cframe = CFrame.new(base + Vector3.new(0, h + 6, 0)),
		color = hex("#277A33"),
		material = Enum.Material.Grass,
		canCollide = false,
	})
	-- Glowing fruit.
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local fruit = part(model, {
			name = "GlowFruit",
			shape = Enum.PartType.Ball,
			size = Vector3.new(2, 2, 2),
			cframe = CFrame.new(base + Vector3.new(math.cos(a) * 20, h - 2, math.sin(a) * 20)),
			color = hex("#FFD54A"),
			material = Enum.Material.Neon,
			canCollide = false,
			castShadow = false,
		})
		if i % 3 == 0 then
			Kit.light(fruit, fruit.Color, 14, 1)
		end
	end
	-- A carved door in the trunk with a glow inside.
	local door = Kit.ellipsoid(model, {
		name = "TreeDoor",
		size = Vector3.new(4.6, 7, 1),
		cframe = CFrame.new(base + Vector3.new(0, 3.5, 5.3)),
		color = hex("#FFB84A"),
		material = Enum.Material.Neon,
	})
	Kit.light(door, hex("#FFB84A"), 16, 1.5)
	vines(model, base + Vector3.new(0, h - 4, 0), 18, 16, Random.new(7))
	model.Parent = parent
	Kit.addObstacle(base, 20)
end

local function shrine(parent: Instance, base: Vector3, rng: Random)
	local model = Instance.new("Model")
	model.Name = "JungleShrine"
	for i = 0, 2 do
		local s = 22 - i * 6
		part(model, {
			name = "ShrineStep",
			size = Vector3.new(s, 2.4, s),
			cframe = CFrame.new(base + Vector3.new(0, 0.2 + i * 2.4, 0)),
			color = MOSS:Lerp(hex("#8C9A7A"), i * 0.2),
			material = Enum.Material.Cobblestone,
		})
	end
	for _, c in { { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } } do
		part(model, {
			name = "ShrinePillar",
			size = Vector3.new(1.6, 9, 1.6),
			cframe = CFrame.new(base + Vector3.new(c[1], 11, c[2])),
			color = hex("#8C9A7A"),
			material = Enum.Material.Cobblestone,
		})
	end
	part(model, {
		name = "ShrineRoof",
		size = Vector3.new(12, 1.6, 12),
		cframe = CFrame.new(base + Vector3.new(0, 16.2, 0)),
		color = MOSS,
		material = Enum.Material.Cobblestone,
	})
	part(model, {
		name = "ShrineRoofTop",
		className = "WedgePart",
		size = Vector3.new(12, 3, 6),
		cframe = CFrame.new(base + Vector3.new(0, 18.4, -3)) * CFrame.Angles(0, math.rad(180), 0),
		color = MOSS,
		material = Enum.Material.Cobblestone,
	})
	part(model, {
		name = "ShrineRoofTop",
		className = "WedgePart",
		size = Vector3.new(12, 3, 6),
		cframe = CFrame.new(base + Vector3.new(0, 18.4, 3)),
		color = MOSS,
		material = Enum.Material.Cobblestone,
	})
	-- The idol on its altar.
	local idol = part(model, {
		name = "Idol",
		size = Vector3.new(2.4, 4, 2),
		cframe = CFrame.new(base + Vector3.new(0, 9.2, 0)),
		color = hex("#FFC933"),
		material = Enum.Material.Metal,
		reflectance = 0.15,
	})
	for _, x in { -0.5, 0.5 } do
		part(model, {
			name = "IdolEye",
			size = Vector3.new(0.4, 0.4, 0.2),
			cframe = idol.CFrame * CFrame.new(x, 0.9, -1.05),
			color = hex("#4FFFB0"),
			material = Enum.Material.Neon,
			canCollide = false,
		})
	end
	Kit.light(idol, hex("#FFE27A"), 16, 1.4)
	vines(model, base + Vector3.new(0, 16, 0), 6, 8, rng)
	-- Mossy broken blocks around it.
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local h = rng:NextNumber(2, 6)
		part(model, {
			name = "MossyRuin",
			size = Vector3.new(3, h, 3),
			cframe = CFrame.new(base + Vector3.new(math.cos(a) * 16, h / 2 - 0.5, math.sin(a) * 16))
				* CFrame.Angles(0, a, rng:NextNumber(-0.15, 0.15)),
			color = hex("#7C8C6A"),
			material = Enum.Material.Cobblestone,
		})
	end
	model.Parent = parent
	Kit.addObstacle(base, 18)
end

local function ropeBridge(parent: Instance, from: Vector3, to: Vector3)
	local model = Instance.new("Model")
	model.Name = "RopeBridge"
	local dir = (to - from).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local length = (to - from).Magnitude
	local count = math.floor(length / 1.6)
	for i = 0, count do
		local t = i / count
		local p = from:Lerp(to, t) - Vector3.new(0, math.sin(t * math.pi) * 0.8, 0)
		part(model, {
			name = "BridgePlank",
			size = Vector3.new(7, 0.4, 1.4),
			cframe = CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, (i % 3 - 1) * 0.03),
			color = if i % 2 == 0 then hex("#A0703F") else hex("#8F6236"),
			material = Enum.Material.WoodPlanks,
		})
	end
	for _, s in { -1, 1 } do
		for _, endPoint in { from, to } do
			part(model, {
				name = "BridgePost",
				size = Vector3.new(0.8, 5, 0.8),
				cframe = CFrame.new(endPoint + side * s * 3.8 + Vector3.new(0, 2, 0)),
				color = hex("#6B4A2B"),
				material = Enum.Material.Wood,
			})
		end
		local a, b =
			from + side * s * 3.8 + Vector3.new(0, 3.6, 0), to + side * s * 3.8 + Vector3.new(0, 3.6, 0)
		part(model, {
			name = "Rope",
			size = Vector3.new(0.25, 0.25, (b - a).Magnitude),
			cframe = CFrame.lookAt((a + b) / 2 - Vector3.new(0, 0.5, 0), b - Vector3.new(0, 0.5, 0)),
			color = hex("#C9A36A"),
			material = Enum.Material.Fabric,
			canCollide = false,
		})
	end
	model.Parent = parent
end

function Jungle.build(rng: Random)
	local decor = Kit.folder("Jungle", workspace:FindFirstChild("Decor") or Kit.folder("Decor", workspace))
	level = Kit.medianGround({
		Vector2.new(-60, -60),
		Vector2.new(-120, -90),
		Vector2.new(-60, -150),
		Vector2.new(-220, -100),
		Vector2.new(-120, -220),
		Vector2.new(-40, -230),
	}, L.plateauHeight)

	local tree = L.ancientTree
	ancientTree(decor, Vector3.new(tree.x, Kit.groundOr(tree.x, tree.z, level) - 1, tree.z))
	local s = L.jungleShrine
	shrine(decor, Vector3.new(s.x, Kit.groundOr(s.x, s.z, level) - 0.5, s.z), rng)

	-- The rope bridge where the main path crosses the river.
	local crossing = L.paths.Jungle[1]
	local a, b = crossing[3], crossing[5]
	local riverPoint = Vector2.new(-185, -134)
	local dir = (Vector2.new(b[1], b[2]) - Vector2.new(a[1], a[2])).Unit
	local fromXZ, toXZ = riverPoint - dir * 12, riverPoint + dir * 12
	local fromY = Kit.groundOr(fromXZ.X, fromXZ.Y, level)
	local toY = Kit.groundOr(toXZ.X, toXZ.Y, level)
	ropeBridge(decor, Vector3.new(fromXZ.X, fromY + 0.3, fromXZ.Y), Vector3.new(toXZ.X, toY + 0.3, toXZ.Y))

	-- Giant mushroom grove in the far corner.
	for i = 1, 7 do
		local p = at(-238 + rng:NextNumber(-18, 18), -222 + rng:NextNumber(-14, 14))
		if p then
			mushroom(decor, p, rng, if i <= 2 then 1.8 else rng:NextNumber(0.8, 1.3))
		end
	end

	-- The forest: kapoks, round trees, bamboo, palms.
	local placed = 0
	for _ = 1, 1400 do
		if placed >= 150 then
			break
		end
		local x, z = rng:NextNumber(-272, -14), rng:NextNumber(-246, -34)
		local p = at(x, z)
		if p and not nearPathOrRiver(x, z, 8) and Kit.clearOfObstacles(x, z, 2) then
			local roll = rng:NextNumber()
			if roll < 0.32 then
				kapok(decor, p, rng, rng:NextNumber(0.8, 1.15))
			elseif roll < 0.72 then
				roundTree(decor, p, rng, rng:NextNumber(0.85, 1.25))
			elseif roll < 0.86 then
				bamboo(decor, p, rng)
			else
				Kit.palm(decor, p, rng, rng:NextInteger(7, 10))
			end
			placed += 1
		end
	end
	-- Undergrowth: bushes, ferns, flowers.
	for _ = 1, 220 do
		local x, z = rng:NextNumber(-272, -14), rng:NextNumber(-246, -34)
		local p = at(x, z)
		if p and not nearPathOrRiver(x, z, 5) then
			local roll = rng:NextNumber()
			if roll < 0.45 then
				bush(decor, p, rng)
			elseif roll < 0.85 then
				fern(decor, p, rng)
			elseif Kit.clearOfObstacles(x, z, 1) then
				bigFlower(decor, p, rng)
			end
		end
	end
	-- Mossy boulders along the river banks.
	for _, q in TerrainBuilder.along(L.river, 14) do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local p = at(q.X + side * rng:NextNumber(9, 12), q.Y + rng:NextNumber(-4, 4))
		if p then
			Kit.rock(decor, p, rng:NextNumber(1, 1.8), rng, hex("#7C8C6A"), Enum.Material.Cobblestone)
		end
	end

	-- Path torches (bamboo tiki torches).
	for _, line in L.paths.Jungle do
		for i, q in TerrainBuilder.along(line, 26) do
			if i > 1 then
				local p = at(q.X + (if i % 2 == 0 then 6 else -6), q.Y)
				if p then
					Kit.torch(decor, p)
				end
			end
		end
	end

	-- Living air: falling leaves, fireflies and low mist over the forest.
	local cx, cz = -140, -140
	local leaves =
		Kit.volume(decor, "FallingLeaves", CFrame.new(cx, level + 40, cz), Vector3.new(250, 4, 210))
	Kit.emitter(leaves, {
		color = hex("#5ACB4F"),
		color2 = hex("#D9B25C"),
		rate = 22,
		lifetime = NumberRange.new(7, 10),
		size = NumberSequence.new(0.6, 0.5),
		speed = NumberRange.new(1, 2),
		acceleration = Vector3.new(0.6, -2.2, 0.3),
		rotSpeed = NumberRange.new(-120, 120),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0.1),
			NumberSequenceKeypoint.new(1, 0.4),
		}),
		direction = Enum.NormalId.Bottom,
	})
	local flies = Kit.volume(decor, "Fireflies", CFrame.new(cx, level + 5, cz), Vector3.new(250, 8, 210))
	Kit.emitter(flies, {
		color = hex("#FFF27A"),
		rate = 26,
		lifetime = NumberRange.new(3, 6),
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		}),
		speed = NumberRange.new(0.5, 1.5),
		lightEmission = 1,
		transparency = NumberSequence.new(0),
		drag = 1,
	})
	local mist = Kit.volume(decor, "JungleMist", CFrame.new(cx, level + 2, cz), Vector3.new(250, 2, 210))
	Kit.emitter(mist, {
		color = Color3.new(1, 1, 1),
		rate = 6,
		lifetime = NumberRange.new(8, 12),
		size = NumberSequence.new(10, 16),
		speed = NumberRange.new(0.3, 0.8),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.86),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
end

return Jungle
