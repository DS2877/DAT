--!strict
-- Creates the RemoteEvents listed in Shared/Remotes and wraps incoming
-- client events with a per-player rate limit and error isolation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local RemoteNames = require(ReplicatedStorage.Shared.Remotes)

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local remotes: { [string]: RemoteEvent } = {}
for _, name in RemoteNames do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	remotes[name] = remote
end

-- Parent last so clients see a complete folder.
folder.Parent = ReplicatedStorage

function Net.get(name: string): RemoteEvent
	local remote = remotes[name]
	assert(remote, "Unknown remote " .. name)
	return remote
end

-- Connects a client -> server handler. Calls beyond the rate limit are dropped.
function Net.on(name: string, ratePerSecond: number, burst: number, handler: (Player, ...any) -> ())
	local limiter = RateLimiter.new(ratePerSecond, burst)
	Net.get(name).OnServerEvent:Connect(function(player: Player, ...)
		if not limiter:allow(player) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[Net] %s handler error for %s: %s", name, player.Name, tostring(err)))
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

function Net.fire(name: string, player: Player, ...: any)
	Net.get(name):FireClient(player, ...)
end

function Net.fireAll(name: string, ...: any)
	Net.get(name):FireAllClients(...)
end

return Net
