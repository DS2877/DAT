--!strict
-- Owns player profiles: load on join, autosave, save on leave / shutdown,
-- and syncing a small snapshot to the owning client.
--
-- On load failure the player is kicked with a friendly message. A blank
-- profile is never started for someone whose save could not be read.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataSchema = require(ReplicatedStorage.Shared.Logic.DataSchema)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Analytics = require(script.Parent.Analytics)
local Net = require(script.Parent.Parent.Net)
local SessionStore = require(script.Parent.Parent.Data.SessionStore)

local STORE_NAME = "DigForCash_Profiles_v1"
local AUTOSAVE_INTERVAL = 60

local PlayerData = {}

-- Fired (player, data) once a profile is loaded and the player may play.
PlayerData.Loaded = Signal.new()

local store = SessionStore.new(STORE_NAME)
local sessions: { [Player]: SessionStore.Session } = {}
local joinClock: { [Player]: number } = {}
local releasing: { [number]: boolean } = {}
local syncQueued: { [Player]: boolean } = {}

local function keyFor(userId: number): string
	return "Player_" .. userId
end

function PlayerData.get(player: Player): { [string]: any }?
	local session = sessions[player]
	return if session then session.data else nil
end

function PlayerData.isLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

-- The part of the profile the owning client needs to draw its UI.
local function snapshot(data: { [string]: any })
	local discoveredCount = 0
	for _ in data.discovered do
		discoveredCount += 1
	end
	return {
		cash = data.cash,
		shovelLevel = data.shovelLevel,
		bagLevel = data.bagLevel,
		bag = data.bagContents,
		rebirths = data.rebirths,
		discoveredCount = discoveredCount,
		finds = data.stats.finds,
		sales = data.stats.sales,
		guideDone = data.onboarding.guideDone,
		discovered = data.discovered,
	}
end

-- Queues a snapshot for the client (coalesced to one per frame).
function PlayerData.changed(player: Player)
	if syncQueued[player] or not sessions[player] then
		return
	end
	syncQueued[player] = true
	task.defer(function()
		syncQueued[player] = nil
		local session = sessions[player]
		if session and player.Parent then
			Net.fire("DataSync", player, snapshot(session.data))
		end
	end)
end

local function onPlayerAdded(player: Player)
	local key = keyFor(player.UserId)
	-- Same-server rejoin: wait for the previous session's release to finish.
	local waited = 0
	while releasing[player.UserId] and waited < 30 do
		waited += task.wait(0.5)
	end
	if not player.Parent then
		return
	end

	local session, reason = store:load(key, DataSchema.migrate)
	if not player.Parent then
		-- Left while loading: release the lock we just took.
		if session then
			store:save(session, true)
		end
		return
	end
	if not session then
		local message = if reason == "Locked"
			then "Your treasure is still being saved from another server. Please rejoin in a minute!"
			else "We couldn't load your save right now. Please rejoin - your progress is safe!"
		player:Kick(message)
		return
	end

	local data = session.data
	local now = os.time()
	data.stats.sessions += 1
	data.stats.lastJoin = now
	if data.stats.firstJoin == 0 then
		data.stats.firstJoin = now
	end
	sessions[player] = session
	joinClock[player] = os.clock()

	Analytics.funnel(player, data, "Joined")
	PlayerData.Loaded:Fire(player, data)
	PlayerData.changed(player)
end

local function saveAndRelease(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	syncQueued[player] = nil
	local started = joinClock[player]
	joinClock[player] = nil
	if started then
		local seconds = os.clock() - started
		session.data.stats.playSeconds += math.floor(seconds)
		Analytics.custom(player, "SessionMinutes", math.floor(seconds / 60 * 10) / 10)
	end
	releasing[player.UserId] = true
	store:save(session, true)
	releasing[player.UserId] = nil
end

function PlayerData.init()
	Net.on("RequestSync", 2, 3, function(player)
		PlayerData.changed(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(saveAndRelease)

	-- Autosave (staggered so requests don't burst), also refreshes locks.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			-- Iterate a copy: players may join or leave while saves yield.
			for player, session in table.clone(sessions) do
				if sessions[player] == session then
					local ok = store:save(session, false)
					if not ok and session.lost and player.Parent then
						sessions[player] = nil
						player:Kick("Your save was opened in another server. Please rejoin!")
					end
					task.wait(0.25)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and store:isMock() then
			return
		end
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				saveAndRelease(player)
				pending -= 1
			end)
		end
		-- Also wait for saves already started by PlayerRemoving.
		local waited = 0
		while (pending > 0 or next(releasing) ~= nil) and waited < 25 do
			waited += task.wait(0.25)
		end
	end)
end

return PlayerData
