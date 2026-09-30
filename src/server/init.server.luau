--!strict
-- Server bootstrap: build the island, then start services in dependency order.

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
LeaderboardService.init() -- before PlayerData: its leave handler must run first
CharacterService.init()
PlayerData.init()

-- start: begin loops and spawn world objects.
DigSpotService.start()
EconomyService.start()
AreaService.start()
LeaderboardService.start()

local _ = Net
print("[DigForCash] Server ready")
