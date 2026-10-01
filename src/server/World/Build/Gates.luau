--!strict
-- Area boundaries and gates. The visible boundaries are terrain (cliffs and
-- the central ridge, see Terrain.luau); here we add invisible collision
-- along them (so nobody climbs the rocks) and the gates: a stone gateway
-- with glowing orbs, a force-field barrier, a sign, a solid ramp up through
-- the canyon to the next tier, and a giant half-buried treasure glimpse.
-- Ramp ends and gate bases are measured from the real ground.

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
local STONE = {
	Jungle = { "#7F8C6A", "#6B7759" },
	Ruins = { "#CDB78C", "#B39C70" },
	Volcano = { "#4A4246", "#3A3336" },
}

-- `inside` (a flat direction) makes the wall one-way: it only stops players
-- coming from outside; players on the `inside` side can walk or jump out
-- through it (WallController turns its collision off for them locally).
local function invisibleWall(parent: Instance, from: Vector3, to: Vector3, inside: Vector3?)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local mid = (from + to) / 2
	local wall = part(parent, {
		name = "Boundary",
		size = Vector3.new(length, 200, 2),
		cframe = CFrame.lookAt(mid, mid + (to - from).Unit)
			* CFrame.Angles(0, math.rad(90), 0)
			* CFrame.new(0, 80, 0),
		transparency = 1,
		castShadow = false,
	})
	if inside then
		wall:SetAttribute("OneWay", true)
		wall:SetAttribute("InsideX", inside.X)
		wall:SetAttribute("InsideZ", inside.Z)
		wall:SetAttribute("PlaneX", mid.X)
		wall:SetAttribute("PlaneZ", mid.Z)
	end
end

local function lowTier(areaId: string): number
	return if areaId == "Volcano" then L.plateauHeight else L.beachHeight
end
local function highTier(areaId: string): number
	return if areaId == "Volcano" then L.highlandHeight else L.plateauHeight
end

local function gate(parent: Instance, areaId: string): GateInfo
	local g = L.gates[areaId]
	local def = Areas.Defs[areaId]
	local w = L.gateWidth
	local model = Instance.new("Model")
	model.Name = areaId .. "Gate"
	local areaColor = hex(AREA_COLORS[areaId])
	local stone, stoneDark = hex(STONE[areaId][1]), hex(STONE[areaId][2])

	-- Real ground at the foot of the gate and at the top of the canyon.
	local footZ = g.z + 6
	local groundY = Kit.medianGround({
		Vector2.new(g.x - 6, footZ),
		Vector2.new(g.x, footZ),
		Vector2.new(g.x + 6, footZ),
		Vector2.new(g.x, footZ + 6),
	}, lowTier(areaId))
	local topZ = g.z - L.rampLength - 8
	local topY = Kit.medianGround({
		Vector2.new(g.x - 6, topZ),
		Vector2.new(g.x, topZ),
		Vector2.new(g.x + 6, topZ),
		Vector2.new(g.x, topZ - 6),
	}, highTier(areaId))

	-- Gateway: two tall stone towers with stepped caps and glowing orbs.
	for _, side in { -1, 1 } do
		local x = g.x + side * (w / 2 + 2.6)
		part(model, {
			name = "GatePillar",
			size = Vector3.new(5.2, 26, 5.2),
			cframe = CFrame.new(x, groundY + 11, g.z),
			color = stone,
			material = Enum.Material.Cobblestone,
		})
		part(model, {
			name = "GatePillarBase",
			size = Vector3.new(7, 3, 7),
			cframe = CFrame.new(x, groundY + 0.5, g.z),
			color = stoneDark,
			material = Enum.Material.Cobblestone,
		})
		part(model, {
			name = "GatePillarCap",
			size = Vector3.new(6.6, 1.6, 6.6),
			cframe = CFrame.new(x, groundY + 24.6, g.z),
			color = stoneDark,
			material = Enum.Material.Cobblestone,
		})
		local orb = part(model, {
			name = "GateOrb",
			shape = Enum.PartType.Ball,
			size = Vector3.new(3.6, 3.6, 3.6),
			cframe = CFrame.new(x, groundY + 27.4, g.z),
			color = areaColor,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		Kit.light(orb, areaColor, 22, 2)
		-- Banners hanging on the inner faces.
		part(model, {
			name = "GateBanner",
			size = Vector3.new(0.2, 9, 3.4),
			cframe = CFrame.new(x - side * 2.75, groundY + 15, g.z + 1.2),
			color = areaColor,
			material = Enum.Material.Fabric,
			canCollide = false,
			castShadow = false,
		})
	end
	part(model, {
		name = "GateLintel",
		size = Vector3.new(w + 12, 3.4, 5.6),
		cframe = CFrame.new(g.x, groundY + 22.4, g.z),
		color = stoneDark,
		material = Enum.Material.Cobblestone,
	})
	local barrier = part(model, {
		name = "Barrier",
		size = Vector3.new(w + 0.5, 21, 1.5),
		cframe = CFrame.new(g.x, groundY + 10, g.z),
		color = areaColor,
		material = Enum.Material.ForceField,
		transparency = 0.1,
		castShadow = false,
	})
	barrier:SetAttribute("AreaId", areaId)

	-- A solid ramp up through the canyon, edged with stone curbs.
	local low = Vector3.new(g.x, groundY, g.z + 2)
	local high = Vector3.new(g.x, topY, topZ + 4)
	local rampColor = if areaId == "Jungle"
		then hex("#8A7350")
		elseif areaId == "Ruins" then hex("#CDB07A")
		else hex("#4E4446")
	Kit.ramp(model, low, high, w + 4, groundY - 1.2, {
		name = "Ramp",
		color = rampColor,
		material = if areaId == "Ruins" then Enum.Material.Sandstone else Enum.Material.Cobblestone,
	})
	-- A flat landing at the top so the ramp meets the ground cleanly.
	part(model, {
		name = "Landing",
		size = Vector3.new(w + 4, 2, 10),
		cframe = CFrame.new(g.x, topY - 0.9, topZ),
		color = rampColor,
		material = if areaId == "Ruins" then Enum.Material.Sandstone else Enum.Material.Cobblestone,
	})
	for _, side in { -1, 1 } do
		local x = g.x + side * (w / 2 + 2.6)
		local curbLow = Vector3.new(x, groundY + 0.6, g.z + 2)
		local curbHigh = Vector3.new(x, topY + 0.6, topZ + 4)
		local mid = (curbLow + curbHigh) / 2
		part(model, {
			name = "RampCurb",
			size = Vector3.new(1.4, 1.6, (curbHigh - curbLow).Magnitude),
			cframe = CFrame.lookAt(mid, curbHigh),
			color = stoneDark,
			material = Enum.Material.Cobblestone,
		})
		-- Torches up the ramp.
		for i = 1, 2 do
			local t = i / 3
			Kit.torch(model, curbLow:Lerp(curbHigh, t) + Vector3.new(side * 1.8, -0.6, 0))
		end
	end

	local shovelName = Progression.getShovel(def.requiredShovel).name
	local subtitle = if def.enabled
		then "Needs " .. shovelName
		else "Needs " .. shovelName .. " - opening soon!"
	Kit.billboard(barrier, string.upper(def.displayName), subtitle, areaColor, 19, 24)

	model.Parent = parent
	Kit.addObstacle(Vector3.new(g.x, groundY, g.z + 4), w / 2 + 8)
	return {
		areaId = areaId,
		barrier = barrier,
		safePoint = Vector3.new(g.x, groundY + 4, g.z + 14),
	}
end

-- A giant, half-buried glowing treasure behind a gate: the "something
-- amazing is in there" glimpse players see through the barrier.
local function glimpse(parent: Instance, areaId: string, treasureId: string, offset: Vector2, scale: number)
	local g = L.gates[areaId]
	local x, z = g.x + offset.X, g.z + offset.Y
	local groundY = Kit.groundOr(x, z, highTier(areaId))
	local model = TreasureBuilder.build(treasureId)
	model.Name = areaId .. "Glimpse"
	TreasureBuilder.scaleTo(model, scale)
	model:PivotTo(
		CFrame.new(x, groundY + scale * 0.3, z) * CFrame.Angles(math.rad(-12), math.rad(25), math.rad(10))
	)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = d.Transparency < 1
		end
	end
	Kit.light(model.PrimaryPart :: BasePart, hex(AREA_COLORS[areaId]), 34, 2.6)
	model.Parent = parent
	Kit.addObstacle(Vector3.new(x, groundY, z), scale * 1.6)
end

function Gates.build(): { [string]: GateInfo }
	local walls = Kit.folder("Walls", workspace)
	local gatesFolder = Kit.folder("Gates", workspace)
	local decor = workspace:FindFirstChild("Decor") or Kit.folder("Decor", workspace)
	local b = L.bounds
	local halfGate = L.gateWidth / 2 + 4

	-- Beach | plateau boundary (the cliff), open at the Jungle and Ruins gates.
	-- One-way: you enter through the gates, but can jump down to leave.
	local north = Vector3.new(0, 0, -1)
	local jx, rx = L.gates.Jungle.x, L.gates.Ruins.x
	local z = L.beachNorthZ
	invisibleWall(walls, Vector3.new(b.minX, 0, z), Vector3.new(jx - halfGate, 0, z), north)
	invisibleWall(walls, Vector3.new(jx + halfGate, 0, z), Vector3.new(rx - halfGate, 0, z), north)
	invisibleWall(walls, Vector3.new(rx + halfGate, 0, z), Vector3.new(b.maxX, 0, z), north)
	-- Volcano cliff, open at the Volcano gate (one-way too).
	local vx, vz = L.gates.Volcano.x, L.volcanoSouthZ
	invisibleWall(walls, Vector3.new(b.minX, 0, vz), Vector3.new(vx - halfGate, 0, vz), north)
	invisibleWall(walls, Vector3.new(vx + halfGate, 0, vz), Vector3.new(b.maxX, 0, vz), north)
	-- Canyon sides behind every gate.
	for _, g in L.gates do
		for _, side in { -1, 1 } do
			local x = g.x + side * halfGate
			invisibleWall(walls, Vector3.new(x, 0, g.z), Vector3.new(x, 0, g.z - L.rampLength - 4))
		end
	end
	-- Jungle | Ruins ridge: the Ruins (east) need the better shovel, so the
	-- ridge only stops people climbing from the Jungle into the Ruins.
	local ruinsSide = Vector3.new(if rx > L.jungleRuinsX then 1 else -1, 0, 0)
	invisibleWall(walls, Vector3.new(L.jungleRuinsX, 0, z), Vector3.new(L.jungleRuinsX, 0, vz), ruinsSide)
	-- Play-area limits.
	invisibleWall(walls, Vector3.new(b.minX, 0, b.minZ), Vector3.new(b.minX, 0, b.maxZ))
	invisibleWall(walls, Vector3.new(b.maxX, 0, b.minZ), Vector3.new(b.maxX, 0, b.maxZ))
	invisibleWall(walls, Vector3.new(b.minX, 0, b.minZ), Vector3.new(b.maxX, 0, b.minZ))
	invisibleWall(walls, Vector3.new(b.minX, 0, b.maxZ), Vector3.new(b.maxX, 0, b.maxZ))

	local gates = {}
	for _, areaId in { "Jungle", "Ruins", "Volcano" } do
		gates[areaId] = gate(gatesFolder, areaId)
	end

	glimpse(decor, "Jungle", "GoldenIdol", Vector2.new(14, -L.rampLength - 26), 7)
	glimpse(decor, "Ruins", "AncientStatue", Vector2.new(-18, -L.rampLength - 24), 7)
	glimpse(decor, "Volcano", "Meteorite", Vector2.new(-6, -L.rampLength - 24), 7)
	return gates
end

return Gates
