--!strict
-- The day and night cycle on this client (Config/DayNight): the sun moves
-- with the shared clock, the sky darkens into a (still playable) blue night
-- and lightens at dawn, and at night crickets chirp and an owl hoots now and
-- then. The ADMIN ABUSE party sky takes over while it runs, and an admin's
-- TIME OF DAY choice shows for a few minutes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)
local Config = require(ReplicatedStorage.Shared.Config.DayNight)
local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)
local DayNight = require(ReplicatedStorage.Shared.Logic.DayNight)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)

local DayNightController = {}

local day = {
	ambient = Lighting.Ambient,
	outdoorAmbient = Lighting.OutdoorAmbient,
	brightness = Lighting.Brightness,
}
local night = {
	ambient = Color3.fromHex(Config.night.ambient),
	outdoorAmbient = Color3.fromHex(Config.night.outdoorAmbient),
	brightness = Config.night.brightness,
}
local crickets: Sound? = nil
local chirping = false
local nextOwl = 0
local current = 0 -- how much night it is (0..1)
local label: TextLabel -- "Night in 3:12" / "Night: moonlit spots!" (under the timers)

local function partyActive(): boolean
	local untilTime = workspace:GetAttribute("AdminAbuseUntil")
	return type(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

local function update()
	local now = workspace:GetServerTimeNow()
	if partyActive() then
		return
	end
	local clock = DayNight.clockTime(now)
	local nightness = DayNight.nightness(now)
	local override = workspace:GetAttribute("ClockOverride")
	local overrideUntil = workspace:GetAttribute("ClockOverrideUntil")
	local cycleOff = workspace:GetAttribute("NightCycleOff") == true -- an admin: always day
	if type(override) == "number" and type(overrideUntil) == "number" and overrideUntil > now then
		clock = override
		nightness = if override >= 19 or override < 6 then 1 else 0
	elseif workspace:GetAttribute("ForceNight") == true then
		clock = 0
		nightness = 1
	elseif cycleOff then
		clock = 14
		nightness = 0
	end
	current = nightness
	local isNight = workspace:GetAttribute("Night") == true
	if cycleOff and not isNight then
		label.Text = "☀️ Always day (admin)"
		label.TextColor3 = Color3.new(1, 1, 1)
	elseif isNight then
		label.Text = "🌙 Night: dig the moonlit spots!"
		label.TextColor3 = Color3.fromHex(Config.moonlit.color)
	else
		local left = math.ceil(DayNight.untilNight(now))
		label.Text = string.format("🌙 Night in %d:%02d", left // 60, left % 60)
		label.TextColor3 = Color3.new(1, 1, 1)
	end
	Lighting.ClockTime = clock
	Lighting.Ambient = day.ambient:Lerp(night.ambient, nightness)
	Lighting.OutdoorAmbient = day.outdoorAmbient:Lerp(night.outdoorAmbient, nightness)
	Lighting.Brightness = day.brightness + (night.brightness - day.brightness) * nightness

	-- Night sounds on the island.
	if crickets then
		crickets.Volume = AssetIds.NightAmbience.volume * nightness
		if nightness > 0 and not chirping then
			chirping = true
			crickets:Play()
		elseif nightness <= 0 and chirping then
			chirping = false
			crickets:Stop()
		end
	end
	if nightness > 0.8 and CurrentWorld.id() == "Island" and os.clock() >= nextOwl then
		nextOwl = os.clock() + math.random(25, 55)
		Sound.play("Owl")
	end
end

function DayNightController.init()
	label = Ui.label({
		Name = "NightTimer",
		Position = UDim2.fromOffset(16, 208),
		Size = UDim2.fromOffset(240, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = HudController.root(),
	})
	if CurrentWorld.id() == "Island" then
		local sound = Sound.create(AssetIds.NightAmbience, "Ambience")
		sound.Name = "NightCrickets"
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		crickets = sound
	end
	nextOwl = os.clock() + 20
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			accumulator = 0
			update()
		end
	end)
	update()
end

-- How much night it is right now (0 day .. 1 night; tests).
function DayNightController.nightness(): number
	return current
end

return DayNightController
