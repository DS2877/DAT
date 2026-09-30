--!strict
-- Server-wide announcements ("💎 Philip found a GOLDEN Cursed Idol!") for
-- big finds and milestones. Rate limited per player and globally; queued
-- announcements are sent in order. Secret finds also carry a position so
-- every client can play a world effect there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionConfig = require(ReplicatedStorage.Shared.Config.Collection)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local Net = require(script.Parent.Parent.Net)

local MAX_QUEUE = 6

local AnnouncementService = {}

export type Announcement = {
	text: string,
	color: string, -- hex
	secret: boolean,
	position: Vector3?,
}

local queue: { Announcement } = {}
local lastByPlayer: { [Player]: number } = {}
local running = false

local function pump()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			Net.fireAll("Announce", table.remove(queue, 1))
			task.wait(CollectionConfig.announce.globalGap)
		end
		running = false
	end)
end

function AnnouncementService.announce(announcement: Announcement)
	if #queue >= MAX_QUEUE then
		return
	end
	table.insert(queue, announcement)
	pump()
end

local function describe(find: { [string]: any }): (string?, string)
	local rules = CollectionConfig.announce
	local def = Treasures.ById[find.id]
	local info = Rarities.Info[find.rarity]
	if not def or not info then
		return nil, "#FFFFFF"
	end
	local rank = Rarities.rank(find.rarity)
	local golden = find.mutation == "Golden" and rules.golden
	local shiny = find.mutation == "Shiny" and rank >= Rarities.rank(rules.shinyMinRarity)
	local rare = rank >= Rarities.rank(rules.minRarity)
	if not (golden or shiny or rare) then
		return nil, info.color
	end
	local prefix = if find.mutation == "Golden"
		then "GOLDEN "
		elseif find.mutation == "Shiny" then "Shiny "
		else ""
	local rarityWord = if rare then string.upper(info.displayName) .. " " else ""
	local color = if find.mutation == "Golden" then "#FFC933" else info.color
	return prefix .. rarityWord .. def.name, color
end

function AnnouncementService.onFind(player: Player, find: { [string]: any }, position: Vector3)
	local what, color = describe(find)
	if not what then
		return
	end
	local secret = find.rarity == "Secret"
	local now = os.clock()
	-- Secrets always go out; everything else respects the per-player cooldown.
	if
		not secret
		and now - (lastByPlayer[player] or -math.huge) < CollectionConfig.announce.perPlayerCooldown
	then
		return
	end
	lastByPlayer[player] = now
	local icon = if secret then "🌟" elseif find.mutation == "Golden" then "✨" else "💎"
	AnnouncementService.announce({
		text = string.format("%s %s found a %s!", icon, player.DisplayName, what),
		color = color,
		secret = secret,
		position = if secret then position else nil,
	})
end

function AnnouncementService.init()
	Players.PlayerRemoving:Connect(function(player)
		lastByPlayer[player] = nil
	end)
end

return AnnouncementService
