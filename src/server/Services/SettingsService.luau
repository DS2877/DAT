--!strict
-- Saves the player's settings (music and sound effects on/off) so they
-- stick between sessions.

local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local SettingsService = {}

local KEYS = { music = true, sounds = true }

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
	end)
end

return SettingsService
