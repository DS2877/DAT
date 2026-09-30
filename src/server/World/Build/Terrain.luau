--!strict
-- Lighting, sky and all terrain: the ocean, a stepped island (low Beach,
-- a higher plateau for the Jungle and Ruins, the Volcano behind), natural
-- rock cliffs and ridges instead of walls, canyons through the gates, coves
-- and islets, a waterfall pool, the volcano cone and its lava rivers.

local Lighting = game:GetService("Lighting")

local Kit = require(script.Parent.Kit)

local L = Kit.L
local Terrain = workspace.Terrain
local M = Enum.Material

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

-- A chain of rock balls between two points: a natural ridge or cliff face.
local function rockLine(
	from: Vector3,
	to: Vector3,
	spacing: number,
	rng: Random,
	radius: NumberRange,
	height: NumberRange,
	skip: ((Vector3) -> boolean)?
)
	local length = (to - from).Magnitude
	local count = math.max(1, math.floor(length / spacing))
	for i = 0, count do
		local p = from:Lerp(to, i / count)
		if not skip or not skip(p) then
			local jitter = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
			local center = Vector3.new(p.X, rng:NextNumber(height.Min, height.Max), p.Z) + jitter
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
		if math.abs(p.X - g.x) < L.gateWidth / 2 + margin and math.abs(p.Z - g.z) < 12 then
			return true
		end
	end
	return false
end

function TerrainBuilder.lighting()
	Lighting.Ambient = Color3.fromRGB(120, 115, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(155, 145, 135)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ExposureCompensation = 0.15
	Lighting.GeographicLatitude = 20

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.24
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(205, 236, 255)
	atmosphere.Decay = Color3.fromRGB(110, 185, 225)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.22
	color.Contrast = 0.07
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 250, 240)
	color.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.05
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting

	-- Soft tropical clouds.
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.5
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = Terrain
end

function TerrainBuilder.build(rng: Random)
	Terrain.WaterColor = Color3.fromRGB(28, 196, 208)
	Terrain.WaterTransparency = 0.65
	Terrain.WaterReflectance = 0.35
	Terrain.WaterWaveSize = 0.12
	Terrain.WaterWaveSpeed = 8
	Terrain:SetMaterialColor(M.Sand, Color3.fromRGB(247, 224, 165))
	Terrain:SetMaterialColor(M.Grass, Color3.fromRGB(96, 186, 72))
	Terrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(58, 150, 62))
	Terrain:SetMaterialColor(M.Sandstone, Color3.fromRGB(214, 178, 122))
	Terrain:SetMaterialColor(M.Basalt, Color3.fromRGB(58, 52, 54))
	Terrain:SetMaterialColor(M.CrackedLava, Color3.fromRGB(255, 110, 30))
	Terrain:SetMaterialColor(M.Rock, Color3.fromRGB(140, 132, 124))
	Terrain:SetMaterialColor(M.Slate, Color3.fromRGB(112, 108, 112))

	local b = L.bounds
	local centerX, centerZ = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
	local width, depth = b.maxX - b.minX + 240, b.maxZ - b.minZ + 240
	local beachTop, plateauTop = L.beachHeight, L.plateauHeight

	-- Sea floor and ocean (water surface at y = 0).
	Terrain:FillBlock(CFrame.new(centerX, -34, centerZ), Vector3.new(width, 4, depth), M.Sand)
	Terrain:FillBlock(CFrame.new(centerX, -16, centerZ), Vector3.new(width, 32, depth), M.Water)

	-- The plateau (Jungle, Ruins, Volcano floor), then clear everything above
	-- the beach level on the beach side so the beach can be laid over it.
	Terrain:FillCylinder(
		CFrame.new(L.plateau.x, (plateauTop - 30) / 2, L.plateau.z),
		plateauTop + 30,
		L.plateau.radius,
		M.Grass
	)
	Terrain:FillBlock(
		CFrame.new(0, beachTop + 30, (L.beachNorthZ + 260) / 2 + 0.5),
		Vector3.new(460, 60, 260 - L.beachNorthZ),
		M.Air
	)

	-- Beach: stepped shelves for a gentle shoreline, plus coves / lobes so the
	-- coast isn't a perfect circle.
	local lobes = {
		{ x = L.beach.x, z = L.beach.z, r = L.beach.radius },
		{ x = -112, z = 95, r = 30 },
		{ x = 118, z = 60, r = 28 },
		{ x = 96, z = 120, r = 22 },
		{ x = -60, z = 160, r = 24 },
	}
	for _, lobe in lobes do
		Terrain:FillCylinder(CFrame.new(lobe.x, -15, lobe.z), 30, lobe.r + 18, M.Sand) -- shallow shelf, top 0
		Terrain:FillCylinder(CFrame.new(lobe.x, -14.5, lobe.z), 31, lobe.r + 8, M.Sand) -- top 1
	end
	for _, lobe in lobes do
		Terrain:FillCylinder(CFrame.new(lobe.x, (beachTop - 30) / 2, lobe.z), beachTop + 30, lobe.r, M.Sand)
	end

	-- Small islets out at sea (decor).
	for _, islet in
		{ { x = -178, z = 70, r = 13 }, { x = 182, z = -40, r = 11 }, { x = 158, z = 172, r = 9 } }
	do
		Terrain:FillCylinder(CFrame.new(islet.x, -15, islet.z), 30, islet.r + 7, M.Sand)
		Terrain:FillCylinder(CFrame.new(islet.x, -13.5, islet.z), 33, islet.r, M.Sand)
	end

	-- Area ground materials.
	local top = plateauTop + 6
	Terrain:ReplaceMaterial(
		region(-230, -40, -320, L.jungleRuinsX, top, L.beachNorthZ),
		4,
		M.Grass,
		M.LeafyGrass
	)
	Terrain:ReplaceMaterial(
		region(L.jungleRuinsX, -40, -320, 230, top, L.beachNorthZ),
		4,
		M.Grass,
		M.Sandstone
	)
	Terrain:ReplaceMaterial(region(-230, -40, -320, 230, top, L.volcanoSouthZ), 4, M.LeafyGrass, M.Basalt)
	Terrain:ReplaceMaterial(region(-230, -40, -320, 230, top, L.volcanoSouthZ), 4, M.Sandstone, M.Basalt)

	-- Rocky cliff face where the beach meets the plateau (gaps at the gates).
	rockLine(
		Vector3.new(-L.plateau.radius + 8, 0, L.beachNorthZ - 1),
		Vector3.new(L.plateau.radius - 8, 0, L.beachNorthZ - 1),
		6.5,
		rng,
		NumberRange.new(4.5, 6.5),
		NumberRange.new(beachTop + 3, plateauTop - 2),
		function(p)
			return nearGate(p, 5)
		end
	)

	-- Sea cliffs around the plateau's outer edge.
	for deg = 0, 359, 7 do
		local a = math.rad(deg)
		local x = L.plateau.x + math.cos(a) * (L.plateau.radius - 1)
		local z = L.plateau.z + math.sin(a) * (L.plateau.radius - 1)
		if z < L.beachNorthZ - 6 then
			Terrain:FillBall(
				Vector3.new(x, rng:NextNumber(4, plateauTop - 3), z),
				rng:NextNumber(6, 9),
				M.Rock
			)
		end
	end

	-- Rocky ridges between the Jungle and Ruins, and before the Volcano.
	rockLine(
		Vector3.new(L.jungleRuinsX, 0, L.beachNorthZ - 6),
		Vector3.new(L.jungleRuinsX, 0, L.volcanoSouthZ + 4),
		5,
		rng,
		NumberRange.new(6, 8.5),
		NumberRange.new(plateauTop + 1, plateauTop + 5)
	)
	rockLine(
		Vector3.new(-L.plateau.radius + 12, 0, L.volcanoSouthZ),
		Vector3.new(L.plateau.radius - 12, 0, L.volcanoSouthZ),
		5,
		rng,
		NumberRange.new(6, 8.5),
		NumberRange.new(plateauTop + 1, plateauTop + 5),
		function(p)
			return nearGate(p, 4)
		end
	)

	-- Canyons through the cliff for the beach gates (ramps are parts).
	for _, areaId in { "Jungle", "Ruins" } do
		local g = L.gates[areaId]
		local halfWidth = L.gateWidth / 2 + 2
		Terrain:FillBlock(CFrame.new(g.x, beachTop + 30, g.z - 14), Vector3.new(halfWidth * 2, 60, 32), M.Air)
	end
	-- Keep the Volcano gate's opening clear of ridge rocks.
	local vg = L.gates.Volcano
	Terrain:FillBlock(CFrame.new(vg.x, plateauTop + 20, vg.z), Vector3.new(L.gateWidth + 4, 40, 14), M.Air)
	Terrain:FillBlock(CFrame.new(vg.x, plateauTop - 10, vg.z), Vector3.new(L.gateWidth + 4, 20, 14), M.Basalt)

	-- Waterfall pool at the foot of the Jungle cliff (the falls are parts).
	local wf = L.waterfall
	Terrain:FillCylinder(CFrame.new(wf.x, beachTop - 2, wf.z + 9), 6, 9, M.Water)
	Terrain:FillCylinder(CFrame.new(wf.x, beachTop - 5.5, wf.z + 9), 1, 10, M.Sand)

	-- Volcano: many thin stacked cylinders make a smooth cone, with a crater.
	local v = L.volcano
	local steps = 30
	for i = 0, steps - 1 do
		local height = (i + 1) * (v.height / steps)
		local radius = v.radius - i * ((v.radius - 14) / steps)
		local material = if i >= steps - 3 then M.CrackedLava elseif i % 5 == 4 then M.Slate else M.Basalt
		Terrain:FillCylinder(CFrame.new(v.x, plateauTop - 4 + height / 2, v.z), height + 8, radius, material)
	end
	local peakY = plateauTop + v.height
	Terrain:FillCylinder(CFrame.new(v.x, peakY - 5, v.z), 16, 11, M.Air)
	Terrain:FillCylinder(CFrame.new(v.x, peakY - 12, v.z), 4, 12, M.CrackedLava)

	-- Lava rivers winding across the Volcano floor (flush with the ground).
	for _, river in L.lavaRivers do
		for i = 1, #river - 1 do
			local a, c = river[i], river[i + 1]
			local from, to = Vector3.new(a[1], 0, a[2]), Vector3.new(c[1], 0, c[2])
			local n = math.max(1, math.floor((to - from).Magnitude / 3))
			for k = 0, n do
				local p = from:Lerp(to, k / n)
				Terrain:ReplaceMaterial(
					region(p.X - 2.5, plateauTop - 4, p.Z - 2.5, p.X + 2.5, plateauTop + 2, p.Z + 2.5),
					4,
					M.Basalt,
					M.CrackedLava
				)
			end
		end
	end
end

return TerrainBuilder
