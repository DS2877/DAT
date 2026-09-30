--!strict
-- The Jungle: dense tall trees with hanging vines, bushes and flowers,
-- mossy ruin blocks, a dirt path from the top of the gate ramp, and a giant
-- ancient tree as a landmark.

local Kit = require(script.Parent.Kit)

local L = Kit.L
local part, hex = Kit.part, Kit.hex

local Jungle = {}

-- Dirt path from the top of the gate ramp (trees stay off it).
local PATH = {
	Vector2.new(-65, -40),
	Vector2.new(-60, -56),
	Vector2.new(-74, -72),
	Vector2.new(-60, -92),
	Vector2.new(-82, -106),
}

local function nearPath(x: number, z: number, distance: number): boolean
	for i = 1, #PATH - 1 do
		local a, b = PATH[i], PATH[i + 1]
		local ab = b - a
		local t = math.clamp((Vector2.new(x, z) - a):Dot(ab) / ab:Dot(ab), 0, 1)
		if (a + ab * t - Vector2.new(x, z)).Magnitude < distance then
			return true
		end
	end
	return false
end

local function tree(parent: Instance, base: Vector3, rng: Random, scale: number?)
	local s = scale or 1
	local height = rng:NextNumber(18, 30) * s
	part(parent, {
		name = "JungleTrunk",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height, 2.4 * s, 2.4 * s),
		cframe = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#6B4A2B"),
		material = Enum.Material.Wood,
	})
	for i = 1, 3 do
		local offset = Vector3.new(
			rng:NextNumber(-3, 3) * s,
			height + rng:NextNumber(-2, 3) * s,
			rng:NextNumber(-3, 3) * s
		)
		local size = rng:NextNumber(10, 15) * s
		part(parent, {
			name = "Canopy",
			shape = Enum.PartType.Ball,
			size = Vector3.new(size, size * 0.75, size),
			cframe = CFrame.new(base + offset),
			color = if i == 2 then hex("#2F8F3A") else hex("#3AA845"),
			material = Enum.Material.Grass,
			canCollide = false,
		})
	end
	if rng:NextNumber() < 0.6 then
		for _ = 1, 2 do
			local length = rng:NextNumber(6, 12) * s
			part(parent, {
				name = "Vine",
				size = Vector3.new(0.3, length, 0.3),
				cframe = CFrame.new(
					base
						+ Vector3.new(
							rng:NextNumber(-4, 4) * s,
							height - 2 - length / 2,
							rng:NextNumber(-4, 4) * s
						)
				),
				color = hex("#2F7A34"),
				material = Enum.Material.Grass,
				canCollide = false,
			})
		end
	end
	Kit.addObstacle(base, 2.5 * s)
end

local function ancientTree(parent: Instance, base: Vector3)
	-- A huge landmark tree with buttress roots, glowing fruit and a big crown.
	local trunkColor = hex("#5A3D24")
	part(parent, {
		name = "AncientTrunk",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(44, 7, 7),
		cframe = CFrame.new(base + Vector3.new(0, 22, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = trunkColor,
		material = Enum.Material.Wood,
	})
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		part(parent, {
			name = "Root",
			size = Vector3.new(1.6, 6, 9),
			cframe = CFrame.new(base + Vector3.new(math.cos(a) * 4.5, 2.4, math.sin(a) * 4.5))
				* CFrame.Angles(0, -a, 0)
				* CFrame.Angles(math.rad(35), 0, 0),
			color = trunkColor,
			material = Enum.Material.Wood,
		})
	end
	for _, c in { { 0, 46, 0, 30 }, { -9, 42, 6, 20 }, { 9, 43, -5, 22 }, { 3, 50, 8, 18 } } do
		part(parent, {
			name = "AncientCanopy",
			shape = Enum.PartType.Ball,
			size = Vector3.new(c[4], c[4] * 0.7, c[4]),
			cframe = CFrame.new(base + Vector3.new(c[1], c[2], c[3])),
			color = hex("#2F8F3A"),
			material = Enum.Material.Grass,
			canCollide = false,
		})
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local fruit = part(parent, {
			name = "GlowFruit",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.4, 1.4, 1.4),
			cframe = CFrame.new(base + Vector3.new(math.cos(a) * 11, 36, math.sin(a) * 11)),
			color = hex("#FFD54A"),
			material = Enum.Material.Neon,
			canCollide = false,
		})
		if i % 2 == 0 then
			Kit.light(fruit, fruit.Color, 10, 1)
		end
	end
	Kit.addObstacle(base, 10)
end

function Jungle.build(rng: Random)
	local decor = workspace:FindFirstChild("Decor") or Kit.folder("Decor", workspace)
	local y = L.plateauHeight

	-- Dirt path segments (flat, walk-through).
	for i = 1, #PATH - 1 do
		local a, b = PATH[i], PATH[i + 1]
		local from, to = Vector3.new(a.X, y + 0.05, a.Y), Vector3.new(b.X, y + 0.05, b.Y)
		part(decor, {
			name = "Path",
			size = Vector3.new(7, 0.2, (to - from).Magnitude + 6),
			cframe = CFrame.lookAt((from + to) / 2, to),
			color = hex("#9C7A4E"),
			material = Enum.Material.Ground,
			canCollide = false,
		})
	end

	ancientTree(decor, Vector3.new(-100, y - 1, -75))

	local placed = 0
	for _ = 1, 240 do
		if placed >= 30 then
			break
		end
		local x, z = rng:NextNumber(-128, -10), rng:NextNumber(-116, -22)
		local farFromLandmark = (Vector2.new(x, z) - Vector2.new(-100, -75)).Magnitude > 16
		if farFromLandmark and not nearPath(x, z, 9) and Kit.groundY(x, z) then
			local ground = Kit.groundY(x, z) :: number
			if math.abs(ground - y) < 3 then
				tree(decor, Vector3.new(x, ground - 1, z), rng, rng:NextNumber(0.85, 1.25))
				placed += 1
			end
		end
	end

	-- Bushes and flowers (walk-through).
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-124, -12), rng:NextNumber(-112, -24)
		local ground = Kit.groundY(x, z)
		if ground and math.abs(ground - y) < 3 and not nearPath(x, z, 6) then
			local size = rng:NextNumber(4, 7)
			part(decor, {
				name = "Bush",
				shape = Enum.PartType.Ball,
				size = Vector3.new(size, size * 0.7, size),
				cframe = CFrame.new(x, ground + size * 0.15, z),
				color = if rng:NextNumber() < 0.5 then hex("#3FAE49") else hex("#2F8F3A"),
				material = Enum.Material.Grass,
				canCollide = false,
			})
			if rng:NextNumber() < 0.5 then
				part(decor, {
					name = "Flower",
					shape = Enum.PartType.Ball,
					size = Vector3.new(1, 1, 1),
					cframe = CFrame.new(
						x + rng:NextNumber(-1.5, 1.5),
						ground + size * 0.45,
						z + rng:NextNumber(-1.5, 1.5)
					),
					color = ({ hex("#FF6FAE"), hex("#FFD54A"), hex("#FF8A3D"), hex("#B45CFF") })[rng:NextInteger(
						1,
						4
					)],
					material = Enum.Material.Neon,
					canCollide = false,
				})
			end
			Kit.addObstacle(Vector3.new(x, ground, z), size / 2)
		end
	end

	-- Mossy ruin blocks.
	for _, spot in { Vector3.new(-104, y, -40), Vector3.new(-36, y, -96), Vector3.new(-30, y, -48) } do
		for i = 1, 4 do
			local h = rng:NextNumber(3, 8)
			part(decor, {
				name = "MossyRuin",
				size = Vector3.new(3, h, 3),
				cframe = CFrame.new(spot + Vector3.new((i - 2.5) * 3.4, h / 2 - 0.5, rng:NextNumber(-1, 1)))
					* CFrame.Angles(0, 0, rng:NextNumber(-0.1, 0.1)),
				color = hex("#7C8C6A"),
				material = Enum.Material.Cobblestone,
			})
		end
		Kit.addObstacle(spot, 8)
	end
end

return Jungle
