--!strict
-- The volcano eruption (Config/Eruption). On a shared clock the volcano
-- rumbles, then erupts: fireballs arc out of the crater (every client draws
-- them from the Meteor remote) and each lands as a smoking meteor dig spot
-- with much better odds. Unclaimed ones cool off after a while.
-- Workspace attributes for the clients:
--   EruptionNext  server time of the next eruption (the rumble starts
--                 `rumble` seconds before)
--   Eruption      "Rumble" | "Erupt" while it happens, nil otherwise

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)
local Eruption = require(ReplicatedStorage.Shared.Config.Eruption)
local Schedule = require(ReplicatedStorage.Shared.Logic.Schedule)
local AnnouncementService = require(script.Parent.AnnouncementService)
local DigSpotService = require(script.Parent.DigSpotService)
local Net = require(script.Parent.Parent.Net)
local World = require(script.Parent.Parent.World.World)

local EruptionService = {}

local scheduled = true
local running = false
local generation = 0 -- bumps on every start / cancel (a cancelled run stops)
local meteorSpots: { [number]: number } = {} -- spot id -> cools off at (os.clock)
local rng = Random.new()
-- The timings and landing weights (Config/Eruption; tests shorten them).
local timing = {
	rumble = Eruption.rumble,
	erupt = Eruption.erupt,
	meteors = Eruption.meteors,
	flight = Eruption.flight,
	areaWeights = Eruption.areaWeights,
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function frost(): boolean
	return CurrentWorld.isFrost()
end

local function crater(): Vector3
	local glow = workspace:FindFirstChild("CraterGlow", true)
	if glow and glow:IsA("BasePart") then
		return glow.Position + Vector3.new(0, 4, 0)
	end
	local v = World.get().spawnPosition
	return v + Vector3.new(0, 200, -700)
end

local function tell(text: string)
	AnnouncementService.announce({
		text = text,
		color = if frost() then Eruption.frostColor else Eruption.color,
		secret = false,
	})
end

-- A smoking, glowing rock on the spot.
local function dress(model: Model, position: Vector3)
	model:SetAttribute("Meteor", true)
	local rock = Instance.new("Part")
	rock.Name = "MeteorRock"
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CanTouch = false
	rock.Material = Enum.Material.Basalt
	rock.Color = if frost() then Color3.fromRGB(70, 90, 120) else Color3.fromRGB(50, 40, 40)
	rock.Size = Vector3.new(2.2, 1.6, 2)
	rock.CFrame = CFrame.new(position + Vector3.new(1.6, 0.9, 1.2))
		* CFrame.Angles(0.4, rng:NextNumber(0, 6), 0.3)
	rock.Parent = model
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromHex(if frost() then Eruption.frostColor else Eruption.color)
	glow.Range = 14
	glow.Brightness = 2
	glow.Parent = rock
	local smoke = Instance.new("Smoke")
	smoke.Color = if frost() then Color3.fromRGB(220, 240, 255) else Color3.fromRGB(70, 60, 60)
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 6
	smoke.Size = 3
	smoke.Parent = rock
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = Color3.fromHex(if frost() then Eruption.frostColor else Eruption.color)
	fire.SecondaryColor = if frost() then Color3.fromRGB(230, 250, 255) else Color3.fromRGB(255, 220, 90)
	fire.Parent = rock
end

local function pickArea(): string
	local total = 0
	for _, areaId in Areas.Order do
		if Areas.Defs[areaId].enabled then
			total += timing.areaWeights[areaId] or 1
		end
	end
	local x = rng:NextNumber() * total
	for _, areaId in Areas.Order do
		if Areas.Defs[areaId].enabled then
			x -= timing.areaWeights[areaId] or 1
			if x < 0 and (timing.areaWeights[areaId] or 1) > 0 then
				return areaId
			end
		end
	end
	return Areas.Order[1]
end

-- A fireball to `landing` (every client draws it), then a meteor spot there.
local function land(from: Vector3, landing: Vector3, areaId: string)
	Net.fireAll("Meteor", from, landing, timing.flight)
	task.delay(timing.flight, function()
		local spot = DigSpotService.spawnAt(landing, areaId, { meteor = true })
		dress(spot.model, landing)
		meteorSpots[spot.id] = os.clock() + Eruption.linger
	end)
end

-- One fireball to a free point in a random area.
local function launch(from: Vector3)
	local areaId = pickArea()
	local points = World.get().candidates[areaId]
	if not points or #points == 0 then
		return
	end
	local target: Vector3? = nil
	for _ = 1, 8 do
		local p = points[rng:NextInteger(1, #points)]
		local clear = true
		for _, spot in DigSpotService.list() do
			if (spot.position - p).Magnitude < 9 then
				clear = false
				break
			end
		end
		if clear then
			target = p
			break
		end
	end
	if not target then
		return
	end
	land(from, target :: Vector3, areaId)
end

-- Starts an eruption now (admins; tests). False if one is running.
function EruptionService.start(): boolean
	if running then
		return false
	end
	running = true
	generation += 1
	local mine = generation
	local function stopped(): boolean
		return generation ~= mine
	end
	task.spawn(function()
		workspace:SetAttribute("Eruption", "Rumble")
		tell(
			if frost()
				then "❄️ The Frozen Peak is cracking... comets are coming!"
				else "🌋 The volcano is rumbling... get ready for meteors!"
		)
		task.wait(timing.rumble)
		if stopped() then
			return
		end
		workspace:SetAttribute("Eruption", "Erupt")
		tell(
			if frost()
				then "☄️ COMET SHOWER! Dig the comet spots for big treasure!"
				else "🌋 ERUPTION! Dig the meteor spots for big treasure!"
		)
		local from = crater()
		local gap = timing.erupt / math.max(1, timing.meteors)
		for _ = 1, timing.meteors do
			if stopped() then
				return
			end
			launch(from)
			task.wait(gap)
		end
		task.wait(timing.flight)
		if stopped() then
			return
		end
		workspace:SetAttribute("Eruption", nil)
		running = false
	end)
	return true
end

-- Stops a running eruption (admins). Meteors already out stay.
function EruptionService.cancel(): boolean
	if not running then
		return false
	end
	generation += 1
	running = false
	workspace:SetAttribute("Eruption", nil)
	return true
end

function EruptionService.isRunning(): boolean
	return running
end

-- A fireball from the crater to `position` (admins).
function EruptionService.meteorAt(position: Vector3, areaId: string)
	land(crater(), position, areaId)
end

-- Cools off every meteor spot now (admins). Returns how many.
function EruptionService.clear(): number
	local n = 0
	for id in meteorSpots do
		DigSpotService.remove(id)
		n += 1
	end
	table.clear(meteorSpots)
	return n
end

-- A meteor spot was dug (it's gone for good).
function EruptionService.onDug(spotId: number)
	meteorSpots[spotId] = nil
end

-- How many meteor spots are out (tests).
function EruptionService.count(): number
	local n = 0
	for _ in meteorSpots do
		n += 1
	end
	return n
end

-- Shorter eruptions or fixed landing areas (tests); nil fields keep the config.
function EruptionService.setTiming(overrides: { [string]: any }?)
	local o = overrides or {}
	timing.rumble = o.rumble or Eruption.rumble
	timing.erupt = o.erupt or Eruption.erupt
	timing.meteors = o.meteors or Eruption.meteors
	timing.flight = o.flight or Eruption.flight
	timing.areaWeights = o.areaWeights or Eruption.areaWeights
end

function EruptionService.setScheduled(on: boolean)
	scheduled = on
end

function EruptionService.run()
	local lastScheduled = Schedule.nextStart(now(), Eruption.interval, Eruption.offset) - Eruption.interval
	task.spawn(function()
		while true do
			task.wait(1) -- (first check after start-up, so tests can turn the schedule off)
			local t = now()
			local nextStart = Schedule.nextStart(t, Eruption.interval, Eruption.offset)
			workspace:SetAttribute("EruptionNext", nextStart)
			-- The rumble starts before the eruption time.
			local rumbleAt = nextStart - Eruption.rumble
			local previous = nextStart - Eruption.interval
			if t >= rumbleAt and nextStart > lastScheduled then
				lastScheduled = nextStart
				-- (An admin can switch them off: workspace EruptionsOff.)
				if scheduled and workspace:GetAttribute("EruptionsOff") ~= true then
					EruptionService.start()
				end
			elseif previous > lastScheduled then
				lastScheduled = previous
			end
			-- Cool off old meteor spots.
			local clock = os.clock()
			for id, coolsAt in meteorSpots do
				if clock >= coolsAt then
					meteorSpots[id] = nil
					DigSpotService.remove(id)
				end
			end
		end
	end)
end

return EruptionService
