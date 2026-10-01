--!strict
-- Candidate points where dig spots may appear, per area: flat, bare,
-- walkable ground inside the area, clear of props and water, including a
-- handful right in front of the base for a new player's first dig.
--
-- "Flat" is judged against the area's own measured ground level (the
-- median of many raycasts), never against the layout's fill heights:
-- Roblox draws terrain a few studs above those, and a fixed comparison
-- would reject every point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DigConfig = require(ReplicatedStorage.Shared.Config.Dig)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Kit = require(script.Parent.Kit)

local L = Kit.L

local Candidates = {}

-- Surface hit straight down. Solid parts (temple, trunks, rocks) block, so
-- spots never land inside them; walk-through decoration is ignored.
local function surfaceAt(x: number, z: number): (Vector3?, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	params.RespectCanCollide = true
	params.IgnoreWater = false
	local result = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -700, 0), params)
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

-- The typical ground height of an area (median of good surface samples).
function Candidates.areaLevel(areaId: string, rng: Random): number?
	local rect = L.spotRegions[areaId]
	local heights = {}
	for _ = 1, 240 do
		local x, z = rng:NextNumber(rect.minX, rect.maxX), rng:NextNumber(rect.minZ, rect.maxZ)
		if Zones.areaAt(x, z) == areaId then
			local surface, material = surfaceAt(x, z)
			if surface and material and not BAD_MATERIALS[material] and surface.Y > L.waterLevel + 0.8 then
				table.insert(heights, surface.Y)
			end
		end
	end
	if #heights < 10 then
		return nil
	end
	table.sort(heights)
	return heights[math.floor((#heights + 1) / 2)]
end

function Candidates.generate(areaId: string, rng: Random): { Vector3 }
	local rect = L.spotRegions[areaId]
	local target = DigConfig.candidateCount[areaId] or 60
	local points: { Vector3 } = {}
	local baseFront = Vector3.new((L.base.minX + L.base.maxX) / 2, 0, L.base.minZ)
	local level = Candidates.areaLevel(areaId, rng)
	if not level then
		warn("[Candidates] no ground found for " .. areaId)
		return points
	end

	local function tryAdd(x: number, z: number): boolean
		if Zones.areaAt(x, z) ~= areaId or Zones.inRect(x, z, L.spotExclusion) then
			return false
		end
		if not Kit.clearOfObstacles(x, z, 3.5) then
			return false
		end
		for _, other in points do
			if Zones.flatDistance(x, z, other.X, other.Z) < DigConfig.minCandidateSpacing then
				return false
			end
		end
		local surface, material = surfaceAt(x, z)
		if not surface or not material or BAD_MATERIALS[material] or surface.Y < L.waterLevel + 0.8 then
			return false
		end
		-- Only ground near the area's level (not slopes, cliffs, ramps, dunes).
		if math.abs(surface.Y - level) > DigConfig.levelTolerance then
			return false
		end
		table.insert(points, surface)
		return true
	end

	-- A handful right in front of the base so a new player digs within seconds.
	if areaId == "Beach" then
		local near = 0
		for _ = 1, 800 do
			if near >= DigConfig.nearSpawnCandidates then
				break
			end
			local angle = rng:NextNumber(math.pi * 1.15, math.pi * 1.85) -- the half facing north
			local dist = rng:NextNumber(DigConfig.nearSpawnMin, DigConfig.nearSpawnMax)
			if tryAdd(baseFront.X + math.cos(angle) * dist, baseFront.Z + math.sin(angle) * dist) then
				near += 1
			end
		end
	end

	for _ = 1, target * 50 do
		if #points >= target then
			break
		end
		tryAdd(rng:NextNumber(rect.minX, rect.maxX), rng:NextNumber(rect.minZ, rect.maxZ))
	end
	return points
end

return Candidates
