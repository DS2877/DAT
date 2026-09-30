--!strict
-- Shared building blocks for the world builder: parts, labels, lights, fire,
-- reusable props (palms, rocks, torches), terrain height lookups, and the
-- obstacle list dig spots keep away from.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)

local Kit = {}

Kit.L = MapLayout
Kit.DECK_TOP = MapLayout.beachHeight + MapLayout.base.deckHeight

export type PartProps = {
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	canCollide: boolean?,
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
	p.CanCollide = if props.canCollide == nil then true else props.canCollide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
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

-- Text painted on both faces of a sign board.
function Kit.signText(board: BasePart, text: string, color: Color3, background: Color3?)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.CanvasSize = Vector2.new(board.Size.X * 40, board.Size.Y * 40)
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = if background then 0 else 1
		label.BackgroundColor3 = background or Color3.new(0, 0, 0)
		label.Font = Enum.Font.LuckiestGuy
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = color
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = Color3.fromRGB(40, 25, 10)
		stroke.Parent = label
	end
end

---------------------------------------------------------------------------
-- Obstacles: dig spot candidates keep clear of these.
---------------------------------------------------------------------------

export type Obstacle = { position: Vector3, radius: number }
Kit.obstacles = {} :: { Obstacle }

function Kit.addObstacle(position: Vector3, radius: number?)
	table.insert(Kit.obstacles, { position = position, radius = radius or 3 })
end

---------------------------------------------------------------------------
-- Terrain lookups
---------------------------------------------------------------------------

-- Height of the terrain surface at (x, z), or nil over nothing.
function Kit.groundY(x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), params)
	return if hit then hit.Position.Y else nil
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
	local segments = height or 6
	local pos = base
	local dir = (CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean * 0.4, 0, 0)).UpVector
	for i = 1, segments do
		local seg = 2.4
		local nextPos = pos + dir * seg
		Kit.part(model, {
			name = "Trunk",
			size = Vector3.new(1.3 - i * 0.06, seg + 0.3, 1.3 - i * 0.06),
			cframe = CFrame.lookAt((pos + nextPos) / 2, nextPos) * CFrame.Angles(math.rad(90), 0, 0),
			color = if i % 2 == 0 then trunkColor else trunkColor:Lerp(Color3.new(0, 0, 0), 0.12),
			material = Enum.Material.Wood,
		})
		pos = nextPos
		dir = (CFrame.fromAxisAngle(Vector3.new(math.cos(yaw), 0, math.sin(yaw)), lean * 0.12) * dir).Unit
	end
	local crown = pos
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local droop = math.rad(rng:NextNumber(-30, -16))
		local leaf = CFrame.new(crown) * CFrame.Angles(0, angle, 0) * CFrame.Angles(droop, 0, 0)
		Kit.part(model, {
			name = "Leaf",
			size = Vector3.new(2.3, 0.25, 7.5),
			cframe = leaf * CFrame.new(0, 0, -3.5),
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
		})
	end
	model.Parent = parent
	Kit.addObstacle(base, 3)
end

function Kit.rock(parent: Instance, position: Vector3, scale: number, rng: Random, color: Color3?)
	Kit.part(parent, {
		name = "Rock",
		size = Vector3.new(4, 3, 3.5) * scale,
		cframe = CFrame.new(position)
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
		color = color or Kit.hex("#8E9196"),
		material = Enum.Material.Slate,
	})
	Kit.addObstacle(position, 2.5 * scale)
end

-- A tiki torch: pole, bowl, fire and warm light.
function Kit.torch(parent: Instance, base: Vector3)
	Kit.part(parent, {
		name = "TorchPole",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(6, 0.6, 0.6),
		cframe = CFrame.new(base + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
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
	Kit.light(bowl, Color3.fromRGB(255, 160, 70), 14, 1.4)
	Kit.addObstacle(base, 1.5)
end

return Kit
