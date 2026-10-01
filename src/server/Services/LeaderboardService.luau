--!strict
-- Leaderboards (Richest = cash earned, Most Rebirths, Rarest Find), all-time
-- and weekly, stored in OrderedDataStores. Scores are written periodically
-- (and on leave); the top entries are read periodically, drawn on the boards
-- at the base, and published to clients as JSON for the small UI.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local LeaderboardScore = require(ReplicatedStorage.Shared.Logic.LeaderboardScore)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local PlayerData = require(script.Parent.PlayerData)

local LeaderboardService = {}

local BOARDS = { "Richest", "Rebirths", "Rarest" }

-- Weeks start Monday 00:00 UTC (the Unix epoch was a Thursday).
local function weekNumber(unixTime: number): number
	return math.floor((unixTime + 3 * 86400) / (7 * 86400))
end

local function storeName(board: string, weekly: boolean, week: number): string
	return if weekly then string.format("LB_%s_W%d", board, week) else "LB_" .. board .. "_All"
end

local stores: { [string]: OrderedDataStore } = {}
local function store(name: string): OrderedDataStore?
	if stores[name] then
		return stores[name]
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if ok then
		stores[name] = result
		return result
	end
	return nil
end

-- Keeps the weekly counters on the current week.
function LeaderboardService.rollWeek(data: { [string]: any })
	local week = weekNumber(os.time())
	if data.weekly.week ~= week then
		data.weekly.week = week
		data.weekly.cashEarned = 0
		data.weekly.rebirths = 0
		data.weekly.bestScore = 0
	end
end

-- Records a new find for the weekly Rarest board.
function LeaderboardService.onFind(data: { [string]: any }, find: { [string]: any })
	LeaderboardService.rollWeek(data)
	local score = LeaderboardScore.encode(find.id, find.mutation)
	if score > data.weekly.bestScore then
		data.weekly.bestScore = score
	end
end

local function scoresFor(data: { [string]: any }): { [string]: number }
	local best = data.bestFind
	return {
		Richest_All = math.floor(data.stats.cashEarned),
		Richest_Week = math.floor(data.weekly.cashEarned),
		Rebirths_All = data.rebirths,
		Rebirths_Week = data.weekly.rebirths,
		Rarest_All = if best.id then LeaderboardScore.encode(best.id, best.m) else 0,
		Rarest_Week = data.weekly.bestScore,
	}
end

local lastWritten: { [Player]: { [string]: number } } = {}
-- When each player's scores are next written (os.clock).
local nextWriteAt: { [Player]: number } = {}
local FIRST_WRITE_DELAY = 20

local function writePlayer(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	LeaderboardService.rollWeek(data)
	local week = data.weekly.week
	local scores = scoresFor(data)
	local previous = lastWritten[player] or {}
	for _, board in BOARDS do
		for _, weekly in { false, true } do
			local key = board .. (if weekly then "_Week" else "_All")
			local value = scores[key]
			if value > 0 and previous[key] ~= value then
				local s = store(storeName(board, weekly, week))
				if s then
					local ok, err = pcall(function()
						s:SetAsync("u" .. player.UserId, value)
					end)
					if ok then
						previous[key] = value
					else
						warn("[Leaderboards] write failed: " .. tostring(err))
					end
				end
			end
		end
	end
	lastWritten[player] = previous
end

local nameCache: { [number]: string } = {}
local function displayNames(userIds: { number })
	local missing = {}
	for _, id in userIds do
		if not nameCache[id] then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok then
		for _, info in infos do
			nameCache[info.Id] = info.DisplayName
		end
	end
	for _, id in missing do
		if not nameCache[id] then
			nameCache[id] = "Player"
		end
	end
end

-- Display names for user ids (cached; "Player" when unknown).
function LeaderboardService.names(userIds: { number }): { [number]: string }
	displayNames(userIds)
	local out = {}
	for _, id in userIds do
		out[id] = nameCache[id] or "Player"
	end
	return out
end

local function readBoard(name: string): { { userId: number, value: number } }
	local s = store(name)
	local rows = {}
	if not s then
		return rows
	end
	local ok, pages = pcall(function()
		return s:GetSortedAsync(false, Retention.leaderboards.top)
	end)
	if not ok then
		return rows
	end
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 2))
		if userId then
			table.insert(rows, { userId = userId, value = entry.value })
		end
	end
	return rows
end

local published: StringValue

function LeaderboardService.refresh()
	local week = weekNumber(os.time())
	local result = {}
	local ids = {}
	for _, board in BOARDS do
		for _, weekly in { false, true } do
			local rows = readBoard(storeName(board, weekly, week))
			result[board .. (if weekly then "_Week" else "_All")] = rows
			for _, row in rows do
				table.insert(ids, row.userId)
			end
		end
	end
	displayNames(ids)
	-- Attach names, and decode Rarest scores into treasure + mutation.
	for key, rows in result do
		for _, row in rows do
			row.name = nameCache[row.userId] or "Player"
			if string.sub(key, 1, 6) == "Rarest" then
				local id, mutation = LeaderboardScore.decode(row.value)
				row.treasureId = id
				row.mutation = mutation
			end
		end
	end
	published.Value = HttpService:JSONEncode(result)
end

function LeaderboardService.init()
	published = Instance.new("StringValue")
	published.Name = "LeaderboardData"
	published.Value = "{}"
	published.Parent = ReplicatedStorage

	PlayerData.Loaded:Connect(function(player: Player, data)
		LeaderboardService.rollWeek(data)
		nextWriteAt[player] = os.clock() + FIRST_WRITE_DELAY
	end)
	-- Final write on leave. Connected before PlayerData's own handler (init
	-- order), so the profile is still readable when this starts.
	Players.PlayerRemoving:Connect(function(player)
		nextWriteAt[player] = nil
		writePlayer(player)
		lastWritten[player] = nil
	end)
end

-- Writes this player's scores on the next loop tick (e.g. after a rebirth).
function LeaderboardService.requestWrite(player: Player)
	if nextWriteAt[player] then
		nextWriteAt[player] = 0
	end
end

function LeaderboardService.start()
	-- Each player is written on their own timer, spread out over time.
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for player, at in nextWriteAt do
				if now >= at then
					nextWriteAt[player] = now + Retention.leaderboards.writeInterval
					writePlayer(player)
				end
			end
		end
	end)
	task.spawn(function()
		task.wait(30)
		while true do
			LeaderboardService.refresh()
			task.wait(Retention.leaderboards.readInterval)
		end
	end)
end

return LeaderboardService
