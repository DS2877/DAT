--!strict
-- Draws the island as a simple, colorful map (GUI frames from MapLayout):
-- the beach, the Jungle / Ruins plateau, the Volcano highland and cone, the
-- base, and markers. North (the volcano) is up. Used on the wooden info
-- board at the base (a SurfaceGui) and in the Island Guide panel.

local Areas = require(script.Parent.Parent.Config.Areas)
local MapLayout = require(script.Parent.Parent.Config.MapLayout)
local Progression = require(script.Parent.Parent.Logic.Progression)

local IslandMap = {}

local L = MapLayout
-- The world rectangle the map shows.
local MIN_X, MAX_X = -320, 320
local MIN_Z, MAX_Z = L.volcano.z - L.volcano.radius - 20, 400

-- World (x, z) -> map scale coordinates (0..1).
function IslandMap.project(x: number, z: number): Vector2
	return Vector2.new((x - MIN_X) / (MAX_X - MIN_X), (z - MIN_Z) / (MAX_Z - MIN_Z))
end

-- The map's width / height ratio (for keeping it undistorted).
IslandMap.aspect = (MAX_X - MIN_X) / (MAX_Z - MIN_Z)

local function blob(
	parent: Instance,
	name: string,
	x: number,
	z: number,
	rx: number,
	rz: number,
	color: Color3,
	z_: number?
)
	local a = IslandMap.project(x - rx, z - rz)
	local b = IslandMap.project(x + rx, z + rz)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = UDim2.fromScale(a.X, a.Y)
	frame.Size = UDim2.fromScale(b.X - a.X, b.Y - a.Y)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = z_ or 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

-- A text label centered on world (x, z); `width` is a share of the map's
-- width, `tall` the label's height / width. `below` moves it down by that
-- many of its own heights.
local function label(
	parent: Instance,
	text: string,
	x: number,
	z: number,
	width: number,
	color: Color3,
	zIndex: number?,
	tall: number?,
	below: number?
)
	local p = IslandMap.project(x, z)
	local h = width * (tall or 0.3) * IslandMap.aspect -- share of the map's height
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(p.X, p.Y + h * (below or 0))
	l.Size = UDim2.fromScale(width, h)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	l.ZIndex = zIndex or 5
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(40, 25, 10)
	stroke.Parent = l
	l.Parent = parent
	return l
end

-- Builds the map inside `parent` (fills it). Returns the map frame.
function IslandMap.build(parent: Instance): Frame
	local map = Instance.new("Frame")
	map.Name = "IslandMap"
	map.Size = UDim2.fromScale(1, 1)
	map.BackgroundColor3 = Color3.fromRGB(63, 169, 217)
	map.BorderSizePixel = 0
	map.ClipsDescendants = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = map

	local sand = Color3.fromRGB(242, 217, 160)
	blob(map, "Beach", L.beach.x, L.beach.z, L.beach.radius, L.beach.radius, sand)
	for i, lobe in L.beachLobes do
		blob(map, "Lobe" .. i, lobe.x, lobe.z, lobe.r, lobe.r, sand)
	end
	-- The plateau: Ruins colors, with the Jungle (west half) clipped over it.
	local plateau = L.plateau
	blob(map, "Ruins", plateau.x, plateau.z, plateau.rx, plateau.rz, Color3.fromRGB(216, 178, 110), 2)
	local westEdge = IslandMap.project(MIN_X, 0)
	local ridge = IslandMap.project(L.jungleRuinsX, 0)
	local west = Instance.new("Frame")
	west.Name = "JungleClip"
	west.Position = UDim2.fromScale(westEdge.X, 0)
	west.Size = UDim2.fromScale(ridge.X - westEdge.X, 1)
	west.BackgroundTransparency = 1
	west.ClipsDescendants = true
	west.ZIndex = 3
	west.Parent = map
	local jungle =
		blob(west, "Jungle", plateau.x, plateau.z, plateau.rx, plateau.rz, Color3.fromRGB(76, 175, 80), 3)
	-- Inside the clip frame the blob's scale positions are relative to it.
	local width = ridge.X - westEdge.X
	jungle.Position = UDim2.fromScale((jungle.Position.X.Scale - westEdge.X) / width, jungle.Position.Y.Scale)
	jungle.Size = UDim2.fromScale(jungle.Size.X.Scale / width, jungle.Size.Y.Scale)

	local high = L.highland
	blob(map, "Highland", high.x, high.z, high.rx, high.rz, Color3.fromRGB(107, 94, 90), 2)
	local v = L.volcano
	blob(map, "Cone", v.x, v.z, v.radius, v.radius, Color3.fromRGB(74, 63, 60), 4)
	blob(map, "Crater", v.x, v.z, 26, 26, Color3.fromRGB(255, 106, 26), 4)

	-- The base.
	local b = L.base
	local a1 = IslandMap.project(b.minX, b.minZ)
	local a2 = IslandMap.project(b.maxX, b.maxZ)
	local base = Instance.new("Frame")
	base.Name = "Base"
	base.Position = UDim2.fromScale(a1.X, a1.Y)
	base.Size = UDim2.fromScale(a2.X - a1.X, a2.Y - a1.Y)
	base.BackgroundColor3 = Color3.fromRGB(199, 145, 90)
	base.BorderSizePixel = 0
	base.ZIndex = 4
	base.Parent = map

	local white = Color3.new(1, 1, 1)
	local function areaLabel(areaId: string, x: number, z: number)
		local def = Areas.Defs[areaId]
		local shovel = Progression.getShovel(def.requiredShovel)
		label(map, string.upper(def.displayName), x, z, 0.4, white, 5, 0.2, -0.5)
		label(map, "needs " .. shovel.name, x, z, 0.36, Color3.fromRGB(255, 230, 150), 5, 0.13, 0.75)
	end
	label(map, "BEACH", 0, 70, 0.3, white)
	areaLabel("Jungle", -140, -150)
	areaLabel("Ruins", 140, -150)
	areaLabel("Volcano", 0, -330)
	label(map, "BASE", 0, 200, 0.2, white, 6)

	-- Markers.
	local function marker(text: string, x: number, z: number)
		label(map, text, x, z, 0.12, white, 6)
	end
	marker("🍹", -118, 230)
	marker("👑", L.vipSite.x, L.vipSite.z)
	marker("🔮", L.rebirthAltar.x, L.rebirthAltar.z)
	for _, g in L.gates do
		marker("🚪", g.x, g.z)
	end

	map.Parent = parent
	return map
end

return IslandMap
