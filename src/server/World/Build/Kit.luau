--!strict
-- Shared building blocks for the world builder: parts, ellipsoids, labels,
-- signs, lights, fire, reusable props (palms, rocks, torches, people),
-- terrain lookups, and the obstacle index dig spots keep away from.
--
-- Placement rule: Roblox draws terrain a few studs above a fill's top
-- (voxel rounding), so anything that stands on the ground measures it with
-- Kit.groundY (a real raycast) instead of using the layout's fill heights.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)

local Kit = {}

Kit.L = MapLayout
-- Top of the base deck. Measured and set by Base.build (the default is only
-- a fallback for code that runs before the base exists).
Kit.DECK_TOP = MapLayout.beachHeight + MapLayout.base.deckHeight

export type PartProps = {
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	canCollide: boolean?,
	castShadow: boolean?,
	reflectance: number?,
	name: string?,
	className: string?, -- e.g. "WedgePart"
}

function Kit.part(parent: Instance, props: PartProps): BasePart
	local p = Instance.new((props.className or "Part") :: any) :: BasePart
	p.Name = props.name or "Part"
	p.Anchored = true
	if props.shape and p:IsA("Part") then
		p.Shape = props.shape
	end
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color or Color3.new(1, 1, 1)
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.Reflectance = props.reflectance or 0
	p.CanCollide = if props.canCollide == nil then true else props.canCollide
	if not p.CanCollide then
		p.CanQuery = false
		p.CanTouch = false
	end
	p.CastShadow = if props.castShadow == nil then true else props.castShadow
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A stretched sphere. Roblox draws Ball parts with the smallest size axis
-- as the diameter, so non-round shapes use a sphere mesh on a block.
function Kit.ellipsoid(parent: Instance, props: PartProps): BasePart
	local p = Kit.part(parent, {
		name = props.name,
		size = props.size,
		cframe = props.cframe,
		color = props.color,
		material = props.material,
		transparency = props.transparency,
		canCollide = props.canCollide,
		castShadow = props.castShadow,
		reflectance = props.reflectance,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A solid wedge ramp: its slope starts at `bottomY` above `low` (keep that
-- a little under the low ground so it starts flush) and rises to `high`.
function Kit.ramp(
	parent: Instance,
	low: Vector3,
	high: Vector3,
	width: number,
	bottomY: number,
	props: { name: string?, color: Color3?, material: Enum.Material? }?
): BasePart
	local flat = Vector3.new(high.X - low.X, 0, high.Z - low.Z)
	local height = high.Y - bottomY
	local mid = Vector3.new((low.X + high.X) / 2, bottomY + height / 2, (low.Z + high.Z) / 2)
	-- A wedge's high edge is its back (+Z): face the front toward the low end.
	return Kit.part(parent, {
		name = if props and props.name then props.name else "Ramp",
		className = "WedgePart",
		size = Vector3.new(width, height, flat.Magnitude),
		cframe = CFrame.lookAt(mid, mid - flat.Unit),
		color = if props then props.color else nil,
		material = if props then props.material else nil,
	})
end

function Kit.folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Kit.hex(s: string): Color3
	return Color3.fromHex(s)
end

function Kit.light(parent: Instance, color: Color3, range: number, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.5
	light.Shadows = false
	light.Parent = parent
	return light
end

function Kit.fire(parent: Instance, size: number, color: Color3?): Fire
	local fire = Instance.new("Fire")
	fire.Size = size
	fire.Heat = size * 2
	fire.Color = color or Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = parent
	return fire
end

-- Soft particles (dust, leaves, embers, ash, mist, fireflies). Emits from
-- the whole volume of `parent` (an invisible box part).
export type EmitterProps = {
	color: Color3,
	color2: Color3?,
	rate: number,
	lifetime: NumberRange,
	size: NumberSequence,
	speed: NumberRange,
	transparency: NumberSequence?,
	lightEmission: number?,
	acceleration: Vector3?,
	spread: Vector2?,
	direction: Enum.NormalId?,
	rotSpeed: NumberRange?,
	drag: number?,
}

function Kit.emitter(parent: BasePart, props: EmitterProps): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(props.color, props.color2 or props.color)
	e.Rate = props.rate
	e.Lifetime = props.lifetime
	e.Size = props.size
	e.Speed = props.speed
	e.Transparency = props.transparency or NumberSequence.new(0.2, 1)
	e.LightEmission = props.lightEmission or 0
	e.Acceleration = props.acceleration or Vector3.zero
	e.SpreadAngle = props.spread or Vector2.new(180, 180)
	e.EmissionDirection = props.direction or Enum.NormalId.Top
	e.RotSpeed = props.rotSpeed or NumberRange.new(0)
	e.Rotation = NumberRange.new(0, 360)
	e.Drag = props.drag or 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = parent
	return e
end

-- An invisible, non-colliding box that hosts particles or lights.
function Kit.volume(parent: Instance, name: string, cframe: CFrame, size: Vector3): BasePart
	return Kit.part(parent, {
		name = name,
		size = size,
		cframe = cframe,
		transparency = 1,
		canCollide = false,
		castShadow = false,
	})
end

-- A world-space label that always faces the camera.
function Kit.billboard(
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

-- A wooden sign on two posts, standing on the ground at `position` and
-- facing `facing` (readable from both sides): a title board, and an
-- optional smaller board under it.
function Kit.standingSign(
	parent: Instance,
	position: Vector3,
	facing: Vector3,
	title: string,
	subtitle: string?,
	color: Color3,
	width: number
): Model
	local model = Instance.new("Model")
	model.Name = "StandingSign"
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local look = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local frame = CFrame.lookAt(position, position + look)
	local wood = Kit.hex("#8B5A2B")
	local dark = Kit.hex("#5B3A22")
	local boardsTop = if subtitle then 7.4 else 6.6
	for _, side in { -1, 1 } do
		Kit.part(model, {
			name = "SignLeg",
			size = Vector3.new(0.6, boardsTop + 0.4, 0.6),
			cframe = frame * CFrame.new(side * (width / 2 + 0.3), (boardsTop + 0.4) / 2 - 0.4, 0),
			color = dark,
			material = Enum.Material.Wood,
		})
	end
	local titleBoard = Kit.part(model, {
		name = "SignBoard",
		size = Vector3.new(width, 2.4, 0.5),
		cframe = frame * CFrame.new(0, boardsTop - 1.2, 0),
		color = wood,
		material = Enum.Material.WoodPlanks,
	})
	Kit.signText(titleBoard, title, color)
	if subtitle then
		local sub = Kit.part(model, {
			name = "SignBoardSmall",
			size = Vector3.new(width * 0.9, 1.4, 0.4),
			cframe = frame * CFrame.new(0, boardsTop - 3.2, 0),
			color = wood,
			material = Enum.Material.WoodPlanks,
		})
		Kit.signText(sub, subtitle, Color3.new(1, 1, 1))
	end
	model.Parent = parent
	Kit.addObstacle(position, width / 2 + 1)
	return model
end

-- Text painted on a sign board. `faces` defaults to front and back.
function Kit.signText(
	board: BasePart,
	text: string,
	color: Color3,
	background: Color3?,
	faces: { Enum.NormalId }?,
	font: Enum.Font?
)
	local faceList: { Enum.NormalId } = faces or { Enum.NormalId.Front, Enum.NormalId.Back }
	for _, face in faceList do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		local w = if face == Enum.NormalId.Left or face == Enum.NormalId.Right
			then board.Size.Z
			else board.Size.X
		local h = if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom
			then board.Size.Z
			else board.Size.Y
		gui.CanvasSize = Vector2.new(w * 40, h * 40)
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = if background then 0 else 1
		label.BackgroundColor3 = background or Color3.new(0, 0, 0)
		label.Font = font or Enum.Font.LuckiestGuy
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = color
		label.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.04, 0)
		padding.PaddingRight = UDim.new(0.04, 0)
		padding.PaddingTop = UDim.new(0.08, 0)
		padding.PaddingBottom = UDim.new(0.08, 0)
		padding.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = Color3.fromRGB(40, 25, 10)
		stroke.Parent = label
	end
end

---------------------------------------------------------------------------
-- Obstacles: dig spot candidates keep clear of these (spatial hash).
---------------------------------------------------------------------------

export type Obstacle = { position: Vector3, radius: number }
Kit.obstacles = {} :: { Obstacle }
local OBSTACLE_CELL = 16
local obstacleCells: { [number]: { Obstacle } } = {}
local maxObstacleRadius = 0

local function cellKey(cx: number, cz: number): number
	return (cx + 4096) * 8192 + (cz + 4096)
end

function Kit.addObstacle(position: Vector3, radius: number?)
	local obstacle = { position = position, radius = radius or 3 }
	table.insert(Kit.obstacles, obstacle)
	maxObstacleRadius = math.max(maxObstacleRadius, obstacle.radius)
	local key = cellKey(math.floor(position.X / OBSTACLE_CELL), math.floor(position.Z / OBSTACLE_CELL))
	local list = obstacleCells[key]
	if not list then
		list = {}
		obstacleCells[key] = list
	end
	table.insert(list, obstacle)
end

-- True if (x, z) is at least `margin` studs outside every obstacle.
function Kit.clearOfObstacles(x: number, z: number, margin: number): boolean
	local reach = maxObstacleRadius + margin
	local c0x, c1x = math.floor((x - reach) / OBSTACLE_CELL), math.floor((x + reach) / OBSTACLE_CELL)
	local c0z, c1z = math.floor((z - reach) / OBSTACLE_CELL), math.floor((z + reach) / OBSTACLE_CELL)
	for cx = c0x, c1x do
		for cz = c0z, c1z do
			local list = obstacleCells[cellKey(cx, cz)]
			if list then
				for _, o in list do
					local dx, dz = x - o.position.X, z - o.position.Z
					local r = o.radius + margin
					if dx * dx + dz * dz < r * r then
						return false
					end
				end
			end
		end
	end
	return true
end

---------------------------------------------------------------------------
-- Terrain lookups (real raycasts against the terrain only)
---------------------------------------------------------------------------

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.IgnoreWater = true

-- Height of the terrain surface at (x, z), or nil over nothing.
function Kit.groundY(x: number, z: number): number?
	terrainParams.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -700, 0), terrainParams)
	return if hit then hit.Position.Y else nil
end

-- Surface position and material at (x, z), water included.
function Kit.surface(x: number, z: number): (number?, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -700, 0), params)
	if not hit then
		return nil, nil
	end
	return hit.Position.Y, hit.Material
end

-- Roblox draws terrain about this much above a fill's top. Only used as a
-- last-resort guess when the real ground can't be measured.
Kit.FILL_OFFSET = 2.5

-- Waits until the terrain answers raycasts with settled heights. Roblox
-- builds terrain collision a moment after the voxels are written, so
-- anything measured straight after a fill would see nothing.
function Kit.waitForTerrain(points: { Vector2 }, timeout: number?): boolean
	local deadline = os.clock() + (timeout or 20)
	local previous: { number }? = nil
	local stableReads = 0
	while os.clock() < deadline do
		local heights: { number } = {}
		for _, p in points do
			local y = Kit.groundY(p.X, p.Y)
			if not y then
				break
			end
			table.insert(heights, y)
		end
		if #heights == #points then
			local same = previous ~= nil
			if previous then
				for i, y in heights do
					if math.abs(y - previous[i]) > 0.05 then
						same = false
						break
					end
				end
			end
			stableReads = if same then stableReads + 1 else 0
			if stableReads >= 2 then
				return true
			end
			previous = heights
		end
		task.wait(0.1)
	end
	warn("[MapBuilder] terrain did not settle in time; placement may be off")
	return false
end

-- Ground height with a fallback (used where something must be placed).
-- `fillHeight` is the layout's fill height; the guess adds the usual offset.
function Kit.groundOr(x: number, z: number, fillHeight: number): number
	return Kit.groundY(x, z) or (fillHeight + Kit.FILL_OFFSET)
end

-- Highest ground in a ring around (x, z) plus its center: for platforms that
-- must sit on top of the sand everywhere (Roblox terrain is bumpy).
function Kit.highestGround(x: number, z: number, radius: number, fallback: number): number
	local best: number? = Kit.groundY(x, z)
	for ring = 1, 2 do
		local r = radius * ring / 2
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local y = Kit.groundY(x + math.cos(a) * r, z + math.sin(a) * r)
			if y and (not best or y > best) then
				best = y
			end
		end
	end
	return best or (fallback + Kit.FILL_OFFSET)
end

-- Median ground height over a set of points (robust to a stray rock).
function Kit.medianGround(points: { Vector2 }, fallback: number): number
	local values = {}
	for _, p in points do
		local y = Kit.groundY(p.X, p.Y)
		if y then
			table.insert(values, y)
		end
	end
	if #values == 0 then
		return fallback + Kit.FILL_OFFSET
	end
	table.sort(values)
	return values[math.floor((#values + 1) / 2)]
end

-- Places a point on the ground if the ground there is near `levelY` (a flat
-- tier), so props don't land on cliffs, in water or on ridges.
function Kit.onLevel(x: number, z: number, levelY: number, tolerance: number?): Vector3?
	local y, material = Kit.surface(x, z)
	if not y or not material then
		return nil
	end
	if material == Enum.Material.Water or material == Enum.Material.CrackedLava then
		return nil
	end
	if math.abs(y - levelY) > (tolerance or 3) then
		return nil
	end
	return Vector3.new(x, y, z)
end

---------------------------------------------------------------------------
-- Reusable props
---------------------------------------------------------------------------

function Kit.palm(parent: Instance, base: Vector3, rng: Random, height: number?)
	local model = Instance.new("Model")
	model.Name = "Palm"
	local lean = rng:NextNumber(-0.35, 0.35)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local trunkColor = Kit.hex("#9C7447")
	local segments = height or rng:NextInteger(6, 8)
	local pos = base - Vector3.new(0, 1.5, 0)
	local dir = (CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean * 0.4, 0, 0)).UpVector
	for i = 1, segments do
		local seg = if i == 1 then 3.9 else 2.4
		local nextPos = pos + dir * seg
		Kit.part(model, {
			name = "Trunk",
			size = Vector3.new(1.4 - i * 0.06, seg + 0.3, 1.4 - i * 0.06),
			cframe = CFrame.lookAt((pos + nextPos) / 2, nextPos) * CFrame.Angles(math.rad(90), 0, 0),
			color = if i % 2 == 0 then trunkColor else trunkColor:Lerp(Color3.new(0, 0, 0), 0.12),
			material = Enum.Material.Wood,
		})
		pos = nextPos
		dir = (CFrame.fromAxisAngle(Vector3.new(math.cos(yaw), 0, math.sin(yaw)), lean * 0.12) * dir).Unit
	end
	local crown = pos
	for i = 1, 9 do
		local angle = (i / 9) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local droop = math.rad(rng:NextNumber(-34, -14))
		local leaf = CFrame.new(crown) * CFrame.Angles(0, angle, 0) * CFrame.Angles(droop, 0, 0)
		Kit.part(model, {
			name = "Leaf",
			className = "WedgePart",
			size = Vector3.new(0.25, 2.4, 8),
			cframe = leaf * CFrame.new(0, 0, -4) * CFrame.Angles(0, 0, math.rad(90)),
			color = if i % 2 == 0 then Kit.hex("#3FAE49") else Kit.hex("#5ACB4F"),
			material = Enum.Material.Grass,
			canCollide = false,
		})
	end
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		Kit.part(model, {
			name = "Coconut",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.9, 0.9, 0.9),
			cframe = CFrame.new(crown + Vector3.new(math.cos(a) * 0.6, -0.6, math.sin(a) * 0.6)),
			color = Kit.hex("#6B4A1F"),
			canCollide = false,
			castShadow = false,
		})
	end
	model.Parent = parent
	Kit.addObstacle(base, 3)
end

function Kit.rock(
	parent: Instance,
	position: Vector3,
	scale: number,
	rng: Random,
	color: Color3?,
	material: Enum.Material?
)
	Kit.ellipsoid(parent, {
		name = "Rock",
		size = Vector3.new(rng:NextNumber(3.6, 5), rng:NextNumber(2.4, 3.4), rng:NextNumber(3.2, 4.4))
			* scale,
		cframe = CFrame.new(position - Vector3.new(0, 0.4 * scale, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
		color = color or Kit.hex("#8E9196"),
		material = material or Enum.Material.Slate,
	})
	Kit.addObstacle(position, 2.4 * scale)
end

-- A tiki torch: pole, bowl, fire and warm light.
function Kit.torch(parent: Instance, base: Vector3)
	Kit.part(parent, {
		name = "TorchPole",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(7, 0.6, 0.6),
		cframe = CFrame.new(base + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Kit.hex("#6B4A2B"),
		material = Enum.Material.Wood,
	})
	local bowl = Kit.part(parent, {
		name = "TorchBowl",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.8, 1.4, 1.4),
		cframe = CFrame.new(base + Vector3.new(0, 6.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Kit.hex("#3B2A1A"),
		material = Enum.Material.Wood,
	})
	Kit.fire(bowl, 2.2)
	Kit.light(bowl, Color3.fromRGB(255, 160, 70), 14, 1.2)
	Kit.addObstacle(base, 1.5)
end

-- A blocky person (decor only): legs, torso, arms, head, optional hat.
export type PersonStyle = {
	skin: Color3?,
	shirt: Color3,
	pants: Color3,
	hat: string?, -- "Straw", "Explorer", "Bandana", "Chef"
	hatColor: Color3?,
	holding: string?, -- "Shovel", "Bag", "Coin"
}

function Kit.person(parent: Instance, cframe: CFrame, style: PersonStyle, name: string?): Model
	local model = Instance.new("Model")
	model.Name = name or "Person"
	local skin = style.skin or Kit.hex("#F2C79A")
	local function piece(
		pieceName: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?
	)
		return Kit.part(model, {
			name = pieceName,
			size = size,
			cframe = cframe * offset,
			color = color,
			material = material or Enum.Material.SmoothPlastic,
			canCollide = false,
		})
	end
	piece("LeftLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), style.pants)
	piece("RightLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), style.pants)
	local torso = piece("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), style.shirt)
	piece("LeftArm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), skin)
	piece(
		"RightArm",
		Vector3.new(1, 2, 1),
		CFrame.new(1.5, 3, -0.3) * CFrame.Angles(math.rad(20), 0, 0),
		skin
	)
	local head = piece("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.6, 0), skin)
	-- Simple face: two eyes and a smile on the front (-Z).
	for _, x in { -0.25, 0.25 } do
		piece("Eye", Vector3.new(0.16, 0.22, 0.05), CFrame.new(x, 4.72, -0.62), Kit.hex("#2B2323"))
	end
	piece("Smile", Vector3.new(0.5, 0.1, 0.05), CFrame.new(0, 4.38, -0.62), Kit.hex("#7A3B2E"))
	if style.hat == "Straw" or style.hat == "Explorer" then
		local hatColor = style.hatColor
			or (if style.hat == "Straw" then Kit.hex("#E8C77A") else Kit.hex("#C9A36A"))
		local brim = Kit.part(model, {
			name = "HatBrim",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.2, 2.6, 2.6),
			cframe = cframe * CFrame.new(0, 5.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
			color = hatColor,
			material = Enum.Material.Fabric,
			canCollide = false,
		})
		Kit.part(model, {
			name = "HatTop",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.8, 1.4, 1.4),
			cframe = brim.CFrame * CFrame.new(0.45, 0, 0),
			color = hatColor:Lerp(Color3.new(0, 0, 0), 0.1),
			material = Enum.Material.Fabric,
			canCollide = false,
		})
	elseif style.hat == "Bandana" then
		piece(
			"Bandana",
			Vector3.new(1.3, 0.45, 1.3),
			CFrame.new(0, 5.1, 0),
			style.hatColor or Kit.hex("#E25B45"),
			Enum.Material.Fabric
		)
	elseif style.hat == "Chef" then
		piece(
			"ChefHat",
			Vector3.new(1.1, 1.1, 1.1),
			CFrame.new(0, 5.6, 0),
			Color3.new(1, 1, 1),
			Enum.Material.Fabric
		)
	end
	if style.holding == "Shovel" then
		piece(
			"ShovelHandle",
			Vector3.new(0.25, 4.5, 0.25),
			CFrame.new(1.7, 3, -1.1) * CFrame.Angles(math.rad(-15), 0, 0),
			Kit.hex("#8B5A2B"),
			Enum.Material.Wood
		)
		piece(
			"ShovelBlade",
			Vector3.new(1, 1.3, 0.2),
			CFrame.new(1.7, 0.9, -0.5) * CFrame.Angles(math.rad(-15), 0, 0),
			Kit.hex("#B8C0C8"),
			Enum.Material.Metal
		)
	elseif style.holding == "Coin" then
		Kit.part(model, {
			name = "Coin",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.25, 1.2, 1.2),
			cframe = cframe * CFrame.new(1.6, 2.2, -1.2) * CFrame.Angles(0, math.rad(90), 0),
			color = Kit.hex("#FFC933"),
			material = Enum.Material.Metal,
			canCollide = false,
		})
	end
	model.PrimaryPart = torso
	head:SetAttribute("Ambient", "Head")
	model:SetAttribute("Ambient", "Person")
	model.Parent = parent
	return model
end

return Kit
