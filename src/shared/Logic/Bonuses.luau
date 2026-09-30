--!strict
-- Pure: every cash multiplier in one place. Categories multiply together;
-- inside a category bonuses add up.

local Boosts = require(script.Parent.Boosts)
local Collection = require(script.Parent.Collection)
local Progression = require(script.Parent.Progression)
local Rebirth = require(script.Parent.Rebirth)
local Retention = require(script.Parent.Parent.Config.Retention)

local Bonuses = {}

export type Parts = {
	sets: number,
	rebirths: number,
	friends: number,
	boost: number,
}

function Bonuses.friendsBonus(friendCount: number): number
	local f = Retention.friends
	return math.min(f.maxBonus, friendCount * f.bonusPerFriend)
end

function Bonuses.parts(data: { [string]: any }, friendCount: number, now: number): Parts
	return {
		sets = Collection.cashMultiplier(data.discovered),
		rebirths = 1 + data.rebirths * Retention.rebirth.cashBonusPerRebirth,
		friends = 1 + Bonuses.friendsBonus(friendCount),
		boost = Boosts.multiplier(data.activeBoosts, "Cash2x", now),
	}
end

function Bonuses.cashMultiplier(data: { [string]: any }, friendCount: number, now: number): number
	local p = Bonuses.parts(data, friendCount, now)
	return p.sets * p.rebirths * p.friends * p.boost
end

-- Cash for a { kind = "Cash" } reward: a share of the player's next goal.
function Bonuses.rewardCash(reward: { [string]: any }, data: { [string]: any }): number
	local goal = Progression.nextGoal(data.cash, data.shovelLevel, data.bagLevel)
	local goalCost = if goal then goal.cost else Rebirth.cost(data.rebirths)
	return math.max(reward.min or 0, math.floor(goalCost * (reward.goalPercent or 0) + 0.5))
end

-- Seconds between dig hits for a shovel, with the dig speed boost.
function Bonuses.hitInterval(data: { [string]: any }, now: number): number
	local shovel = Progression.getShovel(data.shovelLevel)
	return shovel.hitInterval / Boosts.multiplier(data.activeBoosts, "DigSpeed2x", now)
end

return Bonuses
