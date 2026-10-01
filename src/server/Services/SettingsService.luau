--!strict
-- Saves the player's settings so they stick between sessions: music and
-- sound effects on/off, the on/off switch of every pass they own, using
-- saved Instant Deep Digs, and pausing / resuming timed boosts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local SettingsService = {}

-- Fired (player, key, on) after a setting changes.
SettingsService.Changed = Signal.new()

local KEYS: { [string]: boolean } = { music = true, sounds = true, instantDeepDig = true }
for _, pass in Monetization.Passes do
	KEYS[pass.toggle] = true
end

function SettingsService.init()
	Net.on("SetSetting", 4, 8, function(player: Player, key: any, on: any)
		if type(key) ~= "string" or not KEYS[key] or type(on) ~= "boolean" then
			return -- malformed
		end
		local data = PlayerData.get(player)
		if not data then
			return
		end
		data.settings[key] = on
		PlayerData.changed(player)
		SettingsService.Changed:Fire(player, key, on)
	end)

	Net.on("PauseBoost", 4, 8, function(player: Player, boostId: any, paused: any)
		if type(boostId) ~= "string" or not Retention.boosts[boostId] or type(paused) ~= "boolean" then
			return
		end
		local data = PlayerData.get(player)
		if not data then
			return
		end
		local now = os.time()
		local changed = if paused
			then Boosts.pause(data.activeBoosts, data.pausedBoosts, boostId, now)
			else Boosts.resume(data.activeBoosts, data.pausedBoosts, boostId, now)
		if changed then
			PlayerData.changed(player)
		end
	end)
end

return SettingsService
