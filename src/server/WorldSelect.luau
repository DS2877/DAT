--!strict
-- Which world this server runs. Frostbite Peaks runs in reserved servers of
-- this place (only the island portal reserves servers: Services/WorldServers);
-- every other server, public or a player's private server, is the island.
--
-- Runs first thing at boot: the configs read the world (Logic/CurrentWorld,
-- the workspace's WorldId attribute) when they load, on the server and on
-- every client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local WorldSelect = {}

function WorldSelect.resolve(): string
	local reserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
	return if reserved and Worlds.next.open then Worlds.next.id else Worlds.home.id
end

function WorldSelect.apply(): string
	local id = WorldSelect.resolve()
	workspace:SetAttribute("WorldId", id)
	return id
end

return WorldSelect
