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

ClientState.init()
HudController.init()
DigController.init()
StationController.init()
GuideController.init()
GateController.init()
OtherPlayersController.init()

-- Listeners are connected; request the snapshot (the server also pushes one
-- on load, this covers the case where it arrived before we were ready).
local remotes = ReplicatedStorage:WaitForChild("Remotes");
(remotes:WaitForChild("RequestSync") :: RemoteEvent):FireServer()
