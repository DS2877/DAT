--!strict
-- The Beach: palms, a shipwreck, a dock with a boat, umbrellas and towels,
-- sandcastles, a lifeguard tower, crates and barrels, a waterfall from the
-- Jungle cliff, islet palms, and torch-lined sand paths from the base to
-- the Jungle and Ruins gates (so the way forward is always readable).

local Kit = require(script.Parent.Kit)

local L = Kit.L
local part, hex = Kit.part, Kit.hex

local Beach = {}

local WOOD = hex("#7A5230")
local WOOD_DARK = hex("#5B3A22")

local function shipwreck(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "Shipwreck"
	local wood, dark = WOOD, WOOD_DARK
	part(model, {
		size = Vector3.new(10, 3, 22),
		cframe = origin * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(14)),
		color = wood,
		material = Enum.Material.WoodPlanks,
	})
	part(model, {
		size = Vector3.new(1, 5, 20),
		cframe = origin * CFrame.new(-5, 2.5, 0) * CFrame.Angles(0, 0, math.rad(20)),
		color = dark,
		material = Enum.Material.WoodPlanks,
	})
	part(model, {
		size = Vector3.new(1, 3, 12),
		cframe = origin * CFrame.new(4.8, 1.2, -3) * CFrame.Angles(0, 0, math.rad(-8)),
		color = dark,
		material = Enum.Material.WoodPlanks,
	})
	part(model, {
		size = Vector3.new(9, 6, 1),
		cframe = origin * CFrame.new(0, 2.5, 11) * CFrame.Angles(math.rad(-10), 0, math.rad(12)),
		color = wood,
		material = Enum.Material.WoodPlanks,
	})
	part(model, {
		size = Vector3.new(1, 18, 1),
		cframe = origin * CFrame.new(0, 9, -2) * CFrame.Angles(math.rad(8), 0, math.rad(-25)),
		color = dark,
		material = Enum.Material.Wood,
	})
	part(model, {
		size = Vector3.new(0.3, 7, 8),
		cframe = origin * CFrame.new(-3, 12, -2) * CFrame.Angles(math.rad(8), 0, math.rad(-25)),
		color = hex("#F2E6C9"),
		material = Enum.Material.Fabric,
		canCollide = false,
	})
	-- A spilled treasure chest.
	local chest = part(model, {
		size = Vector3.new(3, 2, 2),
		cframe = origin * CFrame.new(6, 0.8, 6) * CFrame.Angles(0, 0.4, 0.2),
		color = hex("#8B5A2B"),
		material = Enum.Material.WoodPlanks,
	})
	part(model, {
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.4, 1, 1.6),
		cframe = chest.CFrame * CFrame.new(0, 1, 0),
		color = hex("#FFD54A"),
		material = Enum.Material.Metal,
		canCollide = false,
	})
	model.Parent = parent
	Kit.addObstacle(origin.Position, 13)
end

local function dock(parent: Instance)
	local d = L.dock
	local model = Instance.new("Model")
	model.Name = "Dock"
	local y = 2.4
	for i = 0, math.floor(d.length / 2) do
		local z = d.z + i * 2
		part(model, {
			name = "Plank",
			size = Vector3.new(8, 0.4, 1.8),
			cframe = CFrame.new(d.x, y, z) * CFrame.Angles(0, (i % 3 - 1) * 0.02, 0),
			color = if i % 2 == 0 then hex("#B07A48") else hex("#A06E40"),
			material = Enum.Material.WoodPlanks,
		})
		if i % 4 == 0 then
			for _, dx in { -4.2, 4.2 } do
				part(model, {
					name = "DockPost",
					shape = Enum.PartType.Cylinder,
					size = Vector3.new(9, 0.9, 0.9),
					cframe = CFrame.new(d.x + dx, y - 2.5, z) * CFrame.Angles(0, 0, math.rad(90)),
					color = WOOD_DARK,
					material = Enum.Material.Wood,
				})
			end
		end
	end
	-- A little boat moored at the end.
	local boat = CFrame.new(d.x + 8, 0.6, d.z + d.length - 4)
	part(model, {
		name = "Hull",
		size = Vector3.new(5, 1.8, 11),
		cframe = boat,
		color = hex("#E25B45"),
		material = Enum.Material.WoodPlanks,
	})
	part(model, {
		name = "HullTrim",
		size = Vector3.new(5.2, 0.4, 11.2),
		cframe = boat * CFrame.new(0, 0.9, 0),
		color = Color3.new(1, 1, 1),
		material = Enum.Material.WoodPlanks,
	})
	local bow = Instance.new("WedgePart")
	bow.Anchored = true
	bow.Size = Vector3.new(5, 1.8, 3.5)
	bow.CFrame = boat * CFrame.new(0, 0, -7.2) * CFrame.Angles(0, math.rad(180), 0)
	bow.Color = hex("#E25B45")
	bow.Material = Enum.Material.WoodPlanks
	bow.Parent = model
	part(model, {
		name = "Mast",
		size = Vector3.new(0.5, 9, 0.5),
		cframe = boat * CFrame.new(0, 5, -1),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
	})
	part(model, {
		name = "Sail",
		size = Vector3.new(0.2, 6, 4.5),
		cframe = boat * CFrame.new(0, 5.8, 1.2),
		color = hex("#FFF4D6"),
		material = Enum.Material.Fabric,
		canCollide = false,
	})
	model.Parent = parent
end

local function umbrella(parent: Instance, base: Vector3, rng: Random)
	local colors = { hex("#FF5A5A"), hex("#FFD54A"), hex("#5CC8FF"), hex("#B45CFF"), hex("#5BE36B") }
	local color = colors[rng:NextInteger(1, #colors)]
	part(parent, {
		name = "UmbrellaPole",
		size = Vector3.new(0.3, 7, 0.3),
		cframe = CFrame.new(base + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0.08, 0, 0.05),
		color = Color3.new(1, 1, 1),
	})
	-- Canopy: a flat cone from wedge slices.
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local slice = Instance.new("WedgePart")
		slice.Anchored = true
		slice.CanCollide = false
		slice.Size = Vector3.new(0.2, 1.4, 4.2)
		slice.CFrame = CFrame.new(base + Vector3.new(0, 7.2, 0))
			* CFrame.Angles(0, a, 0)
			* CFrame.new(0, -0.5, -2.1)
			* CFrame.Angles(math.rad(-18), 0, 0)
		slice.Color = if i % 2 == 0 then Color3.new(1, 1, 1) else color
		slice.Material = Enum.Material.Fabric
		slice.Parent = parent
	end
	part(parent, {
		name = "Towel",
		size = Vector3.new(3, 0.1, 5.5),
		cframe = CFrame.new(base + Vector3.new(3, 0.05, 1)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
		color = colors[rng:NextInteger(1, #colors)],
		material = Enum.Material.Fabric,
		canCollide = false,
	})
	local ball = part(parent, {
		name = "BeachBall",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.6, 1.6, 1.6),
		cframe = CFrame.new(base + Vector3.new(-2.5, 0.8, 2.5)),
		color = Color3.new(1, 1, 1),
		material = Enum.Material.SmoothPlastic,
	})
	part(parent, {
		name = "BallStripe",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.62, 1.62, 0.6),
		cframe = ball.CFrame,
		color = hex("#FF5A5A"),
		canCollide = false,
	})
	Kit.addObstacle(base, 5)
end

local function sandcastle(parent: Instance, base: Vector3)
	local sand = hex("#E9C98C")
	part(parent, {
		name = "Castle",
		size = Vector3.new(4, 2, 4),
		cframe = CFrame.new(base + Vector3.new(0, 1, 0)),
		color = sand,
		material = Enum.Material.Sand,
	})
	for _, c in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
		part(parent, {
			name = "Tower",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(3.2, 1.6, 1.6),
			cframe = CFrame.new(base + Vector3.new(c[1], 1.6, c[2])) * CFrame.Angles(0, 0, math.rad(90)),
			color = sand,
			material = Enum.Material.Sand,
		})
	end
	part(parent, {
		name = "Keep",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(4, 2, 2),
		cframe = CFrame.new(base + Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = sand,
		material = Enum.Material.Sand,
	})
	part(parent, {
		name = "FlagPole",
		size = Vector3.new(0.15, 2, 0.15),
		cframe = CFrame.new(base + Vector3.new(0, 5.6, 0)),
		color = Color3.new(1, 1, 1),
	})
	part(parent, {
		name = "Flag",
		size = Vector3.new(0.1, 0.7, 1.1),
		cframe = CFrame.new(base + Vector3.new(0, 6.2, 0.55)),
		color = hex("#FF5A5A"),
		canCollide = false,
	})
	Kit.addObstacle(base, 4)
end

local function lifeguardTower(parent: Instance, base: Vector3)
	for _, c in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
		part(parent, {
			name = "Leg",
			size = Vector3.new(0.6, 8, 0.6),
			cframe = CFrame.new(base + Vector3.new(c[1], 4, c[2])),
			color = Color3.new(1, 1, 1),
			material = Enum.Material.WoodPlanks,
		})
	end
	part(parent, {
		name = "Platform",
		size = Vector3.new(5.5, 0.6, 5.5),
		cframe = CFrame.new(base + Vector3.new(0, 8, 0)),
		color = hex("#FF5A5A"),
		material = Enum.Material.WoodPlanks,
	})
	part(parent, {
		name = "Seat",
		size = Vector3.new(3, 2, 2),
		cframe = CFrame.new(base + Vector3.new(0, 9.3, 1)),
		color = Color3.new(1, 1, 1),
		material = Enum.Material.WoodPlanks,
	})
	part(parent, {
		name = "Roof",
		size = Vector3.new(6.5, 0.5, 6.5),
		cframe = CFrame.new(base + Vector3.new(0, 13, 0)),
		color = hex("#FF5A5A"),
		material = Enum.Material.Fabric,
	})
	for _, c in { { -2.9, -2.9 }, { 2.9, -2.9 }, { -2.9, 2.9 }, { 2.9, 2.9 } } do
		part(parent, {
			name = "RoofPost",
			size = Vector3.new(0.4, 4.6, 0.4),
			cframe = CFrame.new(base + Vector3.new(c[1], 10.6, c[2])),
			color = Color3.new(1, 1, 1),
		})
	end
	Kit.addObstacle(base, 5)
end

local function crates(parent: Instance, base: Vector3, rng: Random)
	for i = 1, 4 do
		local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		if i % 2 == 0 then
			part(parent, {
				name = "Barrel",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(2.6, 2, 2),
				cframe = CFrame.new(base + offset + Vector3.new(0, 1.3, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				color = hex("#8B5A2B"),
				material = Enum.Material.Wood,
			})
		else
			part(parent, {
				name = "Crate",
				size = Vector3.new(2.4, 2.4, 2.4),
				cframe = CFrame.new(base + offset + Vector3.new(0, 1.2, 0))
					* CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
				color = hex("#B98A55"),
				material = Enum.Material.WoodPlanks,
			})
		end
	end
	Kit.addObstacle(base, 5)
end

local function waterfall(parent: Instance)
	local wf = L.waterfall
	local height = L.plateauHeight - L.beachHeight + 3
	local water = part(parent, {
		name = "Waterfall",
		size = Vector3.new(9, height, 1.2),
		cframe = CFrame.new(wf.x, L.beachHeight - 1 + height / 2, wf.z + 1),
		color = hex("#9FE6FF"),
		material = Enum.Material.Glass,
		transparency = 0.25,
		canCollide = false,
	})
	local mist = Instance.new("ParticleEmitter")
	mist.Color = ColorSequence.new(Color3.new(1, 1, 1))
	mist.Transparency = NumberSequence.new(0.6, 1)
	mist.Size = NumberSequence.new(2, 5)
	mist.Lifetime = NumberRange.new(1, 2)
	mist.Rate = 12
	mist.Speed = NumberRange.new(2, 4)
	mist.SpreadAngle = Vector2.new(60, 20)
	mist.EmissionDirection = Enum.NormalId.Bottom
	mist.Parent = water
	Kit.addObstacle(Vector3.new(wf.x, 0, wf.z + 9), 13)
end

-- A sand path with tiki torches from `from` to `to`.
local function torchPath(parent: Instance, from: Vector3, to: Vector3)
	local dir = (to - from).Unit
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	part(parent, {
		name = "Path",
		size = Vector3.new(7, 0.2, length),
		cframe = CFrame.lookAt(mid, to),
		color = hex("#E4C487"),
		material = Enum.Material.Sand,
		canCollide = false,
	})
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local count = math.floor(length / 26)
	for i = 1, count do
		local p = from + dir * (i * length / (count + 1))
		local flip = if i % 2 == 0 then 1 else -1
		Kit.torch(parent, p + side * 5.5 * flip)
	end
end

function Beach.build(rng: Random)
	local decor = workspace:FindFirstChild("Decor") or Kit.folder("Decor", workspace)
	local y = L.beachHeight

	-- Palms ring the beach and frame the base; a few stand in the dig area.
	for i = 1, 24 do
		local angle = (i / 24) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local dist = L.beach.radius - rng:NextNumber(6, 16)
		local x, z = L.beach.x + math.cos(angle) * dist, L.beach.z + math.sin(angle) * dist
		if z > L.beachNorthZ + 12 then
			Kit.palm(decor, Vector3.new(x, y - 0.5, z), rng)
		end
	end
	for _, p in
		{
			{ -72, 40 },
			{ 60, 25 },
			{ -30, 72 },
			{ 95, 72 },
			{ -104, 100 },
			{ 22, 8 },
			{ -112, 30 },
			{ 108, 108 },
		}
	do
		Kit.palm(decor, Vector3.new(p[1], y - 0.5, p[2]), rng, 7)
	end
	for _, p in { { -47, 104 }, { 47, 104 }, { -47, 152 }, { 47, 152 } } do
		Kit.palm(decor, Vector3.new(p[1], y - 0.5, p[2]), rng)
	end

	-- Shoreline rocks.
	for _ = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = L.beach.radius + rng:NextNumber(2, 10)
		local x, z = L.beach.x + math.cos(angle) * dist, L.beach.z + math.sin(angle) * dist
		if z > L.beachNorthZ + 12 then
			Kit.rock(decor, Vector3.new(x, 0.8, z), rng:NextNumber(0.8, 1.9), rng)
		end
	end

	shipwreck(decor, CFrame.new(-96, 1.5, 128) * CFrame.Angles(0, math.rad(35), 0))
	crates(decor, Vector3.new(-80, y, 112), rng)
	dock(decor)
	lifeguardTower(decor, Vector3.new(104, y, 92))
	for _, p in { { -86, 70 }, { 80, 40 }, { -40, 20 }, { 40, 60 }, { -100, 60 }, { 100, 20 } } do
		umbrella(decor, Vector3.new(p[1], y, p[2]), rng)
	end
	for _, p in { { -60, 88 }, { 88, 128 }, { -20, 46 } } do
		sandcastle(decor, Vector3.new(p[1], y, p[2]))
	end
	waterfall(decor)

	-- Torch-lined paths from the base to the two gates.
	local front = Vector3.new(0, y + 0.1, L.base.minZ - 2)
	local fork = Vector3.new(0, y + 0.1, 50)
	torchPath(decor, front, fork)
	torchPath(decor, fork, Vector3.new(L.gates.Jungle.x, y + 0.1, L.gates.Jungle.z + 4))
	torchPath(decor, fork, Vector3.new(L.gates.Ruins.x, y + 0.1, L.gates.Ruins.z + 4))
	-- Signpost at the fork.
	part(decor, {
		name = "SignPost",
		size = Vector3.new(0.8, 9, 0.8),
		cframe = CFrame.new(fork + Vector3.new(0, 4.5, 0)),
		color = WOOD,
		material = Enum.Material.Wood,
	})
	for _, s in { { "< JUNGLE", -0.5, "#56C451" }, { "RUINS >", 0.5, "#4FD1C5" } } do
		local board = part(decor, {
			name = "SignBoard",
			size = Vector3.new(6, 1.6, 0.4),
			cframe = CFrame.new(fork + Vector3.new(s[2] * 3.4, if s[2] < 0 then 7.4 else 5.4, 0))
				* CFrame.Angles(0, math.rad(s[2] * 20), 0),
			color = hex("#A06E40"),
			material = Enum.Material.WoodPlanks,
		})
		Kit.signText(board, s[1] :: string, hex(s[3] :: string))
	end
	Kit.addObstacle(fork, 4)

	-- Palms on the islets.
	for _, p in { { -178, 70 }, { 182, -40 }, { 158, 172 } } do
		Kit.palm(decor, Vector3.new(p[1], 1.5, p[2]), rng, 7)
	end
end

return Beach
