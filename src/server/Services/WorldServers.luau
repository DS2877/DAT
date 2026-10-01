--!strict
-- Matchmaking for Frostbite Peaks, which runs in reserved servers of this
-- place (Server/WorldSelect).
--   * Island side (`send`): the portal sends a player to the fullest Frost
--     server that still has room, or reserves a new one. Open servers are
--     listed in a MemoryStore sorted map: [PrivateServerId] = { code,
--     players }. A new server is listed right away, so the next traveller
--     joins it instead of reserving another.
--   * Frost side (`host`): the server keeps its entry fresh with its player
--     count (it learns its access code from the travellers' TeleportData);
--     an entry that stops being refreshed expires, and it's removed when the
--     server closes.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Worlds = require(game:GetService("ReplicatedStorage").Shared.Config.Worlds)

local WorldServers = {}

type Entry = { code: string, players: number }

local function list(worldId: string): MemoryStoreSortedMap?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap("WorldServers_" .. worldId)
	end)
	return if ok then map else nil
end

local function capacity(): number
	return math.max(1, Players.MaxPlayers - Worlds.servers.roomForFriends)
end

-- The access code of the fullest listed server with room, if any.
function WorldServers.find(worldId: string): string?
	local map = list(worldId)
	if not map then
		return nil
	end
	local ok, items = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Ascending, 100)
	end)
	if not ok or type(items) ~= "table" then
		return nil
	end
	local best: Entry? = nil
	for _, item in items do
		local entry = item.value
		if
			type(entry) == "table"
			and type(entry.code) == "string"
			and type(entry.players) == "number"
			and entry.players < capacity()
			and (best == nil or entry.players > best.players)
		then
			best = entry
		end
	end
	return if best then best.code else nil
end

-- A new reserved server for the world, listed straight away (empty).
local function reserve(worldId: string): string?
	local ok, code, serverId = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not ok or type(code) ~= "string" then
		warn("[WorldServers] ReserveServer failed: " .. tostring(code))
		return nil
	end
	local map = list(worldId)
	if map and type(serverId) == "string" then
		pcall(function()
			map:SetAsync(serverId, { code = code, players = 0 }, Worlds.servers.expires)
		end)
	end
	return code
end

-- Sends the player to a server of `worldId`. False if the trip couldn't
-- start (the caller tells the player).
function WorldServers.send(player: Player, worldId: string): boolean
	local code = WorldServers.find(worldId) or reserve(worldId)
	if not code then
		return false
	end
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData({ world = worldId, code = code })
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn("[WorldServers] Teleport failed: " .. tostring(err))
	end
	return ok
end

-- Sends the player back to a public island server.
function WorldServers.sendHome(player: Player): boolean
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ world = Worlds.home.id })
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn("[WorldServers] Teleport home failed: " .. tostring(err))
	end
	return ok
end

-- This server's access code, from a traveller's TeleportData (only trusted
-- when they came from this place's portal).
local function codeFrom(player: Player): string?
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(joinData) ~= "table" or joinData.SourcePlaceId ~= game.PlaceId then
		return nil
	end
	local data = joinData.TeleportData
	return if type(data) == "table" and type(data.code) == "string" then data.code else nil
end

-- Frost side: keeps this server listed with its player count.
function WorldServers.host(worldId: string)
	local serverId = game.PrivateServerId
	local map = list(worldId)
	if not map or serverId == "" then
		return
	end
	local code: string? = nil
	local function update()
		if not code then
			for _, player in Players:GetPlayers() do
				code = code or codeFrom(player)
			end
		end
		local count = #Players:GetPlayers()
		local ok, err = pcall(function()
			map:UpdateAsync(serverId, function(old: any)
				-- The code the portal listed it with comes first.
				local known = if type(old) == "table" and type(old.code) == "string" then old.code else code
				if type(known) ~= "string" then
					return nil -- no code to share yet
				end
				return { code = known, players = count }
			end, Worlds.servers.expires)
		end)
		if not ok then
			warn("[WorldServers] Listing this server failed: " .. tostring(err))
		end
	end
	Players.PlayerAdded:Connect(function()
		task.defer(update)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(update)
	end)
	task.spawn(function()
		while true do
			update()
			task.wait(Worlds.servers.heartbeat)
		end
	end)
	game:BindToClose(function()
		pcall(function()
			map:RemoveAsync(serverId)
		end)
	end)
end

return WorldServers
