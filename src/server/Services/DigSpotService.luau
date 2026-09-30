--!strict
-- Shared, respawning dig spots. Each enabled area keeps `activeSpots` spots on
-- random candidate points. A dug-out spot disappears and a new one appears
-- elsewhere after a short delay. Spot models are pooled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local DigConfig = require(ReplicatedStorage.Shared.Config.Dig)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local World = require(script.Parent.Parent.World.World)

export type Spot = {
	id: number,
	areaId: string,
	position: Vector3,
	candidateIndex: number,
	model: Model,
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

local function placeModel(model: Model, position: Vector3)
	local mound = model:FindFirstChild("Mound") :: BasePart
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
	local model = table.remove(pool) or newModel()
	placeModel(model, position)
	model:SetAttribute("SpotId", nextId)
	model:SetAttribute("AreaId", areaId)
	local spot: Spot =
		{ id = nextId, areaId = areaId, position = position, candidateIndex = index, model = model }
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
