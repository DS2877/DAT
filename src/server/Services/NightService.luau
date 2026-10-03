--!strict
-- Night (Config/DayNight): when the shared clock reaches night, the server
-- tells everyone and lights moonlit dig spots in every area (much better
-- odds, see LootService). A dug one comes back somewhere else while the
-- night lasts; at dawn the rest fade away. Admins can force a night
-- (workspace ForceNight) to test it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local DayNightConfig = require(ReplicatedStorage.Shared.Config.DayNight)
local DayNight = require(ReplicatedStorage.Shared.Logic.DayNight)
local AnnouncementService = require(script.Parent.AnnouncementService)
local DigSpotService = require(script.Parent.DigSpotService)
local World = require(script.Parent.Parent.World.World)

local NightService = {}

local night = false
local scheduled = true -- off: only a forced night counts (tests)
local moonlit: { [number]: string } = {} -- spot id -> area
local rng = Random.new()

function NightService.isNight(): boolean
	if workspace:GetAttribute("ForceNight") == true then
		return true
	end
	-- An admin can switch the cycle off (workspace NightCycleOff: always day).
	if workspace:GetAttribute("NightCycleOff") == true then
		return false
	end
	return scheduled and DayNight.isNight(workspace:GetServerTimeNow())
end

-- Follow the clock (default), or only forced nights (tests).
function NightService.setScheduled(on: boolean)
	scheduled = on
end

-- The glow that marks a moonlit spot: a pale beam into the sky and a light.
local function dress(model: Model, position: Vector3)
	local color = Color3.fromHex(DayNightConfig.moonlit.color)
	model:SetAttribute("Moonlit", true)
	local beam = Instance.new("Part")
	beam.Name = "MoonBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.7
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(40, 2.2, 2.2)
	beam.CFrame = CFrame.new(position + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = model
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 2
	light.Parent = beam
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(color)
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.Size = NumberSequence.new(0.5, 0)
	sparkles.LightEmission = 1
	sparkles.Parent = beam
end

-- A moonlit spot on a random free point of the area.
local function spawnIn(areaId: string)
	local points = World.get().candidates[areaId]
	if not points or #points == 0 then
		return
	end
	for _ = 1, 8 do
		local position = points[rng:NextInteger(1, #points)]
		local clear = true
		for _, spot in DigSpotService.list() do
			if (spot.position - position).Magnitude < 9 then
				clear = false
				break
			end
		end
		if clear then
			local spot = DigSpotService.spawnAt(position, areaId, { moonlit = true })
			dress(spot.model, position)
			moonlit[spot.id] = areaId
			return
		end
	end
end

local function begin()
	night = true
	workspace:SetAttribute("Night", true)
	for _, areaId in Areas.Order do
		if Areas.Defs[areaId].enabled then
			for _ = 1, DayNightConfig.moonlit.perArea do
				spawnIn(areaId)
			end
		end
	end
	AnnouncementService.announce({
		text = "🌙 Night falls... moonlit dig spots glow all over the island!",
		color = DayNightConfig.moonlit.color,
		secret = false,
	})
end

local function finish()
	night = false
	workspace:SetAttribute("Night", false)
	for id in moonlit do
		DigSpotService.remove(id)
	end
	table.clear(moonlit)
end

-- Called when a moonlit spot is dug: another one appears later (at night).
function NightService.onDug(spotId: number)
	local areaId = moonlit[spotId]
	if not areaId then
		return
	end
	moonlit[spotId] = nil
	task.delay(DayNightConfig.moonlit.respawn, function()
		if night then
			spawnIn(areaId)
		end
	end)
end

-- A moonlit spot at `position` (admins). It fades at dawn (in daytime,
-- after 5 minutes).
function NightService.spawnAt(position: Vector3, areaId: string)
	local spot = DigSpotService.spawnAt(position, areaId, { moonlit = true })
	dress(spot.model, position)
	moonlit[spot.id] = areaId
	if not night then
		task.delay(300, function()
			if not night and moonlit[spot.id] then
				moonlit[spot.id] = nil
				DigSpotService.remove(spot.id)
			end
		end)
	end
end

-- How many moonlit spots are out (tests).
function NightService.count(): number
	local n = 0
	for _ in moonlit do
		n += 1
	end
	return n
end

function NightService.start()
	task.spawn(function()
		while true do
			task.wait(2)
			local isNight = NightService.isNight()
			if isNight and not night then
				begin()
			elseif not isNight and night then
				finish()
			end
		end
	end)
end

return NightService
