--!strict
-- Client bootstrap: start controllers, then ask the server for our data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controllers = script.Controllers
local ClientState = require(Controllers.ClientState)
local HudController = require(Controllers.HudController)
local DigController = require(Controllers.DigController)
local StationController = require(Controllers.StationController)
local GuideController = require(Controllers.GuideController)
local GateController = require(Controllers.GateController)
local OtherPlayersController = require(Controllers.OtherPlayersController)
local AnnouncementController = require(Controllers.AnnouncementController)
local CollectionController = require(Controllers.CollectionController)
local RewardsController = require(Controllers.RewardsController)
local RushController = require(Controllers.RushController)
local RebirthController = require(Controllers.RebirthController)
local LeaderboardController = require(Controllers.LeaderboardController)
local AmbientController = require(Controllers.AmbientController)

ClientState.init()
HudController.init()
DigController.init()
StationController.init()
GuideController.init()
GateController.init()
OtherPlayersController.init()
AnnouncementController.init()
CollectionController.init()
RewardsController.init() -- after DigController (uses its LocalSpots folder)
RushController.init()
RebirthController.init()
LeaderboardController.init()
AmbientController.init()

-- Listeners are connected; request the snapshot (the server also pushes one
-- on load, this covers the case where it arrived before we were ready).
local remotes = ReplicatedStorage:WaitForChild("Remotes");
(remotes:WaitForChild("RequestSync") :: RemoteEvent):FireServer()
