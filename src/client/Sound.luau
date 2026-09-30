--!strict
-- Plays UI / feedback sounds from AssetIds. Missing ids are silently skipped
-- so the game works before real audio is chosen.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)

local Sound = {}

local templates: { [string]: Sound } = {}

local function template(name: string): Sound?
	local cached = templates[name]
	if cached then
		return cached
	end
	local id = (AssetIds.Sounds :: any)[name]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Parent = SoundService
	templates[name] = sound
	return sound
end

-- Plays a 2D sound. Overlapping plays use short-lived clones.
function Sound.play(name: string, volume: number?, pitch: number?)
	local base = template(name)
	if not base then
		return
	end
	local sound = base:Clone()
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

return Sound
