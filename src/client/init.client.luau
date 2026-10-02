--!strict
-- Client bootstrap: start controllers, then ask the server for our data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The configs read the world (the workspace's WorldId, set by the server
-- before anyone joins) when they load: make sure it has arrived.
do
	local waited = 0
	while workspace:GetAttribute("WorldId") == nil and waited < 10 do
		waited += task.wait(0.1)
	end
end

local Controllers = script.Controllers
local ClientState = require(Controllers.ClientState)
local HudController = require(Controllers.HudController)
local DigController = require(Controllers.DigController)
local StationController = require(Controllers.StationController)
local TutorialController = require(Controllers.TutorialController)
local GateController = require(Controllers.GateController)
local WallController = require(Controllers.WallController)
local OtherPlayersController = require(Controllers.OtherPlayersController)
local AnnouncementController = require(Controllers.AnnouncementController)
local CollectionController = require(Controllers.CollectionController)
local RewardsController = require(Controllers.RewardsController)
local RushController = require(Controllers.RushController)
local RebirthController = require(Controllers.RebirthController)
local LeaderboardController = require(Controllers.LeaderboardController)
local AmbientController = require(Controllers.AmbientController)
local CameraController = require(Controllers.CameraController)
local AudioController = require(Controllers.AudioController)
local SettingsController = require(Controllers.SettingsController)
local ShopController = require(Controllers.ShopController)
local TikiController = require(Controllers.TikiController)
local InfoBoardController = require(Controllers.InfoBoardController)
local AdminController = require(Controllers.AdminController)
local MegaDigController = require(Controllers.MegaDigController)
local PartyController = require(Controllers.PartyController)
local GlobalMessageController = require(Controllers.GlobalMessageController)
local PortalController = require(Controllers.PortalController)
local RadarController = require(Controllers.RadarController)
local ChatController = require(Controllers.ChatController)
local SnowController = require(Controllers.SnowController)
local WindController = require(Controllers.WindController)
local DanceController = require(Controllers.DanceController)
local ChatterController = require(Controllers.ChatterController)
local BountyController = require(Controllers.BountyController)
local PerkController = require(Controllers.PerkController)
local DayNightController = require(Controllers.DayNightController)
local EruptionController = require(Controllers.EruptionController)

ClientState.init()
AudioController.init()
HudController.init()
DigController.init()
StationController.init()
TutorialController.init()
GateController.init()
WallController.init()
OtherPlayersController.init()
AnnouncementController.init()
CollectionController.init()
RewardsController.init() -- after DigController (uses its LocalSpots folder)
RushController.init()
RebirthController.init()
LeaderboardController.init()
AmbientController.init()
CameraController.init()
SettingsController.init()
ShopController.init()
TikiController.init()
InfoBoardController.init()
AdminController.init()
MegaDigController.init()
PartyController.init()
GlobalMessageController.init()
PortalController.init()
RadarController.init()
ChatController.init()
SnowController.init()
WindController.init()
DanceController.init()
ChatterController.init()
BountyController.init()
PerkController.init()
DayNightController.init()
EruptionController.init()

-- Listeners are connected; request the snapshot (the server also pushes one
-- on load, this covers the case where it arrived before we were ready).
local remotes = ReplicatedStorage:WaitForChild("Remotes");
(remotes:WaitForChild("RequestSync") :: RemoteEvent):FireServer()
