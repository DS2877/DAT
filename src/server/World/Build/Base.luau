--!strict
-- The base: a raised wooden plaza on the beach with a golden SELL pavilion
-- at the entrance, a shovel shop and a bag shop (stalls with counters,
-- shopkeepers and signs on their facades), a trophy stand and three
-- leaderboard boards along the back, the rebirth temple on the sand, an
-- entrance arch, lanterns, bunting and planters.
--
-- The deck height is measured from the real sand around it (terrain sits a
-- few studs higher in Roblox than its fill heights suggest) and the sand
-- under the deck is cleared, so nothing gets buried.
--
-- Names and attributes read by other code: Base.SellPad, the station pads
-- (attribute Station = "Shovel" / "Bag" / "Rebirth", Radius), and the
-- Board_<name> parts with a SurfaceGui "Board" (labels Title, Mode, Rows).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionConfig = require(ReplicatedStorage.Shared.Config.Collection)
local ShovelBuilder = require(ReplicatedStorage.Shared.Builders.ShovelBuilder)
local Kit = require(script.Parent.Kit)

local L = Kit.L
local Terrain = workspace.Terrain
local part, hex = Kit.part, Kit.hex

local Base = {}

local WOOD = hex("#8A5A32")
local WOOD_DARK = hex("#5B3A22")
local WOOD_LIGHT = hex("#C7915A")
local PLANK_A = hex("#B5824F")
local PLANK_B = hex("#A87545")
local STONE = hex("#D9CBB0")
local GOLD = hex("#FFC933")

-- Measures the sand around the base footprint (before it's cleared).
local function measureSand(): number
	local b = L.base
	local points = {}
	for x = b.minX - 8, b.maxX + 8, 12 do
		table.insert(points, Vector2.new(x, b.minZ - 8))
		table.insert(points, Vector2.new(x, b.maxZ + 8))
	end
	for z = b.minZ, b.maxZ, 12 do
		table.insert(points, Vector2.new(b.minX - 8, z))
		table.insert(points, Vector2.new(b.maxX + 8, z))
	end
	return Kit.medianGround(points, L.beachHeight)
end

-- The deck: a thick wooden platform with plank stripes, a stone rim, and
-- wedge steps all around so walking on and off is smooth.
local function deck(base: Instance, top: number)
	local b = L.base
	local width, depth = b.maxX - b.minX, b.maxZ - b.minZ
	local cx, cz = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
	local bottom = top - 8
	part(base, {
		name = "Deck",
		size = Vector3.new(width, top - bottom, depth),
		cframe = CFrame.new(cx, (top + bottom) / 2, cz),
		color = PLANK_A,
		material = Enum.Material.WoodPlanks,
	})
	-- Plank stripes (slightly raised alternate boards) for texture.
	for x = b.minX + 3, b.maxX - 3, 6 do
		part(base, {
			name = "Plank",
			size = Vector3.new(3, 0.1, depth - 2),
			cframe = CFrame.new(x, top + 0.05, cz),
			color = PLANK_B,
			material = Enum.Material.WoodPlanks,
			canCollide = false,
			castShadow = false,
		})
	end
	-- Stone rim.
	for _, z in { b.minZ, b.maxZ } do
		part(base, {
			name = "DeckRim",
			size = Vector3.new(width + 2, 1, 2),
			cframe = CFrame.new(cx, top - 0.3, z),
			color = STONE,
			material = Enum.Material.Limestone,
		})
	end
	for _, x in { b.minX, b.maxX } do
		part(base, {
			name = "DeckRim",
			size = Vector3.new(2, 1, depth + 2),
			cframe = CFrame.new(x, top - 0.3, cz),
			color = STONE,
			material = Enum.Material.Limestone,
		})
	end
	-- Wedge steps on all four sides (sunk into the sand at their outer edge).
	local stepRun = 7
	local function step(center: Vector3, length: number, outward: Vector3)
		local low = center + outward * (stepRun + 1)
		local high = center + outward * 1
		Kit.ramp(
			base,
			Vector3.new(low.X, top - 3, low.Z),
			Vector3.new(high.X, top - 0.2, high.Z),
			length,
			top - 3.2,
			{
				name = "Step",
				color = STONE,
				material = Enum.Material.Limestone,
			}
		)
	end
	step(Vector3.new(cx, top, b.minZ), width, Vector3.new(0, 0, -1))
	step(Vector3.new(cx, top, b.maxZ), width, Vector3.new(0, 0, 1))
	step(Vector3.new(b.minX, top, cz), depth, Vector3.new(-1, 0, 0))
	step(Vector3.new(b.maxX, top, cz), depth, Vector3.new(1, 0, 0))
end

-- Four posts and a striped, pitched market awning. `cf` is the awning's
-- footprint center on the floor; its ridge runs along cf's X axis.
local function awning(
	parent: Instance,
	cf: CFrame,
	sizeX: number,
	sizeZ: number,
	height: number,
	stripe: Color3
)
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			part(parent, {
				name = "AwningPost",
				size = Vector3.new(1, height, 1),
				cframe = cf * CFrame.new(dx * sizeX / 2, height / 2, dz * sizeZ / 2),
				color = WOOD,
				material = Enum.Material.Wood,
			})
		end
	end
	local stripes = math.max(4, math.floor(sizeX / 3))
	local slope = math.rad(22)
	local halfDepth = sizeZ / 2 + 1.5
	local panelLength = halfDepth / math.cos(slope)
	local ridgeY = height + halfDepth * math.tan(slope)
	for _, side in { -1, 1 } do
		for i = 1, stripes do
			local w = (sizeX + 3) / stripes
			local x = -(sizeX + 3) / 2 + (i - 0.5) * w
			part(parent, {
				name = "Awning",
				size = Vector3.new(w, 0.4, panelLength),
				cframe = cf
					* CFrame.new(x, ridgeY, 0)
					* CFrame.Angles(side * slope, 0, 0)
					* CFrame.new(0, 0, side * panelLength / 2),
				color = if i % 2 == 0 then hex("#FFF8EA") else stripe,
				material = Enum.Material.Fabric,
				canCollide = false,
			})
		end
	end
	-- Scalloped valance along the front (-Z) edge.
	local n = stripes * 2
	for i = 0, n - 1 do
		local w = (sizeX + 3) / n
		local x = -(sizeX + 3) / 2 + (i + 0.5) * w
		part(parent, {
			name = "Valance",
			size = Vector3.new(w, 1.1, 0.2),
			cframe = cf * CFrame.new(x, height - 0.2, -halfDepth),
			color = if i % 2 == 0 then stripe else hex("#FFF8EA"),
			material = Enum.Material.Fabric,
			canCollide = false,
			castShadow = false,
		})
	end
end

local function lantern(parent: Instance, base: Vector3)
	part(parent, {
		name = "LanternPole",
		size = Vector3.new(0.6, 9, 0.6),
		cframe = CFrame.new(base + Vector3.new(0, 4.5, 0)),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
	})
	part(parent, {
		name = "LanternArm",
		size = Vector3.new(0.4, 0.4, 2),
		cframe = CFrame.new(base + Vector3.new(0, 8.8, -0.8)),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
	})
	local glow = Kit.ellipsoid(parent, {
		name = "Lantern",
		size = Vector3.new(1.4, 1.8, 1.4),
		cframe = CFrame.new(base + Vector3.new(0, 7.9, -1.6)),
		color = hex("#FFD27A"),
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
	})
	Kit.light(glow, Color3.fromRGB(255, 200, 120), 18, 1.2)
end

-- Little colored flags on a line between two points.
local function bunting(parent: Instance, from: Vector3, to: Vector3)
	local colors = { hex("#FF5A5A"), hex("#FFD54A"), hex("#5CC8FF"), hex("#5BE36B"), hex("#B45CFF") }
	local count = math.floor((to - from).Magnitude / 1.8)
	for i = 1, count - 1 do
		local t = i / count
		local p = from:Lerp(to, t) - Vector3.new(0, math.sin(t * math.pi) * 1.4, 0)
		part(parent, {
			name = "Flag",
			className = "WedgePart",
			size = Vector3.new(0.1, 1.2, 1),
			cframe = CFrame.lookAt(p, p + (to - from).Unit) * CFrame.Angles(math.rad(180), math.rad(90), 0),
			color = colors[i % #colors + 1],
			material = Enum.Material.Fabric,
			canCollide = false,
			castShadow = false,
		})
	end
end

local function planter(parent: Instance, position: Vector3, rng: Random)
	part(parent, {
		name = "Planter",
		size = Vector3.new(4, 1.6, 4),
		cframe = CFrame.new(position + Vector3.new(0, 0.8, 0)),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
	})
	Kit.ellipsoid(parent, {
		name = "Leaves",
		size = Vector3.new(4, 2.6, 4),
		cframe = CFrame.new(position + Vector3.new(0, 2, 0)),
		color = hex("#3FAE49"),
		material = Enum.Material.Grass,
		canCollide = false,
	})
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		part(parent, {
			name = "Flower",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.9, 0.9, 0.9),
			cframe = CFrame.new(
				position + Vector3.new(math.cos(a) * 1.4, 2.6 + rng:NextNumber(0, 0.6), math.sin(a) * 1.4)
			),
			color = ({ hex("#FF6FAE"), hex("#FFD54A"), hex("#FF8A3D"), hex("#FFFFFF") })[i % 4 + 1],
			canCollide = false,
			castShadow = false,
		})
	end
end

-- A shop stall: back wall with shelves, counter, side walls, awning, a big
-- sign on the facade, a shopkeeper, and the station pad in front.
local function shop(
	base: Instance,
	top: number,
	station: { x: number, z: number, radius: number },
	kind: string,
	color: Color3,
	title: string,
	facing: number -- +1: the stall opens toward +X, -1 toward -X
): BasePart
	local model = Instance.new("Model")
	model.Name = kind .. "Shop"
	-- The stall stands beside the pad, on the plaza's outer edge.
	local back = station.x - facing * (station.radius + 4)
	local cf = CFrame.new(back, top, station.z)
		* CFrame.Angles(0, if facing > 0 then math.rad(-90) else math.rad(90), 0)
	-- In `cf`, -Z faces the plaza, +X runs along the stall front.
	local width, depthZ, wallH = 20, 10, 11
	part(model, {
		name = "BackWall",
		size = Vector3.new(width, wallH, 1),
		cframe = cf * CFrame.new(0, wallH / 2, depthZ / 2),
		color = WOOD_LIGHT,
		material = Enum.Material.WoodPlanks,
	})
	for _, sx in { -1, 1 } do
		part(model, {
			name = "SideWall",
			size = Vector3.new(1, wallH, depthZ),
			cframe = cf * CFrame.new(sx * (width / 2 - 0.5), wallH / 2, 0),
			color = WOOD,
			material = Enum.Material.WoodPlanks,
		})
	end
	-- Shelves with stock on the back wall.
	for i, y in { 3.2, 6.2 } do
		part(model, {
			name = "Shelf",
			size = Vector3.new(width - 3, 0.4, 1.6),
			cframe = cf * CFrame.new(0, y, depthZ / 2 - 1.2),
			color = WOOD_DARK,
			material = Enum.Material.Wood,
		})
		if kind == "Bag" then
			for k = -3, 3 do
				Kit.ellipsoid(model, {
					name = "BagStock",
					size = Vector3.new(1.6, 1.9, 1.4) * (if i == 1 then 1.1 else 0.9),
					cframe = cf * CFrame.new(k * 2.4, y + 1.1, depthZ / 2 - 1.2),
					color = ({ hex("#A0643C"), hex("#B45CFF"), hex("#5CC8FF"), hex("#FFC933") })[(k + i) % 4 + 1],
					material = Enum.Material.Fabric,
					canCollide = false,
				})
			end
		end
	end
	-- Counter at the front with a striped top.
	part(model, {
		name = "Counter",
		size = Vector3.new(width - 4, 3.4, 2.2),
		cframe = cf * CFrame.new(0, 1.7, -depthZ / 2 + 1.5),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
	})
	part(model, {
		name = "CounterTop",
		size = Vector3.new(width - 3.4, 0.4, 2.8),
		cframe = cf * CFrame.new(0, 3.6, -depthZ / 2 + 1.5),
		color = color,
		material = Enum.Material.SmoothPlastic,
	})
	awning(model, cf * CFrame.new(0, 0, -0.5), width + 1, depthZ + 2, wallH, color)

	-- The big sign above the stall front, facing the plaza.
	local sign = part(model, {
		name = "ShopSign",
		size = Vector3.new(16, 4.4, 0.8),
		cframe = cf * CFrame.new(0, wallH + 6.6, -depthZ / 2 - 1.6) * CFrame.Angles(math.rad(-8), 0, 0),
		color = WOOD_DARK,
		material = Enum.Material.WoodPlanks,
	})
	Kit.signText(sign, title, color, nil, { Enum.NormalId.Front })
	for _, sx in { -6.5, 6.5 } do
		part(model, {
			name = "SignPost",
			size = Vector3.new(0.6, 5, 0.6),
			cframe = cf * CFrame.new(sx, wallH + 3.4, -depthZ / 2 - 1.3),
			color = WOOD_DARK,
			material = Enum.Material.Wood,
		})
	end

	-- Shopkeeper behind the counter.
	Kit.person(
		model,
		cf * CFrame.new(0, 0, -depthZ / 2 + 4) * CFrame.Angles(0, 0, 0),
		if kind == "Shovel"
			then { shirt = hex("#3F8FD6"), pants = hex("#4A3A2A"), hat = "Explorer", holding = "Shovel" }
			else {
				shirt = hex("#9B4FD6"),
				pants = hex("#3A3A4A"),
				hat = "Bandana",
				hatColor = hex("#FFC933"),
			},
		kind .. "Keeper"
	)

	if kind == "Shovel" then
		-- Display rack of shovels on the counter's sides.
		for i, level in { 2, 3, 4, 5, 6, 7 } do
			local display = ShovelBuilder.build(level)
			for _, d in display:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			display:PivotTo(
				cf * CFrame.new((i - 3.5) * 2.6, 6.8, depthZ / 2 - 0.9) * CFrame.Angles(0, 0, math.rad(-8))
			)
			display.Parent = model
		end
		-- A giant shovel stuck in the deck beside the stall.
		local big = ShovelBuilder.build(8)
		for _, d in big:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		big:ScaleTo(3)
		big:PivotTo(
			cf * CFrame.new(width / 2 + 3, 7, -depthZ / 2 - 2) * CFrame.Angles(math.rad(12), 0, math.rad(-10))
		)
		big.Parent = model
	else
		-- A giant treasure bag beside the stall.
		Kit.ellipsoid(model, {
			name = "BigBag",
			size = Vector3.new(7, 8, 7),
			cframe = cf * CFrame.new(width / 2 + 4, 4, -depthZ / 2 - 2),
			color = hex("#A0643C"),
			material = Enum.Material.Fabric,
		})
		part(model, {
			name = "BigBagTie",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1, 3.6, 3.6),
			cframe = cf * CFrame.new(width / 2 + 4, 8.4, -depthZ / 2 - 2) * CFrame.Angles(0, 0, math.rad(90)),
			color = GOLD,
			material = Enum.Material.Fabric,
		})
		for k = 1, 5 do
			part(model, {
				name = "BagCoin",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.4, 1.6, 1.6),
				cframe = cf * CFrame.new(
					width / 2 + 4 + math.cos(k) * 4.4,
					0.25 + k * 0.05,
					-depthZ / 2 - 2 + math.sin(k) * 4.4
				) * CFrame.Angles(0, 0, math.rad(90)),
				color = GOLD,
				material = Enum.Material.Metal,
				canCollide = false,
			})
		end
	end
	model.Parent = base

	-- The station pad: a glowing ring the player steps into.
	local pad = part(base, {
		name = kind .. "Pad",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, station.radius * 1.5, station.radius * 1.5),
		cframe = CFrame.new(station.x, top + 0.15, station.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		material = Enum.Material.Neon,
		transparency = 0.35,
		canCollide = false,
	})
	pad.CanQuery = true
	part(base, {
		name = kind .. "PadRing",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, station.radius * 1.5 + 1.2, station.radius * 1.5 + 1.2),
		cframe = CFrame.new(station.x, top + 0.1, station.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.new(1, 1, 1),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
	})
	pad:SetAttribute("Station", kind)
	pad:SetAttribute("Radius", station.radius)
	return pad
end

-- The SELL pavilion: a golden pad under a domed canopy with a huge sign,
-- treasure chests and coin piles.
local function sellPavilion(base: Instance, top: number, rng: Random): BasePart
	local sp = L.sellPad
	local pad = part(base, {
		name = "SellPad",
		size = Vector3.new(sp.size, 0.3, sp.size),
		cframe = CFrame.new(sp.x, top + 0.15, sp.z),
		color = hex("#FFD54A"),
		material = Enum.Material.Neon,
		transparency = 0.2,
		canCollide = false,
	})
	pad.CanQuery = true
	pad:SetAttribute("Station", "Sell")
	part(base, {
		name = "SellPadRim",
		size = Vector3.new(sp.size + 2, 0.2, sp.size + 2),
		cframe = CFrame.new(sp.x, top + 0.1, sp.z),
		color = hex("#C98A1E"),
		material = Enum.Material.Metal,
		canCollide = false,
	})
	-- Four golden columns and a canopy.
	local h = 12
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			local p = Vector3.new(sp.x + dx * (sp.size / 2 + 0.6), top, sp.z + dz * (sp.size / 2 + 0.6))
			part(base, {
				name = "SellColumn",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(h, 1.6, 1.6),
				cframe = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				color = hex("#FFE7A3"),
				material = Enum.Material.Marble,
			})
			part(base, {
				name = "SellColumnCap",
				size = Vector3.new(2.6, 0.8, 2.6),
				cframe = CFrame.new(p + Vector3.new(0, h + 0.2, 0)),
				color = GOLD,
				material = Enum.Material.Metal,
			})
		end
	end
	part(base, {
		name = "SellRoof",
		size = Vector3.new(sp.size + 5, 1, sp.size + 5),
		cframe = CFrame.new(sp.x, top + h + 1, sp.z),
		color = hex("#E8A82A"),
		material = Enum.Material.Metal,
	})
	Kit.ellipsoid(base, {
		name = "SellDome",
		size = Vector3.new(sp.size - 4, 6, sp.size - 4),
		cframe = CFrame.new(sp.x, top + h + 1.4, sp.z),
		color = GOLD,
		material = Enum.Material.Metal,
		reflectance = 0.1,
	})
	local coin = part(base, {
		name = "SellCoin",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1, 6, 6),
		cframe = CFrame.new(sp.x, top + h + 8.5, sp.z) * CFrame.Angles(0, math.rad(90), 0),
		color = GOLD,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	coin:SetAttribute("Ambient", "Spin")
	-- The big sign, facing north (toward everyone walking back from digging)
	-- and south (toward the spawn).
	local sign = part(base, {
		name = "SellSign",
		size = Vector3.new(sp.size + 2, 4.4, 0.8),
		cframe = CFrame.new(sp.x, top + h - 1.6, sp.z - sp.size / 2 - 1.2),
		color = hex("#7A3E12"),
		material = Enum.Material.WoodPlanks,
	})
	Kit.signText(sign, "SELL", hex("#FFD54A"), nil, { Enum.NormalId.Front })
	local back = part(base, {
		name = "SellSignBack",
		size = Vector3.new(sp.size + 2, 4.4, 0.8),
		cframe = CFrame.new(sp.x, top + h - 1.6, sp.z + sp.size / 2 + 1.2),
		color = hex("#7A3E12"),
		material = Enum.Material.WoodPlanks,
	})
	Kit.signText(back, "SELL HERE", hex("#FFD54A"), nil, { Enum.NormalId.Back })
	-- Chests and coin piles on both sides.
	for _, side in { -1, 1 } do
		local x = sp.x + side * (sp.size / 2 + 5)
		local chest = part(base, {
			name = "SellChest",
			size = Vector3.new(4.4, 2.6, 3),
			cframe = CFrame.new(x, top + 1.3, sp.z + 3) * CFrame.Angles(0, side * 0.25, 0),
			color = hex("#8B5A2B"),
			material = Enum.Material.WoodPlanks,
		})
		part(base, {
			name = "SellChestBand",
			size = Vector3.new(4.6, 0.5, 3.1),
			cframe = chest.CFrame * CFrame.new(0, 0.6, 0),
			color = GOLD,
			material = Enum.Material.Metal,
		})
		Kit.ellipsoid(base, {
			name = "SellChestGold",
			size = Vector3.new(3.8, 1.6, 2.4),
			cframe = chest.CFrame * CFrame.new(0, 1.4, 0),
			color = hex("#FFD54A"),
			material = Enum.Material.Neon,
			canCollide = false,
		})
		for i = 1, 16 do
			local a = i * 0.9
			local r = 0.8 + (i % 4) * 0.55
			part(base, {
				name = "Coin",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.35, 1.8, 1.8),
				cframe = CFrame.new(
					x + math.cos(a) * r,
					top + 0.2 + (16 - i) * 0.14,
					sp.z - 4 + math.sin(a) * r
				) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, math.rad(90)),
				color = GOLD,
				material = Enum.Material.Metal,
				canCollide = false,
				castShadow = false,
			})
		end
	end
	return pad
end

-- The rebirth temple: a marble platform with steps, pillars, glowing orbs
-- and a floating crystal.
local function rebirthTemple(base: Instance, rng: Random): BasePart
	local ra = L.rebirthAltar
	-- On top of the highest sand under it, so no edge is ever buried.
	local ground = Kit.highestGround(ra.x, ra.z, ra.radius * 1.5, L.beachHeight)
	local top = ground + 1.8
	part(base, {
		name = "AltarBase",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(8, ra.radius * 2.4, ra.radius * 2.4),
		cframe = CFrame.new(ra.x, top - 4, ra.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#E8E1D0"),
		material = Enum.Material.Marble,
	})
	part(base, {
		name = "AltarStep",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(8, ra.radius * 2.4 + 5, ra.radius * 2.4 + 5),
		cframe = CFrame.new(ra.x, top - 4.9, ra.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#D6CDB8"),
		material = Enum.Material.Marble,
	})
	local altar = part(base, {
		name = "RebirthPad",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, ra.radius * 1.7, ra.radius * 1.7),
		cframe = CFrame.new(ra.x, top + 0.15, ra.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#B45CFF"),
		material = Enum.Material.Neon,
		transparency = 0.2,
		canCollide = false,
	})
	altar.CanQuery = true
	altar:SetAttribute("Station", "Rebirth")
	altar:SetAttribute("Radius", ra.radius)
	Kit.billboard(altar, "REBIRTH", "Rank up: +25% cash forever", hex("#C77DFF"), 17, 16)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local pillar = part(base, {
			name = "AltarPillar",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(11, 1.8, 1.8),
			cframe = CFrame.new(
				ra.x + math.cos(a) * ra.radius * 1.05,
				top + 5.5,
				ra.z + math.sin(a) * ra.radius * 1.05
			) * CFrame.Angles(0, 0, math.rad(90)),
			color = hex("#F2ECDD"),
			material = Enum.Material.Marble,
		})
		local orb = part(base, {
			name = "AltarOrb",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.8, 1.8, 1.8),
			cframe = CFrame.new(pillar.Position + Vector3.new(0, 6.4, 0)),
			color = hex("#B45CFF"),
			material = Enum.Material.Neon,
			canCollide = false,
		})
		if i % 2 == 0 then
			Kit.light(orb, orb.Color, 12)
		end
	end
	local crystal = part(base, {
		name = "RebirthCrystal",
		size = Vector3.new(3, 5, 3),
		cframe = CFrame.new(ra.x, top + 12, ra.z) * CFrame.Angles(0, math.rad(45), 0),
		color = hex("#D9A6FF"),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	crystal:SetAttribute("Ambient", "Float")
	local sparkle =
		Kit.volume(base, "RebirthSparkles", CFrame.new(ra.x, top + 4, ra.z), Vector3.new(14, 6, 14))
	Kit.emitter(sparkle, {
		color = hex("#D9A6FF"),
		rate = 8,
		lifetime = NumberRange.new(1.5, 2.5),
		size = NumberSequence.new(0.4, 0),
		speed = NumberRange.new(1, 2),
		lightEmission = 1,
		direction = Enum.NormalId.Top,
	})
	Kit.addObstacle(Vector3.new(ra.x, 0, ra.z), ra.radius + 6)
	local _ = rng
	return altar
end

-- The VIP dig site: a patch of sand inside golden posts and a red rope, with
-- a crown sign. Returns the ground point where the VIP dig spot sits.
local function vipSite(base: Instance): Vector3
	local site = L.vipSite
	local ground = Kit.highestGround(site.x, site.z, site.radius + 1, L.beachHeight)
	local posts = {}
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local p = Vector3.new(site.x + math.cos(a) * site.radius, ground, site.z + math.sin(a) * site.radius)
		local post = part(base, {
			name = "VipPost",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(4, 0.7, 0.7),
			cframe = CFrame.new(p + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			color = GOLD,
			material = Enum.Material.Metal,
		})
		part(base, {
			name = "VipPostTop",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.1, 1.1, 1.1),
			cframe = CFrame.new(p + Vector3.new(0, 4.2, 0)),
			color = GOLD,
			material = Enum.Material.Metal,
			canCollide = false,
		})
		table.insert(posts, post)
	end
	-- Velvet rope between the posts (left open at the front, facing the island).
	for i = 1, #posts do
		local a, b = posts[i].Position, posts[i % #posts + 1].Position
		local mid = (a + b) / 2
		if mid.Z < site.z - site.radius * 0.6 then
			continue
		end
		local length = (b - a).Magnitude
		part(base, {
			name = "VipRope",
			size = Vector3.new(0.35, 0.35, length),
			cframe = CFrame.lookAt(mid + Vector3.new(0, 1.2, 0), b + Vector3.new(0, 1.2, 0)),
			color = hex("#C0182F"),
			material = Enum.Material.Fabric,
			canCollide = false,
		})
	end
	part(base, {
		name = "VipCarpet",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, site.radius * 2 + 1, site.radius * 2 + 1),
		cframe = CFrame.new(site.x, ground + 0.1, site.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#9E1B32"),
		material = Enum.Material.Fabric,
		canCollide = false,
		castShadow = false,
	})
	local sign = part(base, {
		name = "VipSign",
		size = Vector3.new(0.4, 0.4, 0.4),
		cframe = CFrame.new(site.x, ground + 7, site.z + site.radius),
		transparency = 1,
		canCollide = false,
	})
	Kit.billboard(sign, "👑 VIP DIG SITE", "Best-area treasure, right at the base", GOLD, 2, 20)
	local sparkle =
		Kit.volume(base, "VipSparkles", CFrame.new(site.x, ground + 2, site.z), Vector3.new(12, 4, 12))
	Kit.emitter(sparkle, {
		color = GOLD,
		rate = 5,
		lifetime = NumberRange.new(1.2, 2),
		size = NumberSequence.new(0.35, 0),
		speed = NumberRange.new(0.5, 1.5),
		lightEmission = 1,
		direction = Enum.NormalId.Top,
	})
	Kit.addObstacle(Vector3.new(site.x, 0, site.z), site.radius + 5)
	return Vector3.new(site.x, ground, site.z)
end

-- A leaderboard board with a wooden frame, roof and lanterns.
local function leaderboard(base: Instance, top: number, board: string, title: string, x: number, z: number)
	local w, h = 17, 15
	local y0 = top + 3
	for _, dx in { -w / 2 - 0.8, w / 2 + 0.8 } do
		part(base, {
			name = "BoardPost",
			size = Vector3.new(1.4, h + 6, 1.4),
			cframe = CFrame.new(x + dx, top + (h + 6) / 2, z),
			color = WOOD,
			material = Enum.Material.Wood,
		})
	end
	part(base, {
		name = "BoardBackPlanks",
		size = Vector3.new(w + 1.4, h + 1.4, 0.6),
		cframe = CFrame.new(x, y0 + h / 2, z + 0.5),
		color = WOOD_LIGHT,
		material = Enum.Material.WoodPlanks,
	})
	part(base, {
		name = "BoardRoof",
		className = "WedgePart",
		size = Vector3.new(w + 4, 1.6, 3.4),
		cframe = CFrame.new(x, y0 + h + 1.6, z - 0.4) * CFrame.Angles(0, math.rad(180), 0),
		color = hex("#B5482E"),
		material = Enum.Material.WoodPlanks,
	})
	local panel = part(base, {
		name = "Board_" .. board,
		size = Vector3.new(w, h, 0.4),
		cframe = CFrame.new(x, y0 + h / 2, z),
		color = hex("#2E2433"),
		material = Enum.Material.SmoothPlastic,
	})
	panel:SetAttribute("Leaderboard", board)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(510, 450)
	gui.LightInfluence = 0
	gui.Parent = panel
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 60)
	titleLabel.Font = Enum.Font.LuckiestGuy
	titleLabel.Text = title
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = GOLD
	titleLabel.Parent = gui
	local mode = Instance.new("TextLabel")
	mode.Name = "Mode"
	mode.BackgroundTransparency = 1
	mode.Position = UDim2.fromOffset(0, 60)
	mode.Size = UDim2.new(1, 0, 0, 28)
	mode.Font = Enum.Font.FredokaOne
	mode.Text = "ALL TIME"
	mode.TextScaled = true
	mode.TextColor3 = Color3.new(1, 1, 1)
	mode.Parent = gui
	local rows = Instance.new("TextLabel")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(18, 98)
	rows.Size = UDim2.new(1, -36, 1, -106)
	rows.Font = Enum.Font.FredokaOne
	rows.Text = "Loading..."
	rows.TextSize = 27
	rows.TextXAlignment = Enum.TextXAlignment.Left
	rows.TextYAlignment = Enum.TextYAlignment.Top
	rows.TextColor3 = Color3.new(1, 1, 1)
	rows.Parent = gui
	for _, dx in { -w / 2 - 0.8, w / 2 + 0.8 } do
		local glow = Kit.ellipsoid(base, {
			name = "BoardLamp",
			size = Vector3.new(1.2, 1.5, 1.2),
			cframe = CFrame.new(x + dx, top + h + 6.6, z),
			color = hex("#FFD27A"),
			material = Enum.Material.Neon,
			canCollide = false,
			castShadow = false,
		})
		Kit.light(glow, Color3.fromRGB(255, 200, 120), 12, 1)
	end
end

export type BaseInfo = {
	folder: Folder,
	deckTop: number,
	pads: { [string]: BasePart },
	vipSpot: Vector3,
}

function Base.build(rng: Random): BaseInfo
	local base = Kit.folder("Base", workspace)
	local b = L.base

	-- Measure the sand, then clear it from under the deck.
	local sand = measureSand()
	local top = sand + b.deckHeight
	Kit.DECK_TOP = top
	Terrain:FillBlock(
		CFrame.new((b.minX + b.maxX) / 2, top + 30, (b.minZ + b.maxZ) / 2),
		Vector3.new(b.maxX - b.minX + 4, 60 + 2, b.maxZ - b.minZ + 4),
		Enum.Material.Air
	)
	deck(base, top)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.CFrame = CFrame.new(L.spawn.x, top + 0.2, L.spawn.z)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = base
	-- A compass rose under the spawn.
	part(base, {
		name = "SpawnRose",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.12, 10, 10),
		cframe = CFrame.new(L.spawn.x, top + 0.07, L.spawn.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#E6C27A"),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		castShadow = false,
	})
	part(base, {
		name = "SpawnRoseInner",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.14, 7, 7),
		cframe = CFrame.new(L.spawn.x, top + 0.09, L.spawn.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#C99A55"),
		material = Enum.Material.WoodPlanks,
		canCollide = false,
		castShadow = false,
	})

	-- Entrance arch at the front of the deck, facing the island.
	local archZ = b.minZ + 1
	for _, x in { -14, 14 } do
		part(base, {
			name = "ArchPost",
			size = Vector3.new(2.4, 17, 2.4),
			cframe = CFrame.new(x, top + 8.5, archZ),
			color = WOOD,
			material = Enum.Material.Wood,
		})
		local cap = part(base, {
			name = "ArchTorch",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.8, 2.6, 2.6),
			cframe = CFrame.new(x, top + 17.4, archZ) * CFrame.Angles(0, 0, math.rad(90)),
			color = WOOD_DARK,
			material = Enum.Material.Wood,
		})
		Kit.fire(cap, 3)
		Kit.light(cap, Color3.fromRGB(255, 170, 80), 18, 1.4)
	end
	local sign = part(base, {
		name = "ArchSign",
		size = Vector3.new(26, 4.6, 0.8),
		cframe = CFrame.new(0, top + 14.6, archZ),
		color = hex("#8B5A2B"),
		material = Enum.Material.WoodPlanks,
	})
	Kit.signText(sign, "DIG FOR CASH", hex("#FFD54A"))

	local pads = {
		Sell = sellPavilion(base, top, rng),
		Shovel = shop(base, top, L.shovelStation, "Shovel", hex("#5CC8FF"), "SHOVELS", 1),
		Bag = shop(base, top, L.bagStation, "Bag", hex("#C77DFF"), "BAGS", -1),
		Rebirth = rebirthTemple(base, rng),
	}

	-- Leaderboards along the back, facing the plaza.
	local titles = { Richest = "RICHEST", Rebirths = "MOST REBIRTHS", Rarest = "RAREST FIND" }
	for i, board in { "Rarest", "Richest", "Rebirths" } do
		leaderboard(base, top, board, titles[board], L.leaderboards.xs[i], L.leaderboards.z)
	end

	-- Trophy stand: a two-step marble bench with a pedestal per slot.
	local shelf = L.trophyShelf
	local shelfWidth = shelf.maxX - shelf.minX + 6
	part(base, {
		name = "ShelfBoard",
		size = Vector3.new(shelfWidth, 1.2, 5),
		cframe = CFrame.new((shelf.minX + shelf.maxX) / 2, top + 0.6, shelf.z),
		color = hex("#E8E1D0"),
		material = Enum.Material.Marble,
	})
	local shelfSign = part(base, {
		name = "ShelfSign",
		size = Vector3.new(18, 2.4, 0.6),
		cframe = CFrame.new((shelf.minX + shelf.maxX) / 2, top + 1.2, shelf.z - 2.8)
			* CFrame.Angles(math.rad(-20), 0, 0),
		color = WOOD_DARK,
		material = Enum.Material.WoodPlanks,
	})
	Kit.signText(shelfSign, "TROPHY STAND", GOLD, nil, { Enum.NormalId.Front })
	for i = 1, CollectionConfig.shelfSlots do
		local x = shelf.minX
			+ (i - 1) * (shelf.maxX - shelf.minX) / math.max(1, CollectionConfig.shelfSlots - 1)
		part(base, {
			name = "ShelfPedestal",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.6, 2.8, 2.8),
			cframe = CFrame.new(x, top + 2, shelf.z) * CFrame.Angles(0, 0, math.rad(90)),
			color = hex("#F7F0E1"),
			material = Enum.Material.Marble,
		})
		part(base, {
			name = "ShelfPedestalTrim",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.2, 3, 3),
			cframe = CFrame.new(x, top + 2.85, shelf.z) * CFrame.Angles(0, 0, math.rad(90)),
			color = GOLD,
			material = Enum.Material.Metal,
			canCollide = false,
		})
	end

	-- Lanterns at the corners and along the sides, bunting, planters.
	for _, p in
		{
			{ b.minX + 2.5, b.minZ + 2.5 },
			{ b.maxX - 2.5, b.minZ + 2.5 },
			{ b.minX + 2.5, b.maxZ - 2.5 },
			{ b.maxX - 2.5, b.maxZ - 2.5 },
			{ -20, b.minZ + 2.5 },
			{ 20, b.minZ + 2.5 },
		}
	do
		lantern(base, Vector3.new(p[1], top, p[2]))
	end
	bunting(base, Vector3.new(-14, top + 16.5, archZ), Vector3.new(-20, top + 8.6, b.minZ + 1.7))
	bunting(base, Vector3.new(14, top + 16.5, archZ), Vector3.new(20, top + 8.6, b.minZ + 1.7))
	bunting(
		base,
		Vector3.new(-20, top + 8.6, b.minZ + 1.7),
		Vector3.new(b.minX + 2.5, top + 8.6, b.minZ + 1.7)
	)
	bunting(
		base,
		Vector3.new(20, top + 8.6, b.minZ + 1.7),
		Vector3.new(b.maxX - 2.5, top + 8.6, b.minZ + 1.7)
	)
	for _, p in { { -42, 168 }, { 42, 168 }, { -14, 230 }, { 14, 230 }, { -46, 214 }, { 46, 214 } } do
		planter(base, Vector3.new(p[1], top, p[2]), rng)
	end
	-- Benches facing the boards.
	for _, x in { -18, 18 } do
		part(base, {
			name = "Bench",
			size = Vector3.new(6, 0.6, 2),
			cframe = CFrame.new(x, top + 1.6, 214),
			color = WOOD,
			material = Enum.Material.WoodPlanks,
		})
		for _, dx in { -2.4, 2.4 } do
			part(base, {
				name = "BenchLeg",
				size = Vector3.new(0.6, 1.4, 1.6),
				cframe = CFrame.new(x + dx, top + 0.7, 214),
				color = WOOD_DARK,
				material = Enum.Material.Wood,
			})
		end
	end

	local vipSpot = vipSite(base)

	return { folder = base, deckTop = top, pads = pads, vipSpot = vipSpot }
end

return Base
