--!strict
-- Builds chunky, readable treasure models from primitive parts.
-- Each treasure's `model` field in Config/Treasures picks an archetype below;
-- `color` and `accent` tint it. Models are ~2 studs tall, centered on the
-- origin, anchored and non-colliding (callers move them with PivotTo).

local Treasures = require(script.Parent.Parent.Config.Treasures)

local TreasureBuilder = {}

type Ctx = { model: Model, color: Color3, accent: Color3 }

local Shape = Enum.PartType
local Mat = Enum.Material

local function add(
	ctx: Ctx,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	-- Roblox draws a Ball with its smallest size axis as the diameter, so
	-- non-round balls become a block with a stretched sphere mesh.
	local stretched = shape == Shape.Ball and (size.X ~= size.Y or size.Y ~= size.Z)
	if stretched then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	else
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color or ctx.color
	part.Material = material or Mat.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = ctx.model
	return part
end

local function cf(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local UPRIGHT = 90 -- Cylinders run along X; rotate 90 degrees on Z to stand them up.

local function isShiny(color: Color3): Enum.Material
	-- Gold/silver-ish colors read better as metal.
	local h, s, v = color:ToHSV()
	if (h > 0.1 and h < 0.17 and s > 0.5 and v > 0.8) or (s < 0.12 and v > 0.8) then
		return Mat.Metal
	end
	return Mat.SmoothPlastic
end

local Archetypes: { [string]: (ctx: Ctx) -> () } = {}

function Archetypes.Coin(ctx)
	local metal = isShiny(ctx.color)
	add(ctx, Shape.Cylinder, Vector3.new(0.35, 1.9, 1.9), cf(0, 0, 0, 0, 90, 0), ctx.color, metal)
	add(
		ctx,
		Shape.Cylinder,
		Vector3.new(0.42, 1.25, 1.25),
		cf(0, 0, 0, 0, 90, 0),
		ctx.color:Lerp(Color3.new(1, 1, 1), 0.25),
		metal
	)
	add(
		ctx,
		Shape.Block,
		Vector3.new(0.25, 0.8, 0.46),
		cf(0, 0, 0),
		ctx.color:Lerp(Color3.new(0, 0, 0), 0.25),
		metal
	)
end

function Archetypes.Bottle(ctx)
	local glass = add(
		ctx,
		Shape.Cylinder,
		Vector3.new(1.4, 0.95, 0.95),
		cf(0, -0.25, 0, 0, 0, UPRIGHT),
		ctx.color,
		Mat.Glass
	)
	glass.Transparency = 0.25
	local neck = add(
		ctx,
		Shape.Cylinder,
		Vector3.new(0.6, 0.45, 0.45),
		cf(0, 0.72, 0, 0, 0, UPRIGHT),
		ctx.color,
		Mat.Glass
	)
	neck.Transparency = 0.25
	add(
		ctx,
		Shape.Cylinder,
		Vector3.new(0.28, 0.4, 0.4),
		cf(0, 1.1, 0, 0, 0, UPRIGHT),
		Color3.fromHex("#A8773F"),
		Mat.Wood
	)
	add(ctx, Shape.Block, Vector3.new(0.5, 0.6, 0.1), cf(0, -0.25, -0.48), ctx.accent, Mat.SmoothPlastic) -- message inside
end

function Archetypes.Shell(ctx)
	add(ctx, Shape.Ball, Vector3.new(1.9, 0.7, 1.7), cf(0, 0, 0), ctx.color)
	for i = -2, 2 do
		add(
			ctx,
			Shape.Block,
			Vector3.new(0.14, 0.72, 1.5),
			cf(i * 0.32, 0.12, 0.05, 0, i * 14, 0),
			ctx.accent
		)
	end
	add(ctx, Shape.Block, Vector3.new(0.7, 0.3, 0.35), cf(0, -0.05, 0.85), ctx.color)
end

function Archetypes.Spoon(ctx)
	add(ctx, Shape.Ball, Vector3.new(0.95, 0.35, 1.25), cf(0, 0, -0.75), ctx.color, Mat.Metal)
	add(ctx, Shape.Block, Vector3.new(0.24, 0.14, 1.7), cf(0, 0.05, 0.6), ctx.color, Mat.Metal)
	add(ctx, Shape.Ball, Vector3.new(0.35, 0.18, 0.4), cf(0, 0.05, 1.45), ctx.color, Mat.Metal)
end

function Archetypes.Compass(ctx)
	add(ctx, Shape.Cylinder, Vector3.new(0.4, 1.8, 1.8), cf(0, 0, 0, 0, 90, 0), ctx.color, isShiny(ctx.color))
	add(ctx, Shape.Cylinder, Vector3.new(0.44, 1.4, 1.4), cf(0, 0, 0, 0, 90, 0), ctx.accent)
	add(ctx, Shape.Block, Vector3.new(0.12, 1.1, 0.5), cf(0, 0, 0, 0, 0, 20), Color3.fromHex("#E53935"))
	add(
		ctx,
		Shape.Cylinder,
		Vector3.new(0.3, 0.4, 0.4),
		cf(0, 1.0, 0, 0, 0, UPRIGHT),
		ctx.color,
		isShiny(ctx.color)
	)
end

function Archetypes.Pearl(ctx)
	local pearl =
		add(ctx, Shape.Ball, Vector3.new(1.4, 1.4, 1.4), cf(0, 0.25, 0), ctx.color, Mat.SmoothPlastic)
	pearl.Reflectance = 0.25
	add(ctx, Shape.Ball, Vector3.new(2.1, 0.55, 1.9), cf(0, -0.5, 0), ctx.accent)
end

function Archetypes.Mug(ctx)
	add(ctx, Shape.Cylinder, Vector3.new(1.5, 1.2, 1.2), cf(0, 0, 0, 0, 0, UPRIGHT), ctx.color, Mat.Wood)
	add(
		ctx,
		Shape.Cylinder,
		Vector3.new(0.2, 1.25, 1.25),
		cf(0, 0.45, 0, 0, 0, UPRIGHT),
		ctx.accent,
		Mat.Metal
	)
	add(
		ctx,
		Shape.Cylinder,
		Vector3.new(0.2, 1.25, 1.25),
		cf(0, -0.45, 0, 0, 0, UPRIGHT),
		ctx.accent,
		Mat.Metal
	)
	add(ctx, Shape.Block, Vector3.new(0.5, 0.18, 0.2), cf(0.8, 0.4, 0), ctx.color, Mat.Wood)
	add(ctx, Shape.Block, Vector3.new(0.2, 0.9, 0.2), cf(1.0, 0, 0), ctx.color, Mat.Wood)
	add(ctx, Shape.Block, Vector3.new(0.5, 0.18, 0.2), cf(0.8, -0.4, 0), ctx.color, Mat.Wood)
	add(ctx, Shape.Ball, Vector3.new(1.15, 0.4, 1.15), cf(0, 0.78, 0), Color3.fromHex("#FFF6E0"))
end

function Archetypes.Watch(ctx)
	add(ctx, Shape.Cylinder, Vector3.new(0.35, 1.5, 1.5), cf(0, 0, 0, 0, 90, 0), ctx.color, Mat.Metal)
	add(ctx, Shape.Cylinder, Vector3.new(0.4, 1.15, 1.15), cf(0, 0, 0, 0, 90, 0), ctx.accent)
	add(ctx, Shape.Block, Vector3.new(0.08, 0.45, 0.45), cf(0, 0.15, 0), Color3.new(0.1, 0.1, 0.1))
	add(ctx, Shape.Block, Vector3.new(0.08, 0.1, 0.35), cf(0, 0, 0.15, 0, 0, 0), Color3.new(0.1, 0.1, 0.1))
	for i = 1, 4 do
		add(ctx, Shape.Ball, Vector3.new(0.22, 0.22, 0.22), cf(0, 0.75 + i * 0.2, 0), ctx.color, Mat.Metal)
	end
end

function Archetypes.Idol(ctx)
	local mat = isShiny(ctx.color)
	add(ctx, Shape.Block, Vector3.new(1.0, 1.1, 0.8), cf(0, -0.45, 0), ctx.color, mat)
	add(ctx, Shape.Block, Vector3.new(1.2, 0.95, 0.95), cf(0, 0.55, 0), ctx.color, mat)
	add(ctx, Shape.Block, Vector3.new(1.3, 0.2, 1.0), cf(0, -1.0, 0), ctx.color, mat)
	local eye = ctx.accent
	add(ctx, Shape.Block, Vector3.new(0.22, 0.16, 0.1), cf(-0.25, 0.65, -0.48), eye, Mat.Neon)
	add(ctx, Shape.Block, Vector3.new(0.22, 0.16, 0.1), cf(0.25, 0.65, -0.48), eye, Mat.Neon)
	add(ctx, Shape.Block, Vector3.new(0.5, 0.1, 0.1), cf(0, 0.3, -0.48), Color3.new(0.1, 0.1, 0.1))
end

function Archetypes.Gem(ctx)
	local outer =
		add(ctx, Shape.Block, Vector3.new(1.3, 1.3, 1.3), cf(0, 0, 0, 45, 0, 45), ctx.color, Mat.Glass)
	outer.Transparency = 0.15
	outer.Reflectance = 0.2
	add(ctx, Shape.Block, Vector3.new(0.7, 0.7, 0.7), cf(0, 0, 0, 45, 0, 45), ctx.color, Mat.Neon)
end

function Archetypes.Skull(ctx)
	local mat = isShiny(ctx.color)
	add(ctx, Shape.Ball, Vector3.new(1.6, 1.5, 1.6), cf(0, 0.2, 0), ctx.color, mat)
	add(ctx, Shape.Block, Vector3.new(1.0, 0.6, 0.9), cf(0, -0.6, -0.25), ctx.color, mat)
	local dark = Color3.fromHex("#1B1B1B")
	add(ctx, Shape.Ball, Vector3.new(0.45, 0.45, 0.3), cf(-0.33, 0.2, -0.7), dark)
	add(ctx, Shape.Ball, Vector3.new(0.45, 0.45, 0.3), cf(0.33, 0.2, -0.7), dark)
	add(ctx, Shape.Block, Vector3.new(0.18, 0.25, 0.2), cf(0, -0.15, -0.76), dark)
end

function Archetypes.Statue(ctx)
	local mat = if isShiny(ctx.color) == Mat.Metal then Mat.Metal else Mat.Slate
	add(ctx, Shape.Block, Vector3.new(1.3, 0.35, 1.3), cf(0, -1.0, 0), ctx.color, mat)
	add(ctx, Shape.Cylinder, Vector3.new(1.3, 0.85, 0.85), cf(0, -0.2, 0, 0, 0, UPRIGHT), ctx.color, mat)
	add(ctx, Shape.Ball, Vector3.new(0.8, 0.8, 0.8), cf(0, 0.8, 0), ctx.color, mat)
	add(ctx, Shape.Block, Vector3.new(1.4, 0.25, 0.3), cf(0, 0.25, 0), ctx.color, mat)
end

function Archetypes.Necklace(ctx)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		add(
			ctx,
			Shape.Ball,
			Vector3.new(0.28, 0.28, 0.28),
			cf(math.cos(a) * 0.85, 0.3 + math.sin(a) * 0.85, 0),
			ctx.color,
			Mat.Metal
		)
	end
	add(ctx, Shape.Block, Vector3.new(0.6, 0.6, 0.3), cf(0, -0.75, 0, 0, 0, 45), ctx.accent, Mat.Neon)
end

function Archetypes.Crown(ctx)
	local mat = isShiny(ctx.color)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local x, z = math.cos(a) * 0.8, math.sin(a) * 0.8
		add(
			ctx,
			Shape.Block,
			Vector3.new(0.7, 0.7, 0.18),
			CFrame.new(x, -0.3, z) * CFrame.Angles(0, -a + math.pi / 2, 0),
			ctx.color,
			mat
		)
		if i % 2 == 0 then
			add(
				ctx,
				Shape.Block,
				Vector3.new(0.3, 0.55, 0.18),
				CFrame.new(x, 0.3, z) * CFrame.Angles(0, -a + math.pi / 2, 0),
				ctx.color,
				mat
			)
			add(
				ctx,
				Shape.Ball,
				Vector3.new(0.28, 0.28, 0.28),
				cf(x * 1.02, 0.65, z * 1.02),
				ctx.accent,
				Mat.Neon
			)
		end
	end
end

function Archetypes.Relic(ctx)
	add(ctx, Shape.Block, Vector3.new(1.3, 0.3, 1.3), cf(0, -0.9, 0), ctx.color, Mat.Slate)
	add(ctx, Shape.Block, Vector3.new(0.9, 1.3, 0.9), cf(0, 0, 0, 0, 45, 0), ctx.color, Mat.Slate)
	add(ctx, Shape.Ball, Vector3.new(0.75, 0.75, 0.75), cf(0, 0.95, 0), ctx.accent, Mat.Neon)
	add(ctx, Shape.Block, Vector3.new(1.0, 0.15, 0.15), cf(0, 0.2, 0, 0, 45, 0), ctx.accent, Mat.Neon)
end

function Archetypes.Chest(ctx)
	add(ctx, Shape.Block, Vector3.new(2.0, 1.0, 1.3), cf(0, -0.35, 0), ctx.color, Mat.Wood)
	add(ctx, Shape.Cylinder, Vector3.new(2.0, 1.3, 1.3), cf(0, 0.15, 0), ctx.color, Mat.Wood)
	for _, x in { -0.7, 0.7 } do
		add(ctx, Shape.Block, Vector3.new(0.2, 1.05, 1.35), cf(x, -0.35, 0), ctx.accent, Mat.Metal)
		add(ctx, Shape.Cylinder, Vector3.new(0.2, 1.35, 1.35), cf(x, 0.15, 0), ctx.accent, Mat.Metal)
	end
	add(ctx, Shape.Block, Vector3.new(0.35, 0.45, 0.15), cf(0, 0.0, -0.7), ctx.accent, Mat.Metal)
	add(ctx, Shape.Ball, Vector3.new(0.9, 0.5, 0.9), cf(0.2, 0.75, 0), Color3.fromHex("#FFC933"), Mat.Neon) -- treasure peeking out
end

function Archetypes.Egg(ctx)
	add(ctx, Shape.Ball, Vector3.new(1.4, 1.9, 1.4), cf(0, 0.1, 0), ctx.color, Mat.Metal)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		add(
			ctx,
			Shape.Ball,
			Vector3.new(0.35, 0.35, 0.2),
			CFrame.new(math.cos(a) * 0.62, 0.1 + (i % 2) * 0.4 - 0.2, math.sin(a) * 0.62)
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			ctx.accent,
			Mat.Neon
		)
	end
end

function Archetypes.Meteor(ctx)
	add(ctx, Shape.Ball, Vector3.new(1.8, 1.6, 1.7), cf(0, 0, 0), ctx.color, Mat.Basalt)
	add(ctx, Shape.Ball, Vector3.new(0.9, 0.8, 0.9), cf(0.55, 0.45, -0.3), ctx.color, Mat.Basalt)
	for _, p in { { -0.6, 0.2, -0.6 }, { 0.3, -0.5, -0.7 }, { 0.7, 0.1, 0.5 } } do
		add(
			ctx,
			Shape.Block,
			Vector3.new(0.5, 0.12, 0.12),
			cf(p[1], p[2], p[3], 0, 30, 20),
			ctx.accent,
			Mat.Neon
		)
	end
end

function Archetypes.Banana(ctx)
	for i = -2, 2 do
		add(
			ctx,
			Shape.Block,
			Vector3.new(0.5, 0.45, 0.5),
			cf(i * 0.42, math.abs(i) * 0.22, 0, 0, 0, i * 16),
			ctx.color,
			Mat.Metal
		)
	end
	add(
		ctx,
		Shape.Block,
		Vector3.new(0.2, 0.3, 0.2),
		cf(-1.05, 0.62, 0, 0, 0, -40),
		Color3.fromHex("#6B4A1F")
	)
end

function Archetypes.Toilet(ctx)
	add(
		ctx,
		Shape.Cylinder,
		Vector3.new(0.9, 0.9, 0.9),
		cf(0, -0.75, 0.1, 0, 0, UPRIGHT),
		ctx.color,
		Mat.Metal
	)
	add(ctx, Shape.Ball, Vector3.new(1.5, 0.6, 1.8), cf(0, -0.15, 0.05), ctx.color, Mat.Metal)
	add(ctx, Shape.Block, Vector3.new(1.4, 1.1, 0.5), cf(0, 0.45, 0.85), ctx.color, Mat.Metal)
	add(ctx, Shape.Block, Vector3.new(1.5, 0.12, 1.8), cf(0, 0.2, 0.05, -12, 0, 0), ctx.color, Mat.Metal)
end

-- Junk ---------------------------------------------------------------------

function Archetypes.Boot(ctx)
	add(ctx, Shape.Block, Vector3.new(0.8, 1.5, 0.8), cf(0, 0.25, -0.35), ctx.color, Mat.Fabric)
	add(ctx, Shape.Block, Vector3.new(0.85, 0.6, 1.7), cf(0, -0.45, 0.1), ctx.color, Mat.Fabric)
	add(ctx, Shape.Ball, Vector3.new(0.85, 0.6, 0.6), cf(0, -0.45, 0.95), ctx.color, Mat.Fabric)
	add(ctx, Shape.Block, Vector3.new(0.95, 0.18, 1.9), cf(0, -0.78, 0.15), ctx.accent)
	for i = 0, 2 do
		add(
			ctx,
			Shape.Block,
			Vector3.new(0.9, 0.08, 0.12),
			cf(0, 0.35 - i * 0.3, 0.06),
			Color3.new(0.9, 0.85, 0.7)
		)
	end
end

function Archetypes.Duck(ctx)
	add(ctx, Shape.Ball, Vector3.new(1.4, 1.1, 1.7), cf(0, -0.35, 0))
	add(ctx, Shape.Ball, Vector3.new(0.95, 0.95, 0.95), cf(0, 0.5, 0.45))
	add(ctx, Shape.Ball, Vector3.new(0.5, 0.25, 0.6), cf(0, 0.42, 1.0), ctx.accent)
	for _, x in { -0.25, 0.25 } do
		add(ctx, Shape.Ball, Vector3.new(0.16, 0.16, 0.16), cf(x, 0.68, 0.86), Color3.new(0.1, 0.1, 0.1))
	end
	add(ctx, Shape.Ball, Vector3.new(0.5, 0.45, 0.6), cf(0, 0.0, -0.85))
end

function Archetypes.Dentures(ctx)
	add(ctx, Shape.Ball, Vector3.new(1.8, 0.45, 1.3), cf(0, 0.28, 0), ctx.accent)
	add(ctx, Shape.Ball, Vector3.new(1.8, 0.45, 1.3), cf(0, -0.28, 0), ctx.accent)
	for i = -3, 3 do
		local a = math.rad(i * 22)
		local x, z = math.sin(a) * 0.72, math.cos(a) * 0.5
		add(ctx, Shape.Block, Vector3.new(0.22, 0.3, 0.18), cf(x, 0.05, z, 0, math.deg(a), 0))
		add(ctx, Shape.Block, Vector3.new(0.22, 0.28, 0.18), cf(x, -0.22, z, 0, math.deg(a), 0))
	end
end

function Archetypes.Rock(ctx)
	add(ctx, Shape.Ball, Vector3.new(1.7, 1.15, 1.4), cf(0, -0.1, 0, 0, 25, 8), ctx.color, Mat.Slate)
	add(ctx, Shape.Ball, Vector3.new(0.7, 0.5, 0.6), cf(0.45, 0.35, 0.1), ctx.color, Mat.Slate)
end

function Archetypes.Paper(ctx)
	local base = CFrame.Angles(math.rad(-8), math.rad(12), math.rad(4))
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	add(ctx, Shape.Block, Vector3.new(1.5, 0.06, 1.9), at(0, -0.1, 0), ctx.color)
	add(
		ctx,
		Shape.Block,
		Vector3.new(1.5, 0.06, 1.9),
		at(0.1, -0.03, 0.06) * CFrame.Angles(0, math.rad(-8), 0),
		ctx.color
	)
	for i = 0, 4 do
		add(ctx, Shape.Block, Vector3.new(1.0, 0.04, 0.06), at(0.15, 0.01, -0.65 + i * 0.26), ctx.accent)
	end
	-- A big red F.
	local red = Color3.fromRGB(220, 40, 40)
	add(ctx, Shape.Block, Vector3.new(0.1, 0.05, 0.5), at(-0.45, 0.02, 0.62), red)
	add(ctx, Shape.Block, Vector3.new(0.32, 0.05, 0.1), at(-0.31, 0.02, 0.42), red)
	add(ctx, Shape.Block, Vector3.new(0.24, 0.05, 0.1), at(-0.35, 0.02, 0.6), red)
end

function Archetypes.Sock(ctx)
	add(ctx, Shape.Block, Vector3.new(0.7, 1.4, 0.7), cf(0, 0.3, -0.2, 0, 0, 8), ctx.color, Mat.Fabric)
	add(ctx, Shape.Ball, Vector3.new(0.75, 0.7, 1.3), cf(0.1, -0.45, 0.3, 0, 0, 8), ctx.color, Mat.Fabric)
	add(ctx, Shape.Block, Vector3.new(0.75, 0.18, 0.75), cf(0, 0.85, -0.2, 0, 0, 8), ctx.accent, Mat.Fabric)
	add(ctx, Shape.Block, Vector3.new(0.75, 0.12, 0.75), cf(0, 0.55, -0.2, 0, 0, 8), ctx.accent, Mat.Fabric)
end

function Archetypes.Remote(ctx)
	local base = CFrame.Angles(0, math.rad(20), math.rad(-6))
	add(ctx, Shape.Block, Vector3.new(0.7, 0.3, 2.0), base)
	add(ctx, Shape.Ball, Vector3.new(0.24, 0.24, 0.24), base * CFrame.new(0, 0.17, -0.65), ctx.accent)
	for i = 0, 2 do
		for _, x in { -0.15, 0.15 } do
			add(
				ctx,
				Shape.Block,
				Vector3.new(0.18, 0.06, 0.18),
				base * CFrame.new(x, 0.17, -0.15 + i * 0.3),
				Color3.new(0.8, 0.8, 0.8)
			)
		end
	end
end

function Archetypes.Chunk(ctx)
	add(ctx, Shape.Block, Vector3.new(1.3, 1.3, 1.3), cf(0, 0, 0, 20, 30, 10), ctx.color)
end

function TreasureBuilder.build(treasureId: string): Model
	local def = Treasures.ById[treasureId]
	local model = Instance.new("Model")
	model.Name = treasureId
	local ctx: Ctx = {
		model = model,
		color = Color3.fromHex(if def then def.color else "#FFC933"),
		accent = Color3.fromHex(if def and def.accent then def.accent else "#FFFFFF"),
	}
	local archetype = def and Archetypes[def.model] or Archetypes.Chunk
	archetype(ctx)

	-- Invisible root at the origin so PivotTo/ScaleTo have a stable center.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root
	return model
end

-- Model:ScaleTo, keeping stretched-sphere meshes sized by their part (mesh
-- Scale is relative to the part for sphere meshes, so it must stay 1).
function TreasureBuilder.scaleTo(model: Model, scale: number)
	model:ScaleTo(scale)
	for _, d in model:GetDescendants() do
		if d:IsA("SpecialMesh") then
			d.Scale = Vector3.one
		end
	end
end

local GOLD = Color3.fromRGB(255, 201, 51)

-- Gives a built treasure its Shiny (sparkly, reflective) or Golden (solid
-- gold, glowing) look. Does nothing for nil.
function TreasureBuilder.applyMutation(model: Model, mutation: string?)
	if not mutation then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			if mutation == "Golden" then
				d.Color = if d.Material == Enum.Material.Neon then Color3.fromRGB(255, 240, 160) else GOLD
				if d.Material ~= Enum.Material.Neon then
					d.Material = Enum.Material.Metal
				end
				d.Reflectance = 0.25
			else
				d.Reflectance = math.min(0.5, d.Reflectance + 0.3)
			end
		end
	end
	local root = model.PrimaryPart :: BasePart
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(if mutation == "Golden" then GOLD else Color3.new(1, 1, 1))
	sparkle.LightEmission = 1
	sparkle.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(0.5, 0.9)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = if mutation == "Golden" then 40 else 22
	sparkle.Parent = root
	if mutation == "Golden" then
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 16
		light.Brightness = 3
		light.Parent = root
	end
end

return TreasureBuilder
