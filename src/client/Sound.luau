--!strict
-- Plays feedback sounds from AssetIds.Sounds: picks a random variant, skips
-- its lead-in, stops it after its length, jitters the pitch, and routes it
-- through the Effects sound group. Sounds marked `duck` briefly lower the
-- music so fanfares come through. Missing sounds are silently skipped.
--
-- Sound groups (Effects, Ambience, Music) are what the Settings toggles mute.

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)

local Sound = {}

local groups: { [string]: SoundGroup } = {}

-- The sound group with this name (created on first use).
function Sound.group(name: string): SoundGroup
	local existing = groups[name]
	if existing then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = AssetIds.Mix[name] or 1
	group.Parent = SoundService
	groups[name] = group
	return group
end

-- Mutes / unmutes a group (smoothly).
function Sound.setGroupEnabled(name: string, enabled: boolean)
	local group = Sound.group(name)
	TweenService
		:Create(group, TweenInfo.new(0.4), { Volume = if enabled then AssetIds.Mix[name] or 1 else 0 })
		:Play()
end

-- Music ducking: callers (AudioController) register how to duck.
local duckHandler: ((seconds: number) -> ())? = nil
function Sound.onDuck(handler: (seconds: number) -> ())
	duckHandler = handler
end

local rng = Random.new()

-- Loaded template per asset id; plays use clones of these (a clone of a
-- loaded sound is ready at once, so start offsets apply immediately).
local templates: { [string]: Sound } = {}

local function template(id: string): Sound
	local existing = templates[id]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = "Template"
	sound.SoundId = id
	sound.Parent = SoundService
	templates[id] = sound
	return sound
end

-- Starts loading every clip in AssetIds (call once at startup).
function Sound.preload()
	local list: { Instance } = {}
	local function add(clip: any)
		if type(clip) == "table" and type(clip.id) == "string" and clip.id ~= "" then
			table.insert(list, template(clip.id))
		end
	end
	for _, def in AssetIds.Sounds do
		for _, c in def.clips do
			add(c)
		end
	end
	for _, clips in AssetIds.Ambience do
		for _, c in clips do
			add(c)
		end
	end
	for _, c in AssetIds.Emitters do
		add(c)
	end
	for _, c in AssetIds.Music do
		add(c)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

-- A fresh Sound for a clip (cloned from its loaded template).
function Sound.create(clip: AssetIds.Clip, group: string): Sound
	local sound = template(clip.id):Clone()
	sound.Name = "Sfx"
	sound.Volume = clip.volume
	sound.SoundGroup = Sound.group(group)
	return sound
end

-- Plays a clip once. `volumeScale` multiplies the clip's own level.
function Sound.playClip(clip: AssetIds.Clip, group: string, volumeScale: number?, pitch: number?): Sound?
	if clip.id == "" then
		return nil
	end
	local sound = Sound.create(clip, group)
	sound.Volume = clip.volume * (volumeScale or 1)
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound.TimePosition = clip.start
	sound:Play()
	local lifetime = if clip.length then clip.length / (pitch or 1) else 8
	task.delay(lifetime, function()
		if sound.Parent then
			if clip.length then
				-- Short fade instead of a hard cut.
				TweenService:Create(sound, TweenInfo.new(0.08), { Volume = 0 }):Play()
				task.wait(0.1)
			end
			sound:Destroy()
		end
	end)
	return sound
end

-- Plays a named sound (a random variant). `volumeScale` (default 1) is
-- relative to the sound's normalized level; `pitch` overrides the jitter.
function Sound.play(name: string, volumeScale: number?, pitch: number?)
	local def = AssetIds.Sounds[name]
	if not def or #def.clips == 0 then
		return
	end
	local clip = def.clips[rng:NextInteger(1, #def.clips)]
	local speed = pitch
	if not speed then
		local jitter = def.jitter or 0
		speed = 1 + rng:NextNumber(-jitter, jitter)
	end
	Sound.playClip(clip, "Effects", volumeScale, speed)
	if def.duck and duckHandler then
		duckHandler(clip.length or 3)
	end
end

return Sound
