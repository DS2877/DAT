--!strict
-- Enforces area gates on the server: a player standing in an area they have
-- not unlocked is moved back in front of that area's gate. Also logs the
-- "reached area" funnel steps. The client opens gate barriers locally for
-- unlocked areas; this loop is the authority.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Analytics = require(script.Parent.Analytics)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.Parent.World.World)

local CHECK_INTERVAL = 0.5

local FUNNEL_BY_AREA = {
	Jungle = "ReachedJungle",
	Ruins = "ReachedRuins",
	Volcano = "ReachedVolcano",
}

local AreaService = {}

local function check(player: Player)
	local data = PlayerData.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not root or not character then
		return
	end
	local areaId = Zones.areaAt(root.Position.X, root.Position.Z)
	if areaId == "Beach" then
		return
	end
	if Progression.isAreaUnlocked(areaId, data.shovelLevel) then
		local step = FUNNEL_BY_AREA[areaId]
		if step then
			Analytics.funnel(player, data, step)
		end
		return
	end
	local gate = World.get().gates[areaId]
	if gate then
		character:PivotTo(CFrame.new(gate.safePoint))
		root.AssemblyLinearVelocity = Vector3.zero
		Net.fire("Notify", player, "That area is locked!", "Denied")
	end
end

function AreaService.start()
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				check(player)
			end
		end
	end)
end

return AreaService
