--!strict
-- Game pass ownership. Checked when a player joins (UserOwnsGamePassAsync,
-- retried) and granted at once when they buy a pass in this server.
-- Each owned pass is exposed as a player attribute "Pass_<name>" = true.
--
-- Passes are perks, not consumables, so there is no receipt to process
-- (developer products, which need ProcessReceipt, come with the Shop).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Analytics = require(script.Parent.Analytics)
local Net = require(script.Parent.Parent.Net)

local MonetizationService = {}

local function passById(id: number): (string?, Monetization.Pass?)
	for name, pass in Monetization.Passes do
		if pass.id ~= 0 and pass.id == id then
			return name, pass
		end
	end
	return nil, nil
end

local function attribute(name: string): string
	return "Pass_" .. name
end

-- True if the player has the pass, or the pass isn't set up yet (then the
-- perk is free for everyone).
function MonetizationService.hasPass(player: Player, name: string): boolean
	local pass = Monetization.Passes[name]
	if not pass then
		return false
	end
	return pass.id == 0 or player:GetAttribute(attribute(name)) == true
end

local function grant(player: Player, name: string)
	if player:GetAttribute(attribute(name)) == true then
		return
	end
	player:SetAttribute(attribute(name), true)
end

local function checkOwnership(player: Player)
	for name, pass in Monetization.Passes do
		if pass.id == 0 then
			continue
		end
		for attempt = 1, Monetization.ownershipRetries do
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok then
				if owns then
					grant(player, name)
				end
				break
			end
			if attempt < Monetization.ownershipRetries then
				task.wait(attempt * 2)
			else
				warn("[Monetization] ownership check failed for " .. name .. ": " .. tostring(owns))
			end
		end
	end
end

function MonetizationService.init()
	Players.PlayerAdded:Connect(function(player)
		checkOwnership(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(checkOwnership, player)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local name, pass = passById(passId)
			if not name or not pass then
				return
			end
			Analytics.custom(player, if purchased then "PassBought_" .. name else "PassDeclined_" .. name)
			if not purchased or player:GetAttribute(attribute(name)) == true then
				return
			end
			grant(player, name)
			Net.fire("Notify", player, pass.icon .. " " .. string.upper(pass.name) .. " UNLOCKED!", "Big")
		end
	)
end

return MonetizationService
