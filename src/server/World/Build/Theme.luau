--!strict
-- The world's look. The island is the default (nothing changes). Frostbite
-- Peaks dresses the very same map as frost biomes: the builders run
-- unchanged, and their terrain fills, parts, fires, lights and particles
-- pass through here on the way:
--   * terrain: sand becomes snow, lava rivers freeze into glowing glacier
--     ice, grass is frosted, stone and paths turn cold blue-grey, icy water
--   * parts: sand-colored parts become snow, foliage turns pine green, warm
--     glows (lava, embers) turn ice blue, stone gets a cold tint, and palms
--     grow as snowy pines (Kit.palm)
--   * fires burn blue, warm lights and particles turn icy
--   * cold lighting and fog (Theme.lighting); snowfall is on the client
-- The base is built with dressing switched off (Theme.dressing), so it's
-- exactly the island's, and players recognize the world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)

local M = Enum.Material

local Theme = {}

Theme.frost = CurrentWorld.isFrost()
-- Parts built while this is on are dressed (the base switches it off).
Theme.dressing = Theme.frost

Theme.SNOW = Color3.fromRGB(240, 247, 252)
Theme.ICE_GLOW = Color3.fromRGB(110, 214, 255)
Theme.ICE_STONE = Color3.fromRGB(176, 196, 216)
Theme.PINE = Color3.fromRGB(38, 92, 70)

---------------------------------------------------------------------------
-- Terrain
---------------------------------------------------------------------------

-- (Tables of materials are keyed by name: enum items aren't always the
-- same object outside Roblox, e.g. in the offline tests.)
local TERRAIN_MATERIAL: { [string]: Enum.Material } = {
	Sand = M.Snow,
	CrackedLava = M.Glacier,
}

-- The material actually filled for one the builders ask for.
function Theme.material(material: Enum.Material): Enum.Material
	return if Theme.frost then TERRAIN_MATERIAL[material.Name] or material else material
end

-- Terrain material colors for Frostbite Peaks (the island's are in Terrain).
Theme.terrainColors = {
	[M.Snow] = Color3.fromRGB(238, 246, 252), -- Frost Shore
	[M.Grass] = Color3.fromRGB(196, 222, 214), -- frosted grass: Pine Woods
	[M.LeafyGrass] = Color3.fromRGB(150, 190, 176),
	[M.Sandstone] = Color3.fromRGB(176, 198, 218), -- Ice Ruins stone
	[M.Basalt] = Color3.fromRGB(58, 68, 92), -- Frozen Peak rock
	[M.Glacier] = Color3.fromRGB(128, 222, 255), -- frozen lava rivers
	[M.Rock] = Color3.fromRGB(150, 164, 182),
	[M.Slate] = Color3.fromRGB(112, 124, 144),
	[M.Ground] = Color3.fromRGB(200, 214, 228), -- packed-snow beach paths
	[M.Mud] = Color3.fromRGB(104, 98, 102), -- woods paths
	[M.Cobblestone] = Color3.fromRGB(160, 182, 202), -- ruins paving
	[M.Pavement] = Color3.fromRGB(192, 208, 224), -- ruins plaza
	[M.Asphalt] = Color3.fromRGB(66, 74, 94), -- peak paths
} :: { [Enum.Material]: Color3 }

Theme.water = {
	color = Color3.fromRGB(64, 148, 190),
	transparency = 0.45,
	reflectance = 0.45,
	waveSize = 0.08,
	waveSpeed = 5,
}

---------------------------------------------------------------------------
-- Parts, fire, lights, particles
---------------------------------------------------------------------------

local STONE: { [string]: boolean } = {
	Slate = true,
	Rock = true,
	Basalt = true,
	Sandstone = true,
	Limestone = true,
	Cobblestone = true,
	Pavement = true,
	Granite = true,
	Concrete = true,
}

-- Lava-, ember- and torch-colored.
local function warm(color: Color3): boolean
	local h, s, v = color:ToHSV()
	return (h < 0.15 or h > 0.94) and s > 0.45 and v > 0.45
end

local function green(color: Color3): boolean
	local h, s = color:ToHSV()
	return h > 0.19 and h < 0.5 and s > 0.3
end

-- Sand-colored (sandy rocks, dunes, sand piles).
local function sandy(color: Color3): boolean
	local h, s, v = color:ToHSV()
	return h > 0.07 and h < 0.16 and s > 0.15 and s < 0.5 and v > 0.7
end

local function cold(color: Color3): Color3
	local _, _, v = color:ToHSV()
	return Theme.ICE_GLOW:Lerp(Color3.new(1, 1, 1), math.clamp(v - 0.85, 0, 0.15) * 2)
end

-- A part's color and material as built in this world.
function Theme.dress(color: Color3, material: Enum.Material): (Color3, Enum.Material)
	if not Theme.dressing then
		return color, material
	end
	if material == M.Sand then
		return Theme.SNOW, M.Snow
	end
	if material == M.Neon then
		return (if warm(color) then cold(color) else color), material
	end
	if green(color) then
		-- Foliage: deep pine green, a touch lighter for the lit side.
		local _, _, v = color:ToHSV()
		return Theme.PINE:Lerp(Color3.fromRGB(86, 140, 116), math.clamp(v - 0.45, 0, 0.5)), material
	end
	if STONE[material.Name] then
		return color:Lerp(Theme.ICE_STONE, if sandy(color) then 0.7 else 0.45), material
	end
	if material == M.Ground or material == M.Mud then
		return color:Lerp(Theme.SNOW, 0.55), material
	end
	if sandy(color) and material == M.SmoothPlastic then
		return Theme.SNOW, M.Snow
	end
	return color, material
end

-- Fire colors: cold blue flames in Frostbite Peaks.
function Theme.fire(color: Color3, secondary: Color3): (Color3, Color3)
	if not Theme.dressing then
		return color, secondary
	end
	return Color3.fromRGB(70, 160, 255), Color3.fromRGB(200, 240, 255)
end

-- Light and particle colors: warm ones turn icy.
function Theme.glow(color: Color3): Color3
	if not Theme.dressing or not warm(color) then
		return color
	end
	return cold(color)
end

-- Snow on top of the leafy canopies, bushes and rocks under `folder` (after
-- the areas are built; the pines bring their own).
function Theme.snowCaps(folder: Instance)
	if not Theme.frost then
		return
	end
	local caps = {}
	for _, item in folder:GetDescendants() do
		local mesh = item:IsA("BasePart") and item:FindFirstChildOfClass("SpecialMesh")
		if mesh and mesh.MeshType == Enum.MeshType.Sphere and item.Transparency < 0.5 then
			local part = item :: BasePart
			local size = part.Size
			local name = part.Material.Name
			local leafy = (name == "Grass" or name == "LeafyGrass" or green(part.Color))
				and part.Parent.Name ~= "Pine"
			local rock = part.Name == "Rock"
			if (leafy or rock) and size.X >= 3 and size.Z >= 3 then
				table.insert(caps, part)
			end
		end
	end
	for _, part in caps do
		local size = part.Size
		local cap = Instance.new("Part")
		cap.Name = "SnowCap"
		cap.Anchored = true
		cap.CanCollide = false
		cap.CanQuery = false
		cap.CanTouch = false
		cap.CastShadow = false
		cap.Color = Theme.SNOW
		cap.Material = M.Snow
		cap.TopSurface = Enum.SurfaceType.Smooth
		cap.BottomSurface = Enum.SurfaceType.Smooth
		cap.Size = Vector3.new(size.X * 0.82, math.max(0.4, size.Y * 0.38), size.Z * 0.82)
		local up = part.CFrame:VectorToObjectSpace(Vector3.new(0, 1, 0))
		cap.CFrame = part.CFrame * CFrame.new(up * size.Y * 0.32)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = cap
		cap.Parent = part.Parent
	end
end

---------------------------------------------------------------------------
-- Lighting
---------------------------------------------------------------------------

-- A crisp, cold winter day (after the island's lighting is set up).
function Theme.lighting(lighting: Instance)
	if not Theme.frost then
		return
	end
	local L = lighting :: Lighting
	L.ClockTime = 13.2
	L.Brightness = 2.2
	L.ExposureCompensation = 0
	L.Ambient = Color3.fromRGB(86, 96, 118)
	L.OutdoorAmbient = Color3.fromRGB(150, 164, 190)
	local atmosphere = L:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.38
		atmosphere.Offset = 0.2
		atmosphere.Color = Color3.fromRGB(214, 232, 248)
		atmosphere.Decay = Color3.fromRGB(150, 178, 214)
		atmosphere.Haze = 1.4
	end
	local color = L:FindFirstChildOfClass("ColorCorrectionEffect")
	if color then
		color.Saturation = 0.02
		color.Contrast = 0.1
		color.TintColor = Color3.fromRGB(238, 246, 255)
	end
	local bloom = L:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Intensity = 0.55
	end
end

return Theme
