--!strict
-- The Ancient Ruins: a stepped temple with a glowing gem and braziers,
-- guardian statues, a tiled plaza, stone arches, broken walls, obelisks with
-- glowing glyphs, and fallen pillars.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TreasureBuilder = require(ReplicatedStorage.Shared.Builders.TreasureBuilder)
local Kit = require(script.Parent.Kit)

local L = Kit.L
local part, hex = Kit.part, Kit.hex

local Ruins = {}

local STONE = hex("#C8B48A")
local STONE_DARK = hex("#A8966E")
local TEMPLE = Vector3.new(72, 0, -78)

local function temple(parent: Instance, center: Vector3)
	for i = 0, 4 do
		local size = 34 - i * 6
		part(parent, {
			name = "TempleStep",
			size = Vector3.new(size, 5, size),
			cframe = CFrame.new(center + Vector3.new(0, 2.5 + i * 5, 0)),
			color = STONE:Lerp(Color3.new(0, 0, 0), i * 0.03),
			material = Enum.Material.Sandstone,
		})
	end
	part(parent, {
		name = "TempleTop",
		size = Vector3.new(8, 6, 8),
		cframe = CFrame.new(center + Vector3.new(0, 28, 0)),
		color = STONE,
		material = Enum.Material.Sandstone,
	})
	local gem = part(parent, {
		name = "TempleGem",
		size = Vector3.new(3.6, 3.6, 3.6),
		cframe = CFrame.new(center + Vector3.new(0, 34, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		color = hex("#4FD1C5"),
		material = Enum.Material.Neon,
	})
	Kit.light(gem, gem.Color, 30, 2.5)
	-- Braziers on the top tier corners.
	for _, c in { { -9, -9 }, { 9, -9 }, { -9, 9 }, { 9, 9 } } do
		local bowl = part(parent, {
			name = "Brazier",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.2, 2.2, 2.2),
			cframe = CFrame.new(center + Vector3.new(c[1], 25.6, c[2])) * CFrame.Angles(0, 0, math.rad(90)),
			color = hex("#3B2A1A"),
			material = Enum.Material.Metal,
		})
		Kit.fire(bowl, 3)
		Kit.light(bowl, Color3.fromRGB(255, 160, 70), 16, 1.2)
	end
	-- Guardian statues at the foot of the stairs (south side).
	for _, dx in { -12, 12 } do
		local statue = TreasureBuilder.build("AncientStatue")
		statue:ScaleTo(3.2)
		statue:PivotTo(CFrame.new(center + Vector3.new(dx, 3.6, 21)) * CFrame.Angles(0, math.rad(180), 0))
		for _, d in statue:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = STONE_DARK
				d.CanCollide = d.Transparency < 1
			end
		end
		statue.Parent = parent
	end
	Kit.addObstacle(center, 22)
end

local function arch(parent: Instance, base: Vector3, yaw: number)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	for _, dx in { -5, 5 } do
		part(parent, {
			name = "ArchPillar",
			size = Vector3.new(2.6, 12, 2.6),
			cframe = cf * CFrame.new(dx, 6, 0),
			color = STONE,
			material = Enum.Material.Sandstone,
		})
	end
	part(parent, {
		name = "ArchTop",
		size = Vector3.new(13.5, 2.4, 3),
		cframe = cf * CFrame.new(0, 13.2, 0),
		color = STONE_DARK,
		material = Enum.Material.Sandstone,
	})
	part(parent, {
		name = "ArchGlyph",
		size = Vector3.new(1.4, 1.4, 0.3),
		cframe = cf * CFrame.new(0, 13.2, -1.6) * CFrame.Angles(0, 0, math.rad(45)),
		color = hex("#4FD1C5"),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	Kit.addObstacle(base, 7)
end

local function brokenWall(parent: Instance, from: Vector3, to: Vector3, rng: Random)
	local dir = (to - from).Unit
	local length = (to - from).Magnitude
	local count = math.floor(length / 3.2)
	for i = 0, count do
		if rng:NextNumber() > 0.25 then
			local h = rng:NextNumber(2, 7)
			local p = from + dir * (i * 3.2)
			part(parent, {
				name = "WallBlock",
				size = Vector3.new(3.2, h, 2.4),
				cframe = CFrame.lookAt(
					p + Vector3.new(0, h / 2 - 0.3, 0),
					p + Vector3.new(0, h / 2 - 0.3, 0) + dir
				) * CFrame.Angles(0, math.rad(90), rng:NextNumber(-0.04, 0.04)),
				color = if i % 3 == 0 then STONE_DARK else STONE,
				material = Enum.Material.Sandstone,
			})
			Kit.addObstacle(p, 2.5)
		end
	end
end

local function obelisk(parent: Instance, base: Vector3)
	part(parent, {
		name = "ObeliskBase",
		size = Vector3.new(4, 1.5, 4),
		cframe = CFrame.new(base + Vector3.new(0, 0.75, 0)),
		color = STONE_DARK,
		material = Enum.Material.Sandstone,
	})
	part(parent, {
		name = "Obelisk",
		size = Vector3.new(2.4, 14, 2.4),
		cframe = CFrame.new(base + Vector3.new(0, 8.5, 0)),
		color = STONE,
		material = Enum.Material.Sandstone,
	})
	local glyph = part(parent, {
		name = "ObeliskGlyph",
		size = Vector3.new(1.6, 1.6, 2.6),
		cframe = CFrame.new(base + Vector3.new(0, 11, 0)),
		color = hex("#4FD1C5"),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	Kit.light(glyph, glyph.Color, 12, 1)
	Kit.addObstacle(base, 3.5)
end

function Ruins.build(rng: Random)
	local decor = workspace:FindFirstChild("Decor") or Kit.folder("Decor", workspace)
	local y = L.plateauHeight
	local center = Vector3.new(TEMPLE.X, y - 1, TEMPLE.Z)

	-- Plaza tiles around the temple (walk-through, so spots can still spawn on them).
	for x = TEMPLE.X - 30, TEMPLE.X + 30, 8 do
		for z = TEMPLE.Z - 28, TEMPLE.Z + 32, 8 do
			local inTemple = math.abs(x - TEMPLE.X) < 18 and math.abs(z - TEMPLE.Z) < 18
			if not inTemple and rng:NextNumber() > 0.22 then
				part(decor, {
					name = "PlazaTile",
					size = Vector3.new(7.6, 0.3, 7.6),
					cframe = CFrame.new(x, y + 0.1, z) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), 0),
					color = STONE:Lerp(STONE_DARK, rng:NextNumber(0, 1)),
					material = Enum.Material.Slate,
					canCollide = false,
				})
			end
		end
	end

	temple(decor, center)
	arch(decor, Vector3.new(66, y - 0.5, -48), 0)
	arch(decor, Vector3.new(110, y - 0.5, -104), math.rad(40))
	brokenWall(decor, Vector3.new(22, y, -60), Vector3.new(22, y, -104), rng)
	brokenWall(decor, Vector3.new(30, y, -110), Vector3.new(92, y, -112), rng)
	brokenWall(decor, Vector3.new(118, y, -30), Vector3.new(118, y, -80), rng)
	for _, p in { { 40, -28 }, { 102, -30 }, { 34, -92 }, { 112, -60 } } do
		obelisk(decor, Vector3.new(p[1], y, p[2]))
	end

	-- Fallen and standing pillars.
	for _ = 1, 10 do
		local x, z = rng:NextNumber(18, 122), rng:NextNumber(-112, -26)
		local ground = Kit.groundY(x, z)
		local clear = (Vector2.new(x, z) - Vector2.new(TEMPLE.X, TEMPLE.Z)).Magnitude > 28
		if ground and math.abs(ground - y) < 3 and clear then
			local fallen = rng:NextNumber() < 0.5
			local height = rng:NextNumber(8, 16)
			part(decor, {
				name = if fallen then "FallenPillar" else "Pillar",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(height, 3, 3),
				cframe = if fallen
					then CFrame.new(x, ground + 1.3, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
					else CFrame.new(x, ground + height / 2 - 0.5, z) * CFrame.Angles(0, 0, math.rad(90)),
				color = hex("#D9C9A3"),
				material = Enum.Material.Sandstone,
			})
			Kit.addObstacle(Vector3.new(x, ground, z), if fallen then height / 2 + 1 else 3)
		end
	end
end

return Ruins
