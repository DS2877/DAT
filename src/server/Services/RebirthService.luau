--!strict
-- Rebirth ("Treasure Hunter Rank") at the base altar. Resets cash, shovel,
-- bag and bag contents; keeps collection, cosmetics, purchases and the
-- rebirth count. Each rebirth: +25% permanent cash, a rank title above the
-- head, a shovel tint, and every 5 rebirths a rebirth-only Secret unlocks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Analytics = require(script.Parent.Analytics)
local AnnouncementService = require(script.Parent.AnnouncementService)
local CharacterService = require(script.Parent.CharacterService)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.Parent.World.World)

local STATION_SLACK = 8

local RebirthService = {}

local function nearAltar(player: Player): boolean
	local station = World.get().stations.Rebirth
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not station or not root then
		return false
	end
	local offset = root.Position - station.position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= station.radius + STATION_SLACK
		and math.abs(offset.Y) < 12
end

local function onRebirth(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if not nearAltar(player) then
		Net.fire("Notify", player, "Step onto the rebirth altar!", "Denied")
		return
	end
	local ok, reason = Rebirth.canRebirth(data)
	if not ok then
		local text = if reason == "NeedShovel"
			then "You need the Legendary Shovel first!"
			else "You need more cash to rebirth!"
		Net.fire("Notify", player, text, "Denied")
		return
	end
	local spent = data.cash
	EconomyService.spendCash(player, data, spent, "Shop", "Rebirth_" .. (data.rebirths + 1))
	Rebirth.apply(data)
	data.weekly.rebirths += 1
	Analytics.funnel(player, data, "FirstRebirth")
	CharacterService.refreshShovel(player)
	CharacterService.refreshTitle(player)

	local title = Rebirth.title(data.rebirths)
	local bonus = math.floor(data.rebirths * Retention.rebirth.cashBonusPerRebirth * 100 + 0.5)
	Net.fire("Notify", player, string.format("REBIRTH! You are now a %s (+%d%% cash)", title, bonus), "Big")
	if data.rebirths % Retention.rebirth.secretEvery == 0 then
		task.delay(3, function()
			Net.fire("Notify", player, "A new rebirth-only SECRET can now be found in the Volcano!", "Big")
		end)
	end
	AnnouncementService.announce({
		text = string.format("🔄 %s reached rank %s!", player.DisplayName, title),
		color = "#B45CFF",
		secret = false,
	})
	PlayerData.changed(player)
end

function RebirthService.init()
	Net.on("Rebirth", 0.5, 1, onRebirth)
end

return RebirthService
