-- Exports the generated island (terrain heights + materials, parts with full
-- rotation and meshes, labels, signs, effects, dig spots) as JSON for
-- scripts/render-map.py (top-down map) and scripts/preview (3D views).
-- Runs the real MapBuilder through the headless harness.
-- Usage: lune run scripts/export-map.luau build.rbxl out.json [step]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local H = require("../tests/runtime/Harness")

local game = H.load(process.args[1] or "build.rbxl")
H.runScript(game:GetService("ServerScriptService").Server)

local MapLayout = H.require(game:GetService("ReplicatedStorage").Shared.Config.MapLayout)
-- Terrain beyond the play area too (the volcano cone, islets).
local pb = MapLayout.bounds
local v = MapLayout.volcano
local b = {
	minX = pb.minX - 80,
	maxX = pb.maxX + 80,
	minZ = math.min(pb.minZ - 80, v.z - v.radius - 20),
	maxZ = pb.maxZ + 40,
}
local step = tonumber(process.args[3]) or 2

local function round(v: number, digits: number?): number
	local m = 10 ^ (digits or 2)
	return math.floor(v * m + 0.5) / m
end

-- Terrain: top surface (water included), the floor under any water, and the
-- top material.
local heights, floors, materials = {}, {}, {}
local palette, paletteIndex = {}, {}
local cols = math.floor((b.maxX - b.minX) / step) + 1
local rows = math.floor((b.maxZ - b.minZ) / step) + 1
for r = 0, rows - 1 do
	local z = b.minZ + r * step
	for c = 0, cols - 1 do
		local x = b.minX + c * step
		local top, material = H.terrainTopRaw(x, z, 600)
		local y = top or -40
		local mat = material or "Air"
		local floor = y
		if mat == "Water" then
			local below = H.terrainTopRaw(x, z, y - 0.1)
			while below do
				if H.materialAt(x, below - 0.05, z) ~= "Water" then
					break
				end
				below = H.terrainTopRaw(x, z, below - 0.1)
			end
			floor = below or -40
		end
		-- Match Roblox's raised surfaces (see Harness.terrainOffset); water
		-- surfaces stay at sea level.
		if top and mat ~= "Water" then
			y += H.terrainOffset
		end
		if floor > -40 then
			floor += H.terrainOffset
		end
		if not paletteIndex[mat] then
			table.insert(palette, mat)
			paletteIndex[mat] = #palette
		end
		table.insert(heights, round(y, 1))
		table.insert(floors, round(floor, 1))
		table.insert(materials, paletteIndex[mat])
	end
end

local function vec(v: any): { number }
	return { round(v.X, 4), round(v.Y, 4), round(v.Z, 4) }
end

-- Parts (visible ones).
local parts = {}
local partIndex = {}
local signs, labels, effects = {}, {}, {}
for _, d in H.unwrap(H.workspace):GetDescendants() do
	if d:IsA("BasePart") and d.ClassName ~= "Terrain" and d.Transparency < 0.98 then
		local cf = d.CFrame
		local look = cf.LookVector
		local shape = if d:IsA("Part") then d.Shape.Name else "Block"
		local mesh = d:FindFirstChildOfClass("SpecialMesh")
		table.insert(parts, {
			n = d.Name,
			cls = d.ClassName,
			x = round(cf.Position.X),
			y = round(cf.Position.Y),
			z = round(cf.Position.Z),
			sx = round(d.Size.X),
			sy = round(d.Size.Y),
			sz = round(d.Size.Z),
			yaw = math.atan2(-look.X, -look.Z),
			up = vec(cf.UpVector),
			right = vec(cf.RightVector),
			color = d.Color:ToHex(),
			mat = d.Material.Name,
			shape = shape,
			t = d.Transparency,
			refl = d.Reflectance,
			mesh = if mesh
				then { type = mesh.MeshType.Name, scale = vec(mesh.Scale), offset = vec(mesh.Offset) }
				else nil,
			parent = if d.Parent then d.Parent.Name else "",
		})
		partIndex[d:GetAttribute("HarnessId") or d:GetFullName()] = #parts
	end
end

local function textOf(gui: any, name: string?): string?
	for _, child in gui:GetDescendants() do
		if child:IsA("TextLabel") and (name == nil or child.Name == name) then
			return child.Text
		end
	end
	return nil
end

local function colorOf(gui: any, name: string?): string
	for _, child in gui:GetDescendants() do
		if child:IsA("TextLabel") and (name == nil or child.Name == name) then
			return child.TextColor3:ToHex()
		end
	end
	return "ffffff"
end

for _, d in H.unwrap(game):GetDescendants() do
	if d:IsA("BillboardGui") then
		local adornee = d.Adornee or d.Parent
		if adornee and adornee:IsA("BasePart") then
			local p = adornee.CFrame.Position + d.StudsOffsetWorldSpace
			table.insert(labels, {
				x = round(p.X),
				y = round(p.Y),
				z = round(p.Z),
				w = d.Size.X.Scale,
				h = d.Size.Y.Scale,
				title = textOf(d, "Title") or textOf(d) or "",
				sub = textOf(d, "Subtitle"),
				color = colorOf(d, "Title"),
				top = d.AlwaysOnTop,
			})
		end
	elseif
		d:IsA("SurfaceGui")
		and d.Parent
		and partIndex[d.Parent:GetAttribute("HarnessId") or d.Parent:GetFullName()]
	then
		local label = d:FindFirstChildOfClass("TextLabel")
		table.insert(signs, {
			part = partIndex[d.Parent:GetAttribute("HarnessId") or d.Parent:GetFullName()],
			face = d.Face.Name,
			text = textOf(d) or "",
			color = colorOf(d),
			bg = if label and label.BackgroundTransparency < 1 then label.BackgroundColor3:ToHex() else nil,
		})
	elseif
		(d:IsA("Fire") or d:IsA("Smoke") or d:IsA("ParticleEmitter") or d:IsA("PointLight"))
		and d.Parent
		and d.Parent:IsA("BasePart")
	then
		local p = d.Parent.CFrame.Position
		local color = if d:IsA("PointLight")
			then d.Color:ToHex()
			elseif d:IsA("Fire") then d.Color:ToHex()
			elseif d:IsA("Smoke") then d.Color:ToHex()
			else "ffffff"
		table.insert(effects, {
			kind = d.ClassName,
			x = round(p.X),
			y = round(p.Y),
			z = round(p.Z),
			color = color,
			size = if d:IsA("Fire") or d:IsA("Smoke")
				then d.Size
				elseif d:IsA("PointLight") then d.Range
				else 2,
		})
	end
end

local spots = {}
for _, spot in H.workspace.DigSpots:GetChildren() do
	local p = spot.PrimaryPart.Position
	table.insert(
		spots,
		{ x = p.X, y = p.Y, z = p.Z, area = spot:GetAttribute("AreaId"), clue = spot:GetAttribute("Clue") }
	)
end

local lighting = H.unwrap(game:GetService("Lighting"))
local function prop(inst: any, name: string): any
	local ok, v = pcall(function()
		return inst[name]
	end)
	return if ok then v else nil
end
local function hexOr(v: any): string?
	return if v then v:ToHex() else nil
end
local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
local cc = lighting:FindFirstChildOfClass("ColorCorrectionEffect")

fs.writeFile(
	process.args[2] or "map.json",
	serde.encode("json", {
		bounds = b,
		step = step,
		cols = cols,
		rows = rows,
		heights = heights,
		floors = floors,
		materials = materials,
		palette = palette,
		parts = parts,
		labels = labels,
		signs = signs,
		effects = effects,
		spots = spots,
		lighting = {
			clockTime = prop(lighting, "ClockTime"),
			latitude = prop(lighting, "GeographicLatitude"),
			brightness = prop(lighting, "Brightness"),
			exposure = prop(lighting, "ExposureCompensation"),
			ambient = hexOr(prop(lighting, "Ambient")),
			outdoorAmbient = hexOr(prop(lighting, "OutdoorAmbient")),
			atmosphere = if atmosphere
				then {
					density = atmosphere.Density,
					haze = atmosphere.Haze,
					color = atmosphere.Color:ToHex(),
					decay = atmosphere.Decay:ToHex(),
				}
				else nil,
			saturation = if cc then cc.Saturation else nil,
			contrast = if cc then cc.Contrast else nil,
		},
		layout = {
			beachHeight = MapLayout.beachHeight,
			plateauHeight = MapLayout.plateauHeight,
			highlandHeight = MapLayout.highlandHeight,
			beachNorthZ = MapLayout.beachNorthZ,
			volcanoSouthZ = MapLayout.volcanoSouthZ,
			base = MapLayout.base,
			spawn = MapLayout.spawn,
			gates = MapLayout.gates,
			volcano = MapLayout.volcano,
		},
	})
)
print(
	string.format(
		"exported %dx%d terrain, %d parts, %d labels, %d signs, %d spots",
		cols,
		rows,
		#parts,
		#labels,
		#signs,
		#spots
	)
)
process.exit(0)
