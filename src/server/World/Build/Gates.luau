--!strict
-- Area boundaries and gates. The visible boundaries are terrain (cliffs and
-- rock ridges, see Terrain.luau); here we add invisible collision along
-- them (so nobody climbs the rocks) and the gates: posts, a glowing barrier,
-- a sign, a ramp up through the cliff canyon, and a giant half-buried
-- treasure glimpse behind each gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local TreasureBuilder = require(ReplicatedStorage.Shared.Builders.TreasureBuilder)
local Kit = require(script.Parent.Kit)

local L = Kit.L
local part, hex = Kit.part, Kit.hex

local Gates = {}

export type GateInfo = { areaId: string, barrier: BasePart, safePoint: Vector3 }

local AREA_COLORS = {
	Jungle = "#56C451",
	Ruins = "#4FD1C5",
	Volcano = "#FF6A1A",
}

local function invisibleWall(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local mid = (from + to) / 2
	part(parent, {
		name = "Boundary",
		size = Vector3.new(length, 120, 2),
		cframe = CFrame.lookAt(mid, mid + (to - from).Unit)
			* CFrame.Angles(0, math.rad(90), 0)
			* CFrame.new(0, 40, 0),
		transparency = 1,
	})
end

local function gate(parent: Instance, areaId: string): GateInfo
	local g = L.gates[areaId]
	local def = Areas.Defs[areaId]
	local w = L.gateWidth
	local onBeach = g.z > L.beachNorthZ - 1
	local groundY = if onBeach then L.beachHeight else L.plateauHeight
	local model = Instance.new("Model")
	model.Name = areaId .. "Gate"
	local areaColor = hex(AREA_COLORS[areaId])

	-- Stone gate frame with glowing orbs.
	for _, x in { -w / 2 - 1.8, w / 2 + 1.8 } do
		part(model, {
			name = "GatePillar",
			size = Vector3.new(3.6, 22, 3.6),
			cframe = CFrame.new(g.x + x, groundY + 9, g.z),
			color = hex("#9A8F80"),
			material = Enum.Material.Cobblestone,
		})
		local orb = part(model, {
			name = "GateOrb",
			shape = Enum.PartType.Ball,
			size = Vector3.new(2.6, 2.6, 2.6),
			cframe = CFrame.new(g.x + x, groundY + 21.5, g.z),
			color = areaColor,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		Kit.light(orb, areaColor, 18, 1.6)
	end
	part(model, {
		name = "GateLintel",
		size = Vector3.new(w + 8, 3, 4.2),
		cframe = CFrame.new(g.x, groundY + 19.5, g.z),
		color = hex("#8A7F70"),
		material = Enum.Material.Cobblestone,
	})
	local barrier = part(model, {
		name = "Barrier",
		size = Vector3.new(w + 0.5, 18, 1.5),
		cframe = CFrame.new(g.x, groundY + 8, g.z),
		color = areaColor,
		material = Enum.Material.ForceField,
		transparency = 0.1,
	})
	barrier:SetAttribute("AreaId", areaId)

	-- Beach gates climb up to the plateau through a canyon in the cliff.
	if onBeach then
		local low = Vector3.new(g.x, groundY, g.z + 3)
		local high = Vector3.new(g.x, L.plateauHeight, g.z - 30)
		local length = (high - low).Magnitude
		local slope = CFrame.lookAt((low + high) / 2, high)
		part(model, {
			name = "Ramp",
			size = Vector3.new(w + 4, 2, length),
			cframe = slope * CFrame.new(0, -1, 0),
			color = if areaId == "Jungle" then hex("#7A9A4A") else hex("#C9A36A"),
			material = if areaId == "Jungle" then Enum.Material.Grass else Enum.Material.Sandstone,
		})
		-- Stone steps edging the ramp.
		for _, side in { -1, 1 } do
			part(model, {
				name = "RampEdge",
				size = Vector3.new(1.2, 1.4, length),
				cframe = slope * CFrame.new(side * (w / 2 + 2.6), -0.3, 0),
				color = hex("#8E857A"),
				material = Enum.Material.Cobblestone,
			})
		end
	end

	local shovelName = Progression.getShovel(def.requiredShovel).name
	local subtitle = if def.enabled
		then "Needs " .. shovelName
		else "Needs " .. shovelName .. " - opening soon!"
	Kit.billboard(barrier, string.upper(def.displayName), subtitle, areaColor, 17, 22)

	model.Parent = parent
	return { areaId = areaId, barrier = barrier, safePoint = Vector3.new(g.x, groundY + 4, g.z + 12) }
end

-- A giant, half-buried glowing treasure behind a gate: the "something
-- amazing is in there" glimpse players see through the barrier.
local function glimpse(parent: Instance, areaId: string, treasureId: string, offset: Vector2, scale: number)
	local g = L.gates[areaId]
	local x, z = g.x + offset.X, g.z + offset.Y
	local groundY = Kit.groundY(x, z) or L.plateauHeight
	local model = TreasureBuilder.build(treasureId)
	model.Name = areaId .. "Glimpse"
	model:ScaleTo(scale)
	model:PivotTo(
		CFrame.new(x, groundY + scale * 0.35, z) * CFrame.Angles(math.rad(-12), math.rad(25), math.rad(10))
	)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = d.Transparency < 1
		end
	end
	Kit.light(model.PrimaryPart :: BasePart, hex(AREA_COLORS[areaId]), 30, 2.5)
	model.Parent = parent
	Kit.addObstacle(Vector3.new(x, groundY, z), scale * 1.5)
end

function Gates.build(): { [string]: GateInfo }
	local walls = Kit.folder("Walls", workspace)
	local gatesFolder = Kit.folder("Gates", workspace)
	local decor = workspace:FindFirstChild("Decor") or Kit.folder("Decor", workspace)
	local b = L.bounds
	local halfGate = L.gateWidth / 2 + 3

	-- Beach | plateau boundary (the cliff), open at the Jungle and Ruins gates.
	local jx, rx = L.gates.Jungle.x, L.gates.Ruins.x
	local z = L.beachNorthZ
	invisibleWall(walls, Vector3.new(b.minX, 0, z), Vector3.new(jx - halfGate, 0, z))
	invisibleWall(walls, Vector3.new(jx + halfGate, 0, z), Vector3.new(rx - halfGate, 0, z))
	invisibleWall(walls, Vector3.new(rx + halfGate, 0, z), Vector3.new(b.maxX, 0, z))
	-- Canyon sides behind the beach gates.
	for _, gx in { jx, rx } do
		for _, side in { -1, 1 } do
			local x = gx + side * halfGate
			invisibleWall(walls, Vector3.new(x, 0, z), Vector3.new(x, 0, z - 32))
		end
	end
	-- Jungle | Ruins ridge.
	invisibleWall(walls, Vector3.new(L.jungleRuinsX, 0, z), Vector3.new(L.jungleRuinsX, 0, L.volcanoSouthZ))
	-- Volcano ridge, open at the Volcano gate.
	local vx, vz = L.gates.Volcano.x, L.volcanoSouthZ
	invisibleWall(walls, Vector3.new(b.minX, 0, vz), Vector3.new(vx - halfGate, 0, vz))
	invisibleWall(walls, Vector3.new(vx + halfGate, 0, vz), Vector3.new(b.maxX, 0, vz))
	-- Play-area limits (stops swimming around the gates).
	invisibleWall(walls, Vector3.new(b.minX, 0, b.minZ), Vector3.new(b.minX, 0, b.maxZ))
	invisibleWall(walls, Vector3.new(b.maxX, 0, b.minZ), Vector3.new(b.maxX, 0, b.maxZ))
	invisibleWall(walls, Vector3.new(b.minX, 0, b.minZ), Vector3.new(b.maxX, 0, b.minZ))
	invisibleWall(walls, Vector3.new(b.minX, 0, b.maxZ), Vector3.new(b.maxX, 0, b.maxZ))

	local gates = {}
	for _, areaId in { "Jungle", "Ruins", "Volcano" } do
		gates[areaId] = gate(gatesFolder, areaId)
	end

	glimpse(decor, "Jungle", "GoldenIdol", Vector2.new(10, -58), 6)
	glimpse(decor, "Ruins", "AncientStatue", Vector2.new(-24, -42), 6)
	glimpse(decor, "Volcano", "Meteorite", Vector2.new(0, -24), 6)
	return gates
end

return Gates
