--!strict
-- Builds the island at server start: lighting, terrain, the base (sell pad and
-- upgrade stations), area walls and gates, decorations, and the candidate
-- points where dig spots may appear.
--
-- Everything is deterministic (fixed seeds). A hand-built map can replace this
-- later: keep the named parts under workspace.Base / workspace.Gates and
-- provide the same `World` fields (see World.luau).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local DigConfig = require(ReplicatedStorage.Shared.Config.Dig)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local ShovelBuilder = require(ReplicatedStorage.Shared.Builders.ShovelBuilder)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)

local Terrain = workspace.Terrain
local L = MapLayout

local MapBuilder = {}

local DECK_TOP = L.beachHeight + L.base.deckHeight

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

type PartProps = {
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	canCollide: boolean?,
	name: string?,
}

local function part(parent: Instance, props: PartProps): Part
	local p = Instance.new("Part")
	p.Name = props.name or "Part"
	p.Anchored = true
	p.Shape = props.shape or Enum.PartType.Block
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color or Color3.new(1, 1, 1)
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.CanCollide = if props.canCollide == nil then true else props.canCollide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

-- A world-space label that always faces the camera.
local function billboard(
	adornee: BasePart,
	title: string,
	subtitle: string?,
	color: Color3,
	heightOffset: number,
	studsWide: number
): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(studsWide, studsWide * 0.42)
	gui.StudsOffsetWorldSpace = Vector3.new(0, heightOffset, 0)
	gui.MaxDistance = 400
	gui.LightInfluence = 0
	gui.Parent = adornee

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, if subtitle then 0.62 else 1)
	titleLabel.Font = Enum.Font.LuckiestGuy
	titleLabel.Text = title
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = color
	titleLabel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(40, 25, 10)
	stroke.Parent = titleLabel

	if subtitle then
		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.62)
		sub.Size = UDim2.fromScale(1, 0.38)
		sub.Font = Enum.Font.FredokaOne
		sub.Text = subtitle
		sub.TextScaled = true
		sub.TextColor3 = Color3.new(1, 1, 1)
		sub.Parent = gui
		local subStroke = Instance.new("UIStroke")
		subStroke.Thickness = 2
		subStroke.Color = Color3.fromRGB(40, 25, 10)
		subStroke.Parent = sub
	end
	return gui
end

---------------------------------------------------------------------------
-- Lighting
---------------------------------------------------------------------------

local function buildLighting()
	Lighting.Ambient = Color3.fromRGB(120, 115, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 130)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ExposureCompensation = 0.15
	Lighting.GeographicLatitude = 20

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.26
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(205, 236, 255)
	atmosphere.Decay = Color3.fromRGB(110, 185, 225)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.1
	atmosphere.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.2
	color.Contrast = 0.06
	color.Brightness = 0.02
	color.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.04
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting
end

---------------------------------------------------------------------------
-- Terrain
---------------------------------------------------------------------------

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

local function buildTerrain()
	Terrain.WaterColor = Color3.fromRGB(30, 190, 205)
	Terrain.WaterTransparency = 0.6
	Terrain.WaterReflectance = 0.35
	Terrain.WaterWaveSize = 0.12
	Terrain.WaterWaveSpeed = 8
	Terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(247, 224, 165))
	Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(96, 186, 72))
	Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(58, 150, 62))
	Terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(212, 176, 120))
	Terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(62, 55, 55))
	Terrain:SetMaterialColor(Enum.Material.CrackedLava, Color3.fromRGB(255, 110, 30))

	local b = L.bounds
	local centerX, centerZ = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
	local width, depth = b.maxX - b.minX + 200, b.maxZ - b.minZ + 200

	-- Sea floor and ocean (water surface at y = 0).
	Terrain:FillBlock(CFrame.new(centerX, -34, centerZ), Vector3.new(width, 4, depth), Enum.Material.Sand)
	Terrain:FillBlock(CFrame.new(centerX, -16, centerZ), Vector3.new(width, 32, depth), Enum.Material.Water)

	-- Northern plateau (Jungle + Ruins), then clear the part that overlaps the
	-- beach so the beach can be laid over it.
	local plateauTop = L.plateauHeight
	Terrain:FillCylinder(
		CFrame.new(L.plateau.x, (plateauTop - 30) / 2, L.plateau.z),
		plateauTop + 30,
		L.plateau.radius,
		Enum.Material.Grass
	)
	Terrain:FillBlock(
		CFrame.new(0, L.beachHeight + 10, (L.beachNorthZ + 250) / 2 + 0.5),
		Vector3.new(420, 20, 250 - L.beachNorthZ),
		Enum.Material.Air
	)

	-- Beach: stepped shelves for a gentle shoreline, main sand top at beachHeight.
	local bx, bz, br = L.beach.x, L.beach.z, L.beach.radius
	Terrain:FillCylinder(CFrame.new(bx, -15, bz), 30, br + 18, Enum.Material.Sand) -- underwater shelf, top 0
	Terrain:FillCylinder(CFrame.new(bx, -14.5, bz), 31, br + 9, Enum.Material.Sand) -- top 1
	Terrain:FillCylinder(
		CFrame.new(bx, (L.beachHeight - 30) / 2, bz),
		L.beachHeight + 30,
		br,
		Enum.Material.Sand
	)

	-- Area ground materials.
	local top = plateauTop + 4
	Terrain:ReplaceMaterial(
		region(-200, -40, -300, L.jungleRuinsX, top, L.beachNorthZ),
		4,
		Enum.Material.Grass,
		Enum.Material.LeafyGrass
	)
	Terrain:ReplaceMaterial(
		region(L.jungleRuinsX, -40, -300, 200, top, L.beachNorthZ),
		4,
		Enum.Material.Grass,
		Enum.Material.Sandstone
	)
	Terrain:ReplaceMaterial(
		region(-200, -40, -300, 200, top, L.volcanoSouthZ),
		4,
		Enum.Material.LeafyGrass,
		Enum.Material.Basalt
	)
	Terrain:ReplaceMaterial(
		region(-200, -40, -300, 200, top, L.volcanoSouthZ),
		4,
		Enum.Material.Sandstone,
		Enum.Material.Basalt
	)

	-- Volcano: stacked cylinders make a stepped cone, with a lava crater.
	local v = L.volcano
	local steps = 14
	for i = 0, steps - 1 do
		local height = (i + 1) * (v.height / steps)
		local radius = v.radius - i * ((v.radius - 18) / steps)
		local material = if i >= steps - 2 then Enum.Material.CrackedLava else Enum.Material.Basalt
		Terrain:FillCylinder(CFrame.new(v.x, plateauTop - 4 + height / 2, v.z), height + 8, radius, material)
	end
	local peakY = plateauTop + v.height
	Terrain:FillCylinder(CFrame.new(v.x, peakY - 4, v.z), 16, 13, Enum.Material.Air)
	Terrain:FillCylinder(CFrame.new(v.x, peakY - 12, v.z), 4, 14, Enum.Material.CrackedLava)
end

---------------------------------------------------------------------------
-- Decorations
---------------------------------------------------------------------------

local obstacles: { Vector3 } = {}

local function addObstacle(position: Vector3)
	table.insert(obstacles, position)
end

local function palm(parent: Instance, base: Vector3, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Palm"
	local lean = rng:NextNumber(-0.35, 0.35)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local trunkColor = hex("#9C7447")
	local segments = 6
	local pos = base
	local dir = (CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean * 0.4, 0, 0)).UpVector
	for i = 1, segments do
		local seg = 2.4
		local nextPos = pos + dir * seg
		part(model, {
			name = "Trunk",
			size = Vector3.new(1.3 - i * 0.07, seg + 0.3, 1.3 - i * 0.07),
			cframe = CFrame.lookAt((pos + nextPos) / 2, nextPos) * CFrame.Angles(math.rad(90), 0, 0),
			color = if i % 2 == 0 then trunkColor else trunkColor:Lerp(Color3.new(0, 0, 0), 0.12),
			material = Enum.Material.Wood,
		})
		pos = nextPos
		dir = (CFrame.fromAxisAngle(Vector3.new(math.cos(yaw), 0, math.sin(yaw)), lean * 0.12) * dir).Unit
	end
	local crown = pos
	for i = 1, 7 do
		local angle = (i / 7) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local leaf = CFrame.new(crown) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(-22), 0, 0)
		part(model, {
			name = "Leaf",
			size = Vector3.new(2.2, 0.25, 7),
			cframe = leaf * CFrame.new(0, 0, -3.3),
			color = if i % 2 == 0 then hex("#3FAE49") else hex("#56C451"),
			material = Enum.Material.Grass,
			canCollide = false,
		})
	end
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		part(model, {
			name = "Coconut",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.9, 0.9, 0.9),
			cframe = CFrame.new(crown + Vector3.new(math.cos(a) * 0.6, -0.6, math.sin(a) * 0.6)),
			color = hex("#6B4A1F"),
			canCollide = false,
		})
	end
	model.Parent = parent
	addObstacle(base)
end

local function rock(parent: Instance, position: Vector3, scale: number, rng: Random, color: Color3?)
	part(parent, {
		name = "Rock",
		size = Vector3.new(4, 3, 3.5) * scale,
		cframe = CFrame.new(position)
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
		color = color or hex("#8E9196"),
		material = Enum.Material.Slate,
	})
	addObstacle(position)
end

local function shipwreck(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "Shipwreck"
	local wood = hex("#7A5230")
	local dark = hex("#5B3A22")
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
	model.Parent = parent
	addObstacle(origin.Position)
end

local function jungleTree(parent: Instance, base: Vector3, rng: Random)
	local height = rng:NextNumber(18, 30)
	part(parent, {
		name = "JungleTrunk",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height, 2.4, 2.4),
		cframe = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#6B4A2B"),
		material = Enum.Material.Wood,
	})
	for i = 1, 3 do
		local offset =
			Vector3.new(rng:NextNumber(-3, 3), height + rng:NextNumber(-2, 3), rng:NextNumber(-3, 3))
		local size = rng:NextNumber(10, 15)
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
	addObstacle(base)
end

local function temple(parent: Instance, center: Vector3)
	local stone = hex("#C8B48A")
	for i = 0, 4 do
		local size = 34 - i * 6
		part(parent, {
			name = "TempleStep",
			size = Vector3.new(size, 5, size),
			cframe = CFrame.new(center + Vector3.new(0, 2.5 + i * 5, 0)),
			color = stone:Lerp(Color3.new(0, 0, 0), i * 0.03),
			material = Enum.Material.Sandstone,
		})
	end
	part(parent, {
		name = "TempleTop",
		size = Vector3.new(8, 6, 8),
		cframe = CFrame.new(center + Vector3.new(0, 28, 0)),
		color = stone,
		material = Enum.Material.Sandstone,
	})
	local glow = part(parent, {
		name = "TempleGem",
		shape = Enum.PartType.Ball,
		size = Vector3.new(4, 4, 4),
		cframe = CFrame.new(center + Vector3.new(0, 33, 0)),
		color = hex("#4FD1C5"),
		material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = glow.Color
	light.Range = 24
	light.Brightness = 2
	light.Parent = glow
	addObstacle(center)
end

local function pillar(parent: Instance, base: Vector3, height: number, broken: boolean)
	part(parent, {
		name = "Pillar",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height, 3, 3),
		cframe = CFrame.new(base + Vector3.new(0, height / 2, 0))
			* CFrame.Angles(0, 0, math.rad(if broken then 84 else 90)),
		color = hex("#D9C9A3"),
		material = Enum.Material.Sandstone,
	})
	addObstacle(base)
end

---------------------------------------------------------------------------
-- Base: deck, spawn, sell pad, upgrade stations
---------------------------------------------------------------------------

local function buildBase(): Folder
	local base = folder("Base", workspace)
	local b = L.base
	local width, depth = b.maxX - b.minX, b.maxZ - b.minZ
	local centerX, centerZ = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2

	part(base, {
		name = "Deck",
		size = Vector3.new(width, b.deckHeight, depth),
		cframe = CFrame.new(centerX, L.beachHeight + b.deckHeight / 2, centerZ),
		color = hex("#C08A55"),
		material = Enum.Material.WoodPlanks,
	})
	-- Rope railing posts along the sides (open at the front and back).
	for z = b.minZ + 4, b.maxZ - 4, 8 do
		for _, x in { b.minX + 1, b.maxX - 1 } do
			part(base, {
				name = "Post",
				size = Vector3.new(1, 3, 1),
				cframe = CFrame.new(x, DECK_TOP + 1.5, z),
				color = hex("#7A5230"),
				material = Enum.Material.Wood,
			})
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.CFrame = CFrame.new(L.spawn.x, DECK_TOP + 0.2, L.spawn.z)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = base

	-- Sell pad.
	local sp = L.sellPad
	local sellPad = part(base, {
		name = "SellPad",
		size = Vector3.new(sp.size, 0.4, sp.size),
		cframe = CFrame.new(sp.x, DECK_TOP + 0.2, sp.z),
		color = hex("#FFD54A"),
		material = Enum.Material.Neon,
		transparency = 0.15,
	})
	sellPad:SetAttribute("Station", "Sell")
	billboard(sellPad, "SELL", "Walk in to sell!", hex("#FFD54A"), 9, 14)
	for _, x in { -sp.size / 2 - 0.5, sp.size / 2 + 0.5 } do
		part(base, {
			name = "SellPost",
			size = Vector3.new(1.2, 10, 1.2),
			cframe = CFrame.new(sp.x + x, DECK_TOP + 5, sp.z),
			color = hex("#7A5230"),
			material = Enum.Material.Wood,
		})
	end
	part(base, {
		name = "SellBeam",
		size = Vector3.new(sp.size + 3, 1.2, 1.4),
		cframe = CFrame.new(sp.x, DECK_TOP + 10.3, sp.z),
		color = hex("#FFB21E"),
		material = Enum.Material.SmoothPlastic,
	})
	-- A coin pile beside the pad.
	for i = 1, 9 do
		local a = i * 0.7
		part(base, {
			name = "Coin",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.4, 2, 2),
			cframe = CFrame.new(
				sp.x + sp.size / 2 + 3 + math.cos(a) * 1.2,
				DECK_TOP + 0.3 + i * 0.25,
				sp.z - 4 + math.sin(a) * 1.2
			) * CFrame.Angles(0, 0, math.rad(90)),
			color = hex("#FFC933"),
			material = Enum.Material.Metal,
			canCollide = false,
		})
	end

	-- Upgrade stations.
	local function station(
		kind: string,
		pos: { x: number, z: number, radius: number },
		color: Color3,
		title: string,
		subtitle: string
	): Part
		local pad = part(base, {
			name = kind .. "Pad",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.4, pos.radius * 1.6, pos.radius * 1.6),
			cframe = CFrame.new(pos.x, DECK_TOP + 0.2, pos.z) * CFrame.Angles(0, 0, math.rad(90)),
			color = color,
			material = Enum.Material.Neon,
			transparency = 0.25,
		})
		pad:SetAttribute("Station", kind)
		pad:SetAttribute("Radius", pos.radius)
		billboard(pad, title, subtitle, color, 10, 14)
		return pad
	end

	local shovelPad = station("Shovel", L.shovelStation, hex("#5CC8FF"), "SHOVELS", "Dig faster!")
	local bagPad = station("Bag", L.bagStation, hex("#B45CFF"), "BAGS", "Carry more!")

	-- Display rack of shovels at the shovel station.
	for i, level in { 2, 3, 4 } do
		local display = ShovelBuilder.build(level)
		for _, d in display:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		display:PivotTo(
			CFrame.new(shovelPad.Position + Vector3.new(-6.5, 3.6, (i - 2) * 2.2))
				* CFrame.Angles(0, math.rad(90), math.rad(-12))
		)
		display.Parent = base
	end
	part(base, {
		name = "Rack",
		size = Vector3.new(0.6, 0.6, 7.5),
		cframe = CFrame.new(shovelPad.Position + Vector3.new(-6.9, 5.3, 0)),
		color = hex("#7A5230"),
		material = Enum.Material.Wood,
	})

	-- A giant bag at the bag station.
	part(base, {
		name = "BigBag",
		shape = Enum.PartType.Ball,
		size = Vector3.new(6, 6.5, 6),
		cframe = CFrame.new(bagPad.Position + Vector3.new(6.5, 3.2, 0)),
		color = hex("#A0643C"),
		material = Enum.Material.Fabric,
	})
	part(base, {
		name = "BigBagTie",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.8, 3, 3),
		cframe = CFrame.new(bagPad.Position + Vector3.new(6.5, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#FFC933"),
		material = Enum.Material.Fabric,
	})

	return base
end

---------------------------------------------------------------------------
-- Area walls and gates
---------------------------------------------------------------------------

type GateInfo = { areaId: string, barrier: BasePart, safePoint: Vector3 }

local function wallSegment(parent: Instance, from: Vector3, to: Vector3, rng: Random)
	-- Chunky rock blocks along the line; invisible over open water.
	local length = (to - from).Magnitude
	local dir = (to - from).Unit
	local count = math.max(1, math.ceil(length / 12))
	local step = length / count
	for i = 0, count - 1 do
		local center = from + dir * (step * (i + 0.5))
		local onLand = Zones.inCircle(center.X, center.Z, L.beach)
			or Zones.inCircle(center.X, center.Z, L.plateau)
		-- Tall enough that the top stays well above a jump from the plateau.
		local height = if onLand then rng:NextNumber(30, 38) else 60
		part(parent, {
			name = "Wall",
			size = Vector3.new(step + 2, height, 10 + (if onLand then rng:NextNumber(0, 4) else 0)),
			cframe = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(
				0,
				height / 2 - 6,
				0
			) * (if onLand
				then CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05))
				else CFrame.identity),
			color = hex("#7C7F85"):Lerp(hex("#6B5B4B"), rng:NextNumber(0, 0.5)),
			material = Enum.Material.Slate,
			transparency = if onLand then 0 else 1,
		})
	end
end

local function gate(parent: Instance, areaId: string): GateInfo
	local g = L.gates[areaId]
	local def = Areas.Defs[areaId]
	local w = L.gateWidth
	local groundY = if g.z > L.beachNorthZ - 1 then L.beachHeight else L.plateauHeight
	local model = Instance.new("Model")
	model.Name = areaId .. "Gate"

	local postColor = hex("#6B4A2B")
	for _, x in { -w / 2 - 1.5, w / 2 + 1.5 } do
		part(model, {
			name = "GatePost",
			size = Vector3.new(3, 22, 3),
			cframe = CFrame.new(g.x + x, groundY + 9, g.z),
			color = postColor,
			material = Enum.Material.Wood,
		})
	end
	part(model, {
		name = "GateBeam",
		size = Vector3.new(w + 6, 3, 3.4),
		cframe = CFrame.new(g.x, groundY + 19.5, g.z),
		color = postColor,
		material = Enum.Material.Wood,
	})

	local areaColor = if areaId == "Jungle"
		then hex("#56C451")
		elseif areaId == "Ruins" then hex("#4FD1C5")
		else hex("#FF6A1A")
	local barrier = part(model, {
		name = "Barrier",
		size = Vector3.new(w + 0.5, 18, 1.5),
		cframe = CFrame.new(g.x, groundY + 8, g.z),
		color = areaColor,
		material = Enum.Material.ForceField,
		transparency = 0.1,
	})
	barrier:SetAttribute("AreaId", areaId)

	-- Ramp up to the plateau for gates that start on the beach.
	if groundY < L.plateauHeight then
		local low = Vector3.new(g.x, groundY, g.z + 1)
		local high = Vector3.new(g.x, L.plateauHeight, g.z - 17)
		local length = (high - low).Magnitude
		local slope = CFrame.lookAt((low + high) / 2, high)
		part(model, {
			name = "Ramp",
			size = Vector3.new(w + 2, 2, length),
			cframe = slope * CFrame.new(0, -1, 0),
			color = if areaId == "Jungle" then hex("#6FBF4A") else hex("#D4B078"),
			material = if areaId == "Jungle" then Enum.Material.Grass else Enum.Material.Sandstone,
		})
	end

	local shovelName = Progression.getShovel(def.requiredShovel).name
	local subtitle = if def.enabled
		then "Needs " .. shovelName
		else "Needs " .. shovelName .. " - opening soon!"
	billboard(barrier, string.upper(def.displayName), subtitle, areaColor, 16, 22)

	model.Parent = parent
	return { areaId = areaId, barrier = barrier, safePoint = Vector3.new(g.x, groundY + 4, g.z + 12) }
end

local function buildWallsAndGates(rng: Random): { [string]: GateInfo }
	local walls = folder("Walls", workspace)
	local gatesFolder = folder("Gates", workspace)
	local w = L.gateWidth / 2 + 3
	local b = L.bounds

	-- Beach | north boundary with openings for the Jungle and Ruins gates.
	local jungleX, ruinsX = L.gates.Jungle.x, L.gates.Ruins.x
	local z = L.beachNorthZ
	wallSegment(walls, Vector3.new(b.minX, 0, z), Vector3.new(jungleX - w, 0, z), rng)
	wallSegment(walls, Vector3.new(jungleX + w, 0, z), Vector3.new(ruinsX - w, 0, z), rng)
	wallSegment(walls, Vector3.new(ruinsX + w, 0, z), Vector3.new(b.maxX, 0, z), rng)

	-- Jungle | Ruins divider.
	wallSegment(
		walls,
		Vector3.new(L.jungleRuinsX, 0, L.beachNorthZ - 4),
		Vector3.new(L.jungleRuinsX, 0, L.volcanoSouthZ + 4),
		rng
	)

	-- Volcano boundary with an opening from the Ruins side.
	local volcanoX = L.gates.Volcano.x
	local vz = L.volcanoSouthZ
	wallSegment(walls, Vector3.new(b.minX, 0, vz), Vector3.new(volcanoX - w, 0, vz), rng)
	wallSegment(walls, Vector3.new(volcanoX + w, 0, vz), Vector3.new(b.maxX, 0, vz), rng)

	-- Invisible play-area limits so nobody swims around the gates.
	local height = 200
	part(walls, {
		name = "Bound",
		size = Vector3.new(4, height, b.maxZ - b.minZ),
		cframe = CFrame.new(b.minX, height / 2 - 40, (b.minZ + b.maxZ) / 2),
		transparency = 1,
	})
	part(walls, {
		name = "Bound",
		size = Vector3.new(4, height, b.maxZ - b.minZ),
		cframe = CFrame.new(b.maxX, height / 2 - 40, (b.minZ + b.maxZ) / 2),
		transparency = 1,
	})
	part(walls, {
		name = "Bound",
		size = Vector3.new(b.maxX - b.minX, height, 4),
		cframe = CFrame.new((b.minX + b.maxX) / 2, height / 2 - 40, b.minZ),
		transparency = 1,
	})
	part(walls, {
		name = "Bound",
		size = Vector3.new(b.maxX - b.minX, height, 4),
		cframe = CFrame.new((b.minX + b.maxX) / 2, height / 2 - 40, b.maxZ),
		transparency = 1,
	})

	local gates = {}
	for _, areaId in { "Jungle", "Ruins", "Volcano" } do
		gates[areaId] = gate(gatesFolder, areaId)
	end
	return gates
end

---------------------------------------------------------------------------
-- Decoration layout
---------------------------------------------------------------------------

local function buildDecorations(rng: Random)
	local decor = folder("Decor", workspace)
	local beachY = L.beachHeight

	-- Palms ring the beach; a few stand inside the dig area for shade.
	for i = 1, 22 do
		local angle = (i / 22) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local dist = L.beach.radius - rng:NextNumber(6, 18)
		local x, z = L.beach.x + math.cos(angle) * dist, L.beach.z + math.sin(angle) * dist
		if z > L.beachNorthZ + 8 then
			palm(decor, Vector3.new(x, beachY - 0.5, z), rng)
		end
	end
	for _, p in { { -70, 40 }, { 60, 25 }, { -30, 70 }, { 95, 70 }, { -100, 95 }, { 20, 5 } } do
		palm(decor, Vector3.new(p[1], beachY - 0.5, p[2]), rng)
	end
	-- Palms framing the base.
	for _, p in { { -46, 104 }, { 46, 104 }, { -46, 150 }, { 46, 150 } } do
		palm(decor, Vector3.new(p[1], beachY - 0.5, p[2]), rng)
	end

	for _ = 1, 12 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = L.beach.radius + rng:NextNumber(0, 8)
		local x, z = L.beach.x + math.cos(angle) * dist, L.beach.z + math.sin(angle) * dist
		if z > L.beachNorthZ + 10 then
			rock(decor, Vector3.new(x, 1, z), rng:NextNumber(0.8, 1.8), rng)
		end
	end

	shipwreck(decor, CFrame.new(-92, 1.5, 128) * CFrame.Angles(0, math.rad(35), 0))

	-- Jungle silhouettes (visible over the wall from the beach).
	for _ = 1, 26 do
		local x = rng:NextNumber(-125, -10)
		local z = rng:NextNumber(-115, -20)
		if Zones.inCircle(x, z, L.plateau) then
			jungleTree(decor, Vector3.new(x, L.plateauHeight - 1, z), rng)
		end
	end

	-- Ruins: a stepped temple and scattered pillars.
	temple(decor, Vector3.new(70, L.plateauHeight - 1, -75))
	for _ = 1, 10 do
		local x = rng:NextNumber(15, 120)
		local z = rng:NextNumber(-110, -25)
		if
			Zones.inCircle(x, z, L.plateau)
			and (Vector3.new(x, 0, z) - Vector3.new(70, 0, -75)).Magnitude > 24
		then
			pillar(
				decor,
				Vector3.new(x, L.plateauHeight - 1, z),
				rng:NextNumber(8, 16),
				rng:NextNumber() < 0.4
			)
		end
	end

	-- Volcano glow and smoke at the crater.
	local v = L.volcano
	local peak = Vector3.new(v.x, L.plateauHeight + v.height - 10, v.z)
	local glow = part(decor, {
		name = "LavaGlow",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1, 24, 24),
		cframe = CFrame.new(peak) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#FF6A1A"),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = glow.Color
	light.Range = 60
	light.Brightness = 3
	light.Parent = glow
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(90, 85, 85)
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 12
	smoke.Size = 30
	smoke.TimeScale = 0.6
	smoke.Parent = glow
end

---------------------------------------------------------------------------
-- Dig spot candidate points
---------------------------------------------------------------------------

local function surfaceAt(x: number, z: number): (Vector3?, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Terrain }
	params.IgnoreWater = false
	local result = workspace:Raycast(Vector3.new(x, 250, z), Vector3.new(0, -400, 0), params)
	if not result then
		return nil, nil
	end
	return result.Position, result.Material
end

local function farFromAll(point: Vector3, list: { Vector3 }, minDistance: number): boolean
	for _, other in list do
		if Zones.flatDistance(point.X, point.Z, other.X, other.Z) < minDistance then
			return false
		end
	end
	return true
end

local function generateCandidates(areaId: string, rng: Random): { Vector3 }
	local rect = L.spotRegions[areaId]
	local target = DigConfig.candidateCount[areaId] or 60
	local points: { Vector3 } = {}
	local baseFront = Vector3.new((L.base.minX + L.base.maxX) / 2, 0, L.base.minZ)

	local function tryAdd(x: number, z: number): boolean
		if Zones.areaAt(x, z) ~= areaId or Zones.inRect(x, z, L.spotExclusion) then
			return false
		end
		local candidate = Vector3.new(x, 0, z)
		if not farFromAll(candidate, obstacles, 6) or not farFromAll(candidate, points, 6) then
			return false
		end
		local surface, material = surfaceAt(x, z)
		if not surface or material == Enum.Material.Water or surface.Y < L.waterLevel + 0.8 then
			return false
		end
		table.insert(points, surface)
		return true
	end

	-- A handful right in front of the base so a new player digs within seconds.
	if areaId == "Beach" then
		local near = 0
		for _ = 1, 600 do
			if near >= DigConfig.nearSpawnCandidates then
				break
			end
			local angle = rng:NextNumber(math.pi * 1.1, math.pi * 1.9) -- the half facing north
			local dist = rng:NextNumber(DigConfig.nearSpawnMin, DigConfig.nearSpawnMax)
			if tryAdd(baseFront.X + math.cos(angle) * dist, baseFront.Z + math.sin(angle) * dist) then
				near += 1
			end
		end
	end

	for _ = 1, target * 40 do
		if #points >= target then
			break
		end
		tryAdd(rng:NextNumber(rect.minX, rect.maxX), rng:NextNumber(rect.minZ, rect.maxZ))
	end
	return points
end

---------------------------------------------------------------------------

export type BuiltWorld = {
	spawnPosition: Vector3,
	sellZone: { cframe: CFrame, size: Vector3 },
	stations: { [string]: { position: Vector3, radius: number } },
	gates: { [string]: GateInfo },
	candidates: { [string]: { Vector3 } },
	baseFront: Vector3,
}

function MapBuilder.build(): BuiltWorld
	local started = os.clock()
	local rng = Random.new(20260930)
	buildLighting()
	buildTerrain()
	buildBase()
	local gates = buildWallsAndGates(rng)
	buildDecorations(rng)

	local candidates = {}
	local candidateRng = Random.new(1337)
	for _, areaId in Areas.Order do
		candidates[areaId] = generateCandidates(areaId, candidateRng)
	end

	local sp = L.sellPad
	print(
		string.format(
			"[MapBuilder] Island built in %.2fs (%d beach dig points)",
			os.clock() - started,
			#candidates.Beach
		)
	)
	return {
		spawnPosition = Vector3.new(L.spawn.x, DECK_TOP + 3, L.spawn.z),
		sellZone = { cframe = CFrame.new(sp.x, DECK_TOP + 4, sp.z), size = Vector3.new(sp.size, 10, sp.size) },
		stations = {
			Shovel = {
				position = Vector3.new(L.shovelStation.x, DECK_TOP, L.shovelStation.z),
				radius = L.shovelStation.radius,
			},
			Bag = {
				position = Vector3.new(L.bagStation.x, DECK_TOP, L.bagStation.z),
				radius = L.bagStation.radius,
			},
		},
		gates = gates,
		candidates = candidates,
		baseFront = Vector3.new((L.base.minX + L.base.maxX) / 2, DECK_TOP, L.base.minZ),
	}
end

return MapBuilder
