--!strict
-- Pure geometry helpers: which area a position belongs to.

local MapLayout = require(script.Parent.Parent.Config.MapLayout)

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

local Zones = {}

function Zones.areaAt(x: number, z: number): string
	if z > MapLayout.beachNorthZ then
		return "Beach"
	elseif z > MapLayout.volcanoSouthZ then
		return if x < MapLayout.jungleRuinsX then "Jungle" else "Ruins"
	end
	return "Volcano"
end

function Zones.inRect(x: number, z: number, rect: Rect): boolean
	return x >= rect.minX and x <= rect.maxX and z >= rect.minZ and z <= rect.maxZ
end

function Zones.inCircle(x: number, z: number, circle: { x: number, z: number, radius: number }): boolean
	local dx, dz = x - circle.x, z - circle.z
	return dx * dx + dz * dz <= circle.radius * circle.radius
end

-- Horizontal distance between two points.
function Zones.flatDistance(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

return Zones
