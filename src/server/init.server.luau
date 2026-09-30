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

-- init: connect remotes and signals. Order matters only for PlayerData.Loaded
-- listeners, which must exist before PlayerData starts loading players.
DigSpotService.init()
DigService.init()
EconomyService.init()
UpgradeService.init()
AnnouncementService.init()
CollectionService.init() -- before TrophyShelfService: it fills in bestFind on load
TrophyShelfService.init()
CharacterService.init()
PlayerData.init()

-- start: begin loops and spawn world objects.
DigSpotService.start()
EconomyService.start()
AreaService.start()

local _ = Net
print("[DigForCash] Server ready")
