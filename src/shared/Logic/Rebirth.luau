--!strict
-- Pure rebirth rules.

local CurrentWorld = require(script.Parent.CurrentWorld)
local Retention = require(script.Parent.Parent.Config.Retention)

local Rebirth = {}

function Rebirth.cost(rebirths: number): number
	local r = Retention.rebirth
	return math.floor(r.baseCost * r.costGrowth ^ rebirths / 1000 + 0.5) * 1000
end

-- ok, reason ("IslandOnly" | "NeedShovel" | "NotEnoughCash"), missing cash.
-- A rebirth resets the island's run, so it only happens on the island.
function Rebirth.canRebirth(data: { [string]: any }): (boolean, string?, number)
	if CurrentWorld.isFrost() then
		return false, "IslandOnly", 0
	end
	if data.shovelLevel < Retention.rebirth.requiredShovel then
		return false, "NeedShovel", 0
	end
	local cost = Rebirth.cost(data.rebirths)
	if data.cash < cost then
		return false, "NotEnoughCash", cost - data.cash
	end
	return true, nil, 0
end

-- Resets the run and counts the rebirth. Keeps collection, cosmetics,
-- purchases and the rebirth count.
function Rebirth.apply(data: { [string]: any })
	data.rebirths += 1
	data.cash = 0
	data.shovelLevel = 1
	data.bagLevel = 1
	data.bagContents = {}
end

-- "" for no rebirths yet.
function Rebirth.title(rebirths: number): string
	if rebirths <= 0 then
		return ""
	end
	local titles = Retention.rebirth.titles
	if rebirths <= #titles then
		return titles[rebirths]
	end
	return titles[#titles] .. " " .. (rebirths - #titles + 1)
end

function Rebirth.tint(rebirths: number): string?
	if rebirths <= 0 then
		return nil
	end
	local tints = Retention.rebirth.tints
	return tints[(rebirths - 1) % #tints + 1]
end

-- How many rebirth-only Secrets are unlocked (one per `secretEvery` rebirths).
function Rebirth.secretTier(rebirths: number): number
	return math.floor(rebirths / Retention.rebirth.secretEvery)
end

return Rebirth
