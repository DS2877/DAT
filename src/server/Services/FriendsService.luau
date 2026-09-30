--!strict
-- Friends bonus: +10% cash per friend in the same server (up to +30%).
-- Friendships are looked up once per pair and cached for the session.

local Players = game:GetService("Players")

local FriendsService = {}

local counts: { [Player]: number } = {}
local pairCache: { [string]: boolean } = {}

local function pairKey(a: number, b: number): string
	return if a < b then a .. ":" .. b else b .. ":" .. a
end

local function areFriends(a: Player, b: Player): boolean
	local key = pairKey(a.UserId, b.UserId)
	local cached = pairCache[key]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	local friends = ok and result == true
	if ok then
		pairCache[key] = friends
	end
	return friends
end

local function recount()
	local players = Players:GetPlayers()
	for _, player in players do
		local n = 0
		for _, other in players do
			if other ~= player and areFriends(player, other) then
				n += 1
			end
		end
		counts[player] = n
		player:SetAttribute("FriendsInServer", n)
	end
end

function FriendsService.count(player: Player): number
	return counts[player] or 0
end

function FriendsService.init()
	Players.PlayerAdded:Connect(function()
		task.spawn(recount)
	end)
	Players.PlayerRemoving:Connect(function(player)
		counts[player] = nil
		task.defer(recount)
	end)
	task.spawn(recount)
end

return FriendsService
