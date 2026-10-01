--!strict
-- The bought server-wide 2x Cash: everyone in the server earns 2x cash
-- until it runs out, and everyone sees who boosted it. Shown to clients
-- through workspace attributes "ServerBoostUntil" (server time) and
-- "ServerBoostBy" (display name). Buying more while it runs adds time.

local Players = game:GetService("Players")

local Net = require(script.Parent.Parent.Net)

local ServerBoostService = {}

function ServerBoostService.isActive(): boolean
	local untilTime = workspace:GetAttribute("ServerBoostUntil")
	return type(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

function ServerBoostService.start(player: Player, seconds: number)
	local now = workspace:GetServerTimeNow()
	local current = workspace:GetAttribute("ServerBoostUntil")
	local from = if type(current) == "number" and current > now then current else now
	workspace:SetAttribute("ServerBoostUntil", from + seconds)
	workspace:SetAttribute("ServerBoostBy", player.DisplayName)
	local minutes = math.floor(seconds / 60 + 0.5)
	for _, other in Players:GetPlayers() do
		Net.fire(
			"Notify",
			other,
			string.format(
				"📣 %s BOOSTED THE SERVER!\n2x Cash for everyone (+%d min)",
				player.DisplayName,
				minutes
			),
			"Big"
		)
	end
end

return ServerBoostService
