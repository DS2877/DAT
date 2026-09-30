--!strict
-- Free retention rewards: playtime gifts (per session), the 7-day daily
-- calendar, the daily Golden X dig spot, and the one-time group reward.
-- None of these ever take away anything a player has earned.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local Daily = require(ReplicatedStorage.Shared.Logic.Daily)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Analytics = require(script.Parent.Analytics)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.Parent.World.World)

local RewardService = {}

type Reward = { [string]: any }

-- Playtime gift session state (not saved: gifts restart each session).
local sessionStart: { [Player]: number } = {} -- server time (GetServerTimeNow)
-- Keyed by tostring(gift index): sparse arrays don't survive remote calls.
local giftsClaimed: { [Player]: { [string]: boolean } } = {}

---------------------------------------------------------------------------
-- Granting
---------------------------------------------------------------------------

-- Grants a reward and returns a short description ("$1,200", "2x Cash 5 min").
function RewardService.grant(player: Player, data: { [string]: any }, reward: Reward, source: string): string
	local kind = reward.kind
	if kind == "Cash" then
		local amount = Bonuses.rewardCash(reward, data)
		EconomyService.addCash(player, data, amount, "TimedReward", source)
		return Format.cash(amount)
	elseif kind == "Boost" then
		Boosts.add(data.activeBoosts, reward.boost, reward.seconds, os.time())
		return string.format(
			"%s for %d min",
			Retention.boosts[reward.boost].displayName,
			math.floor(reward.seconds / 60)
		)
	elseif kind == "RareDig" or kind == "EpicDig" then
		local rarity = if kind == "RareDig" then "Rare" else "Epic"
		data.digCharges[rarity] += reward.count
		return string.format("%dx guaranteed %s dig", reward.count, rarity)
	elseif kind == "Bundle" then
		local parts = {}
		for _, item in reward.items do
			table.insert(parts, RewardService.grant(player, data, item, source))
		end
		return table.concat(parts, " + ")
	end
	return ""
end

---------------------------------------------------------------------------
-- Golden X: one special spot per player per day (guaranteed Epic+)
---------------------------------------------------------------------------

-- The player's Golden X for today, or nil once dug. Placed on a candidate
-- point in their best unlocked area, chosen by day and player.
function RewardService.goldenX(
	player: Player,
	data: { [string]: any }
): { areaId: string, position: Vector3 }?
	local today = Daily.today(os.time())
	if data.dailyState.goldenXDay == today then
		return nil
	end
	local unlocked = Progression.unlockedAreas(data.shovelLevel)
	local areaId = unlocked[#unlocked] or "Beach"
	local candidates = World.get().candidates[areaId]
	if not candidates or #candidates == 0 then
		return nil
	end
	local index = Random.new(today * 7919 + player.UserId):NextInteger(1, #candidates)
	return { areaId = areaId, position = candidates[index] }
end

function RewardService.consumeGoldenX(data: { [string]: any })
	data.dailyState.goldenXDay = Daily.today(os.time())
end

---------------------------------------------------------------------------
-- Snapshot for the client
---------------------------------------------------------------------------

function RewardService.snapshot(player: Player, data: { [string]: any })
	local golden = RewardService.goldenX(player, data)
	local canDaily, dailyDay = Daily.status(data.dailyState, Daily.today(os.time()))
	return {
		giftStart = sessionStart[player] or workspace:GetServerTimeNow(),
		giftsClaimed = giftsClaimed[player] or {},
		dailyCanClaim = canDaily,
		dailyDay = dailyDay,
		dailyStreak = data.dailyState.streak,
		goldenX = if golden then { areaId = golden.areaId, position = golden.position } else nil,
		groupRewardClaimed = data.groupRewardClaimed,
		digCharges = data.digCharges,
		activeBoosts = data.activeBoosts,
	}
end

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------

local function onClaimGift(player: Player, index: any)
	local data = PlayerData.get(player)
	local gift = type(index) == "number" and Retention.playtimeGifts[index]
	if not data or not gift or not sessionStart[player] then
		return
	end
	local claimed = giftsClaimed[player]
	if claimed[tostring(index)] then
		return
	end
	-- Allow a couple of seconds of clock slack.
	if workspace:GetServerTimeNow() - sessionStart[player] + 2 < gift.minutes * 60 then
		return
	end
	claimed[tostring(index)] = true
	local text = RewardService.grant(player, data, gift.reward, "PlaytimeGift_" .. index)
	Analytics.custom(player, "PlaytimeGift", index)
	Net.fire("Notify", player, "Gift: " .. text .. "!", "Reward")
	PlayerData.changed(player)
end

local function onClaimDaily(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local day = Daily.claim(data.dailyState, Daily.today(os.time()))
	if not day then
		return
	end
	local text = RewardService.grant(player, data, Retention.daily[day], "DailyReward_" .. day)
	Analytics.custom(player, "DailyReward", day)
	Net.fire("Notify", player, string.format("Day %d reward: %s!", day, text), "Reward")
	PlayerData.changed(player)
end

local function onClaimGroupReward(player: Player)
	local data = PlayerData.get(player)
	local groupId = Retention.group.groupId
	if not data or groupId == 0 or data.groupRewardClaimed then
		return
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroup(groupId)
	end)
	if not ok or not inGroup then
		Net.fire("Notify", player, "Join the group first, then claim!", "Denied")
		return
	end
	data.groupRewardClaimed = true
	local text = RewardService.grant(player, data, Retention.group.reward, "GroupReward")
	Analytics.custom(player, "GroupReward")
	Net.fire("Notify", player, "Thanks for joining! " .. text, "Reward")
	PlayerData.changed(player)
end

function RewardService.init()
	PlayerData.extendSnapshot(RewardService.snapshot)
	PlayerData.Loaded:Connect(function(player: Player, data)
		sessionStart[player] = workspace:GetServerTimeNow()
		giftsClaimed[player] = {}
		Boosts.prune(data.activeBoosts, os.time())
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessionStart[player] = nil
		giftsClaimed[player] = nil
	end)
	Net.on("ClaimGift", 2, 3, onClaimGift)
	Net.on("ClaimDaily", 1, 2, onClaimDaily)
	Net.on("ClaimGroupReward", 0.5, 1, onClaimGroupReward)
end

return RewardService
