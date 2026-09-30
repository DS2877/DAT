--!strict
-- Pure timed boosts. activeBoosts = { [boostId] = expiry unix time }.

local Retention = require(script.Parent.Parent.Config.Retention)

local Boosts = {}

function Boosts.isActive(activeBoosts: { [string]: number }, boostId: string, now: number): boolean
	local expiry = activeBoosts[boostId]
	return expiry ~= nil and expiry > now
end

function Boosts.secondsLeft(activeBoosts: { [string]: number }, boostId: string, now: number): number
	return math.max(0, (activeBoosts[boostId] or 0) - now)
end

-- Adds time; stacking extends an active boost instead of wasting it.
function Boosts.add(activeBoosts: { [string]: number }, boostId: string, seconds: number, now: number)
	assert(Retention.boosts[boostId], "Unknown boost " .. boostId)
	activeBoosts[boostId] = math.max(activeBoosts[boostId] or 0, now) + seconds
end

function Boosts.multiplier(activeBoosts: { [string]: number }, boostId: string, now: number): number
	return if Boosts.isActive(activeBoosts, boostId, now) then Retention.boosts[boostId].multiplier else 1
end

function Boosts.prune(activeBoosts: { [string]: number }, now: number)
	for id, expiry in activeBoosts do
		if type(expiry) ~= "number" or expiry <= now or not Retention.boosts[id] then
			activeBoosts[id] = nil
		end
	end
end

return Boosts
