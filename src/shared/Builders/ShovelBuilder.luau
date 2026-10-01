--!strict
-- Builds a shovel Model from primitive parts for a shovel level.
-- The model's PrimaryPart is "Handle"; the blade points along the handle's -Y.
-- All parts are massless, non-colliding and non-queryable.

local Progression = require(script.Parent.Parent.Logic.Progression)

local ShovelBuilder = {}

-- A cosmetic skin (Config/Monetization.Skins): replaces the level's colors.
export type Skin = { blade: string, handle: string, material: string, glow: boolean }

-- Overall size: big enough to read clearly in the hand from the camera.
local S = 1.35

-- Where the hand grips the handle (in Handle space), and how the shovel sits
-- in the hand (in hand space). Tweak these two if the grip looks off.
ShovelBuilder.GripOffset = CFrame.new(0, 1.0 * S, 0)
ShovelBuilder.HandOffsetR15 = CFrame.new(0, -0.2, -0.2) * CFrame.Angles(math.rad(50), 0, 0)
ShovelBuilder.HandOffsetR6 = CFrame.new(0, -1.0, -0.2) * CFrame.Angles(math.rad(50), 0, 0)

local function makePart(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.Parent = model
	return part
end

-- `tint` (hex) recolors the blade toward a rebirth color; a `skin`
-- replaces the colors entirely.
function ShovelBuilder.build(level: number, tint: string?, skin: Skin?): Model
	local def = Progression.getShovel(level)
	local model = Instance.new("Model")
	model.Name = "Shovel"
	model:SetAttribute("ShovelLevel", def.level)

	local bladeColor = Color3.fromHex(if skin then skin.blade else def.bladeColor)
	if tint and not skin then
		bladeColor = bladeColor:Lerp(Color3.fromHex(tint), 0.55)
	end
	local handleColor = Color3.fromHex(if skin then skin.handle else def.handleColor)
	local bladeMaterial = (Enum.Material :: any)[if skin then skin.material else def.bladeMaterial]
		or Enum.Material.SmoothPlastic
	local glow = if skin then skin.glow else def.glow

	-- Handle: an unrotated block so the model frame equals the handle frame.
	local handle = makePart(
		model,
		"Handle",
		Enum.PartType.Block,
		Vector3.new(0.3, 3.4, 0.3) * S,
		CFrame.identity,
		handleColor,
		Enum.Material.Wood
	)
	model.PrimaryPart = handle

	-- T-grip on top.
	makePart(
		model,
		"Grip",
		Enum.PartType.Block,
		Vector3.new(0.9, 0.26, 0.26) * S,
		CFrame.new(0, 1.75 * S, 0),
		handleColor,
		Enum.Material.Wood
	)
	-- Collar where the blade meets the handle.
	makePart(
		model,
		"Collar",
		Enum.PartType.Block,
		Vector3.new(0.45, 0.4, 0.3) * S,
		CFrame.new(0, -1.7 * S, 0),
		bladeColor,
		bladeMaterial
	)
	-- Blade: a chunky spade with a pointed tip.
	makePart(
		model,
		"Blade",
		Enum.PartType.Block,
		Vector3.new(1.3, 1.25, 0.18) * S,
		CFrame.new(0, -2.45 * S, 0),
		bladeColor,
		bladeMaterial
	)
	local tip = makePart(
		model,
		"Tip",
		Enum.PartType.Block,
		Vector3.new(0.92, 0.92, 0.18) * S,
		CFrame.new(0, -3.05 * S, 0) * CFrame.Angles(0, 0, math.rad(45)),
		bladeColor,
		bladeMaterial
	)

	if glow then
		local light = Instance.new("PointLight")
		light.Color = bladeColor
		light.Range = 6
		light.Brightness = 1.2
		light.Parent = tip
	end

	-- Weld every part to the handle so the model moves as one.
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
	end
	return model
end

-- Attaches a shovel model to a character's right hand. Returns the model, or
-- nil if the character has no recognizable right hand.
function ShovelBuilder.attach(character: Model, level: number, tint: string?, skin: Skin?): Model?
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	local offset = ShovelBuilder.HandOffsetR15
	if not hand then
		hand = character:FindFirstChild("Right Arm") :: BasePart?
		offset = ShovelBuilder.HandOffsetR6
	end
	if not hand then
		return nil
	end
	local existing = character:FindFirstChild("Shovel")
	if existing then
		existing:Destroy()
	end
	local model = ShovelBuilder.build(level, tint, skin)
	local handle = model.PrimaryPart :: BasePart
	model:PivotTo(hand.CFrame * offset * ShovelBuilder.GripOffset:Inverse())
	local weld = Instance.new("Weld")
	weld.Name = "HandWeld"
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = offset
	weld.C1 = ShovelBuilder.GripOffset
	weld.Parent = handle
	model.Parent = character
	return model
end

return ShovelBuilder
