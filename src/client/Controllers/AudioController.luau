--!strict
-- The island's soundscape on this client:
--   * background music (a light ukulele track; an upbeat one during
--     Treasure Rush), ducked under big fanfares
--   * an ambience bed per area (waves and gulls, jungle, desert wind, lava),
--     crossfaded as the player walks between areas
--   * 3D loops on world objects: the waterfall, the campfire, the lava lake,
--     the volcano crater and the skull rock's burning eyes
--   * the player's Music / Sounds settings (saved in their profile)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Sound = require(script.Parent.Parent.Sound)
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local AudioController = {}

local FADE = 2.5
local DUCK_LEVEL = 0.25

type Loop = { sound: Sound, level: number, playing: boolean }

local music: { [string]: Loop } = {}
local currentMusic = ""
local ambience: { [string]: { Loop } } = {}
local currentArea = ""
local duckUntil = 0

local function loop(clip: AssetIds.Clip, group: string, parent: Instance): Loop
	local sound = Sound.create(clip, group)
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = parent
	return { sound = sound, level = clip.volume, playing = false }
end

local function fade(l: Loop, on: boolean, time: number?)
	if on and not l.playing then
		l.playing = true
		l.sound:Play()
	end
	local tween =
		TweenService:Create(l.sound, TweenInfo.new(time or FADE), { Volume = if on then l.level else 0 })
	tween:Play()
	if not on then
		tween.Completed:Once(function()
			if l.sound.Volume == 0 then
				l.playing = false
				l.sound:Pause()
			end
		end)
	end
end

local function setMusic(name: string)
	if name == currentMusic then
		return
	end
	for key, l in music do
		fade(l, key == name)
	end
	currentMusic = name
end

local function setArea(area: string)
	if area == currentArea then
		return
	end
	for key, layers in ambience do
		for _, l in layers do
			fade(l, key == area)
		end
	end
	currentArea = area
end

-- Lowers the music while a fanfare plays, then brings it back.
local function duck(seconds: number)
	local l = music[currentMusic]
	if not l then
		return
	end
	duckUntil = os.clock() + seconds
	TweenService:Create(l.sound, TweenInfo.new(0.25), { Volume = l.level * DUCK_LEVEL }):Play()
	task.delay(seconds, function()
		if os.clock() >= duckUntil - 0.01 and music[currentMusic] == l then
			TweenService:Create(l.sound, TweenInfo.new(1.2), { Volume = l.level }):Play()
		end
	end)
end

-- The upbeat track plays while anything wants it (a Treasure Rush, being
-- at a Mega Dig...).
local upbeat: { [string]: boolean } = {}
local special: string? = nil
local function pick()
	setMusic(special or (if next(upbeat) then "Rush" else "Main"))
end
function AudioController.setUpbeat(reason: string, on: boolean)
	upbeat[reason] = if on then true else nil
	pick()
end

-- A track that plays over everything else while set (the Mega Dig's party
-- music for the players digging it); nil goes back to the usual music.
function AudioController.setSpecialMusic(name: string?)
	if name == special then
		return
	end
	special = name
	pick()
end

-- The track playing now (tests).
function AudioController.currentMusic(): string
	return currentMusic
end

-- Treasure Rush switches to the upbeat track while it lasts.
function AudioController.setRush(active: boolean)
	AudioController.setUpbeat("Rush", active)
end

local function attachEmitter(part: BasePart, clip: AssetIds.Clip, maxDistance: number)
	if part:FindFirstChild("AmbientLoop") then
		return
	end
	local sound = Sound.create(clip, "Ambience")
	sound.Name = "AmbientLoop"
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = maxDistance * 0.12
	sound.RollOffMaxDistance = maxDistance
	sound.Parent = part
	sound:Play()
end

local EMITTERS: { [string]: { kind: string, distance: number } } = {
	Waterfall = { kind = "Waterfall", distance = 110 },
	Campfire = { kind = "Fire", distance = 45 },
	EyeFire = { kind = "Fire", distance = 60 },
	LakeGlow = { kind = "Lava", distance = 120 },
	CraterGlow = { kind = "Lava", distance = 320 },
}

local function attachEmitters()
	local decor = workspace:WaitForChild("Decor", 30)
	if not decor then
		return
	end
	local count = { Waterfall = 0 }
	for _, d in decor:GetDescendants() do
		local spec = d:IsA("BasePart") and EMITTERS[d.Name]
		if spec then
			-- One sound per waterfall (it has a front and a back sheet).
			if d.Name == "Waterfall" then
				count.Waterfall += 1
				if count.Waterfall > 1 then
					continue
				end
			end
			attachEmitter(d :: BasePart, (AssetIds.Emitters :: any)[spec.kind], spec.distance)
		end
	end
end

local function applySettings()
	local data = ClientState.data
	local settings = data and data.settings
	local musicOn = not settings or settings.music ~= false
	local soundsOn = not settings or settings.sounds ~= false
	Sound.setGroupEnabled("Music", musicOn)
	Sound.setGroupEnabled("Effects", soundsOn)
	Sound.setGroupEnabled("Ambience", soundsOn)
end

function AudioController.init()
	Sound.preload()
	local holder = Instance.new("Folder")
	holder.Name = "Soundscape"
	holder.Parent = game:GetService("SoundService")

	for name, clip in AssetIds.Music do
		music[name] = loop(clip, "Music", holder)
	end
	for area, clips in AssetIds.Ambience do
		local layers = {}
		for _, clip in clips do
			table.insert(layers, loop(clip, "Ambience", holder))
		end
		ambience[area] = layers
	end
	Sound.onDuck(duck)
	ClientState.Changed:Connect(applySettings)
	applySettings()
	setMusic("Main")

	task.spawn(attachEmitters)
	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				setArea(Zones.areaAt(root.Position.X, root.Position.Z))
			end
			task.wait(1)
		end
	end)
end

return AudioController
