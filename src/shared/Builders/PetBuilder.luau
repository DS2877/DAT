--!strict
-- Builds a pet's model from its parts list (Config/Pets): feet at the
-- origin, facing -Z, anchored and non-colliding (callers move it with
-- PivotTo). The PrimaryPart is an invisible "Root" at the feet.

local Pets = require(script.Parent.Parent.Logic.Pets)

local PetBuilder = {}

local SHAPES: { [string]: Enum.PartType } = {
	Ball = Enum.PartType.Ball,
	Block = Enum.PartType.Block,
	Cylinder = Enum.PartType.Cylinder,
}

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function quiet(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
end

function PetBuilder.build(id: string): Model?
	local pet = Pets.byId[id]
	if not pet then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Pet_" .. id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CFrame = CFrame.new()
	quiet(root)
	root.Parent = model
	model.PrimaryPart = root
	for i, def in pet.parts do
		local size = vec(def.size)
		local part: BasePart
		if def.shape == "Wedge" then
			part = Instance.new("WedgePart")
		else
			local p = Instance.new("Part")
			local shape = SHAPES[def.shape] or Enum.PartType.Block
			if shape == Enum.PartType.Ball and (size.X ~= size.Y or size.Y ~= size.Z) then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = p
			else
				p.Shape = shape
			end
			part = p
		end
		part.Name = if i == 1 then "Body" else "Part"
		part.Size = size
		local rot = def.rot or { 0, 0, 0 }
		part.CFrame = CFrame.new(vec(def.at))
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		part.Color = Color3.fromHex(def.color)
		part.Material = if def.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		quiet(part)
		part.Parent = model
	end
	if pet.glow then
		local body = model:FindFirstChild("Body") :: BasePart
		local light = Instance.new("PointLight")
		light.Color = Color3.fromHex(pet.glow)
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = body
		if pet.fly then
			local fire = Instance.new("Fire")
			fire.Size = 2
			fire.Heat = 4
			fire.Color = Color3.fromHex(pet.glow)
			fire.SecondaryColor = Color3.fromRGB(255, 230, 120)
			fire.Parent = body
		end
	end
	model:SetAttribute("PetId", id)
	return model
end

return PetBuilder
