--!strict
-- Server bootstrap: pick the world, build it, then start services in
-- dependency order.

-- First: the configs read the world when they load.
local world = require(script.WorldSelect).apply()

local Net = require(script.Net) -- creates the remotes first
local MapBuilder = require(script.World.MapBuilder)
local World = require(script.World.World)

World.set(MapBuilder.build())

local Services = script.Services
local PlayerData = require(Services.PlayerData)
local CharacterService = require(Services.CharacterService)
local DigSpotService = require(Services.DigSpotService)
local DigService = require(Services.DigService)
local EconomyService = require(Services.EconomyService)
local UpgradeService = require(Services.UpgradeService)
local AreaService = require(Services.AreaService)
local AnnouncementService = require(Services.AnnouncementService)
local CollectionService = require(Services.CollectionService)
local TrophyShelfService = require(Services.TrophyShelfService)
local FriendsService = require(Services.FriendsService)
local RewardService = require(Services.RewardService)
local RebirthService = require(Services.RebirthService)
local LeaderboardService = require(Services.LeaderboardService)
local SettingsService = require(Services.SettingsService)
local PurchaseService = require(Services.PurchaseService)
local DrinkService = require(Services.DrinkService)
local JackpotService = require(Services.JackpotService)
local AdminService = require(Services.AdminService)
local MegaDigService = require(Services.MegaDigService)
local PartyService = require(Services.PartyService)
local GlobalMessageService = require(Services.GlobalMessageService)
local WorldPortalService = require(Services.WorldPortalService)
local WorldServers = require(Services.WorldServers)
local BountyService = require(Services.BountyService)
local NightService = require(Services.NightService)
local EruptionService = require(Services.EruptionService)

-- init: connect remotes and signals. Order matters only for PlayerData.Loaded
-- listeners, which must exist before PlayerData starts loading players.
DigSpotService.init()
DigService.init()
EconomyService.init()
UpgradeService.init()
AnnouncementService.init()
CollectionService.init() -- before TrophyShelfService: it fills in bestFind on load
TrophyShelfService.init()
FriendsService.init()
RewardService.init()
RebirthService.init()
SettingsService.init()
PurchaseService.init()
DrinkService.init()
DigService.onHiddenFound = JackpotService.onFound
PartyService.init()
GlobalMessageService.init()
WorldPortalService.init()
BountyService.init()
AdminService.init()
LeaderboardService.init() -- before PlayerData: its leave handler must run first
CharacterService.init()
PlayerData.init()

-- start: begin loops and spawn world objects.
DigSpotService.start()
EconomyService.start()
AreaService.start()
LeaderboardService.start()
JackpotService.start()
MegaDigService.run()
NightService.start()
EruptionService.run()
if world ~= "Island" then
	WorldServers.host(world)
end

local _ = Net
print("[DigForCash] Server ready: " .. world)
