--!strict
-- Makes the island feel alive, entirely on this client: seagulls over the
-- beach, parrots over the jungle, vultures over the ruins and volcano,
-- butterflies, crabs on the shore, fish jumping out of the sea, and the
-- animated decor the world builder tags with an "Ambient" attribute
-- (Spin, Float, Bob, Beam). Also loops each area's ambience sound when an
-- id is set in AssetIds.
--
-- Cheap by design: creatures are a few small parts, only creatures near the
-- camera are updated, and all moves go through one BulkMoveTo per frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)

local AmbientController = {}

local UPDATE_DISTANCE = 420
local L = MapLayout

type Creature = {
	parts: { BasePart },
	-- Returns the root CFrame and each part's offset from it at time t.
	pose: (t: number) -> (CFrame, { CFrame }),
	center: Vector3,
}

local creatures: { Creature } = {}
local decor: { { part: BasePart, kind: string, base: CFrame, phase: number, pivot: Vector3? } } = {}
local folder: Folder
local rng = Random.new()

local function newPart(size: Vector3, color: Color3, material: Enum.Material?, sphere: boolean?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = CFrame.new(0, -500, 0) -- out of sight until first posed
	if sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = folder
	return p
end

local function groundAt(x: number, z: number): (number?, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -700, 0), params)
	if hit then
		return hit.Position.Y, hit.Material
	end
	return nil, nil
end

---------------------------------------------------------------------------
-- Birds
---------------------------------------------------------------------------

type BirdStyle = {
	body: Color3,
	wing: Color3,
	head: Color3,
	beak: Color3,
	scale: number,
	flap: number,
	glide: number,
}

local function bird(center: Vector3, radius: number, speed: number, style: BirdStyle)
	local s = style.scale
	local body = newPart(Vector3.new(1.2, 1, 2.6) * s, style.body, nil, true)
	local head = newPart(Vector3.new(0.9, 0.9, 0.9) * s, style.head, nil, true)
	local beak = newPart(Vector3.new(0.3, 0.3, 0.7) * s, style.beak)
	local wingL = newPart(Vector3.new(3.4, 0.15, 1.3) * s, style.wing)
	local wingR = newPart(Vector3.new(3.4, 0.15, 1.3) * s, style.wing)
	local tail = newPart(Vector3.new(0.9, 0.15, 1.2) * s, style.wing)
	local phase = rng:NextNumber(0, math.pi * 2)
	local climb = rng:NextNumber(2, 6)
	local direction = if rng:NextNumber() < 0.5 then 1 else -1
	table.insert(creatures, {
		parts = { body, head, beak, wingL, wingR, tail },
		center = center,
		pose = function(t: number)
			local a = phase + t * speed * direction / radius
			local pos = center
				+ Vector3.new(math.cos(a) * radius, math.sin(t * 0.4 + phase) * climb, math.sin(a) * radius)
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * direction
			local root = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, -0.35 * direction)
			-- Flap in bursts, glide in between.
			local flapping = math.sin(t * 0.7 + phase) > style.glide
			local flap = if flapping then math.sin(t * style.flap + phase) * 0.6 else 0.12
			return root,
				{
					CFrame.new(),
					CFrame.new(0, 0.35 * s, -1.4 * s),
					CFrame.new(0, 0.3 * s, -2.05 * s),
					CFrame.new(-1.6 * s, 0.2 * s, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.1 * s, 0, 0),
					CFrame.new(1.6 * s, 0.2 * s, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.1 * s, 0, 0),
					CFrame.new(0, 0.05 * s, 1.6 * s),
				}
		end,
	})
end

---------------------------------------------------------------------------
-- Butterflies, crabs, fish
---------------------------------------------------------------------------

local BUTTERFLY_COLORS = {
	Color3.fromRGB(255, 120, 190),
	Color3.fromRGB(255, 213, 74),
	Color3.fromRGB(92, 200, 255),
	Color3.fromRGB(180, 92, 255),
	Color3.fromRGB(255, 138, 61),
}

local function butterfly(anchor: Vector3)
	local color = BUTTERFLY_COLORS[rng:NextInteger(1, #BUTTERFLY_COLORS)]
	local wingL = newPart(Vector3.new(0.7, 0.05, 0.6), color, Enum.Material.Neon)
	local wingR = newPart(Vector3.new(0.7, 0.05, 0.6), color, Enum.Material.Neon)
	local phase = rng:NextNumber(0, 100)
	local rx, rz = rng:NextNumber(3, 7), rng:NextNumber(3, 7)
	table.insert(creatures, {
		parts = { wingL, wingR },
		center = anchor,
		pose = function(t: number)
			local u = t * 0.5 + phase
			local pos = anchor
				+ Vector3.new(math.sin(u) * rx, 1.5 + math.sin(u * 2.3) * 1.2, math.sin(u * 0.7) * rz)
			local ahead = anchor + Vector3.new(math.sin(u + 0.1) * rx, 1.5, math.sin((u + 0.1) * 0.7) * rz)
			local root = CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z))
			local flap = math.sin(t * 22 + phase) * 1.1
			return root,
				{
					CFrame.Angles(0, 0, flap) * CFrame.new(-0.35, 0, 0),
					CFrame.Angles(0, 0, -flap) * CFrame.new(0.35, 0, 0),
				}
		end,
	})
end

local function crab(home: Vector3)
	local red = Color3.fromRGB(230, 80, 60)
	local body = newPart(Vector3.new(1.6, 0.7, 1.2), red, nil, true)
	local clawL = newPart(Vector3.new(0.5, 0.5, 0.5), red, nil, true)
	local clawR = newPart(Vector3.new(0.5, 0.5, 0.5), red, nil, true)
	local eyeL = newPart(Vector3.new(0.18, 0.4, 0.18), Color3.fromRGB(30, 30, 30))
	local eyeR = newPart(Vector3.new(0.18, 0.4, 0.18), Color3.fromRGB(30, 30, 30))
	local yaw = rng:NextNumber(0, math.pi * 2)
	local phase = rng:NextNumber(0, 100)
	local side = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	table.insert(creatures, {
		parts = { body, clawL, clawR, eyeL, eyeR },
		center = home,
		pose = function(t: number)
			-- Scuttle sideways back and forth, pausing at each end.
			local u = math.clamp(math.sin(t * 0.6 + phase) * 1.4, -1, 1)
			local pos = home + side * u * 4 + Vector3.new(0, 0.35 + math.abs(math.sin(t * 14)) * 0.08, 0)
			local root = CFrame.lookAt(pos, pos + Vector3.new(-side.Z, 0, side.X))
			local snip = math.max(0, math.sin(t * 6 + phase)) * 0.3
			return root,
				{
					CFrame.new(),
					CFrame.new(-0.9, 0.1, -0.6 - snip),
					CFrame.new(0.9, 0.1, -0.6 - snip),
					CFrame.new(-0.3, 0.45, -0.4),
					CFrame.new(0.3, 0.45, -0.4),
				}
		end,
	})
end

-- One fish that keeps jumping out of the sea somewhere near the camera.
local function jumpingFish()
	local color = if rng:NextNumber() < 0.5
		then Color3.fromRGB(255, 170, 60)
		else Color3.fromRGB(90, 190, 255)
	local body = newPart(Vector3.new(0.6, 1, 2.2), color, nil, true)
	local tailFin = newPart(Vector3.new(0.12, 1, 0.8), color)
	local start = Vector3.zero
	local dir = Vector3.new(0, 0, 1)
	local jumpAt = -10
	local hidden = CFrame.new(0, -500, 0)
	local creature: Creature
	creature = {
		parts = { body, tailFin },
		center = Vector3.zero,
		pose = function(t: number)
			if t > jumpAt + 1.2 then
				-- Pick the next jump: open water 50-150 studs from the camera.
				local camera = workspace.CurrentCamera
				local origin = if camera then camera.CFrame.Position else Vector3.zero
				for _ = 1, 6 do
					local a = rng:NextNumber(0, math.pi * 2)
					local d = rng:NextNumber(50, 150)
					local x, z = origin.X + math.cos(a) * d, origin.Z + math.sin(a) * d
					local y, material = groundAt(x, z)
					if y and material == Enum.Material.Water then
						start = Vector3.new(x, L.waterLevel - 0.5, z)
						local h = rng:NextNumber(0, math.pi * 2)
						dir = Vector3.new(math.cos(h), 0, math.sin(h))
						break
					end
				end
				jumpAt = t + rng:NextNumber(1.5, 4)
				creature.center = start
			end
			local u = (t - jumpAt) / 1.2
			if u < 0 or u > 1 then
				return hidden, { CFrame.new(), CFrame.new(0, 0, 1.3) }
			end
			local pos = start + dir * (u * 9) + Vector3.new(0, 4.5 * (1 - (2 * u - 1) ^ 2), 0)
			local root = CFrame.lookAt(pos, pos + dir) * CFrame.Angles((0.5 - u) * 1.6, 0, 0)
			return root, { CFrame.new(), CFrame.new(0, 0, 1.3) * CFrame.Angles(0, math.sin(t * 30) * 0.5, 0) }
		end,
	}
	table.insert(creatures, creature)
end

---------------------------------------------------------------------------
-- Populate
---------------------------------------------------------------------------

local function spawnCreatures()
	local gull = {
		body = Color3.fromRGB(245, 245, 245),
		wing = Color3.fromRGB(205, 210, 220),
		head = Color3.fromRGB(250, 250, 250),
		beak = Color3.fromRGB(255, 190, 60),
		scale = 1,
		flap = 9,
		glide = 0.2,
	}
	for _, c in
		{
			{ -60, 50, 90, 34 },
			{ 90, 55, 60, 42 },
			{ 0, 40, 300, 30 },
			{ -170, 42, 220, 26 },
			{ 200, 50, 140, 36 },
			{ 40, 60, 0, 48 },
			{ -120, 46, 10, 30 },
			{ 140, 44, 280, 28 },
		}
	do
		bird(Vector3.new(c[1], c[2], c[3]), c[4], rng:NextNumber(10, 14), gull)
	end
	local parrots = {
		{ Color3.fromRGB(230, 50, 50), Color3.fromRGB(40, 110, 230) },
		{ Color3.fromRGB(40, 190, 80), Color3.fromRGB(255, 210, 60) },
		{ Color3.fromRGB(40, 140, 230), Color3.fromRGB(255, 200, 40) },
	}
	local y = L.plateauHeight
	for i, c in
		{
			{ -80, -90, 22 },
			{ -180, -180, 30 },
			{ -220, -80, 26 },
			{ -120, -210, 20 },
			{ -150, -130, 34 },
			{ -50, -170, 18 },
		}
	do
		local colors = parrots[(i % #parrots) + 1]
		bird(Vector3.new(c[1], y + rng:NextNumber(30, 46), c[2]), c[3], rng:NextNumber(12, 16), {
			body = colors[1],
			wing = colors[2],
			head = colors[1],
			beak = Color3.fromRGB(240, 220, 160),
			scale = 0.8,
			flap = 12,
			glide = 0.5,
		})
	end
	local vulture = {
		body = Color3.fromRGB(70, 55, 50),
		wing = Color3.fromRGB(45, 38, 36),
		head = Color3.fromRGB(220, 160, 150),
		beak = Color3.fromRGB(230, 210, 150),
		scale = 1.5,
		flap = 5,
		glide = 0.75,
	}
	bird(Vector3.new(150, y + 75, -170), 50, 9, vulture)
	bird(Vector3.new(90, y + 62, -90), 36, 8, vulture)
	bird(Vector3.new(-20, L.highlandHeight + 70, -330), 60, 9, vulture)
	bird(Vector3.new(120, L.highlandHeight + 60, -360), 40, 8, vulture)

	-- Butterflies near flowers on the beach and in the jungle.
	for _, c in
		{
			{ -40, 60 },
			{ 50, 40 },
			{ -120, 120 },
			{ 120, 180 },
			{ -80, 230 },
			{ 30, 120 },
			{ -60, -60 },
			{ -100, -160 },
			{ -200, -120 },
			{ -150, -220 },
			{ -40, -120 },
			{ -230, -200 },
			{ 214, -70 },
			{ 200, -110 },
		}
	do
		local gy = groundAt(c[1], c[2])
		if gy then
			for _ = 1, 2 do
				butterfly(Vector3.new(c[1] + rng:NextNumber(-6, 6), gy + 1, c[2] + rng:NextNumber(-6, 6)))
			end
		end
	end

	-- Crabs along the shore.
	local b = L.beach
	local placed = 0
	for _ = 1, 60 do
		if placed >= 12 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local d = b.radius + rng:NextNumber(-6, 4)
		local x, z = b.x + math.cos(a) * d, b.z + math.sin(a) * d
		local gy, material = groundAt(x, z)
		if gy and material == Enum.Material.Sand and z > L.beachNorthZ + 10 and gy > L.waterLevel + 0.5 then
			crab(Vector3.new(x, gy, z))
			placed += 1
		end
	end

	for _ = 1, 3 do
		jumpingFish()
	end
end

local function collectDecor()
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") then
			local kind = d:GetAttribute("Ambient")
			if
				type(kind) == "string"
				and (kind == "Spin" or kind == "Float" or kind == "Bob" or kind == "Beam")
			then
				local pivot = d:GetAttribute("Pivot")
				table.insert(decor, {
					part = d,
					kind = kind,
					base = d.CFrame,
					phase = rng:NextNumber(0, math.pi * 2),
					pivot = if typeof(pivot) == "Vector3" then pivot else nil,
				})
			end
		end
	end
end

local function decorCFrame(entry: any, t: number): CFrame
	local base: CFrame = entry.base
	local pos = base.Position
	local rotation = base - pos
	if entry.kind == "Spin" then
		return CFrame.new(pos) * CFrame.Angles(0, t * 1.2 + entry.phase, 0) * rotation
	elseif entry.kind == "Float" then
		return CFrame.new(pos + Vector3.new(0, math.sin(t * 1.4 + entry.phase) * 0.8, 0))
			* CFrame.Angles(0, t * 0.6, 0)
			* rotation
	elseif entry.kind == "Bob" then
		return CFrame.new(pos + Vector3.new(0, math.sin(t * 1.3 + entry.phase) * 0.35, 0))
			* CFrame.Angles(math.sin(t * 0.9 + entry.phase) * 0.08, 0, math.sin(t * 1.1) * 0.08)
			* rotation
	elseif entry.kind == "Beam" and entry.pivot then
		local pivot: Vector3 = entry.pivot
		return CFrame.new(pivot) * CFrame.Angles(0, t * 0.7, 0) * CFrame.new(0, 0, -(pos - pivot).Magnitude)
	end
	return base
end

---------------------------------------------------------------------------
-- Ambience sound per area
---------------------------------------------------------------------------

local ambience: { [string]: Sound } = {}
local currentArea: string? = nil

local function updateAmbience(position: Vector3)
	local area = Zones.areaAt(position.X, position.Z)
	if area == currentArea then
		return
	end
	currentArea = area
	local ids = (AssetIds :: any).Ambient or {}
	for id, sound in ambience do
		if id ~= area then
			sound:Stop()
		end
	end
	local soundId = ids[area]
	if type(soundId) == "string" and soundId ~= "" then
		local sound = ambience[area]
		if not sound then
			sound = Instance.new("Sound")
			sound.Name = "Ambience" .. area
			sound.SoundId = soundId
			sound.Looped = true
			sound.Volume = 0.35
			sound.Parent = SoundService
			ambience[area] = sound
		end
		sound:Play()
	end
end

---------------------------------------------------------------------------

function AmbientController.init()
	folder = Instance.new("Folder")
	folder.Name = "Ambient"
	folder.Parent = workspace
	task.spawn(function()
		-- Wait for the world (it's built by the server before anyone spawns).
		workspace:WaitForChild("Decor", 30)
		workspace:WaitForChild("Base", 30)
		spawnCreatures()
		collectDecor()
		local start = os.clock()
		local player = Players.LocalPlayer
		local lastAmbience = 0
		RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			local camera = workspace.CurrentCamera
			local camPos = if camera then camera.CFrame.Position else Vector3.zero
			local parts: { BasePart } = {}
			local cframes: { CFrame } = {}
			for _, c in creatures do
				if (c.center - camPos).Magnitude < UPDATE_DISTANCE then
					local root, offsets = c.pose(t)
					for i, p in c.parts do
						table.insert(parts, p)
						table.insert(cframes, root * offsets[i])
					end
				end
			end
			for _, entry in decor do
				if entry.part.Parent and (entry.base.Position - camPos).Magnitude < 600 then
					table.insert(parts, entry.part)
					table.insert(cframes, decorCFrame(entry, t))
				end
			end
			local ok = pcall(function()
				workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			end)
			if not ok then
				for i, p in parts do
					p.CFrame = cframes[i]
				end
			end
			if t - lastAmbience > 1 then
				lastAmbience = t
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					updateAmbience(root.Position)
				end
			end
		end)
	end)
end

return AmbientController
