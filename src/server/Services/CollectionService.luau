--!strict
-- Collection sets: when a player completes an area's set they get a
-- permanent cash bonus (applied in LootService), a badge (if configured),
-- and a server announcement. Also keeps each player's best find for the
-- trophy shelf.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Collection = require(ReplicatedStorage.Shared.Logic.Collection)
local CollectionConfig = require(ReplicatedStorage.Shared.Config.Collection)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Analytics = require(script.Parent.Analytics)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local TrophyShelfService = require(script.Parent.TrophyShelfService)

local CollectionService = {}

local function awardBadge(player: Player, areaId: string)
	local badgeId = CollectionConfig.setBadges[areaId]
	if not badgeId or badgeId == 0 then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, badgeId) then
				BadgeService:AwardBadge(player.UserId, badgeId)
			end
		end)
		if not ok then
			warn("[CollectionService] Badge award failed: " .. tostring(err))
		end
	end)
end

-- Awards any newly completed sets. `announce` is false for catch-up on join.
local function checkSets(player: Player, data: { [string]: any }, announce: boolean)
	for _, areaId in Collection.completedSets(data.discovered) do
		if not data.setsAwarded[areaId] then
			data.setsAwarded[areaId] = true
			awardBadge(player, areaId)
			Analytics.custom(player, "SetComplete_" .. areaId)
			if announce then
				local name = string.upper(Areas.Defs[areaId].displayName)
				local bonus = math.floor(CollectionConfig.setBonus * 100 + 0.5)
				Net.fire(
					"Notify",
					player,
					string.format("%s SET COMPLETE! +%d%% cash forever", name, bonus),
					"Big"
				)
				AnnouncementService.announce({
					text = string.format(
						"🏆 %s completed the %s collection!",
						player.DisplayName,
						Areas.Defs[areaId].displayName
					),
					color = "#5BE36B",
					secret = false,
				})
			end
		end
	end
end

function CollectionService.onFind(player: Player, data: { [string]: any }, find: { [string]: any })
	checkSets(player, data, true)
	if find.newBest then
		TrophyShelfService.refresh(player)
	end
end

function CollectionService.init()
	PlayerData.Loaded:Connect(function(player: Player, data)
		-- Existing saves: derive the best find once from what they've discovered.
		if not data.bestFind.id then
			local best = nil
			for id, entry in data.discovered do
				local variants = {}
				if entry.normal then
					table.insert(variants, { id = id })
				end
				if entry.shiny then
					table.insert(variants, { id = id, m = "Shiny" })
				end
				if entry.golden then
					table.insert(variants, { id = id, m = "Golden" })
				end
				for _, candidate in variants do
					if Collection.isBetter(candidate, best) then
						best = candidate
					end
				end
			end
			if best then
				data.bestFind = best
			end
		end
		checkSets(player, data, false)
	end)
end

return CollectionService
