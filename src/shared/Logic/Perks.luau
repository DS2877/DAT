--!strict
-- Pure: what a player's passes do. `data.passes` = { [passKey] = true } for
-- owned passes (VIP also counts as Auto Dig and Auto Sell). Every pass has
-- an on/off switch in `data.settings` (on unless switched off); a perk that
-- comes with VIP also turns off when VIP is switched off.

export type Data = { [string]: any }

local Boosts = require(script.Parent.Boosts)
local Monetization = require(script.Parent.Parent.Config.Monetization)
local Progression = require(script.Parent.Progression)
local RebirthPerks = require(script.Parent.RebirthPerks)

local Perks = {}

local P = Monetization.Perks

-- True if the player has the pass (bought directly or through VIP). A pass
-- that is switched off in the config (enabled = false) never counts.
function Perks.has(data: { [string]: any }, passKey: string): boolean
	local pass = Monetization.Passes[passKey]
	if not pass or pass.enabled == false then
		return false
	end
	local passes = data.passes
	if type(passes) ~= "table" then
		return false
	end
	if passes[passKey] == true then
		return true
	end
	if passes.VIP == true then
		for _, included in P.vipIncludes do
			if included == passKey then
				return true
			end
		end
	end
	return false
end

local function switchedOn(data: { [string]: any }, passKey: string): boolean
	local toggle = Monetization.Passes[passKey].toggle
	local settings = data.settings
	return type(settings) ~= "table" or settings[toggle] ~= false
end

-- True if the player has the pass and hasn't switched the perk off.
function Perks.enabled(data: { [string]: any }, passKey: string): boolean
	if not Perks.has(data, passKey) or not switchedOn(data, passKey) then
		return false
	end
	if data.passes[passKey] == true then
		return true
	end
	-- Only through VIP: VIP must be on too.
	return switchedOn(data, "VIP")
end

-- Passes that include this one (for "Included in VIP" on the shop card).
function Perks.includedBy(passKey: string): string?
	for _, included in P.vipIncludes do
		if included == passKey then
			return "VIP"
		end
	end
	return nil
end

function Perks.bagCapacity(data: { [string]: any }): number
	local base = Progression.bagCapacity(data.bagLevel)
	if Perks.enabled(data, "BigBag") then
		base = math.ceil(base * P.bigBagMultiplier) -- rounded up
	end
	-- The Big Pockets rebirth perk.
	return base + RebirthPerks.value(data, "BigPockets")
end

-- Dig speed: 1 + 1 for the 2x Dig Speed pass + 1 for the boost (capped).
function Perks.digSpeed(data: { [string]: any }, now: number): number
	local speed = 1
	if Perks.enabled(data, "FastDig") then
		speed += P.fastDigBonus
	end
	if Boosts.isActive(data.activeBoosts, "DigSpeed2x", now) then
		speed += 1
	end
	return math.min(speed, P.maxDigSpeed)
end

-- Permanent cash multiplier from passes (2x Cash, VIP's +10%).
function Perks.cashMultiplier(data: { [string]: any }): number
	local multiplier = 1
	if Perks.enabled(data, "CashX2") then
		multiplier *= P.cashPassMultiplier
	end
	if Perks.enabled(data, "VIP") then
		multiplier *= 1 + P.vipCashBonus
	end
	return multiplier
end

-- Odds multipliers from 2x Luck (Rare and better), or nil without it.
function Perks.luckMultipliers(data: { [string]: any }): { [string]: number }?
	if not Perks.enabled(data, "Luck2x") then
		return nil
	end
	local m = P.luckMultiplier
	return { Rare = m, Epic = m, Legendary = m, Mythic = m, Secret = m }
end

-- A shovel skin the player may equip.
function Perks.ownsSkin(data: { [string]: any }, skinId: string): boolean
	local skin = Monetization.Skins[skinId]
	if not skin then
		return false
	end
	if Monetization.Passes[skin.source] then
		return Perks.has(data, skin.source)
	end
	return type(data.ownedCosmetics) == "table" and data.ownedCosmetics[skinId] == true
end

-- The equipped skin, if it's still owned.
function Perks.equippedSkin(data: { [string]: any }): string?
	local id = data.equippedSkin
	if type(id) == "string" and id ~= "" and Perks.ownsSkin(data, id) then
		return id
	end
	return nil
end

return Perks
