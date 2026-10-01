--!strict
-- The Frost Portal (Config/Worlds): the way to the next world.
--   * Below the required rebirths, stepping in pushes you back out with
--     your progress ("Rebirth 3 to enter, you: 1/3").
--   * Reaching it opens the portal for you for good: a fanfare, a server
--     announcement, and your name on the First Explorers board (an
--     OrderedDataStore of unlock times, earliest first).
--   * Stepping in once it's open sends you to a Frostbite Peaks server
--     (Services/WorldServers), or, while the world is closed (Worlds.next
--     .open = false), shows the "being built" screen with the launch sign-up.
--   * In Frostbite Peaks the same portal leads back to the island, open for
--     everyone.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)
local Analytics = require(script.Parent.Analytics)
local AnnouncementService = require(script.Parent.AnnouncementService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local WorldServers = require(script.Parent.WorldServers)
local World = require(script.Parent.Parent.World.World)

local WorldPortalService = {}

local inFrost = CurrentWorld.isFrost()

local nextReactAt: { [Player]: number } = {}
local boardDirty = true

local function explorers(): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("FirstExplorers_" .. Worlds.next.id)
	end)
	return if ok then store else nil
end

function WorldPortalService.isOpenFor(data: { [string]: any }): boolean
	return data.rebirths >= Worlds.next.requiredRebirths
end

-- The portal opens for this player (once).
local function attune(player: Player, data: { [string]: any })
	local w = Worlds.next
	local now = os.time()
	data.worldUnlocks[w.id] = now
	local store = explorers()
	if store then
		task.spawn(function()
			pcall(function()
				-- Keep the earliest time if this player was recorded before.
				store:UpdateAsync("u" .. player.UserId, function(old: number?)
					return if type(old) == "number" then old else now
				end)
			end)
			boardDirty = true
		end)
	end
	Net.fire("Portal", player, "Attuned", { name = w.name })
	AnnouncementService.announce({
		text = string.format("❄️ %s opened the FROST PORTAL!", player.DisplayName),
		color = w.color,
		secret = false,
	})
	Analytics.custom(player, "PortalUnlocked_" .. w.id)
	PlayerData.changed(player)
end

-- Puts the player on the dais step, facing away from the portal.
local function stepOut(player: Player)
	local portal = World.get().portal
	local character = player.Character
	if not character then
		return
	end
	local spot = Vector3.new(portal.center.X, portal.ground, portal.center.Z)
		+ portal.normal * Worlds.portal.pushBack
		+ Vector3.new(0, 4, 0)
	character:PivotTo(CFrame.lookAt(spot, spot + portal.normal))
end

local function travel(player: Player, name: string, go: () -> boolean)
	Net.fire("Portal", player, "Teleporting", { name = name })
	if not go() then
		stepOut(player)
		Net.fire("Portal", player, "TripFailed", nil)
		Net.fire("Notify", player, "The portal flickered... try again in a moment!", "Denied")
	end
end

local function enter(player: Player, data: { [string]: any })
	local w = Worlds.next
	if inFrost then
		travel(player, Worlds.home.name, function()
			return WorldServers.sendHome(player)
		end)
		return
	end
	if not WorldPortalService.isOpenFor(data) then
		stepOut(player)
		Net.fire("Portal", player, "Locked", { have = data.rebirths, need = w.requiredRebirths })
		Net.fire(
			"Notify",
			player,
			string.format(
				"❄️ Rebirth %d to enter the Frost Portal (you: %d/%d)",
				w.requiredRebirths,
				data.rebirths,
				w.requiredRebirths
			),
			"Denied"
		)
		return
	end
	if w.open then
		Analytics.custom(player, "PortalTravel_" .. w.id)
		travel(player, w.name, function()
			return WorldServers.send(player, w.id)
		end)
		return
	end
	stepOut(player)
	Net.fire("Portal", player, "ComingSoon", { name = w.name })
	Analytics.custom(player, "PortalComingSoon_" .. w.id)
end

local function refreshBoard()
	local store = explorers()
	local board = workspace:FindFirstChild("FrostPortal")
	local list = board and board:FindFirstChild("List", true) :: TextLabel?
	if not store or not list then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(true, Worlds.portal.explorersShown)
	end)
	if not ok then
		return
	end
	local ids = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 2))
		if userId then
			table.insert(ids, userId)
		end
	end
	if #ids == 0 then
		return
	end
	local names = LeaderboardService.names(ids)
	local lines = {}
	for i, id in ids do
		table.insert(lines, string.format("%d. %s", i, names[id]))
	end
	list.Text = table.concat(lines, "\n")
end

-- Checks every player: open the portal for those who just qualified, and
-- react to anyone stepping into the ring.
local function tick()
	local portal = World.get().portal
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		if data then
			if
				not inFrost
				and WorldPortalService.isOpenFor(data)
				and not data.worldUnlocks[Worlds.next.id]
			then
				attune(player, data)
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and now >= (nextReactAt[player] or 0) then
				local offset = root.Position - portal.center
				local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if
					flat <= Worlds.portal.triggerRadius
					and math.abs(offset.Y) <= Worlds.portal.ringRadius + 2
				then
					nextReactAt[player] = now + Worlds.portal.cooldown
					enter(player, data)
				end
			end
		end
	end
end

function WorldPortalService.init()
	Players.PlayerRemoving:Connect(function(player)
		nextReactAt[player] = nil
	end)
	-- A trip that failed after it started (full server, Roblox hiccup).
	TeleportService.TeleportInitFailed:Connect(function(player: Player, _result, message: string)
		warn("[WorldPortalService] Teleport failed: " .. tostring(message))
		if player.Parent then
			stepOut(player)
			Net.fire("Portal", player, "TripFailed", nil)
			Net.fire("Notify", player, "The portal flickered... try again in a moment!", "Denied")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			tick()
		end
	end)
	task.spawn(function()
		local lastRead = -math.huge
		while true do
			task.wait(1)
			if boardDirty or os.clock() - lastRead >= Worlds.portal.boardRefresh then
				boardDirty = false
				lastRead = os.clock()
				refreshBoard()
			end
		end
	end)
end

return WorldPortalService
