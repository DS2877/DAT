--!strict
-- The base: the wooden deck hub with the sell pad, shovel and bag shops
-- (striped market awnings), the rebirth altar, leaderboard boards, the trophy
-- shelf, an entrance arch, lanterns and bunting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionConfig = require(ReplicatedStorage.Shared.Config.Collection)
local ShovelBuilder = require(ReplicatedStorage.Shared.Builders.ShovelBuilder)
local Kit = require(script.Parent.Kit)

local L = Kit.L
local DECK_TOP = Kit.DECK_TOP
local part, hex = Kit.part, Kit.hex

local Base = {}

local WOOD = hex("#7A5230")
local WOOD_DARK = hex("#5B3A22")

-- Four posts and a striped, pitched market awning over a pad.
local function awning(parent: Instance, center: Vector3, size: number, stripe: Color3)
	local h = 10
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			part(parent, {
				name = "AwningPost",
				size = Vector3.new(0.9, h, 0.9),
				cframe = CFrame.new(center + Vector3.new(dx * size / 2, h / 2, dz * size / 2)),
				color = WOOD,
				material = Enum.Material.Wood,
			})
		end
	end
	-- Two roof halves meeting at a ridge along X, each made of stripes.
	local stripes = 6
	local slope = math.rad(24)
	for _, side in { -1, 1 } do
		local halfDepth = size / 2 + 1.2
		local panelLength = halfDepth / math.cos(slope)
		for i = 1, stripes do
			local w = (size + 3) / stripes
			local x = center.X - (size + 3) / 2 + (i - 0.5) * w
			local cf = CFrame.new(x, center.Y + h + 1.6, center.Z)
				* CFrame.Angles(side * slope, 0, 0)
				* CFrame.new(0, 0, side * panelLength / 2)
			part(parent, {
				name = "Awning",
				size = Vector3.new(w, 0.35, panelLength),
				cframe = cf,
				color = if i % 2 == 0 then Color3.new(1, 1, 1) else stripe,
				material = Enum.Material.Fabric,
				canCollide = false,
			})
		end
	end
end

local function lantern(parent: Instance, base: Vector3)
	part(parent, {
		name = "LanternPole",
		size = Vector3.new(0.5, 7, 0.5),
		cframe = CFrame.new(base + Vector3.new(0, 3.5, 0)),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
	})
	local glow = part(parent, {
		name = "Lantern",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.4, 1.6, 1.4),
		cframe = CFrame.new(base + Vector3.new(0, 7.4, 0)),
		color = hex("#FFD27A"),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	Kit.light(glow, Color3.fromRGB(255, 200, 120), 16, 1.2)
end

-- Little colored flags on a line between two points.
local function bunting(parent: Instance, from: Vector3, to: Vector3)
	local colors = { hex("#FF5A5A"), hex("#FFD54A"), hex("#5CC8FF"), hex("#5BE36B"), hex("#B45CFF") }
	local count = math.floor((to - from).Magnitude / 1.6)
	for i = 1, count - 1 do
		local t = i / count
		local p = from:Lerp(to, t) - Vector3.new(0, math.sin(t * math.pi) * 1.2, 0)
		local flag = Instance.new("WedgePart")
		flag.Name = "Flag"
		flag.Anchored = true
		flag.CanCollide = false
		flag.CanQuery = false
		flag.Size = Vector3.new(0.1, 1.1, 0.9)
		flag.CFrame = CFrame.lookAt(p, p + (to - from).Unit) * CFrame.Angles(math.rad(180), math.rad(90), 0)
		flag.Color = colors[i % #colors + 1]
		flag.Material = Enum.Material.Fabric
		flag.Parent = parent
	end
end

local function planter(parent: Instance, position: Vector3, rng: Random)
	part(parent, {
		name = "Planter",
		size = Vector3.new(3, 1.2, 3),
		cframe = CFrame.new(position + Vector3.new(0, 0.6, 0)),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
	})
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		part(parent, {
			name = "Flower",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.9, 0.9, 0.9),
			cframe = CFrame.new(
				position + Vector3.new(math.cos(a) * 0.8, 1.6 + rng:NextNumber(0, 0.4), math.sin(a) * 0.8)
			),
			color = ({ hex("#FF6FAE"), hex("#FFD54A"), hex("#FF8A3D"), hex("#FFFFFF") })[i % 4 + 1],
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
		})
	end
	part(parent, {
		name = "Leaves",
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.6, 1.4, 2.6),
		cframe = CFrame.new(position + Vector3.new(0, 1.3, 0)),
		color = hex("#3FAE49"),
		material = Enum.Material.Grass,
		canCollide = false,
	})
end

function Base.build(rng: Random): Folder
	local base = Kit.folder("Base", workspace)
	local b = L.base
	local width, depth = b.maxX - b.minX, b.maxZ - b.minZ
	local centerX, centerZ = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2

	part(base, {
		name = "Deck",
		size = Vector3.new(width, b.deckHeight, depth),
		cframe = CFrame.new(centerX, L.beachHeight + b.deckHeight / 2, centerZ),
		color = hex("#C08A55"),
		material = Enum.Material.WoodPlanks,
	})
	-- Deck trim.
	for _, z in { b.minZ, b.maxZ } do
		part(base, {
			name = "DeckTrim",
			size = Vector3.new(width + 0.6, 0.6, 0.8),
			cframe = CFrame.new(centerX, DECK_TOP - 0.1, z),
			color = WOOD_DARK,
			material = Enum.Material.Wood,
		})
	end
	-- Railing posts along the sides (open at the front and back).
	for z = b.minZ + 4, b.maxZ - 4, 8 do
		for _, x in { b.minX + 1, b.maxX - 1 } do
			part(base, {
				name = "Post",
				size = Vector3.new(1, 3, 1),
				cframe = CFrame.new(x, DECK_TOP + 1.5, z),
				color = WOOD,
				material = Enum.Material.Wood,
			})
		end
	end
	for _, x in { b.minX + 1, b.maxX - 1 } do
		part(base, {
			name = "Rail",
			size = Vector3.new(0.5, 0.5, depth - 8),
			cframe = CFrame.new(x, DECK_TOP + 2.8, centerZ),
			color = WOOD,
			material = Enum.Material.Wood,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.CFrame = CFrame.new(L.spawn.x, DECK_TOP + 0.2, L.spawn.z)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = base

	-- Entrance arch at the front of the deck, facing the island.
	local archZ = b.minZ + 1
	for _, x in { -13, 13 } do
		part(base, {
			name = "ArchPost",
			size = Vector3.new(2, 15, 2),
			cframe = CFrame.new(x, DECK_TOP + 7.5, archZ),
			color = WOOD,
			material = Enum.Material.Wood,
		})
		local cap = part(base, {
			name = "ArchTorch",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.8, 2.4, 2.4),
			cframe = CFrame.new(x, DECK_TOP + 15.4, archZ) * CFrame.Angles(0, 0, math.rad(90)),
			color = WOOD_DARK,
			material = Enum.Material.Wood,
		})
		Kit.fire(cap, 3)
		Kit.light(cap, Color3.fromRGB(255, 170, 80), 18, 1.5)
	end
	local sign = part(base, {
		name = "ArchSign",
		size = Vector3.new(24, 4.4, 0.8),
		cframe = CFrame.new(0, DECK_TOP + 13, archZ),
		color = hex("#8B5A2B"),
		material = Enum.Material.WoodPlanks,
	})
	Kit.signText(sign, "DIG FOR CASH", hex("#FFD54A"))

	-- Sell pad under a golden arch, with a treasure pile.
	local sp = L.sellPad
	local sellPad = part(base, {
		name = "SellPad",
		size = Vector3.new(sp.size, 0.4, sp.size),
		cframe = CFrame.new(sp.x, DECK_TOP + 0.2, sp.z),
		color = hex("#FFD54A"),
		material = Enum.Material.Neon,
		transparency = 0.15,
	})
	sellPad:SetAttribute("Station", "Sell")
	Kit.billboard(sellPad, "SELL", "Walk in to sell!", hex("#FFD54A"), 12, 14)
	for _, x in { -sp.size / 2 - 0.5, sp.size / 2 + 0.5 } do
		part(base, {
			name = "SellPost",
			size = Vector3.new(1.2, 10, 1.2),
			cframe = CFrame.new(sp.x + x, DECK_TOP + 5, sp.z),
			color = WOOD,
			material = Enum.Material.Wood,
		})
	end
	part(base, {
		name = "SellBeam",
		size = Vector3.new(sp.size + 3, 1.2, 1.4),
		cframe = CFrame.new(sp.x, DECK_TOP + 10.3, sp.z),
		color = hex("#FFB21E"),
		material = Enum.Material.Metal,
	})
	for i = 1, 14 do
		local a = i * 0.9
		local r = 1 + (i % 3) * 0.6
		part(base, {
			name = "Coin",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.4, 2, 2),
			cframe = CFrame.new(
				sp.x + sp.size / 2 + 3.5 + math.cos(a) * r,
				DECK_TOP + 0.3 + (14 - i) * 0.18,
				sp.z - 4 + math.sin(a) * r
			) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, math.rad(90)),
			color = hex("#FFC933"),
			material = Enum.Material.Metal,
			canCollide = false,
		})
	end
	local chest = part(base, {
		name = "SellChest",
		size = Vector3.new(4, 2.4, 2.6),
		cframe = CFrame.new(sp.x - sp.size / 2 - 3.5, DECK_TOP + 1.2, sp.z - 4),
		color = hex("#8B5A2B"),
		material = Enum.Material.WoodPlanks,
	})
	part(base, {
		name = "SellChestGold",
		shape = Enum.PartType.Ball,
		size = Vector3.new(3.2, 1.4, 2),
		cframe = chest.CFrame * CFrame.new(0, 1.3, 0),
		color = hex("#FFD54A"),
		material = Enum.Material.Neon,
		canCollide = false,
	})

	-- Upgrade shops.
	local function station(
		kind: string,
		pos: { x: number, z: number, radius: number },
		color: Color3,
		title: string,
		subtitle: string
	): BasePart
		local pad = part(base, {
			name = kind .. "Pad",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.4, pos.radius * 1.6, pos.radius * 1.6),
			cframe = CFrame.new(pos.x, DECK_TOP + 0.2, pos.z) * CFrame.Angles(0, 0, math.rad(90)),
			color = color,
			material = Enum.Material.Neon,
			transparency = 0.25,
		})
		pad:SetAttribute("Station", kind)
		pad:SetAttribute("Radius", pos.radius)
		Kit.billboard(pad, title, subtitle, color, 15, 14)
		awning(base, Vector3.new(pos.x, DECK_TOP, pos.z), pos.radius * 1.5, color)
		return pad
	end

	local shovelPad = station("Shovel", L.shovelStation, hex("#5CC8FF"), "SHOVELS", "Dig faster!")
	local bagPad = station("Bag", L.bagStation, hex("#B45CFF"), "BAGS", "Carry more!")

	-- Display rack of shovels at the shovel shop.
	for i, level in { 2, 3, 4, 5 } do
		local display = ShovelBuilder.build(level)
		for _, d in display:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		display:PivotTo(
			CFrame.new(shovelPad.Position + Vector3.new(-6.5, 3.6, (i - 2.5) * 2.2))
				* CFrame.Angles(0, math.rad(90), math.rad(-12))
		)
		display.Parent = base
	end
	part(base, {
		name = "Rack",
		size = Vector3.new(0.6, 0.6, 9.5),
		cframe = CFrame.new(shovelPad.Position + Vector3.new(-6.9, 5.3, 0)),
		color = WOOD,
		material = Enum.Material.Wood,
	})

	-- A giant bag at the bag shop.
	part(base, {
		name = "BigBag",
		shape = Enum.PartType.Ball,
		size = Vector3.new(6, 6.5, 6),
		cframe = CFrame.new(bagPad.Position + Vector3.new(6.5, 3.2, 0)),
		color = hex("#A0643C"),
		material = Enum.Material.Fabric,
	})
	part(base, {
		name = "BigBagTie",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.8, 3, 3),
		cframe = CFrame.new(bagPad.Position + Vector3.new(6.5, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#FFC933"),
		material = Enum.Material.Fabric,
	})

	-- Rebirth altar on the sand, left of the deck.
	local ra = L.rebirthAltar
	part(base, {
		name = "AltarBase",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1, ra.radius * 2.1, ra.radius * 2.1),
		cframe = CFrame.new(ra.x, L.beachHeight + 0.2, ra.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#E8E1D0"),
		material = Enum.Material.Marble,
	})
	local altar = part(base, {
		name = "RebirthPad",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.5, ra.radius * 1.7, ra.radius * 1.7),
		cframe = CFrame.new(ra.x, L.beachHeight + 0.75, ra.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = hex("#B45CFF"),
		material = Enum.Material.Neon,
		transparency = 0.2,
	})
	altar:SetAttribute("Station", "Rebirth")
	altar:SetAttribute("Radius", ra.radius)
	Kit.billboard(altar, "REBIRTH", "Rank up: +25% cash forever", hex("#B45CFF"), 13, 14)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local pillar = part(base, {
			name = "AltarPillar",
			size = Vector3.new(1.6, 9, 1.6),
			cframe = CFrame.new(
				ra.x + math.cos(a) * ra.radius * 0.95,
				L.beachHeight + 5,
				ra.z + math.sin(a) * ra.radius * 0.95
			),
			color = hex("#E8E1D0"),
			material = Enum.Material.Marble,
		})
		local orb = part(base, {
			name = "AltarOrb",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.8, 1.8, 1.8),
			cframe = pillar.CFrame * CFrame.new(0, 5.4, 0),
			color = hex("#B45CFF"),
			material = Enum.Material.Neon,
			canCollide = false,
		})
		Kit.light(orb, orb.Color, 10)
	end
	Kit.addObstacle(Vector3.new(ra.x, 0, ra.z), ra.radius + 2)

	-- Leaderboard boards (text drawn by each client from published data).
	local titles = { Richest = "RICHEST", Rebirths = "MOST REBIRTHS", Rarest = "RAREST FIND" }
	for i, board in { "Richest", "Rebirths", "Rarest" } do
		local x = L.leaderboards.xs[i]
		local z = L.leaderboards.z
		for _, dx in { -8.5, 8.5 } do
			part(base, {
				name = "BoardPost",
				size = Vector3.new(1, 22, 1),
				cframe = CFrame.new(x + dx, L.beachHeight + 11, z + 0.8),
				color = WOOD,
				material = Enum.Material.Wood,
			})
		end
		part(base, {
			name = "BoardRoof",
			size = Vector3.new(19, 0.8, 3),
			cframe = CFrame.new(x, L.beachHeight + 21.6, z + 0.4),
			color = WOOD_DARK,
			material = Enum.Material.WoodPlanks,
		})
		local panel = part(base, {
			name = "Board_" .. board,
			size = Vector3.new(17, 14, 0.6),
			cframe = CFrame.new(x, L.beachHeight + 14, z),
			color = hex("#2B2323"),
			material = Enum.Material.SmoothPlastic,
		})
		panel:SetAttribute("Leaderboard", board)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(510, 420)
		gui.LightInfluence = 0
		gui.Parent = panel
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 56)
		title.Font = Enum.Font.LuckiestGuy
		title.Text = titles[board]
		title.TextScaled = true
		title.TextColor3 = hex("#FFC933")
		title.Parent = gui
		local mode = Instance.new("TextLabel")
		mode.Name = "Mode"
		mode.BackgroundTransparency = 1
		mode.Position = UDim2.fromOffset(0, 56)
		mode.Size = UDim2.new(1, 0, 0, 28)
		mode.Font = Enum.Font.FredokaOne
		mode.Text = "ALL TIME"
		mode.TextScaled = true
		mode.TextColor3 = Color3.new(1, 1, 1)
		mode.Parent = gui
		local rows = Instance.new("TextLabel")
		rows.Name = "Rows"
		rows.BackgroundTransparency = 1
		rows.Position = UDim2.fromOffset(16, 92)
		rows.Size = UDim2.new(1, -32, 1, -100)
		rows.Font = Enum.Font.FredokaOne
		rows.Text = "Loading..."
		rows.TextSize = 26
		rows.TextXAlignment = Enum.TextXAlignment.Left
		rows.TextYAlignment = Enum.TextYAlignment.Top
		rows.TextColor3 = Color3.new(1, 1, 1)
		rows.Parent = gui
	end

	-- Trophy shelf: a pedestal per slot; TrophyShelfService fills them.
	local shelf = L.trophyShelf
	part(base, {
		name = "ShelfBoard",
		size = Vector3.new(shelf.maxX - shelf.minX + 5, 1.2, 3.4),
		cframe = CFrame.new((shelf.minX + shelf.maxX) / 2, DECK_TOP + 0.6, shelf.z),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
	})
	local shelfSign = part(base, {
		name = "ShelfSign",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new((shelf.minX + shelf.maxX) / 2, DECK_TOP + 8, shelf.z),
		transparency = 1,
		canCollide = false,
	})
	Kit.billboard(shelfSign, "TROPHY SHELF", "Everyone's rarest find", hex("#FFC933"), 0, 12)
	for i = 1, CollectionConfig.shelfSlots do
		local x = shelf.minX
			+ (i - 1) * (shelf.maxX - shelf.minX) / math.max(1, CollectionConfig.shelfSlots - 1)
		part(base, {
			name = "ShelfPedestal",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.6, 2.6, 2.6),
			cframe = CFrame.new(x, DECK_TOP + 2, shelf.z) * CFrame.Angles(0, 0, math.rad(90)),
			color = hex("#F2E6C9"),
			material = Enum.Material.Marble,
		})
	end

	-- Lanterns, bunting and planters.
	for _, p in
		{
			{ b.minX + 2, b.minZ + 2 },
			{ b.maxX - 2, b.minZ + 2 },
			{ b.minX + 2, b.maxZ - 2 },
			{ b.maxX - 2, b.maxZ - 2 },
		}
	do
		lantern(base, Vector3.new(p[1], DECK_TOP, p[2]))
	end
	bunting(
		base,
		Vector3.new(-13, DECK_TOP + 14.5, archZ),
		Vector3.new(-sp.size / 2 - 0.5, DECK_TOP + 9.8, sp.z)
	)
	bunting(
		base,
		Vector3.new(13, DECK_TOP + 14.5, archZ),
		Vector3.new(sp.size / 2 + 0.5, DECK_TOP + 9.8, sp.z)
	)
	bunting(base, Vector3.new(b.minX + 2, DECK_TOP + 7.2, b.minZ + 2), Vector3.new(-13, DECK_TOP + 14, archZ))
	bunting(base, Vector3.new(b.maxX - 2, DECK_TOP + 7.2, b.minZ + 2), Vector3.new(13, DECK_TOP + 14, archZ))
	for _, p in { { -20, 104 }, { 20, 104 }, { -35, 146 }, { 35, 146 } } do
		planter(base, Vector3.new(p[1], DECK_TOP, p[2]), rng)
	end

	return base
end

return Base
