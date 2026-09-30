-- Exports the generated island (terrain heights + materials, parts, dig
-- spots) as JSON for scripts/render-map.py. Runs the real MapBuilder through
-- the headless harness.
-- Usage: lune run scripts/export-map.luau build.rbxl out.json

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local H = require("../tests/runtime/Harness")

local game = H.load(process.args[1] or "build.rbxl")
H.runScript(game:GetService("ServerScriptService").Server)

local MapLayout = H.require(game:GetService("ReplicatedStorage").Shared.Config.MapLayout)
local b = MapLayout.bounds
local step = 2

-- Terrain height / material grid.
local heights, materials = {}, {}
local palette, paletteIndex = {}, {}
local cols = math.floor((b.maxX - b.minX) / step) + 1
local rows = math.floor((b.maxZ - b.minZ) / step) + 1
for r = 0, rows - 1 do
	local z = b.minZ + r * step
	for c = 0, cols - 1 do
		local x = b.minX + c * step
		local top, material = H.terrainTop(x, z, 400)
		local y = top or -40
		local mat = material or "Air"
		if not paletteIndex[mat] then
			table.insert(palette, mat)
			paletteIndex[mat] = #palette
		end
		table.insert(heights, math.floor(y * 10 + 0.5) / 10)
		table.insert(materials, paletteIndex[mat])
	end
end

-- Parts (visible ones), with yaw for footprints.
local parts = {}
for _, d in H.unwrap(H.workspace):GetDescendants() do
	if d:IsA("BasePart") and d.ClassName ~= "Terrain" and d.Transparency < 0.95 then
		local cf = d.CFrame
		local look = cf.LookVector
		local shape = if d:IsA("Part") then d.Shape.Name else "Block"
		table.insert(parts, {
			n = d.Name,
			x = cf.Position.X,
			y = cf.Position.Y,
			z = cf.Position.Z,
			sx = d.Size.X,
			sy = d.Size.Y,
			sz = d.Size.Z,
			yaw = math.atan2(-look.X, -look.Z),
			up = { cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z },
			right = { cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z },
			color = d.Color:ToHex(),
			mat = d.Material.Name,
			shape = shape,
			t = d.Transparency,
			parent = if d.Parent then d.Parent.Name else "",
		})
	end
end

local spots = {}
for _, spot in H.workspace.DigSpots:GetChildren() do
	local p = spot.PrimaryPart.Position
	table.insert(
		spots,
		{ x = p.X, z = p.Z, area = spot:GetAttribute("AreaId"), clue = spot:GetAttribute("Clue") }
	)
end

fs.writeFile(
	process.args[2] or "map.json",
	serde.encode("json", {
		bounds = b,
		step = step,
		cols = cols,
		rows = rows,
		heights = heights,
		materials = materials,
		palette = palette,
		parts = parts,
		spots = spots,
		layout = {
			beachNorthZ = MapLayout.beachNorthZ,
			volcanoSouthZ = MapLayout.volcanoSouthZ,
			base = MapLayout.base,
			spawn = MapLayout.spawn,
			gates = MapLayout.gates,
		},
	})
)
print(string.format("exported %dx%d terrain, %d parts, %d spots", cols, rows, #parts, #spots))
process.exit(0)
