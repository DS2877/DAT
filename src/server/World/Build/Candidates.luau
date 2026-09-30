--!strict
-- Candidate points where dig spots may appear, per area: flat, bare,
-- walkable terrain inside the area, clear of props and water, including a
-- handful right in front of the base for a new player's first dig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DigConfig = require(ReplicatedStorage.Shared.Config.Dig)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Kit = require(script.Parent.Kit)

local L = Kit.L

local Candidates = {}

-- Surface hit straight down, ignoring walk-through decoration. Solid parts
-- (temple, trunks, rocks) block, so spots never land inside them.
local function surfaceAt(x: number, z: number): (Vector3?, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	params.RespectCanCollide = true
	params.IgnoreWater = false
	local result = workspace:Raycast(Vector3.new(x, 250, z), Vector3.new(0, -400, 0), params)
	if not result or result.Instance ~= workspace.Terrain then
		return nil, nil
	end
	return result.Position, result.Material
end

local BAD_MATERIALS = {
	[Enum.Material.Water] = true,
	[Enum.Material.CrackedLava] = true,
	[Enum.Material.Rock] = true,
	[Enum.Material.Slate] = true,
}

local function clearOfObstacles(x: number, z: number): boolean
	for _, obstacle in Kit.obstacles do
		local p = obstacle.position
		if Zones.flatDistance(x, z, p.X, p.Z) < obstacle.radius + 3.5 then
			return false
		end
	end
	return true
end

function Candidates.generate(areaId: string, rng: Random): { Vector3 }
	local rect = L.spotRegions[areaId]
	local target = DigConfig.candidateCount[areaId] or 60
	local points: { Vector3 } = {}
	local baseFront = Vector3.new((L.base.minX + L.base.maxX) / 2, 0, L.base.minZ)
	local groundY = if areaId == "Beach" then L.beachHeight else L.plateauHeight

	local function tryAdd(x: number, z: number): boolean
		if Zones.areaAt(x, z) ~= areaId or Zones.inRect(x, z, L.spotExclusion) then
			return false
		end
		if not clearOfObstacles(x, z) then
			return false
		end
		for _, other in points do
			if Zones.flatDistance(x, z, other.X, other.Z) < 6 then
				return false
			end
		end
		local surface, material = surfaceAt(x, z)
		if not surface or not material or BAD_MATERIALS[material] or surface.Y < L.waterLevel + 0.8 then
			return false
		end
		-- Only flat, walkable ground (not slopes, cliffs or ramps).
		if math.abs(surface.Y - groundY) > 3 then
			return false
		end
		table.insert(points, surface)
		return true
	end

	-- A handful right in front of the base so a new player digs within seconds.
	if areaId == "Beach" then
		local near = 0
		for _ = 1, 600 do
			if near >= DigConfig.nearSpawnCandidates then
				break
			end
			local angle = rng:NextNumber(math.pi * 1.1, math.pi * 1.9) -- the half facing north
			local dist = rng:NextNumber(DigConfig.nearSpawnMin, DigConfig.nearSpawnMax)
			if tryAdd(baseFront.X + math.cos(angle) * dist, baseFront.Z + math.sin(angle) * dist) then
				near += 1
			end
		end
	end

	for _ = 1, target * 40 do
		if #points >= target then
			break
		end
		tryAdd(rng:NextNumber(rect.minX, rect.maxX), rng:NextNumber(rect.minZ, rect.maxZ))
	end
	return points
end

return Candidates
