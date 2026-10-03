--!strict
-- The admin panel's server side. Only admins (Config/Admin: the game's
-- owner, listed user ids, everyone in Studio) may act; every request is
-- checked here, never trusted from the client.
--
-- Actions on a player (target = a user id, default yourself): cash, shovel,
-- bag, rebirths, passes (for testing: the profile only, not Roblox), boosts,
-- Instant Deep Digs, treasures, junk, pets, rebirth perks, bounties, always
-- PERFECT hits, a victory dance, a seagull, tutorial / progress / full
-- reset, teleport, bring, kick.
-- Server actions: Treasure Rush, server 2x Cash, ADMIN ABUSE, Egg Rush,
-- hidden treasures, announcements, messages to every server, time of day,
-- night (now / off), eruptions, seagulls, your own speed / jump, and
-- spawning things where you stand (treasure / moonlit / meteor spots, clue
-- rings, money rain, fireworks, a Mega Dig).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Admin = require(ReplicatedStorage.Shared.Config.Admin)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local DataSchema = require(ReplicatedStorage.Shared.Logic.DataSchema)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local LootRoller = require(ReplicatedStorage.Shared.Logic.LootRoller)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)
local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Analytics = require(script.Parent.Analytics)
local AnnouncementService = require(script.Parent.AnnouncementService)
local CharacterService = require(script.Parent.CharacterService)
local DigSpotService = require(script.Parent.DigSpotService)
local EconomyService = require(script.Parent.EconomyService)
local GlobalMessageService = require(script.Parent.GlobalMessageService)
local JackpotService = require(script.Parent.JackpotService)
local EruptionService = require(script.Parent.EruptionService)
local SeagullService = require(script.Parent.SeagullService)
local PetService = require(script.Parent.PetService)
local Pets = require(ReplicatedStorage.Shared.Logic.Pets)
local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local PerkConfig = require(ReplicatedStorage.Shared.Config.RebirthPerks)
local RebirthPerks = require(ReplicatedStorage.Shared.Logic.RebirthPerks)
local BountyService = require(script.Parent.BountyService)
local NightService = require(script.Parent.NightService)
local MegaDigService = require(script.Parent.MegaDigService)
local PartyService = require(script.Parent.PartyService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local WorldServers = require(script.Parent.WorldServers)
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

-- Admins by user id (players who may be offline): the listed ids and the
-- owner of a user-owned game.
function AdminService.isAdminId(userId: number): boolean
	if table.find(Admin.userIds, userId) then
		return true
	end
	local ok, owner = pcall(function()
		return game.CreatorType == Enum.CreatorType.User and game.CreatorId == userId
	end)
	return ok and owner == true
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
	elseif name == "Portal" then
		local portal = world.portal
		return Vector3.new(portal.center.X, portal.ground, portal.center.Z) + portal.normal * 12
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

-- A random junk find, straight into the bag (and collection).
local function giveJunk(data: { [string]: any }): string?
	local pool = {}
	for _, def in Treasures.List do
		if def.set == "Junk" then
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

local function random01(): number
	return math.random()
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

-- Replaces the profile with a fresh one, keeping `keep`, and sends the
-- player back to the spawn.
local function resetData(target: Player, data: { [string]: any }, keep: { string })
	local fresh = DataSchema.template()
	for _, key in keep do
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
	teleport(target, World.get().spawnPosition)
end

-- A point on the ground `distance` studs in front of the admin.
local function inFront(admin: Player, distance: number): Vector3?
	local root = rootOf(admin)
	if not root then
		return nil
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local at = root.Position + flat * distance
	return PartyService.groundAt(at.X, at.Z, root.Position.Y)
end

-- A dig spot at `position`; `rarity` makes its treasure that rarity.
-- (Its treasure comes from an area that has that rarity.)
local function spawnSpot(position: Vector3, rarity: string?)
	local areaId = Zones.areaAt(position.X, position.Z)
	DigSpotService.spawnAt(position, areaId, {
		clue = true,
		forceRarity = rarity,
		lootArea = if rarity then LootRoller.areaFor(areaId, rarity) else nil,
	})
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
	Junk = function(_, target, data)
		local name = giveJunk(data)
		PlayerData.changed(target)
		return if name then name .. " added to the bag" else nil
	end,
	-- Pets: one by id (with the hatch show), all, max, level up the one
	-- that's out, an egg on the next dig, remove them all.
	PetGive = function(_, target, _data, args)
		local id = args[1]
		if type(id) ~= "string" or not Pets.byId[id] then
			return nil
		end
		local outcome = PetService.hatch(target, id)
		return if outcome then Pets.byId[id].name .. ": " .. outcome else nil
	end,
	PetsAll = function(_, target, data)
		for id in Pets.byId do
			PetService.setLevel(target, id, math.max(1, Pets.level(data, id)))
		end
		return "Every pet (" .. Pets.count(data) .. ")"
	end,
	PetsMax = function(_, target)
		for id in Pets.byId do
			PetService.setLevel(target, id, PetConfig.maxLevel)
		end
		return "Every pet at level " .. PetConfig.maxLevel
	end,
	PetLevelUp = function(_, target, data)
		local id = Pets.equipped(data)
		if id == "" then
			return "No pet out"
		end
		return Pets.byId[id].name .. ": " .. tostring(PetService.hatch(target, id))
	end,
	PetEgg = function(_, target, data)
		data.pets.digsSinceEgg = PetConfig.pity - 1
		PlayerData.changed(target)
		return "An egg on the next dig"
	end,
	PetsClear = function(_, target, data)
		for id in Pets.byId do
			if Pets.level(data, id) > 0 then
				PetService.setLevel(target, id, 0)
			end
		end
		return "Pets removed"
	end,
	-- Rebirth perks: a card set to pick from, every perk maxed, or none.
	PerkCards = function(_, target, data)
		local set = RebirthPerks.roll(data, random01)
		if #set == 0 then
			return "Every perk is maxed"
		end
		table.insert(data.perkChoices, set)
		PlayerData.changed(target)
		return "Perk cards to pick from"
	end,
	PerksMax = function(_, target, data)
		for _, perk in PerkConfig.list do
			data.rebirthPerks[perk.id] = perk.max
		end
		table.clear(data.perkChoices)
		PlayerData.changed(target)
		return "Every perk maxed"
	end,
	PerksClear = function(_, target, data)
		table.clear(data.rebirthPerks)
		table.clear(data.perkChoices)
		data.perksEarned = data.rebirths -- (no cards come back for old rebirths)
		PlayerData.changed(target)
		return "Perks cleared"
	end,
	Bounty = function(_, target, data, args)
		return BountyService.adminAction(target, data, tostring(args[1]))
	end,
	-- Every dig hit counts as PERFECT (on / off).
	Perfect = function(_, target, _data, args)
		local on = args[1] == true
		target:SetAttribute("AdminPerfect", if on then true else nil)
		return if on then "Every hit is PERFECT" else "PERFECT hits back to normal"
	end,
	Dance = function(_, target)
		local character = target.Character
		if not character then
			return nil
		end
		character:SetAttribute("Celebrate", ((character:GetAttribute("Celebrate") :: number?) or 0) + 1)
		return "Dance!"
	end,
	StealHat = function(_, target)
		return if SeagullService.steal(target)
			then "A seagull is after their hat!"
			else "No seagull: they need a hat and palms nearby (Island), one at a time"
	end,
	ResetTutorial = function(_, target, data)
		data.onboarding.guideDone = false
		data.onboarding.freeDrinkUsed = false
		PlayerData.changed(target)
		return "Tutorial reset"
	end,
	ResetProgress = function(admin, target, data)
		-- A brand new player, except for what they bought with Robux: game
		-- passes, skins (and the one they wear), the Starter Pack flag and
		-- unused Instant Deep Digs. Receipts are kept so nothing is ever
		-- granted twice. (Cash bought with Robux was spent into progress.)
		resetData(target, data, {
			"passes",
			"ownedCosmetics",
			"equippedSkin",
			"starterPackBought",
			"instantDeepDigs",
			"processedPurchaseIds",
			"robuxSpent",
		})
		if target ~= admin then
			Net.fire(
				"Notify",
				target,
				"🛠️ An admin gave you a fresh start! Your Robux purchases are kept.",
				"Big"
			)
		end
		return "Progress reset (Robux purchases kept). The tutorial starts over!"
	end,
	ResetAll = function(_, target, data)
		-- A brand new player: test passes and skins go too. Receipts are
		-- kept so no purchase is ever granted twice; passes really owned on
		-- Roblox come back on the next join.
		resetData(target, data, { "processedPurchaseIds", "robuxSpent" })
		for key in Monetization.Passes do
			target:SetAttribute("Pass_" .. key, nil)
		end
		target:SetAttribute("VIP", nil)
		target:SetAttribute("AdminSpeed", nil)
		target:SetAttribute("AdminJump", nil)
		return "You're a brand new player. The tutorial starts over!"
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
	-- To the other world (Frostbite Peaks, or back to the island).
	Travel = function(admin, args)
		local target = tostring(args[1])
		local here = CurrentWorld.id()
		if target == here then
			return "You're already here"
		end
		local name = if target == Worlds.next.id then Worlds.next.name else Worlds.home.name
		Net.fire("Portal", admin, "Teleporting", { name = name })
		local ok, reason
		if target == Worlds.next.id then
			ok, reason = WorldServers.send(admin, target)
		else
			ok, reason = WorldServers.sendHome(admin)
		end
		if not ok then
			Net.fire("Portal", admin, "TripFailed", nil)
			return "Teleport failed: " .. tostring(reason)
		end
		return "Off to " .. name .. "!"
	end,
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
		local filtered = GlobalMessageService.filter(text, admin.UserId)
		if not filtered then
			return "The text filter is busy, try again"
		end
		AnnouncementService.announce({ text = "📢 " .. filtered, color = "#FFD54A", secret = false })
		Net.fireAll("Notify", "📢 " .. filtered, "Big")
		return "Announced"
	end,
	GlobalMessage = function(admin, args)
		return GlobalMessageService.send(admin, tostring(args[1] or ""))
	end,
	SpawnSpot = function(admin, args)
		local rarity = args[1]
		if type(rarity) ~= "string" or not Rarities.Info[rarity] then
			return nil
		end
		local at = inFront(admin, Admin.spawn.spotDistance)
		if not at then
			return nil
		end
		spawnSpot(at, rarity)
		return rarity .. " spot in front of you"
	end,
	SpawnRing = function(admin)
		local root = rootOf(admin)
		if not root then
			return nil
		end
		local cfg = Admin.spawn
		for i = 1, cfg.ringCount do
			local angle = i / cfg.ringCount * math.pi * 2
			local x = root.Position.X + math.cos(angle) * cfg.ringRadius
			local z = root.Position.Z + math.sin(angle) * cfg.ringRadius
			spawnSpot(PartyService.groundAt(x, z, root.Position.Y), nil)
		end
		return cfg.ringCount .. " clue spots around you"
	end,
	MoneyRain = function(admin)
		local root = rootOf(admin)
		if not root then
			return nil
		end
		PartyService.moneyRain(root.Position)
		return "Money rain!"
	end,
	Fireworks = function(admin)
		local root = rootOf(admin)
		if not root then
			return nil
		end
		PartyService.fireworks(root.Position, 10)
		return "Fireworks!"
	end,
	MegaDig = function(admin, args)
		if args[1] == "Stop" then
			return if MegaDigService.cancel() then "Mega Dig closed" else "No Mega Dig open"
		end
		local at = if args[1] == "Here" then inFront(admin, Admin.spawn.megaDistance) else nil
		if args[1] == "Here" and not at then
			return nil
		end
		return if MegaDigService.start(at) then "Mega Dig started" else "A Mega Dig is already open"
	end,
	-- Start / Stop / Clear (meteor spots) / Off / On (the schedule).
	Eruption = function(_, args)
		local what = args[1]
		if what == "Stop" then
			return if EruptionService.cancel() then "Eruption stopped" else "No eruption going"
		elseif what == "Clear" then
			return EruptionService.clear() .. " meteor spots cooled off"
		elseif what == "Off" or what == "On" then
			workspace:SetAttribute("EruptionsOff", if what == "Off" then true else nil)
			return if what == "Off" then "Eruptions off" else "Eruptions back on (:05 and :35)"
		end
		return if EruptionService.start() then "The volcano is waking up!" else "An eruption is already going"
	end,
	MeteorSpot = function(admin)
		local at = inFront(admin, Admin.spawn.spotDistance)
		if not at then
			return nil
		end
		EruptionService.meteorAt(at, Zones.areaAt(at.X, at.Z))
		return "Incoming meteor!"
	end,
	MoonSpot = function(admin)
		local at = inFront(admin, Admin.spawn.spotDistance)
		if not at then
			return nil
		end
		NightService.spawnAt(at, Zones.areaAt(at.X, at.Z))
		return "Moonlit spot in front of you"
	end,
	-- On (night now, until Off) / Off / CycleOff (always day) / CycleOn.
	Night = function(_, args)
		local what = args[1]
		local now = workspace:GetServerTimeNow()
		if what == "On" then
			workspace:SetAttribute("NightCycleOff", nil)
			workspace:SetAttribute("ForceNight", true)
			workspace:SetAttribute("ClockOverride", 0)
			workspace:SetAttribute("ClockOverrideUntil", now + 3600)
			return "Night! (until you end it, or an hour)"
		elseif what == "Off" or what == "CycleOff" then
			workspace:SetAttribute("ForceNight", nil)
			workspace:SetAttribute("ClockOverride", nil)
			workspace:SetAttribute("ClockOverrideUntil", nil)
			if what == "CycleOff" then
				workspace:SetAttribute("NightCycleOff", true)
				return "Always day (nights off)"
			end
			return "Night ended"
		elseif what == "CycleOn" then
			workspace:SetAttribute("NightCycleOff", nil)
			return "Day and night back on"
		end
		return nil
	end,
	EggRush = function(_, args)
		local minutes = tonumber(args[1]) or 0
		if minutes <= 0 then
			workspace:SetAttribute("EggRushUntil", nil)
			return "Egg Rush stopped"
		end
		workspace:SetAttribute("EggRushUntil", workspace:GetServerTimeNow() + minutes * 60)
		local text = string.format("🥚 EGG RUSH for %d minutes! Pet eggs are 10x more common!", minutes)
		AnnouncementService.announce({ text = text, color = "#7CFC8A", secret = false })
		Net.fireAll("Notify", text, "Big")
		return "Egg Rush for " .. minutes .. " min"
	end,
	-- (none: your hat) / Random / Recall / Off / On.
	Seagull = function(admin, args)
		local what = args[1]
		if what == "Random" then
			local victim = SeagullService.stealRandom()
			return if victim
				then "A seagull is after " .. victim.DisplayName .. "'s hat!"
				else "Nobody to rob: needs a hat and palms nearby (Island), one at a time"
		elseif what == "Recall" then
			return if SeagullService.recall() then "The seagull brings the hat back" else "No seagull out"
		elseif what == "Off" or what == "On" then
			workspace:SetAttribute("SeagullsOff", if what == "Off" then true else nil)
			return if what == "Off" then "Seagulls off" else "Seagulls back on"
		end
		return if SeagullService.steal(admin)
			then "Incoming seagull!"
			else "No seagull: wear a hat, stand near palms (Island), one at a time"
	end,
	Time = function(_, args)
		local clock = tonumber(args[1])
		if not clock then
			return nil
		end
		-- Shown for 5 minutes (the day/night cycle runs on every client);
		-- a night hour also starts a night (moonlit spots).
		clock %= 24
		Lighting.ClockTime = clock
		workspace:SetAttribute("ClockOverride", clock)
		workspace:SetAttribute("ClockOverrideUntil", workspace:GetServerTimeNow() + 300)
		workspace:SetAttribute("ForceNight", if clock >= 19 or clock < 6 then true else nil)
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
				pets = Pets.count(data),
				petOut = Pets.equipped(data),
				bounties = type(data.bounties) == "table" and data.bounties.completed or 0,
				perfect = player:GetAttribute("AdminPerfect") == true,
			})
		end
	end
	local hidden = {}
	for _, entry in JackpotService.list() do
		table.insert(hidden, entry.rarity .. " in " .. entry.area)
	end
	local now = workspace:GetServerTimeNow()
	local function minutesLeft(attribute: string): string?
		local untilTime = workspace:GetAttribute(attribute)
		return if type(untilTime) == "number" and untilTime > now
			then string.format("%d min", math.ceil((untilTime - now) / 60))
			else nil
	end
	local nextEruption = workspace:GetAttribute("EruptionNext")
	local events = {
		"Night: "
			.. (if NightService.isNight() then "NOW" else "day")
			.. (if workspace:GetAttribute("NightCycleOff") then " (nights off)" else "")
			.. (if workspace:GetAttribute("ForceNight") then " (forced)" else "")
			.. " · moonlit spots "
			.. NightService.count(),
		"Eruption: " .. (if EruptionService.isRunning()
			then "NOW"
			elseif workspace:GetAttribute("EruptionsOff") then "off"
			elseif type(nextEruption) == "number" then string.format(
				"next in %d min",
				math.max(0, math.ceil((nextEruption - now) / 60))
			)
			else "?") .. " · meteor spots " .. EruptionService.count(),
		"Seagull: "
			.. (if SeagullService.isBusy() then "out stealing" else "waiting")
			.. (if workspace:GetAttribute("SeagullsOff") then " (off)" else ""),
		"Egg Rush: " .. (minutesLeft("EggRushUntil") or "off"),
	}
	return {
		uptime = math.floor(os.clock() - started),
		players = players,
		hidden = hidden,
		abuse = abuseActive(),
		events = events,
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
