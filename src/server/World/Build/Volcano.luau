--!strict
-- The Volcano: crater glow and smoke, glowing lava pools, steam vents,
-- obsidian spikes, dark boulders, and warm light along the lava rivers
-- (the rivers themselves are CrackedLava terrain, see Terrain.luau).

local Kit = require(script.Parent.Kit)

local L = Kit.L
local part, hex = Kit.part, Kit.hex

local Volcano = {}

local LAVA = hex("#FF6A1A")

local function lavaPool(parent: Instance, center: Vector3, radius: number)
	local pool = part(parent, {
		name = "LavaPool",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.4, radius * 2, radius * 2),
		cframe = CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = LAVA,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	part(parent, {
		name = "LavaRim",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.6, radius * 2 + 2, radius * 2 + 2),
		cframe = CFrame.new(center + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#2A2224"),
		material = Enum.Material.Basalt,
		canCollide = false,
	})
	Kit.light(pool, LAVA, radius * 3, 2)
	Kit.addObstacle(center, radius + 3)
end

local function steamVent(parent: Instance, base: Vector3)
	local vent = part(parent, {
		name = "SteamVent",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.2, 2.4, 2.4),
		cframe = CFrame.new(base + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#2A2224"),
		material = Enum.Material.Basalt,
	})
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(210, 205, 200)
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 8
	smoke.Size = 4
	smoke.Parent = vent
	Kit.addObstacle(base, 3)
end

local function spike(parent: Instance, base: Vector3, rng: Random)
	local h = rng:NextNumber(4, 9)
	local s = Instance.new("WedgePart")
	s.Name = "Obsidian"
	s.Anchored = true
	s.Size = Vector3.new(rng:NextNumber(1.5, 2.5), h, rng:NextNumber(1.5, 3))
	s.CFrame = CFrame.new(base + Vector3.new(0, h / 2 - 0.5, 0))
		* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2))
	s.Color = hex("#1C1A24")
	s.Material = Enum.Material.Glass
	s.Reflectance = 0.2
	s.Parent = parent
	Kit.addObstacle(base, 2.5)
end

function Volcano.build(rng: Random)
	local decor = workspace:FindFirstChild("Decor") or Kit.folder("Decor", workspace)
	local y = L.plateauHeight
	local v = L.volcano

	-- Crater glow and smoke.
	local peak = Vector3.new(v.x, y + v.height - 11, v.z)
	local glow = part(decor, {
		name = "LavaGlow",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1, 22, 22),
		cframe = CFrame.new(peak) * CFrame.Angles(0, 0, math.rad(90)),
		color = LAVA,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	Kit.light(glow, LAVA, 60, 3)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(90, 85, 85)
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 12
	smoke.Size = 30
	smoke.TimeScale = 0.6
	smoke.Parent = glow
	local embers = Instance.new("Fire")
	embers.Size = 18
	embers.Heat = 20
	embers.Color = LAVA
	embers.SecondaryColor = hex("#FFD54A")
	embers.Parent = glow

	-- Warm light along the lava rivers.
	for _, river in L.lavaRivers do
		for i, p in river do
			if i % 2 == 1 then
				local anchor = part(decor, {
					name = "LavaLight",
					size = Vector3.new(0.4, 0.4, 0.4),
					cframe = CFrame.new(p[1], y + 1.5, p[2]),
					transparency = 1,
					canCollide = false,
				})
				Kit.light(anchor, LAVA, 18, 1.6)
			end
			Kit.addObstacle(Vector3.new(p[1], y, p[2]), 4)
		end
	end

	lavaPool(decor, Vector3.new(-62, y, -155), 5)
	lavaPool(decor, Vector3.new(62, y, -158), 4)
	for _, p in { { -40, -130 }, { 30, -150 }, { 70, -135 }, { -80, -152 } } do
		steamVent(decor, Vector3.new(p[1], y, p[2]))
	end

	for _ = 1, 30 do
		local x, z = rng:NextNumber(-100, 100), rng:NextNumber(-172, -126)
		local ground = Kit.groundY(x, z)
		if ground and math.abs(ground - y) < 3 then
			if rng:NextNumber() < 0.55 then
				Kit.rock(decor, Vector3.new(x, ground, z), rng:NextNumber(0.8, 1.7), rng, hex("#3A3232"))
			else
				spike(decor, Vector3.new(x, ground, z), rng)
			end
		end
	end
end

return Volcano
