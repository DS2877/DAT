--!strict
-- Validates dig hits and completes digs. The client only says "I hit spot N";
-- the server checks the spot, range, area unlock, bag space and hit timing,
-- then rolls loot when the required number of hits is reached.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bag = require(ReplicatedStorage.Shared.Logic.Bag)
local DigConfig = require(ReplicatedStorage.Shared.Config.Dig)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Streak = require(ReplicatedStorage.Shared.Logic.Streak)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Analytics = require(script.Parent.Analytics)
local DigSpotService = require(script.Parent.DigSpotService)
local LootService = require(script.Parent.LootService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local DigService = {}

type DigState = {
	spotId: number,
	hits: number,
	required: number,
	lastHit: number,
}

local states: { [Player]: DigState } = {}
local streaks: { [Player]: Streak.State } = {}

local function reject(player: Player, spotId: number, reason: string)
	Net.fire("DigResult", player, { spotId = spotId, rejected = reason })
end

local function onDigHit(player: Player, spotId: any)
	if type(spotId) ~= "number" or spotId ~= spotId or spotId % 1 ~= 0 then
		return -- malformed
	end
	local data = PlayerData.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	local spot = DigSpotService.get(spotId)
	if not spot then
		reject(player, spotId, "Gone")
		return
	end
	if not Progression.isAreaUnlocked(spot.areaId, data.shovelLevel) then
		reject(player, spotId, "Locked")
		return
	end
	local pos = root.Position
	if
		Zones.flatDistance(pos.X, pos.Z, spot.position.X, spot.position.Z) > DigConfig.serverRange
		or math.abs(pos.Y - spot.position.Y) > 14
	then
		reject(player, spotId, "TooFar")
		return
	end
	if Bag.isFull(data.bagContents, data.bagLevel) then
		reject(player, spotId, "BagFull")
		return
	end

	local shovel = Progression.getShovel(data.shovelLevel)
	local now = os.clock()
	local state = states[player]
	if state and now - state.lastHit < shovel.hitInterval * DigConfig.hitTolerance then
		reject(player, spotId, "TooFast")
		return
	end
	if not state or state.spotId ~= spotId or now - state.lastHit > DigConfig.progressTimeout then
		state = { spotId = spotId, hits = 0, required = shovel.hits, lastHit = now }
		states[player] = state
	end
	local s = state :: DigState
	s.hits += 1
	s.lastHit = now

	if data.stats.digs == 0 and s.hits == 1 then
		Analytics.funnel(player, data, "FirstDig")
	end
	-- Lets every client play this player's swing (see EffectsController).
	character:SetAttribute("DigHits", ((character:GetAttribute("DigHits") :: number?) or 0) + 1)

	if s.hits < s.required then
		Net.fire("DigResult", player, { spotId = spotId, hits = s.hits, required = s.required })
		return
	end

	-- Dig complete.
	s.spotId = -1
	s.hits = 0
	DigSpotService.consume(spotId)
	local streak = streaks[player] or Streak.new()
	streaks[player] = streak
	local find = LootService.rollFor(data, {
		areaId = spot.areaId,
		clue = spot.clue,
		streak = Streak.onDig(streak, os.clock()),
	})
	Bag.add(data.bagContents, { id = find.id, v = find.value, m = find.mutation }, data.bagLevel)
	data.stats.digs += 1
	data.stats.finds += 1
	if data.stats.finds == 1 then
		Analytics.funnel(player, data, "FirstFind")
	end

	Net.fire("DigResult", player, {
		spotId = spotId,
		hits = s.required,
		required = s.required,
		done = true,
		find = find,
		bagCount = Bag.count(data.bagContents),
		bagValue = Bag.totalValue(data.bagContents),
	})
	PlayerData.changed(player)
end

function DigService.init()
	Net.on("DigHit", DigConfig.maxHitsPerSecond, DigConfig.maxHitsPerSecond, onDigHit)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		streaks[player] = nil
	end)
end

return DigService
