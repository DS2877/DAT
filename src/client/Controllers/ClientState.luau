--!strict
-- The client's copy of its own profile snapshot (sent by the server).
-- Read-only on the client: all changes happen on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bag = require(ReplicatedStorage.Shared.Logic.Bag)
local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local Perks = require(ReplicatedStorage.Shared.Logic.Perks)
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
	discovered: { [string]: { normal: boolean?, shiny: boolean?, golden: boolean? } },
	-- Retention (from RewardService)
	giftStart: number, -- server time the session's playtime gifts started counting
	giftsClaimed: { [string]: boolean }, -- keyed by tostring(gift index)
	dailyCanClaim: boolean,
	dailyDay: number,
	dailyStreak: number,
	goldenX: { areaId: string, position: Vector3 }?,
	groupRewardClaimed: boolean,
	digCharges: { Rare: number, Epic: number },
	activeBoosts: { [string]: number },
	settings: { [string]: boolean }?, -- music, sounds, autoDig, autoSell, radar
	-- Purchases (from PurchaseService)
	passes: { [string]: boolean }?,
	ownedCosmetics: { [string]: boolean }?,
	equippedSkin: string?,
	starterPackBought: boolean?,
	instantDeepDigs: number?,
	paidRandomRestricted: boolean?,
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
	return if data then Perks.bagCapacity(data :: any) else 0
end

function ClientState.isBagFull(): boolean
	local data = ClientState.data
	return data ~= nil and Bag.isFull(data.bag, ClientState.bagCapacity())
end

-- True if the player owns the pass (directly or through VIP).
function ClientState.hasPass(key: string): boolean
	local data = ClientState.data
	return data ~= nil and Perks.has(data :: any, key)
end

-- True if the player owns the pass and has the perk switched on.
function ClientState.perkOn(key: string): boolean
	local data = ClientState.data
	return data ~= nil and Perks.enabled(data :: any, key)
end

function ClientState.bagValue(): number
	local data = ClientState.data
	return if data then Bag.totalValue(data.bag) else 0
end

-- Seconds between dig hits right now (shovel + dig speed boost).
function ClientState.hitInterval(): number
	local data = ClientState.data
	if not data then
		return 0.5
	end
	return Bonuses.hitInterval(data :: any, workspace:GetServerTimeNow())
end

function ClientState.shovel()
	local data = ClientState.data
	return Progression.getShovel(if data then data.shovelLevel else 1)
end

return ClientState
