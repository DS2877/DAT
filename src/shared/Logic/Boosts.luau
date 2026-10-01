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

-- Pausing (the player switched a boost off): the time left moves to
-- `paused` and doesn't run down until it's resumed.
function Boosts.pause(
	active: { [string]: number },
	paused: { [string]: number },
	boostId: string,
	now: number
): boolean
	local left = Boosts.secondsLeft(active, boostId, now)
	if left <= 0 then
		return false
	end
	paused[boostId] = (paused[boostId] or 0) + left
	active[boostId] = nil
	return true
end

function Boosts.resume(
	active: { [string]: number },
	paused: { [string]: number },
	boostId: string,
	now: number
): boolean
	local left = paused[boostId]
	if not left or left <= 0 then
		return false
	end
	paused[boostId] = nil
	Boosts.add(active, boostId, left, now)
	return true
end

function Boosts.prune(activeBoosts: { [string]: number }, now: number)
	for id, expiry in activeBoosts do
		if type(expiry) ~= "number" or expiry <= now or not Retention.boosts[id] then
			activeBoosts[id] = nil
		end
	end
end

return Boosts
