--!strict
-- Buying shovel and bag upgrades at their base stations.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Tutorial = require(ReplicatedStorage.Shared.Logic.Tutorial)
local Analytics = require(script.Parent.Analytics)
local CharacterService = require(script.Parent.CharacterService)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.Parent.World.World)

-- Extra studs of slack beyond the station radius (latency, big avatars).
local STATION_SLACK = 8

local UpgradeService = {}

local function nearStation(player: Player, kind: string): boolean
	local station = World.get().stations[kind]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not station or not root then
		return false
	end
	local offset = root.Position - station.position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= station.radius + STATION_SLACK
		and math.abs(offset.Y) < 12
end

local function onBuyUpgrade(player: Player, kind: any)
	if kind ~= "Shovel" and kind ~= "Bag" then
		return -- malformed
	end
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if not nearStation(player, kind) then
		Net.fire("UpgradeResult", player, { ok = false, kind = kind, reason = "TooFar" })
		return
	end
	local levelKey = if kind == "Shovel" then "shovelLevel" else "bagLevel"
	local ok, reason, missing = Progression.canBuy(kind, data[levelKey], data.cash)
	if not ok then
		Net.fire("UpgradeResult", player, { ok = false, kind = kind, reason = reason, missing = missing })
		return
	end
	local nextDef = Progression.nextUpgrade(kind, data[levelKey]) :: any
	if not EconomyService.spendCash(player, data, nextDef.cost, "Shop", kind .. "_" .. nextDef.level) then
		return
	end
	data[levelKey] = nextDef.level
	Analytics.funnel(player, data, "FirstUpgrade")
	Tutorial.update(data)
	if kind == "Shovel" then
		CharacterService.refreshShovel(player)
	end
	Net.fire("UpgradeResult", player, { ok = true, kind = kind, level = nextDef.level, name = nextDef.name })
	PlayerData.changed(player)
end

function UpgradeService.init()
	Net.on("BuyUpgrade", 4, 4, onBuyUpgrade)
end

return UpgradeService
