--!strict
-- Lighting, sky and all terrain: the ocean, a three-tier island (the Beach,
-- the Jungle / Ruins plateau, the Volcano highland), rock cliffs and a
-- central ridge instead of walls, canyons through the gates, a jungle river
-- that falls onto the beach, an oasis, dunes, lava rivers and a lava lake,
-- the volcano cone, paths, coves and islets.
--
-- Fill heights are approximate in Roblox (voxels are 4 studs), so nothing
-- here is relied on for exact placement; builders raycast the real ground.

local Lighting = game:GetService("Lighting")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local L = Kit.L
local RealTerrain = workspace.Terrain
local M = Enum.Material

-- Every fill goes through the world's theme (sand -> snow in Frostbite Peaks).
local Terrain = {}
function Terrain.FillBlock(_self: any, cframe: CFrame, size: Vector3, material: Enum.Material)
	RealTerrain:FillBlock(cframe, size, Theme.material(material))
end
function Terrain.FillCylinder(
	_self: any,
	cframe: CFrame,
	height: number,
	radius: number,
	material: Enum.Material
)
	RealTerrain:FillCylinder(cframe, height, radius, Theme.material(material))
end
function Terrain.FillBall(_self: any, center: Vector3, radius: number, material: Enum.Material)
	RealTerrain:FillBall(center, radius, Theme.material(material))
end
function Terrain.ReplaceMaterial(
	_self: any,
	area: Region3,
	resolution: number,
	from: Enum.Material,
	to: Enum.Material
)
	RealTerrain:ReplaceMaterial(area, resolution, Theme.material(from), Theme.material(to))
end

local TerrainBuilder = {}

local function region(
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number
): Region3
	return Region3.new(Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ)):ExpandToGrid(4)
end

-- An axis-aligned ellipse filled as 4-stud rows.
local function fillEllipse(
	e: { x: number, z: number, rx: number, rz: number },
	bottom: number,
	top: number,
	material: Enum.Material
)
	for z = e.z - e.rz, e.z + e.rz, 4 do
		local t = (z + 2 - e.z) / e.rz
		if math.abs(t) < 1 then
			local half = e.rx * math.sqrt(1 - t * t)
			Terrain:FillBlock(
				CFrame.new(e.x, (bottom + top) / 2, z + 2),
				Vector3.new(half * 2, top - bottom, 4),
				material
			)
		end
	end
end

-- A vertical cylinder of material between two heights.
local function column(
	x: number,
	z: number,
	bottom: number,
	top: number,
	radius: number,
	material: Enum.Material
)
	Terrain:FillCylinder(CFrame.new(x, (bottom + top) / 2, z), top - bottom, radius, material)
end

-- Points every `spacing` studs along a polyline of { x, z }.
local function along(points: { { number } }, spacing: number): { Vector2 }
	local out = {}
	for i = 1, #points - 1 do
		local a, b = Vector2.new(points[i][1], points[i][2]), Vector2.new(points[i + 1][1], points[i + 1][2])
		local n = math.max(1, math.floor((b - a).Magnitude / spacing))
		for k = 0, n - (if i < #points - 1 then 1 else 0) do
			table.insert(out, a:Lerp(b, k / n))
		end
	end
	return out
end
TerrainBuilder.along = along

-- A chain of rock balls between two points: a natural ridge or cliff face.
local function rockLine(
	from: Vector3,
	to: Vector3,
	spacing: number,
	rng: Random,
	radius: NumberRange,
	height: NumberRange,
	skip: ((Vector3) -> boolean)?,
	jitter: number?
)
	local length = (to - from).Magnitude
	local count = math.max(1, math.floor(length / spacing))
	local j = jitter or 1.5
	for i = 0, count do
		local p = from:Lerp(to, i / count)
		if not skip or not skip(p) then
			local offset = Vector3.new(rng:NextNumber(-j, j), 0, rng:NextNumber(-j, j))
			local center = Vector3.new(p.X, rng:NextNumber(height.Min, height.Max), p.Z) + offset
			Terrain:FillBall(
				center,
				rng:NextNumber(radius.Min, radius.Max),
				if rng:NextNumber() < 0.7 then M.Rock else M.Slate
			)
		end
	end
end

local function nearGate(p: Vector3, margin: number): boolean
	for _, g in L.gates do
		if math.abs(p.X - g.x) < L.gateWidth / 2 + margin and math.abs(p.Z - g.z) < 14 then
			return true
		end
	end
	return false
end

-- Paints a path into the terrain: `from` material becomes `to` along it.
local function paintPath(
	points: { { number } },
	width: number,
	y: number,
	from: Enum.Material,
	to: Enum.Material
)
	local h = width / 2
	for _, p in along(points, 3) do
		Terrain:ReplaceMaterial(region(p.X - h, y - 8, p.Y - h, p.X + h, y + 10, p.Y + h), 4, from, to)
	end
end

function TerrainBuilder.lighting()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 28
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = -0.1
	Lighting.Ambient = Color3.fromRGB(78, 74, 86)
	Lighting.OutdoorAmbient = Color3.fromRGB(122, 122, 136)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.ShadowSoftness = 0.3
	Lighting.GlobalShadows = true

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 8
	sky.StarCount = 1500
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.22
	atmosphere.Color = Color3.fromRGB(196, 226, 248)
	atmosphere.Decay = Color3.fromRGB(104, 146, 190)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.14
	color.Contrast = 0.12
	color.Brightness = -0.01
	color.TintColor = Color3.fromRGB(255, 249, 242)
	color.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 22
	bloom.Threshold = 2.2
	bloom.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.03
	sunRays.Spread = 0.5
	sunRays.Parent = Lighting

	-- Soft tropical clouds.
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.45
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = RealTerrain
	Theme.lighting(Lighting)
end

function TerrainBuilder.build(rng: Random)
	RealTerrain.WaterColor = Color3.fromRGB(24, 178, 196)
	RealTerrain.WaterTransparency = 0.6
	RealTerrain.WaterReflectance = 0.3
	RealTerrain.WaterWaveSize = 0.15
	RealTerrain.WaterWaveSpeed = 9
	RealTerrain:SetMaterialColor(M.Sand, Color3.fromRGB(236, 210, 156))
	RealTerrain:SetMaterialColor(M.Grass, Color3.fromRGB(96, 176, 70))
	RealTerrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(62, 146, 56))
	RealTerrain:SetMaterialColor(M.Sandstone, Color3.fromRGB(218, 182, 124))
	RealTerrain:SetMaterialColor(M.Basalt, Color3.fromRGB(56, 50, 52))
	RealTerrain:SetMaterialColor(M.CrackedLava, Color3.fromRGB(255, 104, 26))
	RealTerrain:SetMaterialColor(M.Rock, Color3.fromRGB(138, 128, 118))
	RealTerrain:SetMaterialColor(M.Slate, Color3.fromRGB(104, 100, 104))
	RealTerrain:SetMaterialColor(M.Ground, Color3.fromRGB(204, 168, 112)) -- beach paths
	RealTerrain:SetMaterialColor(M.Mud, Color3.fromRGB(122, 90, 58)) -- jungle paths
	RealTerrain:SetMaterialColor(M.Cobblestone, Color3.fromRGB(196, 170, 124)) -- ruins paving
	RealTerrain:SetMaterialColor(M.Pavement, Color3.fromRGB(206, 184, 140)) -- ruins plaza
	RealTerrain:SetMaterialColor(M.Asphalt, Color3.fromRGB(78, 66, 62)) -- volcano paths
	if Theme.frost then
		local w = Theme.water
		RealTerrain.WaterColor = w.color
		RealTerrain.WaterTransparency = w.transparency
		RealTerrain.WaterReflectance = w.reflectance
		RealTerrain.WaterWaveSize = w.waveSize
		RealTerrain.WaterWaveSpeed = w.waveSpeed
		for material, color in Theme.terrainColors do
			RealTerrain:SetMaterialColor(material, color)
		end
	end

	local beachTop, plateauTop, highTop = L.beachHeight, L.plateauHeight, L.highlandHeight

	-- Sea floor and ocean (water surface at y = 0).
	Terrain:FillBlock(CFrame.new(0, -34, -60), Vector3.new(1400, 4, 1700), M.Sand)
	Terrain:FillBlock(CFrame.new(0, -16, -60), Vector3.new(1400, 32, 1700), M.Water)

	-- Tier 3: the Volcano highland (basalt), cut back to the cliff line.
	fillEllipse(L.highland, -30, highTop, M.Basalt)
	Terrain:FillBlock(
		CFrame.new(0, plateauTop + 60, (L.volcanoSouthZ + 60) / 2),
		Vector3.new(700, 120, 60 - L.volcanoSouthZ),
		M.Air
	)

	-- Tier 2: the plateau (Jungle and Ruins), cut back to the beach cliff.
	fillEllipse(L.plateau, -30, plateauTop, M.Grass)
	Terrain:FillBlock(
		CFrame.new(0, beachTop + 60, (L.beachNorthZ + 460) / 2),
		Vector3.new(800, 120, 460 - L.beachNorthZ),
		M.Air
	)

	-- Tier 1: the Beach, with stepped shelves for a gentle shoreline and
	-- lobes so the coast isn't a perfect circle.
	local lobes = { { x = L.beach.x, z = L.beach.z, r = L.beach.radius } }
	for _, lobe in L.beachLobes do
		table.insert(lobes, lobe)
	end
	for _, lobe in lobes do
		Terrain:FillCylinder(CFrame.new(lobe.x, -15, lobe.z), 30, lobe.r + 22, M.Sand) -- shallow shelf, top 0
		Terrain:FillCylinder(CFrame.new(lobe.x, -14.5, lobe.z), 31, lobe.r + 10, M.Sand) -- top 1
	end
	for _, lobe in lobes do
		Terrain:FillCylinder(CFrame.new(lobe.x, (beachTop - 30) / 2, lobe.z), beachTop + 30, lobe.r, M.Sand)
	end
	-- Small islets out at sea (decor).
	for _, islet in
		{
			{ x = -330, z = 120, r = 16 },
			{ x = 340, z = -40, r = 14 },
			{ x = 260, z = 360, r = 12 },
			{ x = -280, z = 380, r = 10 },
			{ x = -350, z = -160, r = 18 },
		}
	do
		Terrain:FillCylinder(CFrame.new(islet.x, -15, islet.z), 30, islet.r + 8, M.Sand)
		Terrain:FillCylinder(CFrame.new(islet.x, -13.5, islet.z), 33, islet.r, M.Sand)
	end
	-- Sea stacks.
	for _, s in { { -300, 20 }, { 310, 160 }, { 300, -200 }, { -320, -280 }, { 120, 420 } } do
		Terrain:FillBall(Vector3.new(s[1], 2, s[2]), rng:NextNumber(9, 13), M.Rock)
		Terrain:FillBall(Vector3.new(s[1] + 4, 12, s[2] - 3), rng:NextNumber(6, 8), M.Rock)
	end

	-- Area ground materials.
	local top = highTop + 10
	Terrain:ReplaceMaterial(
		region(-400, -40, L.volcanoSouthZ, L.jungleRuinsX, top, L.beachNorthZ),
		4,
		M.Grass,
		M.LeafyGrass
	)
	Terrain:ReplaceMaterial(
		region(L.jungleRuinsX, -40, L.volcanoSouthZ, 400, top, L.beachNorthZ),
		4,
		M.Grass,
		M.Sandstone
	)
	Terrain:ReplaceMaterial(region(-400, -40, -800, 400, top, L.volcanoSouthZ), 4, M.Grass, M.Basalt)

	-- Ruins: sand dunes along the outer edge; Jungle: gentle grassy mounds.
	for _ = 1, 26 do
		local a = rng:NextNumber(-0.95, 0.75)
		local x = L.plateau.x + math.cos(a) * L.plateau.rx * rng:NextNumber(0.78, 0.92)
		local z = L.plateau.z + math.sin(a) * L.plateau.rz * rng:NextNumber(0.7, 0.9)
		if x > 30 and z < L.beachNorthZ - 20 and z > L.volcanoSouthZ + 16 then
			Terrain:FillBall(
				Vector3.new(x, plateauTop - rng:NextNumber(8, 12), z),
				rng:NextNumber(12, 18),
				M.Sand
			)
		end
	end
	for _ = 1, 16 do
		local x, z = rng:NextNumber(-260, -30), rng:NextNumber(-236, -40)
		Terrain:FillBall(
			Vector3.new(x, plateauTop - rng:NextNumber(10, 13), z),
			rng:NextNumber(12, 16),
			M.LeafyGrass
		)
	end

	-- Rocky outcrops and low ridges break up the Volcano highland.
	for _ = 1, 26 do
		local x, z = rng:NextNumber(-230, 230), rng:NextNumber(-410, -268)
		local r = rng:NextNumber(6, 12)
		Terrain:FillBall(
			Vector3.new(x, highTop - r * 0.45, z),
			r,
			if rng:NextNumber() < 0.5 then M.Slate else M.Basalt
		)
	end

	-- Cliff where the beach meets the plateau (gaps at the gates and the
	-- waterfall), with rocks stepping out onto the sand.
	local river = L.river
	local fallX = river[#river][1]
	rockLine(
		Vector3.new(-L.plateau.rx + 10, 0, L.beachNorthZ - 1),
		Vector3.new(L.plateau.rx - 10, 0, L.beachNorthZ - 1),
		6,
		rng,
		NumberRange.new(5, 7.5),
		NumberRange.new(beachTop + 4, plateauTop - 2),
		function(p)
			return nearGate(p, 5) or math.abs(p.X - fallX) < 9
		end,
		2.5
	)
	-- Sea cliffs around the plateau and highland edges.
	for _, e in { L.plateau, L.highland } do
		for deg = 0, 359, 4 do
			local a = math.rad(deg)
			local x = e.x + math.cos(a) * (e.rx - 2)
			local z = e.z + math.sin(a) * (e.rz - 2)
			local tierTop = if e == L.highland then highTop else plateauTop
			local inside = if e == L.highland then z < L.volcanoSouthZ - 8 else z < L.beachNorthZ - 8
			if inside then
				Terrain:FillBall(
					Vector3.new(x, rng:NextNumber(4, tierTop - 3), z),
					rng:NextNumber(7, 11),
					if rng:NextNumber() < 0.75 then M.Rock else M.Slate
				)
			end
		end
	end

	-- The central ridge between the Jungle and the Ruins: a tall rocky spine.
	rockLine(
		Vector3.new(L.jungleRuinsX, 0, L.beachNorthZ - 8),
		Vector3.new(L.jungleRuinsX, 0, L.volcanoSouthZ + 4),
		6,
		rng,
		NumberRange.new(9, 13),
		NumberRange.new(plateauTop + 2, plateauTop + 12),
		nil,
		3
	)
	for _ = 1, 8 do
		local z = rng:NextNumber(L.volcanoSouthZ + 20, L.beachNorthZ - 30)
		Terrain:FillBall(
			Vector3.new(rng:NextNumber(-3, 3), plateauTop + rng:NextNumber(14, 22), z),
			rng:NextNumber(7, 10),
			M.Rock
		)
	end
	-- Cliff up to the highland (gap at the Volcano gate).
	rockLine(
		Vector3.new(-L.highland.rx + 10, 0, L.volcanoSouthZ - 1),
		Vector3.new(L.highland.rx - 10, 0, L.volcanoSouthZ - 1),
		6,
		rng,
		NumberRange.new(6, 8.5),
		NumberRange.new(plateauTop + 3, highTop - 1),
		function(p)
			return nearGate(p, 4)
		end,
		2.5
	)

	-- Canyons through the cliffs for the gates (the ramps are parts).
	local halfWidth = L.gateWidth / 2 + 2
	for areaId, g in L.gates do
		local floorY = if areaId == "Volcano" then plateauTop else beachTop
		local length = L.rampLength + 4
		Terrain:FillBlock(
			CFrame.new(g.x, floorY + 60, g.z - length / 2 + 2),
			Vector3.new(halfWidth * 2, 120, length),
			M.Air
		)
		-- Rocky canyon walls.
		for _, side in { -1, 1 } do
			rockLine(
				Vector3.new(g.x + side * (halfWidth + 5), 0, g.z - 2),
				Vector3.new(g.x + side * (halfWidth + 5), 0, g.z - length + 2),
				6,
				rng,
				NumberRange.new(5, 6.5),
				NumberRange.new(floorY + 4, floorY + 14),
				nil,
				1
			)
		end
	end

	-- The Jungle river: a channel with water a little below its banks, and
	-- a pool where it lands on the beach.
	for _, p in along(river, 3) do
		column(p.X, p.Y, plateauTop - 4, plateauTop + 40, 7, M.Air)
		column(p.X, p.Y, plateauTop - 8, plateauTop - 1.5, 7, M.Water)
	end
	local pool = L.beachPool
	column(pool.x, pool.z, beachTop - 1, beachTop + 40, pool.radius, M.Air)
	column(pool.x, pool.z, beachTop - 6, beachTop - 0.5, pool.radius, M.Water)
	-- Where the river starts: a pool at the foot of the highland cliff.
	local source = river[1]
	column(source[1], source[2] + 6, plateauTop - 4, plateauTop + 10, 12, M.Air)
	column(source[1], source[2] + 6, plateauTop - 8, plateauTop - 1.5, 12, M.Water)

	-- Ruins oasis: a pond with a grassy rim.
	local oasis = L.oasis
	column(oasis.x, oasis.z, plateauTop - 1, plateauTop + 1, oasis.radius + 7, M.Grass)
	column(oasis.x, oasis.z, plateauTop - 4, plateauTop + 40, oasis.radius, M.Air)
	column(oasis.x, oasis.z, plateauTop - 8, plateauTop - 1.5, oasis.radius, M.Water)

	-- Volcano: many thin stacked cylinders make a smooth cone, with a crater.
	local v = L.volcano
	-- One ring per voxel layer (4 studs) so the cone reads as a smooth slope.
	local steps = math.floor(v.height / 4)
	for i = 0, steps - 1 do
		local height = (i + 1) * (v.height / steps)
		local radius = v.radius - i * ((v.radius - 18) / steps)
		local material = if i >= steps - 3 then M.CrackedLava elseif i % 9 >= 7 then M.Slate else M.Basalt
		column(v.x, v.z, -30, highTop + height, radius, material)
	end
	local peakY = highTop + v.height
	column(v.x, v.z, peakY - 14, peakY + 4, 14, M.Air)
	column(v.x, v.z, peakY - 17, peakY - 13, 15, M.CrackedLava)
	-- Rocky shoulders on the cone.
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local t = rng:NextNumber(0.15, 0.7)
		local r = v.radius * (1 - t) * 0.92
		Terrain:FillBall(
			Vector3.new(v.x + math.cos(a) * r, highTop + v.height * t, v.z + math.sin(a) * r),
			rng:NextNumber(10, 18),
			if rng:NextNumber() < 0.5 then M.Slate else M.Basalt
		)
	end

	-- Lava streams down the cone's face, painted into its surface.
	for _, angle in { math.rad(-25), math.rad(18), math.rad(48) } do
		local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
		for r = 16, v.radius - 6, 3 do
			local x, z = v.x + dir.X * r, v.z + dir.Z * r
			local t = (r - 16) / (v.radius - 22)
			local y = highTop + v.height * (1 - t)
			local w = 3 + t * 2
			Terrain:ReplaceMaterial(
				region(x - w, y - 12, z - w, x + w, y + 12, z + w),
				4,
				M.Basalt,
				M.CrackedLava
			)
			Terrain:ReplaceMaterial(
				region(x - w, y - 12, z - w, x + w, y + 12, z + w),
				4,
				M.Slate,
				M.CrackedLava
			)
		end
	end

	-- Lava rivers and a lava lake on the highland (flush with the ground).
	for _, riverLine in L.lavaRivers do
		for _, p in along(riverLine, 3) do
			Terrain:ReplaceMaterial(
				region(p.X - 3, highTop - 6, p.Y - 3, p.X + 3, highTop + 6, p.Y + 3),
				4,
				M.Basalt,
				M.CrackedLava
			)
		end
	end
	local lake = L.lavaLake
	column(lake.x, lake.z, highTop - 2, highTop + 40, lake.radius, M.Air)
	column(lake.x, lake.z, highTop - 7, highTop - 1.5, lake.radius, M.CrackedLava)

	-- Paths painted into the ground.
	for _, line in L.paths.Beach do
		paintPath(line, 9, beachTop, M.Sand, M.Ground)
	end
	for _, line in L.paths.Jungle do
		paintPath(line, 8, plateauTop, M.LeafyGrass, M.Mud)
	end
	for _, line in L.paths.Ruins do
		paintPath(line, 10, plateauTop, M.Sandstone, M.Cobblestone)
		paintPath(line, 10, plateauTop, M.Sand, M.Cobblestone)
	end
	for _, line in L.paths.Volcano do
		paintPath(line, 8, highTop, M.Basalt, M.Asphalt)
	end
	-- Paved plaza in front of the temple.
	local t = L.temple
	Terrain:ReplaceMaterial(
		region(
			t.x - 40,
			plateauTop - 8,
			t.z + t.size / 2 - 4,
			t.x + 40,
			plateauTop + 10,
			t.z + t.size / 2 + 40
		),
		4,
		M.Sandstone,
		M.Pavement
	)
end

return TerrainBuilder
