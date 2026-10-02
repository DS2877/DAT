--!strict
-- Validates dig hits and completes digs. The client only says "I hit spot N";
-- the server checks the spot, range, area unlock, bag space and hit timing,
-- then rolls loot when the required number of hits is reached.
--
-- Pass perks handled here: the VIP dig spot (VIP only), Auto Sell (sells
-- the bag the moment it fills), and Instant Deep Dig (finishes a Deep Dig).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bag = require(ReplicatedStorage.Shared.Logic.Bag)
local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local DigConfig = require(ReplicatedStorage.Shared.Config.Dig)
local Loot = require(ReplicatedStorage.Shared.Config.Loot)
local Perks = require(ReplicatedStorage.Shared.Logic.Perks)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Rush = require(ReplicatedStorage.Shared.Logic.Rush)
local Streak = require(ReplicatedStorage.Shared.Logic.Streak)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Analytics = require(script.Parent.Analytics)
local AnnouncementService = require(script.Parent.AnnouncementService)
local CollectionService = require(script.Parent.CollectionService)
local DigSpotService = require(script.Parent.DigSpotService)
local EconomyService = require(script.Parent.EconomyService)
local FriendsService = require(script.Parent.FriendsService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local LootService = require(script.Parent.LootService)
local MegaDigService = require(script.Parent.MegaDigService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local RewardService = require(script.Parent.RewardService)
local ServerBoostService = require(script.Parent.ServerBoostService)

local DigService = {}

-- Fired (player, data) for each PERFECT hit, and (player, data, find, spot)
-- for each finished dig (bounties, pets and events listen).
DigService.Perfect = Signal.new()
DigService.Found = Signal.new()

type DigState = {
	spotId: number,
	hits: number,
	required: number,
	lastHit: number,
	deep: boolean,
}

local states: { [Player]: DigState } = {}
local finish: (Player, { [string]: any }, DigSpotService.Spot, DigState, boolean) -> ()
local streaks: { [Player]: Streak.State } = {}
local random = Random.new()
local lastRushLogged: { [Player]: number } = {}
local lastPerfect: { [Player]: number } = {}
local autoSellQueued: { [Player]: boolean } = {}

-- Set by JackpotService: a hidden treasure was dug up.
DigService.onHiddenFound = function(_player: Player, _spotId: number, _find: { [string]: any }) end

-- Set by PurchaseService: whether paid luck may apply to this player
-- (PolicyService's paid-random-items restriction).
DigService.luckAllowed = function(_player: Player): boolean
	return true
end

-- The id the client uses for its personal daily Golden X spot.
local GOLDEN_X_ID = -1

local function reject(player: Player, spotId: number, reason: string)
	Net.fire("DigResult", player, { spotId = spotId, rejected = reason })
end

local function onDigHit(player: Player, spotId: any, perfect: any)
	if type(spotId) ~= "number" or spotId ~= spotId or spotId % 1 ~= 0 then
		return -- malformed
	end
	perfect = perfect == true
	local data = PlayerData.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	local isGoldenX = spotId == GOLDEN_X_ID
	local spot: DigSpotService.Spot? = nil
	if isGoldenX then
		local golden = RewardService.goldenX(player, data)
		if golden then
			spot = {
				id = GOLDEN_X_ID,
				areaId = golden.areaId,
				position = golden.position,
				candidateIndex = 0,
				model = nil :: any,
				clue = nil,
				reservedBy = player,
				reservedUntil = math.huge,
			}
		end
	else
		spot = DigSpotService.get(spotId)
	end
	if not spot then
		reject(player, spotId, "Gone")
		return
	end
	-- The Mega Dig site: dug by everyone together.
	if spot.mega then
		local p = root.Position
		if
			Zones.flatDistance(p.X, p.Z, spot.position.X, spot.position.Z)
				> (spot.range or DigConfig.serverRange)
			or math.abs(p.Y - spot.position.Y) > 14
		then
			reject(player, spotId, "TooFar")
		elseif MegaDigService.onHit(player, data) then
			character:SetAttribute("DigHits", ((character:GetAttribute("DigHits") :: number?) or 0) + 1)
		end
		return
	end
	if spot.vip then
		if not Perks.enabled(data, "VIP") then
			reject(player, spotId, "VipOnly")
			return
		end
	elseif not Progression.isAreaUnlocked(spot.areaId, data.shovelLevel) then
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
	if Bag.isFull(data.bagContents, Perks.bagCapacity(data)) then
		reject(player, spotId, "BagFull")
		return
	end
	-- A Deep Dig reserves its spot for the player who found it.
	if spot.reservedBy and spot.reservedBy ~= player and os.clock() < spot.reservedUntil then
		reject(player, spotId, "Taken")
		return
	end

	local shovel = Progression.getShovel(data.shovelLevel)
	local hitInterval = Bonuses.hitInterval(data, os.time())
	local now = os.clock()
	local state = states[player]
	if state and now - state.lastHit < hitInterval * DigConfig.hitTolerance then
		reject(player, spotId, "TooFast")
		return
	end
	if not state or state.spotId ~= spotId or now - state.lastHit > DigConfig.progressTimeout then
		local required = shovel.hits + (DigConfig.areaExtraHits[spot.areaId] or 0)
		state = { spotId = spotId, hits = 0, required = required, lastHit = now, deep = false }
		states[player] = state
	end
	local s = state :: DigState
	s.hits += 1
	s.lastHit = now
	-- A PERFECT tap (timed on the client's ring) digs extra, once per cycle.
	local wasPerfect = false
	if perfect and now - (lastPerfect[player] or -math.huge) >= DigConfig.perfect.cycle * 0.75 then
		lastPerfect[player] = now
		s.hits += DigConfig.perfect.bonusHits
		wasPerfect = true
		DigService.Perfect:Fire(player, data)
	end

	if data.stats.digs == 0 and s.hits == 1 then
		Analytics.funnel(player, data, "FirstDig")
	end
	-- Lets every client play this player's swing (see EffectsController).
	character:SetAttribute("DigHits", ((character:GetAttribute("DigHits") :: number?) or 0) + 1)

	if s.deep then
		spot.reservedUntil = now + DigConfig.progressTimeout
	end

	-- The finishing hit of a normal dig may turn into a Deep Dig.
	if
		s.hits >= s.required
		and not s.deep
		and not isGoldenX
		and Loot.deepDig.areas[spot.areaId]
		and random:NextNumber() < Loot.deepDig.areas[spot.areaId].chance
	then
		s.deep = true
		s.required += Loot.deepDig.areas[spot.areaId].extraHits
		spot.reservedBy = player
		spot.reservedUntil = now + DigConfig.progressTimeout
		Analytics.custom(player, "DeepDig")
		Net.fire(
			"DigResult",
			player,
			{ spotId = spotId, hits = s.hits, required = s.required, deepDig = true, perfect = wasPerfect }
		)
		-- A saved Instant Deep Dig finishes it right away.
		if data.instantDeepDigs > 0 and data.settings.instantDeepDig ~= false then
			task.delay(0.8, function()
				if data.instantDeepDigs > 0 and DigService.instantDeepDig(player) then
					data.instantDeepDigs -= 1
					PlayerData.changed(player)
				end
			end)
		end
		return
	end

	if s.hits < s.required then
		Net.fire(
			"DigResult",
			player,
			{ spotId = spotId, hits = s.hits, required = s.required, deep = s.deep, perfect = wasPerfect }
		)
		return
	end

	if wasPerfect then
		Net.fire(
			"DigResult",
			player,
			{ spotId = spotId, perfect = true, hits = s.hits, required = s.required }
		)
	end
	finish(player, data, spot, s, isGoldenX)
end

-- Completes a dig: rolls the find, bags it, and tells everyone.
function finish(
	player: Player,
	data: { [string]: any },
	spot: DigSpotService.Spot,
	s: DigState,
	isGoldenX: boolean
)
	local spotId = spot.id
	local wasDeep = s.deep
	s.spotId = -1
	s.hits = 0
	s.deep = false
	if isGoldenX then
		RewardService.consumeGoldenX(data)
	else
		DigSpotService.consume(spotId)
	end
	local serverNow = workspace:GetServerTimeNow()
	if
		Rush.isActive(serverNow, workspace:GetAttribute("RushUntil"))
		and lastRushLogged[player] ~= Rush.id(serverNow)
	then
		lastRushLogged[player] = Rush.id(serverNow)
		Analytics.custom(player, "TreasureRushDig")
	end
	local streak = streaks[player] or Streak.new()
	streaks[player] = streak
	-- The VIP spot rolls like a clue spot in the player's best area.
	local unlocked = Progression.unlockedAreas(data.shovelLevel)
	local lootArea = if spot.vip then unlocked[#unlocked] or spot.areaId else spot.lootArea or spot.areaId
	local find = LootService.rollFor(data, {
		areaId = lootArea,
		clue = spot.clue,
		luck = if DigService.luckAllowed(player) then Perks.luckMultipliers(data) else nil,
		serverBoost = ServerBoostService.isActive(),
		jackpot = spot.jackpot or spot.forceRarity,
		streak = Streak.onDig(streak, os.clock()),
		deep = wasDeep,
		goldenX = isGoldenX,
		friends = FriendsService.count(player),
	})
	LeaderboardService.onFind(data, find)
	local capacity = Perks.bagCapacity(data)
	Bag.add(data.bagContents, { id = find.id, v = find.value, m = find.mutation }, capacity)
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
	CollectionService.onFind(player, data, find)
	DigService.Found:Fire(player, data, find, spot)
	if spot.jackpot then
		DigService.onHiddenFound(player, spotId, find)
	else
		AnnouncementService.onFind(player, find, spot.position)
	end
	PlayerData.changed(player)

	-- Auto Sell: a full bag sells itself (after the find's reveal).
	if
		Bag.isFull(data.bagContents, capacity)
		and Perks.enabled(data, "AutoSell")
		and not autoSellQueued[player]
	then
		autoSellQueued[player] = true
		task.delay(1.6, function()
			autoSellQueued[player] = nil
			if player.Parent and Perks.enabled(data, "AutoSell") then
				EconomyService.sellAll(player, "AutoSell")
			end
		end)
	end
end

-- Finishes the player's running Deep Dig at once (Instant Deep Dig).
-- Returns false if no Deep Dig is running.
function DigService.instantDeepDig(player: Player): boolean
	local data = PlayerData.get(player)
	local state = states[player]
	if not data or not state or not state.deep or state.spotId <= 0 then
		return false
	end
	local spot = DigSpotService.get(state.spotId)
	if not spot or spot.reservedBy ~= player then
		return false
	end
	state.hits = state.required
	finish(player, data, spot, state, false)
	return true
end

-- True while the player has a Deep Dig running.
function DigService.hasDeepDig(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.deep and state.spotId > 0
end

function DigService.init()
	Net.on("DigHit", DigConfig.maxHitsPerSecond, DigConfig.maxHitsPerSecond, onDigHit)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		streaks[player] = nil
		lastRushLogged[player] = nil
		lastPerfect[player] = nil
		autoSellQueued[player] = nil
	end)
end

return DigService
