--!strict
-- Pure: every cash multiplier in one place. Categories multiply together;
-- inside a category bonuses add up.

local Boosts = require(script.Parent.Boosts)
local Collection = require(script.Parent.Collection)
local Goals = require(script.Parent.Goals)
local Perks = require(script.Parent.Perks)
local Progression = require(script.Parent.Progression)
local RebirthPerks = require(script.Parent.RebirthPerks)
local Retention = require(script.Parent.Parent.Config.Retention)

local Bonuses = {}

export type Parts = {
	sets: number,
	rebirths: number,
	friends: number,
	boost: number,
	passes: number,
}

function Bonuses.friendsBonus(friendCount: number): number
	local f = Retention.friends
	return math.min(f.maxBonus, friendCount * f.bonusPerFriend)
end

-- `serverBoost`: a bought server-wide 2x Cash is running. It doesn't stack
-- with a personal 2x Cash boost (the bigger of the two counts).
function Bonuses.parts(
	data: { [string]: any },
	friendCount: number,
	now: number,
	serverBoost: boolean?
): Parts
	local boost = Boosts.multiplier(data.activeBoosts, "Cash2x", now)
	if serverBoost then
		boost = math.max(boost, Retention.boosts.Cash2x.multiplier)
	end
	boost *= Boosts.multiplier(data.activeBoosts, "CoconutCash", now)
	return {
		sets = Collection.cashMultiplier(data.discovered),
		-- Rebirths, and the Haggler rebirth perk.
		rebirths = 1
			+ data.rebirths * Retention.rebirth.cashBonusPerRebirth
			+ RebirthPerks.value(data, "Haggler"),
		friends = 1 + Bonuses.friendsBonus(friendCount),
		boost = boost,
		passes = Perks.cashMultiplier(data),
	}
end

function Bonuses.cashMultiplier(
	data: { [string]: any },
	friendCount: number,
	now: number,
	serverBoost: boolean?
): number
	local p = Bonuses.parts(data, friendCount, now, serverBoost)
	return p.sets * p.rebirths * p.friends * p.boost * p.passes
end

-- Cash for a { kind = "Cash" } reward: a share of the player's next goal.
function Bonuses.rewardCash(reward: { [string]: any }, data: { [string]: any }): number
	local goalCost = Goals.current(data).cost
	return math.max(reward.min or 0, math.floor(goalCost * (reward.goalPercent or 0) + 0.5))
end

-- Seconds between dig hits for a shovel, with the dig speed pass / boost.
function Bonuses.hitInterval(data: { [string]: any }, now: number): number
	local shovel = Progression.getShovel(data.shovelLevel)
	return shovel.hitInterval / Perks.digSpeed(data, now)
end

return Bonuses
