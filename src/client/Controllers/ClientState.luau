--!strict
-- The client's copy of its own profile snapshot (sent by the server).
-- Read-only on the client: all changes happen on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bag = require(ReplicatedStorage.Shared.Logic.Bag)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

export type Snapshot = {
	cash: number,
	shovelLevel: number,
	bagLevel: number,
	bag: { { id: string, v: number } },
	rebirths: number,
	discoveredCount: number,
	finds: number,
	sales: number,
	guideDone: boolean,
}

local ClientState = {}

ClientState.data = nil :: Snapshot?
-- Fired (data, previous) whenever a new snapshot arrives.
ClientState.Changed = Signal.new()

function ClientState.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local dataSync = remotes:WaitForChild("DataSync") :: RemoteEvent
	dataSync.OnClientEvent:Connect(function(snapshot: Snapshot)
		local previous = ClientState.data
		ClientState.data = snapshot
		ClientState.Changed:Fire(snapshot, previous)
	end)
end

function ClientState.bagCapacity(): number
	local data = ClientState.data
	return if data then Progression.bagCapacity(data.bagLevel) else 0
end

function ClientState.isBagFull(): boolean
	local data = ClientState.data
	return data ~= nil and Bag.isFull(data.bag, data.bagLevel)
end

function ClientState.bagValue(): number
	local data = ClientState.data
	return if data then Bag.totalValue(data.bag) else 0
end

function ClientState.shovel()
	local data = ClientState.data
	return Progression.getShovel(if data then data.shovelLevel else 1)
end

return ClientState
