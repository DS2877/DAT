--!strict
-- The Beach: palm groves, a lighthouse on the east point, a shipwreck on
-- the west shore, a dock with a boat, a tiki bar, a campfire with people,
-- umbrellas and towels, a volleyball net, a lifeguard on his tower,
-- surfboards, sandcastles, tide-pool rocks and starfish, the waterfall from
-- the Jungle cliff, torch-lined paths to both gates with a signpost, buoys
-- and islets. Everything stands on the measured ground.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Drinks = require(ReplicatedStorage.Shared.Config.Drinks)
local Kit = require(script.Parent.Kit)

local L = Kit.L
local part, hex = Kit.part, Kit.hex

local Beach = {}

local WOOD = hex("#7A5230")
local WOOD_DARK = hex("#5B3A22")
local SAND = hex("#E9C98C")
local BRIGHT =
	{ hex("#FF5A5A"), hex("#FFD54A"), hex("#5CC8FF"), hex("#B45CFF"), hex("#5BE36B"), hex("#FF8A3D") }

local level = L.beachHeight

local function at(x: number, z: number): Vector3?
	return Kit.onLevel(x, z, level, 3.5)
end

local function shipwreck(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "Shipwreck"
	local function plank(size: Vector3, offset: CFrame, color: Color3?, material: Enum.Material?)
		return part(model, {
			size = size,
			cframe = origin * offset,
			color = color or WOOD,
			material = material or Enum.Material.WoodPlanks,
		})
	end
	-- Hull: keel, two tilted sides, a broken bow and the stern cabin.
	plank(Vector3.new(14, 3, 34), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(16)))
	plank(Vector3.new(1.4, 9, 32), CFrame.new(-7, 4, 0) * CFrame.Angles(0, 0, math.rad(26)), WOOD_DARK)
	plank(Vector3.new(1.4, 5, 20), CFrame.new(7, 2, 5) * CFrame.Angles(0, 0, math.rad(-6)), WOOD_DARK)
	plank(Vector3.new(12, 9, 1.4), CFrame.new(0, 4, 16) * CFrame.Angles(math.rad(-8), 0, math.rad(16)))
	plank(Vector3.new(10, 7, 8), CFrame.new(-1, 7, 12) * CFrame.Angles(0, 0, math.rad(16)), hex("#8A6038"))
	plank(
		Vector3.new(2, 1.6, 2),
		CFrame.new(-3, 9, 7.8) * CFrame.Angles(0, 0, math.rad(16)),
		hex("#FFD27A"),
		Enum.Material.Neon
	)
	-- Broken masts and a torn sail.
	plank(
		Vector3.new(1.4, 26, 1.4),
		CFrame.new(0, 14, -4) * CFrame.Angles(math.rad(8), 0, math.rad(-22)),
		WOOD_DARK,
		Enum.Material.Wood
	)
	plank(
		Vector3.new(1.2, 14, 1.2),
		CFrame.new(2, 6, -14) * CFrame.Angles(math.rad(-30), 0, math.rad(40)),
		WOOD_DARK,
		Enum.Material.Wood
	)
	part(model, {
		name = "Sail",
		size = Vector3.new(0.3, 11, 12),
		cframe = origin * CFrame.new(-4, 17, -4) * CFrame.Angles(math.rad(8), 0, math.rad(-22)),
		color = hex("#F2E6C9"),
		material = Enum.Material.Fabric,
		canCollide = false,
	})
	part(model, {
		name = "Flag",
		size = Vector3.new(0.2, 3, 4.5),
		cframe = origin * CFrame.new(-5.5, 26, -6.5) * CFrame.Angles(math.rad(8), 0, math.rad(-22)),
		color = hex("#1E1E24"),
		material = Enum.Material.Fabric,
		canCollide = false,
	})
	-- Spilled treasure chest, barrels and gold.
	local chest = part(model, {
		name = "Chest",
		size = Vector3.new(4.4, 2.8, 3),
		cframe = origin * CFrame.new(11, 0.2, -6) * CFrame.Angles(0, 0.5, 0.15),
		color = hex("#8B5A2B"),
		material = Enum.Material.WoodPlanks,
	})
	Kit.ellipsoid(model, {
		name = "Gold",
		size = Vector3.new(3.6, 1.6, 2.4),
		cframe = chest.CFrame * CFrame.new(0, 1.4, 0),
		color = hex("#FFD54A"),
		material = Enum.Material.Metal,
		canCollide = false,
	})
	for i = 1, 3 do
		part(model, {
			name = "Barrel",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(3, 2.4, 2.4),
			cframe = origin
				* CFrame.new(9 + i * 2.2, -0.2, 6 + i)
				* CFrame.Angles(0, i, math.rad(90 * (i % 2))),
			color = hex("#8B5A2B"),
			material = Enum.Material.Wood,
		})
	end
	model.Parent = parent
	Kit.addObstacle(origin.Position, 22)
end

local function lighthouse(parent: Instance, base: Vector3)
	local model = Instance.new("Model")
	model.Name = "Lighthouse"
	-- Rocky foot.
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		Kit.ellipsoid(model, {
			name = "Rock",
			size = Vector3.new(8, 5, 7),
			cframe = CFrame.new(base + Vector3.new(math.cos(a) * 7, 0.5, math.sin(a) * 7))
				* CFrame.Angles(0, a, 0.2),
			color = hex("#8E8A86"),
			material = Enum.Material.Slate,
		})
	end
	-- Striped tower, tapering.
	local h = 0
	for i = 1, 8 do
		local radius = 7.5 - i * 0.45
		part(model, {
			name = "Tower",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(6, radius * 2, radius * 2),
			cframe = CFrame.new(base + Vector3.new(0, h + 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			color = if i % 2 == 0 then hex("#E2423A") else hex("#F7F4EE"),
			material = Enum.Material.SmoothPlastic,
		})
		h += 6
	end
	part(model, {
		name = "Gallery",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1, 11, 11),
		cframe = CFrame.new(base + Vector3.new(0, h + 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#2E2A2A"),
		material = Enum.Material.Metal,
	})
	local lamp = part(model, {
		name = "Lamp",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(5, 6, 6),
		cframe = CFrame.new(base + Vector3.new(0, h + 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#FFF2B0"),
		material = Enum.Material.Neon,
	})
	Kit.light(lamp, hex("#FFF2B0"), 40, 2)
	Kit.ellipsoid(model, {
		name = "Cap",
		size = Vector3.new(8, 6, 8),
		cframe = CFrame.new(base + Vector3.new(0, h + 6.4, 0)),
		color = hex("#E2423A"),
		material = Enum.Material.SmoothPlastic,
	})
	-- A rotating light beam (spun by the client).
	local beam = part(model, {
		name = "Beam",
		size = Vector3.new(3, 3, 60),
		cframe = CFrame.new(base + Vector3.new(0, h + 3.5, 0)) * CFrame.new(0, 0, -30),
		color = hex("#FFF6C8"),
		material = Enum.Material.Neon,
		transparency = 0.82,
		canCollide = false,
		castShadow = false,
	})
	beam:SetAttribute("Ambient", "Beam")
	beam:SetAttribute("Pivot", base + Vector3.new(0, h + 3.5, 0))
	-- Door.
	part(model, {
		name = "Door",
		size = Vector3.new(3, 5, 0.4),
		cframe = CFrame.new(base + Vector3.new(0, 2.5, 7.2)),
		color = hex("#5B3A22"),
		material = Enum.Material.WoodPlanks,
	})
	model.Parent = parent
	Kit.addObstacle(base, 15)
end

local function dock(parent: Instance, start: Vector3, length: number)
	local model = Instance.new("Model")
	model.Name = "Dock"
	local y = math.max(start.Y + 0.4, 2.6)
	for i = 0, math.floor(length / 2) do
		local z = start.Z + i * 2
		part(model, {
			name = "Plank",
			size = Vector3.new(9, 0.5, 1.8),
			cframe = CFrame.new(start.X, y, z) * CFrame.Angles(0, (i % 3 - 1) * 0.02, 0),
			color = if i % 2 == 0 then hex("#B07A48") else hex("#A06E40"),
			material = Enum.Material.WoodPlanks,
		})
		if i % 4 == 0 then
			for _, dx in { -4.6, 4.6 } do
				part(model, {
					name = "DockPost",
					shape = Enum.PartType.Cylinder,
					size = Vector3.new(12, 1, 1),
					cframe = CFrame.new(start.X + dx, y - 4, z) * CFrame.Angles(0, 0, math.rad(90)),
					color = WOOD_DARK,
					material = Enum.Material.Wood,
				})
			end
		end
	end
	-- A little sailing boat moored at the end.
	local boat = CFrame.new(start.X + 9, 0.6, start.Z + length - 6)
	part(model, {
		name = "Hull",
		size = Vector3.new(6, 2.2, 13),
		cframe = boat,
		color = hex("#E25B45"),
		material = Enum.Material.WoodPlanks,
	})
	part(model, {
		name = "HullTrim",
		size = Vector3.new(6.2, 0.4, 13.2),
		cframe = boat * CFrame.new(0, 1.1, 0),
		color = Color3.new(1, 1, 1),
		material = Enum.Material.WoodPlanks,
	})
	part(model, {
		name = "Bow",
		className = "WedgePart",
		size = Vector3.new(6, 2.2, 4),
		cframe = boat * CFrame.new(0, 0, -8.5) * CFrame.Angles(0, math.rad(180), 0),
		color = hex("#E25B45"),
		material = Enum.Material.WoodPlanks,
	})
	part(model, {
		name = "Mast",
		size = Vector3.new(0.6, 12, 0.6),
		cframe = boat * CFrame.new(0, 6.5, -1),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
	})
	part(model, {
		name = "Sail",
		className = "WedgePart",
		size = Vector3.new(0.2, 9, 6),
		cframe = boat * CFrame.new(0, 7, 2.2),
		color = hex("#FFF4D6"),
		material = Enum.Material.Fabric,
		canCollide = false,
	})
	-- Crates and a fisherman at the end of the dock.
	for i = 1, 3 do
		part(model, {
			name = "Crate",
			size = Vector3.new(2.4, 2.4, 2.4),
			cframe = CFrame.new(
				start.X - 2.5,
				y + 1.45 + (if i == 3 then 2.4 else 0),
				start.Z + 8 + (i % 2) * 2.6
			) * CFrame.Angles(0, i * 0.4, 0),
			color = hex("#B98A55"),
			material = Enum.Material.WoodPlanks,
		})
	end
	Kit.person(
		model,
		CFrame.new(start.X + 2.6, y + 0.25, start.Z + length - 2) * CFrame.Angles(0, math.rad(-90), 0),
		{ shirt = hex("#3F7FD6"), pants = hex("#2E3A55"), hat = "Straw" },
		"Fisherman"
	)
	part(model, {
		name = "FishingRod",
		size = Vector3.new(0.2, 0.2, 9),
		cframe = CFrame.new(start.X + 6.5, y + 4.5, start.Z + length - 2)
			* CFrame.Angles(math.rad(25), math.rad(-90), 0),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
		canCollide = false,
	})
	model.Parent = parent
end

local function umbrella(parent: Instance, base: Vector3, rng: Random, withPerson: boolean)
	local color = BRIGHT[rng:NextInteger(1, #BRIGHT)]
	part(parent, {
		name = "UmbrellaPole",
		size = Vector3.new(0.35, 8, 0.35),
		cframe = CFrame.new(base + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0.08, 0, 0.05),
		color = Color3.new(1, 1, 1),
	})
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		part(parent, {
			name = "Canopy",
			className = "WedgePart",
			size = Vector3.new(0.2, 1.5, 4.6),
			cframe = CFrame.new(base + Vector3.new(0, 7.8, 0))
				* CFrame.Angles(0, a, 0)
				* CFrame.new(0, -0.5, -2.3)
				* CFrame.Angles(math.rad(-18), 0, 0),
			color = if i % 2 == 0 then Color3.new(1, 1, 1) else color,
			material = Enum.Material.Fabric,
			canCollide = false,
		})
	end
	local towelCf = CFrame.new(base + Vector3.new(3.4, 0.08, 1.2))
		* CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
	part(parent, {
		name = "Towel",
		size = Vector3.new(3.2, 0.15, 6),
		cframe = towelCf,
		color = BRIGHT[rng:NextInteger(1, #BRIGHT)],
		material = Enum.Material.Fabric,
		canCollide = false,
		castShadow = false,
	})
	if withPerson then
		-- Sunbathing: a person lying on the towel.
		Kit.person(
			parent,
			towelCf * CFrame.new(0, 0.6, 0) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, -2.6, 0),
			{ shirt = BRIGHT[rng:NextInteger(1, #BRIGHT)], pants = hex("#2E5AA8"), skin = hex("#E8B98A") },
			"Sunbather"
		)
	end
	local ball = part(parent, {
		name = "BeachBall",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.8, 1.8, 1.8),
		cframe = CFrame.new(base + Vector3.new(-2.6, 0.9, 2.6)),
		color = Color3.new(1, 1, 1),
	})
	Kit.ellipsoid(parent, {
		name = "BallStripe",
		size = Vector3.new(1.84, 1.84, 0.7),
		cframe = ball.CFrame,
		color = hex("#FF5A5A"),
		canCollide = false,
	})
	Kit.addObstacle(base, 6)
end

local function sandcastle(parent: Instance, base: Vector3)
	part(parent, {
		name = "Castle",
		size = Vector3.new(5, 2.4, 5),
		cframe = CFrame.new(base + Vector3.new(0, 1, 0)),
		color = SAND,
		material = Enum.Material.Sand,
	})
	for _, c in { { -2.5, -2.5 }, { 2.5, -2.5 }, { -2.5, 2.5 }, { 2.5, 2.5 } } do
		part(parent, {
			name = "Tower",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(4, 1.8, 1.8),
			cframe = CFrame.new(base + Vector3.new(c[1], 1.8, c[2])) * CFrame.Angles(0, 0, math.rad(90)),
			color = SAND,
			material = Enum.Material.Sand,
		})
	end
	part(parent, {
		name = "Keep",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(5, 2.4, 2.4),
		cframe = CFrame.new(base + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = SAND,
		material = Enum.Material.Sand,
	})
	part(parent, {
		name = "Flag",
		size = Vector3.new(0.1, 0.8, 1.2),
		cframe = CFrame.new(base + Vector3.new(0, 6.6, 0.6)),
		color = hex("#FF5A5A"),
		canCollide = false,
	})
	part(parent, {
		name = "FlagPole",
		size = Vector3.new(0.15, 2.4, 0.15),
		cframe = CFrame.new(base + Vector3.new(0, 6, 0)),
		color = Color3.new(1, 1, 1),
		canCollide = false,
	})
	-- A bucket and spade.
	part(parent, {
		name = "Bucket",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.4, 1.4, 1.4),
		cframe = CFrame.new(base + Vector3.new(4, 0.6, 1)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#5CC8FF"),
	})
	Kit.addObstacle(base, 5)
end

local function lifeguardTower(parent: Instance, base: Vector3)
	for _, c in { { -2.4, -2.4 }, { 2.4, -2.4 }, { -2.4, 2.4 }, { 2.4, 2.4 } } do
		part(parent, {
			name = "Leg",
			size = Vector3.new(0.7, 10, 0.7),
			cframe = CFrame.new(base + Vector3.new(c[1], 4.5, c[2])),
			color = Color3.new(1, 1, 1),
			material = Enum.Material.WoodPlanks,
		})
	end
	part(parent, {
		name = "Platform",
		size = Vector3.new(6.5, 0.6, 6.5),
		cframe = CFrame.new(base + Vector3.new(0, 9, 0)),
		color = hex("#FF5A5A"),
		material = Enum.Material.WoodPlanks,
	})
	part(parent, {
		name = "Roof",
		className = "WedgePart",
		size = Vector3.new(7.5, 2, 7.5),
		cframe = CFrame.new(base + Vector3.new(0, 15, 0)),
		color = hex("#FF5A5A"),
		material = Enum.Material.Fabric,
	})
	for _, c in { { -3.1, -3.1 }, { 3.1, -3.1 }, { -3.1, 3.1 }, { 3.1, 3.1 } } do
		part(parent, {
			name = "RoofPost",
			size = Vector3.new(0.4, 5, 0.4),
			cframe = CFrame.new(base + Vector3.new(c[1], 11.6, c[2])),
			color = Color3.new(1, 1, 1),
		})
	end
	-- Ladder.
	for i = 1, 6 do
		part(parent, {
			name = "Rung",
			size = Vector3.new(2.4, 0.3, 0.3),
			cframe = CFrame.new(base + Vector3.new(0, i * 1.4, -3.6)),
			color = Color3.new(1, 1, 1),
		})
	end
	Kit.person(parent, CFrame.new(base + Vector3.new(0, 9.3, 0.6)) * CFrame.Angles(0, math.rad(180), 0), {
		shirt = hex("#E2423A"),
		pants = hex("#E2423A"),
		skin = hex("#D9A27A"),
		hat = "Bandana",
		hatColor = hex("#FFD54A"),
	}, "Lifeguard")
	Kit.addObstacle(base, 6)
end

-- The Tiki Bar: also the drinks shop. Returns its pad (Station = "Drinks").
local function tikiBar(parent: Instance, base: Vector3, rng: Random): BasePart
	local model = Instance.new("Model")
	model.Name = "TikiBar"
	for _, c in { { -6, -4 }, { 6, -4 }, { -6, 4 }, { 6, 4 } } do
		part(model, {
			name = "Post",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(10, 1, 1),
			cframe = CFrame.new(base + Vector3.new(c[1], 5, c[2])) * CFrame.Angles(0, 0, math.rad(90)),
			color = hex("#9C7447"),
			material = Enum.Material.Wood,
		})
	end
	-- Thatched roof: layered straw wedges.
	for _, side in { -1, 1 } do
		part(model, {
			name = "Thatch",
			className = "WedgePart",
			size = Vector3.new(16, 3.4, 6.5),
			cframe = CFrame.new(base + Vector3.new(0, 11.2, side * 3.25))
				* CFrame.Angles(0, if side > 0 then math.rad(180) else 0, 0),
			color = hex("#D9B25C"),
			material = Enum.Material.Grass,
		})
	end
	part(model, {
		name = "Counter",
		size = Vector3.new(11, 3.6, 2),
		cframe = CFrame.new(base + Vector3.new(0, 1.8, -3)),
		color = hex("#8B5A2B"),
		material = Enum.Material.WoodPlanks,
	})
	part(model, {
		name = "CounterTop",
		size = Vector3.new(12, 0.4, 2.6),
		cframe = CFrame.new(base + Vector3.new(0, 3.8, -3)),
		color = hex("#5CC8FF"),
	})
	for i = -2, 2 do
		local cup = part(model, {
			name = "Coconut Drink",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.9, 0.9, 0.9),
			cframe = CFrame.new(base + Vector3.new(i * 2.2, 4.4, -3)),
			color = hex("#6B4A1F"),
			canCollide = false,
		})
		part(model, {
			name = "Straw",
			size = Vector3.new(0.1, 1, 0.1),
			cframe = cup.CFrame * CFrame.new(0.1, 0.6, 0) * CFrame.Angles(0, 0, 0.3),
			color = BRIGHT[(i + 3) % #BRIGHT + 1],
			canCollide = false,
			castShadow = false,
		})
	end
	for i = -2, 2, 2 do
		part(model, {
			name = "Stool",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(2.6, 1.6, 1.6),
			cframe = CFrame.new(base + Vector3.new(i * 2, 1.3, -6)) * CFrame.Angles(0, 0, math.rad(90)),
			color = hex("#9C7447"),
			material = Enum.Material.Wood,
		})
	end
	Kit.person(model, CFrame.new(base + Vector3.new(0, 0, 0.5)), {
		shirt = hex("#FF8A3D"),
		pants = hex("#3A3A4A"),
		hat = "Straw",
	}, "Bartender")
	local sign = part(model, {
		name = "TikiSign",
		size = Vector3.new(10, 2.2, 0.4),
		cframe = CFrame.new(base + Vector3.new(0, 8.6, -4.4)),
		color = hex("#7A5230"),
		material = Enum.Material.WoodPlanks,
	})
	Kit.signText(sign, "TIKI DRINKS", hex("#FFD54A"), nil, { Enum.NormalId.Front })
	-- Walk onto the pad in front of the stools to open the drinks menu.
	local pad = part(model, {
		name = "TikiPad",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, Drinks.stationRadius * 1.6, Drinks.stationRadius * 1.6),
		cframe = CFrame.new(base + Vector3.new(0, 0.15, -11)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#FF8A3D"),
		material = Enum.Material.Neon,
		transparency = 0.35,
		canCollide = false,
		castShadow = false,
	})
	pad:SetAttribute("Station", "Drinks")
	pad:SetAttribute("Radius", Drinks.stationRadius)
	-- A wooden sign beside the pad, facing the base.
	local signAt = base + Vector3.new(Drinks.stationRadius + 3, 0, -11)
	Kit.standingSign(
		parent,
		Vector3.new(signAt.X, Kit.groundOr(signAt.X, signAt.Z, level), signAt.Z),
		Vector3.xAxis,
		"TIKI BAR",
		"Drinks: 5-minute boosts",
		hex("#FFD54A"),
		9
	)
	local _ = rng
	model.Parent = parent
	Kit.addObstacle(base, 10)
	Kit.addObstacle(pad.Position, Drinks.stationRadius + 2)
	return pad
end

local function campfire(parent: Instance, base: Vector3, rng: Random)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		Kit.ellipsoid(parent, {
			name = "FireStone",
			size = Vector3.new(1.4, 0.9, 1.2),
			cframe = CFrame.new(base + Vector3.new(math.cos(a) * 2.2, 0.3, math.sin(a) * 2.2)),
			color = hex("#7E7A76"),
			material = Enum.Material.Slate,
		})
	end
	for i = 1, 3 do
		part(parent, {
			name = "FireLog",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(3, 0.7, 0.7),
			cframe = CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, i * 1.05, math.rad(12)),
			color = hex("#5A3D24"),
			material = Enum.Material.Wood,
		})
	end
	local fireAnchor =
		Kit.volume(parent, "Campfire", CFrame.new(base + Vector3.new(0, 0.8, 0)), Vector3.new(1, 1, 1))
	Kit.fire(fireAnchor, 4)
	Kit.light(fireAnchor, Color3.fromRGB(255, 160, 70), 20, 2)
	-- Log seats with people around the fire.
	for i, a in { 0.4, 2.6, 4.6 } do
		local seat = base + Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6)
		part(parent, {
			name = "SeatLog",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(5, 1.6, 1.6),
			cframe = CFrame.lookAt(seat + Vector3.new(0, 0.7, 0), base + Vector3.new(0, 0.7, 0))
				* CFrame.Angles(0, math.rad(90), 0),
			color = hex("#6B4A2B"),
			material = Enum.Material.Wood,
		})
		if i <= 2 then
			Kit.person(
				parent,
				CFrame.lookAt(seat + Vector3.new(0, 0.2, 0), Vector3.new(base.X, seat.Y + 0.2, base.Z)),
				{
					shirt = BRIGHT[rng:NextInteger(1, #BRIGHT)],
					pants = hex("#4A3A2A"),
					hat = if i == 1 then "Explorer" else nil,
				},
				"Camper"
			)
		end
	end
	Kit.addObstacle(base, 9)
end

local function volleyball(parent: Instance, base: Vector3)
	for _, dx in { -8, 8 } do
		part(parent, {
			name = "NetPole",
			size = Vector3.new(0.5, 9, 0.5),
			cframe = CFrame.new(base + Vector3.new(dx, 4.5, 0)),
			color = Color3.new(1, 1, 1),
		})
	end
	part(parent, {
		name = "Net",
		size = Vector3.new(16, 2.4, 0.1),
		cframe = CFrame.new(base + Vector3.new(0, 7.4, 0)),
		color = Color3.new(1, 1, 1),
		material = Enum.Material.Fabric,
		transparency = 0.35,
		canCollide = false,
	})
	part(parent, {
		name = "Volleyball",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.6, 1.6, 1.6),
		cframe = CFrame.new(base + Vector3.new(3, 0.8, 5)),
		color = hex("#FFD54A"),
	})
	Kit.addObstacle(base, 9)
end

local function surfboards(parent: Instance, base: Vector3)
	for i = 1, 3 do
		Kit.ellipsoid(parent, {
			name = "Surfboard",
			size = Vector3.new(2.2, 9, 0.5),
			cframe = CFrame.new(base + Vector3.new(i * 2.8, 3.6, 0))
				* CFrame.Angles(math.rad(-8), 0, math.rad((i - 2) * 9)),
			color = BRIGHT[i * 2 - 1],
			material = Enum.Material.SmoothPlastic,
		})
	end
	Kit.addObstacle(base + Vector3.new(5, 0, 0), 5)
end

local function starfish(parent: Instance, base: Vector3, color: Color3)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		part(parent, {
			name = "Starfish",
			size = Vector3.new(0.5, 0.2, 1.4),
			cframe = CFrame.new(base + Vector3.new(0, 0.1, 0))
				* CFrame.Angles(0, a, 0)
				* CFrame.new(0, 0, -0.6),
			color = color,
			canCollide = false,
			castShadow = false,
		})
	end
end

local function beachGrass(parent: Instance, base: Vector3, rng: Random)
	for i = 1, 5 do
		part(parent, {
			name = "BeachGrass",
			className = "WedgePart",
			size = Vector3.new(0.2, rng:NextNumber(1.6, 2.8), 0.9),
			cframe = CFrame.new(
				base + Vector3.new(rng:NextNumber(-0.8, 0.8), 0.9, rng:NextNumber(-0.8, 0.8))
			) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), i * 1.2, rng:NextNumber(-0.3, 0.3)),
			color = if i % 2 == 0 then hex("#8DBF4E") else hex("#6FA83C"),
			material = Enum.Material.Grass,
			canCollide = false,
			castShadow = false,
		})
	end
end

local function waterfall(parent: Instance)
	local river = L.river
	local top = river[#river]
	local pool = L.beachPool
	local lipY = Kit.groundOr(top[1] + 10, top[2] - 6, L.plateauHeight) - 1.5
	local poolY = Kit.surface(pool.x, pool.z) or L.beachHeight
	local height = lipY - poolY + 1
	for i, w in { 13, 9 } do
		local sheet = part(parent, {
			name = "Waterfall",
			size = Vector3.new(w, height, 1.4 + i * 0.4),
			cframe = CFrame.new(top[1], poolY - 0.5 + height / 2, L.beachNorthZ + 1.2 - i * 0.3),
			color = if i == 1 then hex("#9FE6FF") else hex("#E6FAFF"),
			material = Enum.Material.Glass,
			transparency = if i == 1 then 0.3 else 0.55,
			canCollide = false,
			castShadow = false,
		})
		if i == 1 then
			Kit.emitter(sheet, {
				color = Color3.new(1, 1, 1),
				rate = 30,
				lifetime = NumberRange.new(0.8, 1.4),
				size = NumberSequence.new(1.2, 3.5),
				speed = NumberRange.new(10, 16),
				transparency = NumberSequence.new(0.5, 1),
				direction = Enum.NormalId.Bottom,
				spread = Vector2.new(8, 8),
			})
		end
	end
	local foam = Kit.volume(
		parent,
		"WaterfallFoam",
		CFrame.new(top[1], poolY + 1, L.beachNorthZ + 5),
		Vector3.new(14, 1, 6)
	)
	Kit.emitter(foam, {
		color = Color3.new(1, 1, 1),
		rate = 26,
		lifetime = NumberRange.new(1, 2),
		size = NumberSequence.new(2, 5),
		speed = NumberRange.new(2, 5),
		transparency = NumberSequence.new(0.45, 1),
		spread = Vector2.new(70, 70),
	})
	Kit.addObstacle(Vector3.new(pool.x, 0, pool.z), pool.radius + 4)
end

-- A path's torches and the signpost at the fork.
local function pathTorches(parent: Instance)
	for _, line in L.paths.Beach do
		for i = 1, #line - 1 do
			local a, b =
				Vector3.new(line[i][1], 0, line[i][2]), Vector3.new(line[i + 1][1], 0, line[i + 1][2])
			local dir = (b - a).Unit
			local side = Vector3.new(-dir.Z, 0, dir.X)
			local length = (b - a).Magnitude
			local count = math.floor(length / 24)
			for k = 1, count do
				local p = a + dir * (k * length / (count + 1)) + side * 6.5 * (if k % 2 == 0 then 1 else -1)
				local ground = Kit.groundY(p.X, p.Z)
				if ground then
					Kit.torch(parent, Vector3.new(p.X, ground, p.Z))
				end
			end
		end
	end
	local fork = L.paths.Beach[1][2]
	local base = Vector3.new(fork[1] + 7, Kit.groundOr(fork[1] + 7, fork[2], level), fork[2])
	part(parent, {
		name = "SignPost",
		size = Vector3.new(0.9, 12, 0.9),
		cframe = CFrame.new(base + Vector3.new(0, 5, 0)),
		color = WOOD,
		material = Enum.Material.Wood,
	})
	-- One board per destination, fixed to the side of the post and pointing
	-- at it (with an arrow tip), so the post never covers the text and both
	-- faces read from either side of the path.
	local sell = L.sellPad
	for _, s in
		{
			{ "JUNGLE", L.gates.Jungle.x, L.gates.Jungle.z, "#56C451", 9.6 },
			{ "RUINS", L.gates.Ruins.x, L.gates.Ruins.z, "#4FD1C5", 7.4 },
			{ "SELL", sell.x, sell.z, "#FFD54A", 5.2 },
		}
	do
		local toward = Vector3.new((s[2] :: number) - base.X, 0, (s[3] :: number) - base.Z).Unit
		local length = 7
		local center = base + Vector3.new(0, s[5] :: number, 0) + toward * (length / 2 + 0.55)
		local frame = CFrame.fromMatrix(center, toward, Vector3.yAxis)
		local board = part(parent, {
			name = "SignBoard",
			size = Vector3.new(length, 1.8, 0.4),
			cframe = frame,
			color = hex("#A06E40"),
			material = Enum.Material.WoodPlanks,
		})
		part(parent, {
			name = "SignTip",
			size = Vector3.new(1.27, 1.27, 0.4),
			cframe = frame * CFrame.new(length / 2, 0, 0) * CFrame.Angles(0, 0, math.rad(45)),
			color = hex("#A06E40"),
			material = Enum.Material.WoodPlanks,
		})
		Kit.signText(board, s[1] :: string, hex(s[4] :: string))
	end
	Kit.addObstacle(base, 4)
end

export type BeachInfo = { tikiPad: BasePart? }

function Beach.build(rng: Random): BeachInfo
	local decor = Kit.folder("Beach", workspace:FindFirstChild("Decor") or Kit.folder("Decor", workspace))
	level = Kit.medianGround({
		Vector2.new(-60, 100),
		Vector2.new(60, 100),
		Vector2.new(0, 120),
		Vector2.new(-100, 60),
		Vector2.new(100, 60),
		Vector2.new(0, 30),
		Vector2.new(-140, 160),
		Vector2.new(140, 160),
	}, L.beachHeight)

	-- Palms: a ring near the shore, groves, and a few framing the base.
	local b = L.beach
	for i = 1, 56 do
		local angle = (i / 56) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local dist = b.radius - rng:NextNumber(8, 22)
		local p = at(b.x + math.cos(angle) * dist, b.z + math.sin(angle) * dist)
		if p and p.Z > L.beachNorthZ + 16 then
			Kit.palm(decor, p, rng)
		end
	end
	for _, grove in
		{
			{ -150, 110 },
			{ 150, 120 },
			{ -130, 20 },
			{ 140, 16 },
			{ -70, 120 },
			{ 76, 116 },
			{ -50, 300 },
			{ 60, 300 },
			{ 180, 220 },
			{ -176, 220 },
			{ -200, 80 },
			{ 214, 110 },
			{ -30, 40 },
			{ 40, 50 },
		}
	do
		for _ = 1, rng:NextInteger(3, 5) do
			local p = at(grove[1] + rng:NextNumber(-12, 12), grove[2] + rng:NextNumber(-12, 12))
			if p then
				Kit.palm(decor, p, rng, rng:NextInteger(6, 9))
			end
		end
	end
	for _, c in { { -62, 158 }, { 62, 158 }, { -62, 244 }, { 62, 244 }, { -24, 250 }, { 24, 250 } } do
		local p = at(c[1], c[2])
		if p then
			Kit.palm(decor, p, rng, 8)
		end
	end

	-- Landmarks.
	local lhx, lhz = 232, 76
	lighthouse(decor, Vector3.new(lhx, Kit.groundOr(lhx, lhz, level), lhz))
	local swx, swz = -222, 34
	shipwreck(
		decor,
		CFrame.new(swx, Kit.groundOr(swx, swz, level) - 0.5, swz) * CFrame.Angles(0, math.rad(30), 0)
	)
	local dockStart = Vector3.new(104, 0, 318)
	local shoreY = Kit.groundOr(dockStart.X, dockStart.Z, level)
	dock(decor, Vector3.new(dockStart.X, shoreY, dockStart.Z), 60)
	local tiki = at(-118, 236)
	local tikiPad = if tiki then tikiBar(decor, tiki, rng) else nil
	local fire = at(-96, 284)
	if fire then
		campfire(decor, fire, rng)
	end
	local net = at(118, 238)
	if net then
		volleyball(decor, net)
	end
	local tower = at(160, 160)
	if tower then
		lifeguardTower(decor, tower)
	end
	for i, c in
		{
			{ 120, 280 },
			{ 150, 196 },
			{ -150, 176 },
			{ -130, 290 },
			{ 170, 260 },
			{ -60, 60 },
			{ 90, 60 },
			{ 30, 300 },
		}
	do
		local p = at(c[1], c[2])
		if p then
			umbrella(decor, p, rng, i % 2 == 1)
		end
	end
	for _, c in { { -80, 84 }, { 110, 140 }, { -24, 96 }, { 150, 300 }, { -170, 260 } } do
		local p = at(c[1], c[2])
		if p then
			sandcastle(decor, p)
		end
	end
	local boards = at(186, 236)
	if boards then
		surfboards(decor, boards)
	end
	waterfall(decor)
	pathTorches(decor)

	-- Crates and barrels by the shipwreck and the dock.
	for _, c in { { -196, 64 }, { 92, 312 } } do
		local p = at(c[1], c[2])
		if p then
			for i = 1, 4 do
				local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
				if i % 2 == 0 then
					part(decor, {
						name = "Barrel",
						shape = Enum.PartType.Cylinder,
						size = Vector3.new(2.8, 2.2, 2.2),
						cframe = CFrame.new(p + offset + Vector3.new(0, 1.2, 0))
							* CFrame.Angles(0, 0, math.rad(90)),
						color = hex("#8B5A2B"),
						material = Enum.Material.Wood,
					})
				else
					part(decor, {
						name = "Crate",
						size = Vector3.new(2.6, 2.6, 2.6),
						cframe = CFrame.new(p + offset + Vector3.new(0, 1.1, 0))
							* CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
						color = hex("#B98A55"),
						material = Enum.Material.WoodPlanks,
					})
				end
			end
			Kit.addObstacle(p, 6)
		end
	end

	-- Rocks along the cliff foot and the shoreline; starfish and beach grass.
	for _ = 1, 22 do
		local x = rng:NextNumber(-260, 260)
		local p = at(x, L.beachNorthZ + rng:NextNumber(4, 12))
		if p and math.abs(x - L.gates.Jungle.x) > 20 and math.abs(x - L.gates.Ruins.x) > 20 then
			Kit.rock(decor, p, rng:NextNumber(1, 2.2), rng, hex("#9A928A"))
		end
	end
	for _ = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = b.radius + rng:NextNumber(4, 14)
		local x, z = b.x + math.cos(angle) * dist, b.z + math.sin(angle) * dist
		local y = Kit.groundY(x, z)
		if y and z > L.beachNorthZ + 12 then
			Kit.rock(decor, Vector3.new(x, y, z), rng:NextNumber(0.9, 2), rng, hex("#8E8A86"))
		end
	end
	for _ = 1, 30 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = b.radius - rng:NextNumber(0, 6)
		local p = at(b.x + math.cos(angle) * dist, b.z + math.sin(angle) * dist)
		if p and p.Z > L.beachNorthZ + 10 then
			starfish(decor, p, BRIGHT[rng:NextInteger(1, #BRIGHT)])
		end
	end
	for _ = 1, 50 do
		local p = at(rng:NextNumber(-210, 210), rng:NextNumber(-10, 330))
		if p and not (p.X > -110 and p.X < 70 and p.Z > 140 and p.Z < 260) then
			beachGrass(decor, p, rng)
		end
	end

	-- Buoys out at sea (bobbed by the client).
	for _, c in { { -80, 400 }, { 40, 420 }, { 180, 380 }, { -260, 300 }, { 300, 220 }, { -320, 40 } } do
		local buoy = part(decor, {
			name = "Buoy",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(3, 2.4, 2.4),
			cframe = CFrame.new(c[1], 0.8, c[2]) * CFrame.Angles(0, 0, math.rad(90)),
			color = hex("#E2423A"),
			canCollide = false,
		})
		buoy:SetAttribute("Ambient", "Bob")
		part(decor, {
			name = "BuoyStripe",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.8, 2.5, 2.5),
			cframe = buoy.CFrame,
			color = Color3.new(1, 1, 1),
			canCollide = false,
		})
	end

	-- Palms on the islets.
	for _, c in { { -330, 120 }, { 340, -40 }, { 260, 360 }, { -280, 380 }, { -350, -160 } } do
		local y = Kit.groundY(c[1], c[2])
		if y and y > 0.5 then
			Kit.palm(decor, Vector3.new(c[1], y, c[2]), rng, 8)
			Kit.palm(decor, Vector3.new(c[1] + 5, y, c[2] + 3), rng, 6)
		end
	end

	return { tikiPad = tikiPad }
end

return Beach
