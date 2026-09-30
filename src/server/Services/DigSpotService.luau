--!strict
-- Shared, respawning dig spots. Each enabled area keeps `activeSpots` spots on
-- random candidate points. A dug-out spot disappears and a new one appears
-- elsewhere after a short delay. Spot models are pooled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local DigConfig = require(ReplicatedStorage.Shared.Config.Dig)
local Loot = require(ReplicatedStorage.Shared.Config.Loot)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local World = require(script.Parent.Parent.World.World)

export type Spot = {
	id: number,
	areaId: string,
	position: Vector3,
	candidateIndex: number,
	model: Model,
	clue: string?,
}

local DigSpotService = {}

local spotsFolder: Folder
local active: { [number]: Spot } = {}
local occupied: { [string]: { [number]: boolean } } = {}
local nearBase: { [string]: { [number]: boolean } } = {}
local pool: { Model } = {}
local nextId = 0
local rng = Random.new()

local MOUND_COLOR = Color3.fromRGB(150, 98, 52)
local MARK_COLOR = Color3.fromRGB(120, 40, 25)

local function newModel(): Model
	local model = Instance.new("Model")
	model.Name = "DigSpot"

	local mound = Instance.new("Part")
	mound.Name = "Mound"
	mound.Shape = Enum.PartType.Cylinder
	mound.Size = Vector3.new(0.9, 5.5, 5.5)
	mound.Color = MOUND_COLOR
	mound.Material = Enum.Material.Ground
	mound.Anchored = true
	mound.CanCollide = false
	mound.CanTouch = false
	mound.TopSurface = Enum.SurfaceType.Smooth
	mound.BottomSurface = Enum.SurfaceType.Smooth
	mound.Parent = model
	model.PrimaryPart = mound

	for i, angle in { 45, -45 } do
		local mark = Instance.new("Part")
		mark.Name = "Mark" .. i
		mark.Size = Vector3.new(0.7, 0.2, 3.6)
		mark.Color = MARK_COLOR
		mark.Material = Enum.Material.SmoothPlastic
		mark.Anchored = true
		mark.CanCollide = false
		mark.CanQuery = false
		mark.CanTouch = false
		mark:SetAttribute("Angle", angle)
		mark.Parent = model
	end
	return model
end

local CLUE_COLORS: { [string]: Color3 } = {
	Sparkle = Color3.fromRGB(255, 214, 80),
	Bone = Color3.fromRGB(255, 250, 235),
	Gem = Color3.fromRGB(90, 235, 255),
	Glow = Color3.fromRGB(255, 150, 60),
	OddDirt = Color3.fromRGB(255, 110, 90),
	Symbol = Color3.fromRGB(190, 110, 255),
}

local function cluePart(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Builds the clue decoration: a sparkle, light and floating marker that read
-- from a distance, plus a small prop that says what kind of clue it is.
local function decorateClue(folder: Folder, position: Vector3, clueType: string)
	local color = CLUE_COLORS[clueType] or CLUE_COLORS.Sparkle
	local top = position + Vector3.new(0, 0.8, 0)

	local anchor = cluePart(
		folder,
		Vector3.new(0.4, 0.4, 0.4),
		CFrame.new(top + Vector3.new(0, 1, 0)),
		color,
		Enum.Material.Neon
	)
	anchor.Transparency = 1
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	sparkles.LightEmission = 1
	sparkles.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Lifetime = NumberRange.new(1, 1.6)
	sparkles.Speed = NumberRange.new(1.5, 3)
	sparkles.SpreadAngle = Vector2.new(35, 35)
	sparkles.Rate = if clueType == "Sparkle" then 14 else 6
	sparkles.Parent = anchor
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 1.6
	light.Parent = anchor

	-- Floating marker, sized in studs so it shrinks naturally with distance.
	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromScale(3, 3)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	marker.MaxDistance = 220
	marker.LightInfluence = 0
	marker.Adornee = anchor
	marker.Parent = anchor
	local glyph = Instance.new("TextLabel")
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Font = Enum.Font.LuckiestGuy
	glyph.Text = "✦"
	glyph.TextScaled = true
	glyph.TextColor3 = color
	glyph.Parent = marker
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(60, 35, 10)
	stroke.Parent = glyph

	if clueType == "Bone" then
		local bone = CFrame.new(top + Vector3.new(0.8, 0.1, 0))
			* CFrame.Angles(math.rad(-20), math.rad(30), 0)
		cluePart(folder, Vector3.new(0.35, 0.35, 2.4), bone, color, Enum.Material.SmoothPlastic)
		for _, z in { -1.2, 1.2 } do
			cluePart(
				folder,
				Vector3.new(0.6, 0.6, 0.6),
				bone * CFrame.new(0, 0, z),
				color,
				Enum.Material.SmoothPlastic,
				Enum.PartType.Ball
			)
		end
	elseif clueType == "Gem" then
		local gem = CFrame.new(top + Vector3.new(-0.9, 0, 0.6))
			* CFrame.Angles(math.rad(45), math.rad(20), math.rad(45))
		cluePart(folder, Vector3.new(1.1, 1.1, 1.1), gem, color, Enum.Material.Neon)
	elseif clueType == "Glow" then
		local ringCf = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local ring = cluePart(
			folder,
			Vector3.new(0.2, 7, 7),
			ringCf,
			color,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		ring.Transparency = 0.45
	elseif clueType == "OddDirt" then
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local pebble = CFrame.new(top + Vector3.new(math.cos(a) * 1.8, -0.1, math.sin(a) * 1.8))
				* CFrame.Angles(0, a, 0.3)
			cluePart(
				folder,
				Vector3.new(0.7, 0.5, 0.7),
				pebble,
				Color3.fromRGB(120, 50, 35),
				Enum.Material.Ground
			)
		end
	elseif clueType == "Symbol" then
		for _, angle in { 0, 90 } do
			local bar = CFrame.new(top + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.rad(angle + 45), 0)
			cluePart(folder, Vector3.new(0.3, 0.12, 3.2), bar, color, Enum.Material.Neon)
		end
	end
end

local function placeModel(model: Model, position: Vector3, clueType: string?)
	local old = model:FindFirstChild("Clue")
	if old then
		old:Destroy()
	end
	local mound = model:FindFirstChild("Mound") :: BasePart
	mound.Color = if clueType == "OddDirt" then Color3.fromRGB(125, 62, 40) else MOUND_COLOR
	if clueType then
		local folder = Instance.new("Folder")
		folder.Name = "Clue"
		decorateClue(folder, position, clueType)
		folder.Parent = model
	end
	mound.CFrame = CFrame.new(position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	for _, child in model:GetChildren() do
		local angle = child:GetAttribute("Angle")
		if child:IsA("BasePart") and angle then
			child.CFrame = CFrame.new(position + Vector3.new(0, 0.78, 0))
				* CFrame.Angles(0, math.rad(angle :: number), 0)
		end
	end
end

local function playersNear(position: Vector3, distance: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if
			root
			and Zones.flatDistance(root.Position.X, root.Position.Z, position.X, position.Z) < distance
		then
			return true
		end
	end
	return false
end

local function spacedFromActive(position: Vector3): boolean
	for _, spot in active do
		if
			Zones.flatDistance(spot.position.X, spot.position.Z, position.X, position.Z)
			< DigConfig.minSpotSpacing
		then
			return false
		end
	end
	return true
end

local function countActiveNearBase(areaId: string): number
	local count = 0
	for _, spot in active do
		if spot.areaId == areaId and nearBase[areaId][spot.candidateIndex] then
			count += 1
		end
	end
	return count
end

-- Picks a free candidate index for an area, or nil if none fits right now.
local function pickCandidate(areaId: string): number?
	local candidates = World.get().candidates[areaId]
	local taken = occupied[areaId]
	local preferNear = countActiveNearBase(areaId) < DigConfig.minNearBaseSpots

	local function collect(onlyNear: boolean, checkPlayers: boolean): { number }
		local list = {}
		for index, position in candidates do
			if
				not taken[index]
				and (not onlyNear or nearBase[areaId][index])
				and spacedFromActive(position)
			then
				if not checkPlayers or not playersNear(position, DigConfig.minPlayerDistance) then
					table.insert(list, index)
				end
			end
		end
		return list
	end

	local options = if preferNear then collect(true, true) else {}
	if #options == 0 then
		options = collect(false, true)
	end
	if #options == 0 then
		options = collect(false, false)
	end
	if #options == 0 then
		return nil
	end
	return options[rng:NextInteger(1, #options)]
end

local function spawnSpot(areaId: string): Spot?
	local index = pickCandidate(areaId)
	if not index then
		return nil
	end
	local position = World.get().candidates[areaId][index]
	nextId += 1
	local clue: string? = nil
	if rng:NextNumber() < Loot.clueChance then
		clue = Loot.clueTypes[rng:NextInteger(1, #Loot.clueTypes)]
	end
	local model = table.remove(pool) or newModel()
	placeModel(model, position, clue)
	model:SetAttribute("SpotId", nextId)
	model:SetAttribute("AreaId", areaId)
	model:SetAttribute("Clue", clue)
	local spot: Spot = {
		id = nextId,
		areaId = areaId,
		position = position,
		candidateIndex = index,
		model = model,
		clue = clue,
	}
	occupied[areaId][index] = true
	active[nextId] = spot
	model.Parent = spotsFolder
	return spot
end

local function scheduleRespawn(areaId: string)
	task.delay(rng:NextNumber(DigConfig.respawnMin, DigConfig.respawnMax), function()
		if not spawnSpot(areaId) then
			scheduleRespawn(areaId) -- no free point right now; try again later
		end
	end)
end

function DigSpotService.get(spotId: number): Spot?
	return active[spotId]
end

-- Removes a dug-out spot and schedules a replacement in the same area.
function DigSpotService.consume(spotId: number)
	local spot = active[spotId]
	if not spot then
		return
	end
	active[spotId] = nil
	occupied[spot.areaId][spot.candidateIndex] = nil
	spot.model.Parent = nil
	table.insert(pool, spot.model)
	scheduleRespawn(spot.areaId)
end

function DigSpotService.init()
	spotsFolder = Instance.new("Folder")
	spotsFolder.Name = "DigSpots"
	spotsFolder.Parent = workspace
end

function DigSpotService.start()
	local world = World.get()
	for _, areaId in Areas.Order do
		occupied[areaId] = {}
		nearBase[areaId] = {}
		for index, position in world.candidates[areaId] do
			local d = Zones.flatDistance(position.X, position.Z, world.baseFront.X, world.baseFront.Z)
			if d <= DigConfig.nearSpawnMax + 2 then
				nearBase[areaId][index] = true
			end
		end
		local def = Areas.Defs[areaId]
		if def.enabled then
			local count = math.min(def.activeSpots, #world.candidates[areaId])
			for _ = 1, count do
				spawnSpot(areaId)
			end
		end
	end
end

return DigSpotService
