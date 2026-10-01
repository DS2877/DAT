--!strict
-- The admin panel's server side. Only admins (Config/Admin: the game's
-- owner, listed user ids, everyone in Studio) may act; every request is
-- checked here, never trusted from the client.
--
-- Actions on a player (target = a user id, default yourself): cash, shovel,
-- bag, rebirths, passes (for testing: the profile only, not Roblox), boosts,
-- Instant Deep Digs, treasures, tutorial / full reset, teleport, bring, kick.
-- Server actions: Treasure Rush, server 2x Cash, ADMIN ABUSE, hidden
-- treasures, announcements, time of day, your own speed / jump.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Admin = require(ReplicatedStorage.Shared.Config.Admin)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local DataSchema = require(ReplicatedStorage.Shared.Logic.DataSchema)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local Analytics = require(script.Parent.Analytics)
local AnnouncementService = require(script.Parent.AnnouncementService)
local CharacterService = require(script.Parent.CharacterService)
local EconomyService = require(script.Parent.EconomyService)
local JackpotService = require(script.Parent.JackpotService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.Parent.World.World)

local AdminService = {}

local started = os.clock()

function AdminService.isAdmin(player: Player): boolean
	if RunService:IsStudio() or table.find(Admin.userIds, player.UserId) then
		return true
	end
	local ok, result = pcall(function()
		if game.CreatorType == Enum.CreatorType.User then
			return player.UserId == game.CreatorId
		end
		return player:GetRankInGroup(game.CreatorId) >= Admin.groupMinRank
	end)
	return ok and result == true
end

local function say(player: Player, text: string)
	Net.fire("Notify", player, "🛠️ " .. text, "Reward")
end

local function refresh(player: Player)
	CharacterService.refreshShovel(player)
	CharacterService.refreshTitle(player)
	PlayerData.changed(player)
end

local function setCash(target: Player, data: { [string]: any }, amount: number)
	amount = math.max(0, math.floor(amount))
	if amount > data.cash then
		EconomyService.addCash(target, data, amount - data.cash, "Gameplay", "Admin")
	else
		EconomyService.spendCash(target, data, data.cash - amount, "Gameplay", "Admin")
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function teleport(player: Player, position: Vector3)
	local root = rootOf(player)
	if root and player.Character then
		player.Character:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	end
end

-- Named places to teleport to.
local function place(name: string): Vector3?
	local world = World.get()
	local function ground(x: number, z: number): Vector3
		local hit = workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -1200, 0))
		return Vector3.new(x, if hit then hit.Position.Y else MapLayout.beachHeight + 3, z)
	end
	if name == "Base" then
		return world.spawnPosition
	elseif name == "VIP" then
		return world.vipSpot + Vector3.new(0, 1, 6)
	elseif name == "Tiki" then
		local drinks = world.stations.Drinks
		return if drinks then drinks.position else nil
	elseif name == "Summit" then
		local v = MapLayout.volcano
		return ground(v.x + 22, v.z)
	elseif Areas.Defs[name] then
		local region = MapLayout.spotRegions[name]
		return ground((region.minX + region.maxX) / 2, (region.minZ + region.maxZ) / 2)
	end
	return nil
end

-- A random treasure of a rarity, straight into the bag (and collection).
local function giveTreasure(data: { [string]: any }, rarity: string): string?
	local pool = {}
	for _, def in Treasures.List do
		if def.rarity == rarity then
			table.insert(pool, def)
		end
	end
	if #pool == 0 then
		return nil
	end
	local def = pool[math.random(1, #pool)]
	table.insert(data.bagContents, { id = def.id, v = def.value })
	data.discovered[def.id] = data.discovered[def.id] or { normal = true }
	return def.name
end

local function abuseActive(): boolean
	local untilTime = workspace:GetAttribute("AdminAbuseUntil")
	return type(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

-- ADMIN ABUSE: 2x cash + Treasure Rush for everyone, every spot is a clue
-- spot, and a hidden treasure every minute.
local function startAbuse(admin: Player, minutes: number)
	local untilTime = workspace:GetServerTimeNow() + minutes * 60
	workspace:SetAttribute("AdminAbuseUntil", untilTime)
	workspace:SetAttribute("RushUntil", untilTime)
	workspace:SetAttribute("ServerBoostUntil", untilTime)
	workspace:SetAttribute("ServerBoostBy", "ADMIN ABUSE")
	local text = string.format(
		"🎉 ADMIN ABUSE for %d minutes! 2x Cash, Treasure Rush, clue odds everywhere!",
		minutes
	)
	AnnouncementService.announce({ text = text, color = "#FF5FD2", secret = false })
	Net.fireAll("Notify", text, "Big")
	Analytics.custom(admin, "AdminAbuse", minutes)
	task.spawn(function()
		while abuseActive() do
			task.wait(Admin.abuse.hiddenTreasureEvery)
			if abuseActive() and #JackpotService.list() < 4 then
				JackpotService.hide()
			end
		end
	end)
end

local function stopAbuse()
	for _, key in { "AdminAbuseUntil", "RushUntil", "ServerBoostUntil", "ServerBoostBy" } do
		workspace:SetAttribute(key, nil)
	end
end

type Handler = (admin: Player, target: Player, data: { [string]: any }, args: { any }) -> string?

-- Actions on the target player.
local PLAYER_ACTIONS: { [string]: Handler } = {
	AddCash = function(_, target, data, args)
		local amount = tonumber(args[1]) or 0
		setCash(target, data, data.cash + amount)
		return "Cash: " .. data.cash
	end,
	SetCash = function(_, target, data, args)
		setCash(target, data, tonumber(args[1]) or 0)
		return "Cash: " .. data.cash
	end,
	Shovel = function(_, target, data, args)
		data.shovelLevel =
			math.clamp(data.shovelLevel + (tonumber(args[1]) or 0), 1, Progression.MaxShovelLevel)
		refresh(target)
		return "Shovel: " .. Progression.getShovel(data.shovelLevel).name
	end,
	Bag = function(_, target, data, args)
		data.bagLevel = math.clamp(data.bagLevel + (tonumber(args[1]) or 0), 1, Progression.MaxBagLevel)
		refresh(target)
		return "Bag: " .. Progression.getBag(data.bagLevel).name
	end,
	Rebirths = function(_, target, data, args)
		data.rebirths = math.max(0, data.rebirths + (tonumber(args[1]) or 0))
		refresh(target)
		return "Rebirths: " .. data.rebirths
	end,
	UnlockAll = function(_, target, data)
		data.shovelLevel = Progression.MaxShovelLevel
		data.bagLevel = Progression.MaxBagLevel
		refresh(target)
		return "Max shovel and bag"
	end,
	TogglePass = function(_, target, data, args)
		local key = args[1]
		if type(key) ~= "string" or not Monetization.Passes[key] then
			return nil
		end
		data.passes[key] = if data.passes[key] then nil else true
		target:SetAttribute("Pass_" .. key, data.passes[key])
		target:SetAttribute("VIP", if data.passes.VIP then true else nil)
		refresh(target)
		return key .. (if data.passes[key] then " given (test)" else " removed")
	end,
	Boost = function(_, target, data, args)
		local id, minutes = args[1], tonumber(args[2]) or 15
		if type(id) ~= "string" or not Retention.boosts[id] then
			return nil
		end
		Boosts.add(data.activeBoosts, id, math.clamp(minutes, 1, 600) * 60, os.time())
		PlayerData.changed(target)
		return Retention.boosts[id].displayName .. " +" .. minutes .. " min"
	end,
	ClearBoosts = function(_, target, data)
		table.clear(data.activeBoosts)
		table.clear(data.pausedBoosts)
		PlayerData.changed(target)
		return "Boosts cleared"
	end,
	InstantDeepDig = function(_, target, data)
		data.instantDeepDigs += 1
		PlayerData.changed(target)
		return "Instant Deep Digs: " .. data.instantDeepDigs
	end,
	Treasure = function(_, target, data, args)
		local rarity = args[1]
		if type(rarity) ~= "string" or not Rarities.Info[rarity] then
			return nil
		end
		local name = giveTreasure(data, rarity)
		PlayerData.changed(target)
		return if name then name .. " added to the bag" else nil
	end,
	ResetTutorial = function(_, target, data)
		data.onboarding.guideDone = false
		data.onboarding.freeDrinkUsed = false
		PlayerData.changed(target)
		return "Tutorial reset"
	end,
	ResetProgress = function(_, target, data)
		-- Fresh progress; purchases (passes, skins, receipts) are kept.
		local fresh = DataSchema.template()
		for _, key in { "passes", "ownedCosmetics", "processedPurchaseIds", "settings", "robuxSpent" } do
			fresh[key] = data[key]
		end
		for key in data do
			data[key] = nil
		end
		for key, value in fresh do
			data[key] = value
		end
		EconomyService.addCash(target, data, 0, "Gameplay", "Admin")
		refresh(target)
		return "Progress reset (purchases kept)"
	end,
	GoTo = function(admin, target)
		local root = rootOf(target)
		if root then
			teleport(admin, root.Position + Vector3.new(4, 0, 0))
		end
		return "Teleported to " .. target.DisplayName
	end,
	Bring = function(admin, target)
		local root = rootOf(admin)
		if root then
			teleport(target, root.Position + Vector3.new(4, 0, 0))
		end
		return "Brought " .. target.DisplayName
	end,
	Kick = function(admin, target)
		if target == admin then
			return nil
		end
		target:Kick("Removed by an admin.")
		return "Kicked " .. target.Name
	end,
}

-- Server-wide actions.
local SERVER_ACTIONS: { [string]: (admin: Player, args: { any }) -> string? } = {
	Teleport = function(admin, args)
		local position = place(tostring(args[1]))
		if not position then
			return nil
		end
		teleport(admin, position)
		return "Teleported: " .. tostring(args[1])
	end,
	Rush = function(_, args)
		local minutes = tonumber(args[1]) or 0
		workspace:SetAttribute(
			"RushUntil",
			if minutes > 0 then workspace:GetServerTimeNow() + minutes * 60 else nil
		)
		return if minutes > 0 then "Treasure Rush for " .. minutes .. " min" else "Admin rush stopped"
	end,
	ServerBoost = function(_, args)
		local minutes = tonumber(args[1]) or 0
		if minutes <= 0 then
			workspace:SetAttribute("ServerBoostUntil", nil)
			return "Server 2x Cash stopped"
		end
		workspace:SetAttribute("ServerBoostUntil", workspace:GetServerTimeNow() + minutes * 60)
		workspace:SetAttribute("ServerBoostBy", "an admin")
		Net.fireAll("Notify", string.format("📣 2x CASH FOR EVERYONE for %d minutes!", minutes), "Big")
		return "Server 2x Cash for " .. minutes .. " min"
	end,
	Abuse = function(admin, args)
		local minutes = tonumber(args[1]) or 0
		if minutes <= 0 then
			stopAbuse()
			return "Admin Abuse stopped"
		end
		startAbuse(admin, math.clamp(minutes, 1, 120))
		return "ADMIN ABUSE for " .. minutes .. " min"
	end,
	Hide = function(_, args)
		local rarity, area = args[1], args[2]
		if type(rarity) ~= "string" or type(area) ~= "string" then
			return nil
		end
		return if JackpotService.hide(rarity, area)
			then "Hidden: " .. rarity .. " in " .. area
			else "No spot free"
	end,
	Announce = function(admin, args)
		local text = tostring(args[1] or ""):sub(1, 120)
		if text == "" then
			return nil
		end
		local filtered = text
		pcall(function()
			local result = game:GetService("TextService"):FilterStringAsync(text, admin.UserId)
			filtered = result:GetNonChatStringForBroadcastAsync()
		end)
		AnnouncementService.announce({ text = "📢 " .. filtered, color = "#FFD54A", secret = false })
		Net.fireAll("Notify", "📢 " .. filtered, "Big")
		return "Announced"
	end,
	Time = function(_, args)
		local clock = tonumber(args[1])
		if not clock then
			return nil
		end
		Lighting.ClockTime = clock % 24
		return "Time: " .. clock
	end,
	Speed = function(admin, args)
		admin:SetAttribute("AdminSpeed", math.clamp(tonumber(args[1]) or 1, 1, 6))
		return "Speed x" .. admin:GetAttribute("AdminSpeed")
	end,
	Jump = function(admin, args)
		admin:SetAttribute("AdminJump", math.clamp(tonumber(args[1]) or 1, 1, 6))
		return "Jump x" .. admin:GetAttribute("AdminJump")
	end,
}

-- Info for the panel's INFO tab.
function AdminService.info(): { [string]: any }
	local players = {}
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		if data then
			table.insert(players, {
				userId = player.UserId,
				name = player.DisplayName,
				cash = data.cash,
				shovel = data.shovelLevel,
				bag = data.bagLevel,
				rebirths = data.rebirths,
			})
		end
	end
	local hidden = {}
	for _, entry in JackpotService.list() do
		table.insert(hidden, entry.rarity .. " in " .. entry.area)
	end
	return {
		uptime = math.floor(os.clock() - started),
		players = players,
		hidden = hidden,
		abuse = abuseActive(),
	}
end

function AdminService.init()
	Players.PlayerAdded:Connect(function(player)
		if AdminService.isAdmin(player) then
			player:SetAttribute("Admin", true)
		end
	end)
	for _, player in Players:GetPlayers() do
		if AdminService.isAdmin(player) then
			player:SetAttribute("Admin", true)
		end
	end

	Net.on("AdminAction", 10, 20, function(admin: Player, action: any, targetId: any, ...: any)
		if not AdminService.isAdmin(admin) or type(action) ~= "string" then
			return
		end
		local args = { ... }
		local message: string? = nil
		if action == "Info" then
			Net.fire("AdminInfo", admin, AdminService.info())
			return
		end
		local serverAction = SERVER_ACTIONS[action]
		if serverAction then
			message = serverAction(admin, args)
		else
			local handler = PLAYER_ACTIONS[action]
			local target = if type(targetId) == "number" then Players:GetPlayerByUserId(targetId) else admin
			local data = target and PlayerData.get(target)
			if not handler or not target or not data then
				return
			end
			message = handler(admin, target, data, args)
			if message and target ~= admin then
				message = target.DisplayName .. ": " .. message
			end
		end
		if message then
			say(admin, message)
			Analytics.custom(admin, "Admin_" .. action)
		end
	end)
end

return AdminService
