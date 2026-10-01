--!strict
-- The Frost Portal to the next world (Config/Worlds), on the beach where it
-- rises into view from the spawn: an ice ring on a frosted stone dais with
-- three rebirth seals on top, a glimpse of the snowy world inside it, ice
-- crystals and snow around it, a beam of light into the sky, a sign, and
-- the First Explorers board (filled in by WorldPortalService). Clients
-- light the seals and animate the glimpse (PortalController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)
local Kit = require(script.Parent.Kit)

local L = Kit.L
local part, hex = Kit.part, Kit.hex

local Portal = {}

local ICE = hex("#A8E6FF")
local ICE_DEEP = hex("#5CC6F2")
local FROST_STONE = hex("#8FA6B8")
local SNOW = hex("#F4FBFF")
local SEAL_OFF = hex("#3B4A5A")

-- The view through the portal: a snowy sky with aurora, white peaks and
-- snowy ground, clipped to a circle. Snowflakes and the swirl are added
-- and animated by the client.
local function glimpse(face: BasePart, normal: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Glimpse"
	gui.Face = normal
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = face

	local view = Instance.new("CanvasGroup")
	view.Name = "View"
	view.Size = UDim2.fromScale(1, 1)
	view.BackgroundColor3 = hex("#BFEFFF")
	view.BorderSizePixel = 0
	view.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = view
	local sky = Instance.new("UIGradient")
	sky.Rotation = 90
	sky.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex("#4E7FD8")),
		ColorSequenceKeypoint.new(0.55, hex("#9EDCFF")),
		ColorSequenceKeypoint.new(1, hex("#E8F8FF")),
	})
	sky.Parent = view

	local function frame(props: { [string]: any }): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		for key, value in props do
			(f :: any)[key] = value
		end
		f.Parent = view
		return f
	end
	-- Aurora.
	local aurora = frame({
		Name = "Aurora",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromScale(1.2, 0.12),
		Rotation = -8,
		BackgroundColor3 = hex("#6CFFC4"),
		BackgroundTransparency = 0.35,
	})
	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new(hex("#6CFFC4"), hex("#B98CFF"))
	glow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	glow.Parent = aurora
	-- Peaks: rotated squares, back row paler.
	for _, peak in
		{
			{ 0.15, 0.62, 0.42, "#C9DDF0" },
			{ 0.85, 0.6, 0.46, "#C9DDF0" },
			{ 0.5, 0.56, 0.5, "#E6F2FF" },
			{ 0.3, 0.7, 0.36, "#FFFFFF" },
			{ 0.72, 0.72, 0.34, "#FFFFFF" },
		}
	do
		local p = frame({
			Name = "Peak",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(peak[1], peak[2] - peak[3] * 0.35),
			Size = UDim2.fromScale(peak[3] * 0.72, peak[3] * 0.72),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Rotation = 45,
			BackgroundColor3 = hex(peak[4]),
		})
		local shade = Instance.new("UIGradient")
		shade.Rotation = 45
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), hex("#A9C8E6"))
		shade.Parent = p
	end
	frame({
		Name = "Ground",
		Position = UDim2.fromScale(0, 0.8),
		Size = UDim2.fromScale(1, 0.2),
		BackgroundColor3 = SNOW,
	})
	-- The portal's swirl over the view (turned by the client).
	local swirl = frame({
		Name = "Swirl",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.5, 1.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		ZIndex = 5,
	})
	local swirlGradient = Instance.new("UIGradient")
	swirlGradient.Color = ColorSequence.new(hex("#CFF6FF"), hex("#7FDBFF"))
	swirlGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	swirlGradient.Parent = swirl
end

-- A cluster of ice crystals at `base`.
local function crystals(parent: Instance, base: Vector3, rng: Random, scale: number)
	for i = 1, 3 do
		local height = rng:NextNumber(3, 6) * scale
		local tiltX = rng:NextNumber(-0.35, 0.35)
		local tiltZ = rng:NextNumber(-0.35, 0.35)
		local offset = Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2)) * scale
		part(parent, {
			name = "IceCrystal",
			size = Vector3.new(1.1 * scale, height, 1.1 * scale),
			cframe = CFrame.new(base + offset)
				* CFrame.Angles(tiltX, rng:NextNumber(0, math.pi) + i, tiltZ)
				* CFrame.new(0, height / 2 - 0.4, 0),
			color = if i == 1 then ICE_DEEP else ICE,
			material = Enum.Material.Glass,
			transparency = 0.15,
			reflectance = 0.2,
			canCollide = false,
		})
	end
end

export type Built = {
	model: Model,
	center: Vector3, -- the middle of the ring
	ground: number, -- the top of the dais
	normal: Vector3, -- the way the portal faces (toward the spawn)
}

function Portal.build(rng: Random): Built
	local cfg = Worlds.portal
	local p = L.portal
	local R = cfg.ringRadius
	local groundY = Kit.highestGround(p.x, p.z, 12, L.beachHeight)
	local toSpawn = Vector3.new(L.spawn.x - p.x, 0, L.spawn.z - p.z).Unit
	local n = toSpawn
	local up = Vector3.new(0, 1, 0)
	local right = up:Cross(-n).Unit
	local model = Instance.new("Model")
	model.Name = "FrostPortal"

	-- Frost on the sand, and the stone dais with a step.
	part(model, {
		name = "Frost",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, 46, 46),
		cframe = CFrame.new(p.x, groundY + 0.05, p.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = SNOW,
		material = Enum.Material.Snow,
		canCollide = false,
	})
	local daisTop = groundY + 2
	part(model, {
		name = "Dais",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(3, 24, 24),
		cframe = CFrame.new(p.x, daisTop - 1.5, p.z) * CFrame.Angles(0, 0, math.rad(90)),
		color = FROST_STONE,
		material = Enum.Material.Slate,
	})
	local origin = Vector3.new(p.x, daisTop, p.z)
	part(model, {
		name = "Step",
		size = Vector3.new(10, 1, 4),
		cframe = CFrame.fromMatrix(origin + n * 13 - Vector3.new(0, 1.5, 0), right, Vector3.yAxis),
		color = FROST_STONE,
		material = Enum.Material.Slate,
	})

	-- The ice ring, standing on the dais and facing the spawn.
	local center = origin + Vector3.new(0, R + 0.6, 0)
	local segments = 24
	local segLength = 2 * math.pi * R / segments + 0.35
	for i = 0, segments - 1 do
		local a = (i + 0.5) / segments * math.pi * 2
		local radial = right * math.cos(a) + Vector3.yAxis * math.sin(a)
		local tangent = -right * math.sin(a) + Vector3.yAxis * math.cos(a)
		part(model, {
			name = "Ring",
			size = Vector3.new(segLength, 2.4, 2.6),
			cframe = CFrame.fromMatrix(center + radial * R, tangent, radial),
			color = ICE,
			material = Enum.Material.Ice,
			reflectance = 0.1,
		})
		part(model, {
			name = "RingGlow",
			size = Vector3.new(segLength, 0.5, 2.8),
			cframe = CFrame.fromMatrix(center + radial * (R - 1.3), tangent, radial),
			color = ICE_DEEP,
			material = Enum.Material.Neon,
			canCollide = false,
			castShadow = false,
		})
	end
	-- Feet that hold the ring on the dais.
	for _, side in { -1, 1 } do
		part(model, {
			name = "Foot",
			size = Vector3.new(3, 3, 4),
			cframe = CFrame.fromMatrix(
				origin + right * side * (R * 0.55) + Vector3.new(0, 1.2, 0),
				right,
				Vector3.yAxis
			),
			color = FROST_STONE,
			material = Enum.Material.Slate,
		})
	end

	-- The view through it (both sides) and its cold light.
	local face = part(model, {
		name = "PortalFace",
		size = Vector3.new(2 * R - 1.8, 2 * R - 1.8, 0.2),
		cframe = CFrame.fromMatrix(center, right, Vector3.yAxis),
		color = ICE,
		transparency = 1,
		canCollide = false,
		castShadow = false,
	})
	glimpse(face, Enum.NormalId.Front)
	glimpse(face, Enum.NormalId.Back)
	Kit.light(face, ICE_DEEP, 32, 2.5)

	-- Three rebirth seals across the top of the ring.
	for i, angle in { 55, 90, 125 } do
		local a = math.rad(angle)
		local radial = right * math.cos(a) + Vector3.yAxis * math.sin(a)
		local seal = part(model, {
			name = "Seal" .. i,
			-- A diamond-shaped gem set into the ring.
			size = Vector3.new(2.4, 2.4, 1.4),
			cframe = CFrame.fromMatrix(
				center + radial * (R + 1.9),
				(right + Vector3.yAxis).Unit,
				(Vector3.yAxis - right).Unit
			),
			color = SEAL_OFF,
			material = Enum.Material.Slate,
		})
		seal:SetAttribute("Seal", i)
	end

	-- A beam of light into the sky, seen from across the island.
	part(model, {
		name = "Beacon",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(220, 5, 5),
		cframe = CFrame.new(center + Vector3.new(0, R + 116, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = ICE,
		material = Enum.Material.Neon,
		transparency = 0.4,
		canCollide = false,
		castShadow = false,
	})

	-- Ice crystals around the dais, and falling snow.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.3
		local at = Vector3.new(p.x + math.cos(a) * 17, groundY, p.z + math.sin(a) * 17)
		if (at - (origin + n * 13)).Magnitude > 6 then
			crystals(model, at, rng, if i % 2 == 0 then 1.2 else 0.8)
		end
	end
	local snow =
		Kit.volume(model, "Snowfall", CFrame.new(center + Vector3.new(0, 18, 0)), Vector3.new(36, 1, 36))
	Kit.emitter(snow, {
		color = SNOW,
		rate = 18,
		lifetime = NumberRange.new(7, 9),
		size = NumberSequence.new(0.35),
		speed = NumberRange.new(2, 3),
		acceleration = Vector3.new(0.4, -0.6, 0),
		direction = Enum.NormalId.Bottom,
		spread = Vector2.new(15, 15),
		transparency = NumberSequence.new(0.1, 0.6),
		lightEmission = 0.3,
	})

	-- The sign (the client writes your progress on its small board) and
	-- the First Explorers board, either side of the step.
	local w = Worlds.next
	Kit.standingSign(
		model,
		origin + n * 16 - right * 11 - Vector3.new(0, 2, 0),
		n,
		"❄️ FROST PORTAL",
		string.format("Rebirth %d to enter", w.requiredRebirths),
		hex(w.color),
		11
	)
	local boardFrame =
		CFrame.fromMatrix(origin + n * 15 + right * 12 + Vector3.new(0, 3.5, 0), right, Vector3.yAxis)
	local board = part(model, {
		name = "ExplorersBoard",
		size = Vector3.new(10, 9, 0.6),
		cframe = boardFrame,
		color = hex("#3E5A73"),
		material = Enum.Material.Slate,
	})
	for _, side in { -1, 1 } do
		part(model, {
			name = "BoardLeg",
			size = Vector3.new(0.7, 4, 0.7),
			cframe = boardFrame * CFrame.new(side * 4.4, -6, 0),
			color = FROST_STONE,
			material = Enum.Material.Slate,
		})
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Explorers"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.CanvasSize = Vector2.new(400, 360)
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 64)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.Text = "❄️ FIRST EXPLORERS"
	title.TextScaled = true
	title.TextColor3 = hex(w.color)
	title.Parent = gui
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(20, 70)
	list.Size = UDim2.new(1, -40, 1, -84)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.FredokaOne
	list.Text = "Be the first!\nReach Rebirth " .. w.requiredRebirths
	list.TextScaled = true
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Parent = gui

	model:SetAttribute("Center", center)
	model:SetAttribute("Normal", n)
	model:SetAttribute("Ground", daisTop)
	model.Parent = workspace
	Kit.addObstacle(Vector3.new(p.x, 0, p.z), 28)
	return { model = model, center = center, ground = daisTop, normal = n }
end

return Portal
