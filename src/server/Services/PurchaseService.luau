--!strict
-- Everything bought with Robux (Config/Monetization).
--
-- Developer products: ONE ProcessReceipt handler, idempotent. Each receipt's
-- PurchaseId is recorded in the profile together with the grant, the profile
-- is saved, and only then is PurchaseGranted returned (NotProcessedYet
-- otherwise, so Roblox retries). A retried receipt whose id is already
-- recorded is never granted twice.
--
-- Game passes: ownership is checked on join (UserOwnsGamePassAsync, retried)
-- and granted at once on PromptGamePassPurchaseFinished. Owned passes are
-- cached in the profile (data.passes) and exposed as player attributes
-- ("Pass_<key>", and "VIP" for other clients' chat tags).
--
-- Also: PolicyService per player, equipping skins, Auto Sell's SELL button,
-- and the shop's analytics events.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Perks = require(ReplicatedStorage.Shared.Logic.Perks)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Analytics = require(script.Parent.Analytics)
local CharacterService = require(script.Parent.CharacterService)
local DigService = require(script.Parent.DigService)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local ServerBoostService = require(script.Parent.ServerBoostService)

local PurchaseService = {}

local productKeyById: { [number]: string } = {}
for key, product in Monetization.Products do
	if product.id ~= 0 then
		productKeyById[product.id] = key
	end
end
local passKeyById: { [number]: string } = {}
for key, pass in Monetization.Passes do
	if pass.id ~= 0 and pass.enabled ~= false then
		passKeyById[pass.id] = key
	end
end

type Policy = { paidRandomRestricted: boolean }
local policies: { [Player]: Policy } = {}

local SHOP_EVENTS = { ShopOpened = true, OfferShown = true, PurchasePrompted = true }

---------------------------------------------------------------------------
-- Passes
---------------------------------------------------------------------------

local function applyPassAttributes(player: Player, data: { [string]: any })
	for key in Monetization.Passes do
		if data.passes[key] then
			player:SetAttribute("Pass_" .. key, true)
		end
	end
	player:SetAttribute("VIP", if Perks.has(data, "VIP") then true else nil)
end

-- Records an owned pass. Returns true if it's new.
local function grantPass(player: Player, data: { [string]: any }, key: string): boolean
	if data.passes[key] then
		return false
	end
	data.passes[key] = true
	applyPassAttributes(player, data)
	if key == "VIP" then
		-- The VIP skin comes with the pass; wear it unless another is on.
		if not Perks.equippedSkin(data) then
			data.equippedSkin = "VIPGold"
		end
		CharacterService.refreshShovel(player)
		CharacterService.refreshTitle(player)
	end
	return true
end

local function checkOwnership(player: Player, data: { [string]: any })
	local changed = false
	for key, pass in Monetization.Passes do
		if pass.id == 0 or pass.enabled == false or data.passes[key] then
			continue
		end
		for attempt = 1, Monetization.ownershipRetries do
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok then
				if owns and player.Parent and grantPass(player, data, key) then
					changed = true
				end
				break
			end
			if attempt < Monetization.ownershipRetries then
				task.wait(attempt * 2)
			else
				warn("[Purchases] ownership check failed for " .. key .. ": " .. tostring(owns))
			end
		end
	end
	if changed then
		PlayerData.changed(player)
	end
end

local function onPassPurchaseFinished(player: Player, passId: number, purchased: boolean)
	local key = passKeyById[passId]
	local data = PlayerData.get(player)
	if not key or not data then
		return
	end
	if not purchased then
		Analytics.custom(player, "PurchaseDeclined_" .. key)
		return
	end
	if grantPass(player, data, key) then
		local pass = Monetization.Passes[key]
		Analytics.custom(player, "PurchaseCompleted_" .. key, pass.price)
		Net.fire("Notify", player, pass.emoji .. " " .. string.upper(pass.name) .. " UNLOCKED!", "Big")
		PlayerData.changed(player)
	end
end

---------------------------------------------------------------------------
-- Developer products
---------------------------------------------------------------------------

-- Applies one grant to the profile. Must not yield (it runs between the
-- duplicate check and recording the purchase). Returns a short message and
-- an optional follow-up to run after the purchase is saved.
local function applyGrant(
	player: Player,
	data: { [string]: any },
	key: string,
	grant: { [string]: any }
): (string, (() -> ())?)
	local kind = grant.kind
	if kind == "Cash" then
		local amount = Bonuses.rewardCash(grant, data)
		EconomyService.addCash(player, data, amount, "IAP", key)
		return "+" .. Format.cash(amount), nil
	elseif kind == "Boost" then
		Boosts.add(data.activeBoosts, grant.boost, grant.seconds, os.time())
		local name = Retention.boosts[grant.boost].displayName
		return string.format("%s for %d min", name, math.floor(grant.seconds / 60 + 0.5)), nil
	elseif kind == "ServerBoost" then
		return "Server boosted!", function()
			ServerBoostService.start(player, grant.seconds)
		end
	elseif kind == "InstantDeepDig" then
		data.instantDeepDigs += 1
		return "Instant Deep Dig",
			function()
				if data.instantDeepDigs > 0 and DigService.instantDeepDig(player) then
					data.instantDeepDigs -= 1
					PlayerData.changed(player)
				else
					Net.fire("Notify", player, "Saved for your next Deep Dig!", "Reward")
				end
			end
	elseif kind == "Skin" then
		local skin = Monetization.Skins[grant.skin]
		data.ownedCosmetics[grant.skin] = true
		data.equippedSkin = grant.skin
		return skin.name .. " Shovel", function()
			CharacterService.refreshShovel(player)
		end
	elseif kind == "Bundle" then
		local parts, followUps = {}, {}
		for _, item in grant.items do
			local text, followUp = applyGrant(player, data, key, item)
			table.insert(parts, text)
			if followUp then
				table.insert(followUps, followUp)
			end
		end
		return table.concat(parts, " + "),
			function()
				for _, followUp in followUps do
					followUp()
				end
			end
	end
	error("Unknown grant kind " .. tostring(kind))
end

local function waitForProfile(player: Player): { [string]: any }?
	local waited = 0
	while player.Parent and not PlayerData.get(player) and waited < 20 do
		waited += task.wait(0.5)
	end
	return PlayerData.get(player)
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local key = productKeyById[receipt.ProductId]
	if not key then
		warn("[Purchases] receipt for an unknown product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- granted when they next join
	end
	local data = waitForProfile(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receipt.PurchaseId)
	local history = data.processedPurchaseIds
	if not table.find(history, purchaseId) then
		-- Recorded first, so even a grant that yields can't run twice.
		table.insert(history, purchaseId)
		local product = Monetization.Products[key]
		local ok, message, followUp = pcall(applyGrant, player, data, key, product.grant)
		if not ok then
			table.remove(history, table.find(history, purchaseId))
			warn("[Purchases] granting " .. key .. " failed: " .. tostring(message))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if key == "StarterPack" then
			data.starterPackBought = true
		end
		while #history > Monetization.receiptHistory do
			table.remove(history, 1)
		end
		local spent = tonumber(receipt.CurrencySpent) or 0
		data.robuxSpent += spent
		Analytics.custom(player, "PurchaseCompleted_" .. key, spent)
		PlayerData.changed(player)
		task.spawn(function()
			Net.fire(
				"Notify",
				player,
				product.emoji .. " " .. string.upper(product.name) .. "!\n" .. message,
				"Big"
			)
			if followUp then
				followUp()
			end
		end)
	end

	-- Granted only once the purchase (and its id) is safely saved.
	if PlayerData.saveNow(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

---------------------------------------------------------------------------

-- False when PolicyService restricts paid random items for this player
-- (checked before 2x Luck applies; unknown = restricted, to be safe).
function PurchaseService.luckAllowed(player: Player): boolean
	local policy = policies[player]
	return policy ~= nil and not policy.paidRandomRestricted
end

local function loadPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	policies[player] = {
		paidRandomRestricted = not ok or type(info) ~= "table" or info.ArePaidRandomItemsRestricted == true,
	}
end

function PurchaseService.init()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchaseFinished)
	DigService.luckAllowed = PurchaseService.luckAllowed

	PlayerData.extendSnapshot(function(player, data)
		local policy = policies[player]
		return {
			passes = data.passes,
			ownedCosmetics = data.ownedCosmetics,
			equippedSkin = data.equippedSkin,
			starterPackBought = data.starterPackBought,
			instantDeepDigs = data.instantDeepDigs,
			paidRandomRestricted = policy == nil or policy.paidRandomRestricted,
		}
	end)

	PlayerData.Loaded:Connect(function(player: Player, data)
		applyPassAttributes(player, data)
		task.spawn(function()
			loadPolicy(player)
			PlayerData.changed(player)
		end)
		task.spawn(checkOwnership, player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		policies[player] = nil
	end)

	Net.on("EquipSkin", 2, 4, function(player: Player, skinId: any)
		local data = PlayerData.get(player)
		if not data or type(skinId) ~= "string" then
			return
		end
		if skinId ~= "" and not Perks.ownsSkin(data, skinId) then
			return
		end
		data.equippedSkin = skinId
		CharacterService.refreshShovel(player)
		PlayerData.changed(player)
	end)

	Net.on("SellAnywhere", 1, 2, function(player: Player)
		local data = PlayerData.get(player)
		if data and Perks.has(data, "AutoSell") then
			EconomyService.sellAll(player, "Anywhere")
		end
	end)

	Net.on("ShopEvent", 4, 8, function(player: Player, event: any, key: any)
		if type(event) ~= "string" or not SHOP_EVENTS[event] then
			return
		end
		if
			key ~= nil
			and (type(key) ~= "string" or not (Monetization.Passes[key] or Monetization.Products[key]))
		then
			return
		end
		Analytics.custom(player, if key then event .. "_" .. key else event)
	end)
end

return PurchaseService
