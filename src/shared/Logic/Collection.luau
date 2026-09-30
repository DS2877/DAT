--!strict
-- Pure collection rules: set progress, completed sets, the permanent cash
-- multiplier, and ranking finds for the trophy shelf.

local Areas = require(script.Parent.Parent.Config.Areas)
local CollectionConfig = require(script.Parent.Parent.Config.Collection)
local LootRoller = require(script.Parent.LootRoller)
local Rarities = require(script.Parent.Parent.Config.Rarities)
local Treasures = require(script.Parent.Parent.Config.Treasures)

export type Discovered = { [string]: { normal: boolean?, shiny: boolean?, golden: boolean? } }
export type BestFind = { id: string, m: string? }

local Collection = {}

-- Found / total base treasures in an area's set.
function Collection.setProgress(discovered: Discovered, areaId: string): (number, number)
	local found, total = 0, 0
	for _, def in Treasures.List do
		if def.area == areaId and def.rebirths == nil then
			total += 1
			if discovered[def.id] ~= nil then
				found += 1
			end
		end
	end
	return found, total
end

function Collection.completedSets(discovered: Discovered): { string }
	local done = {}
	for _, areaId in Areas.Order do
		local found, total = Collection.setProgress(discovered, areaId)
		if total > 0 and found >= total then
			table.insert(done, areaId)
		end
	end
	return done
end

-- Discovered counts for base / Shiny / Golden versions, and the total.
function Collection.totals(discovered: Discovered): (number, number, number, number)
	local normal, shiny, golden = 0, 0, 0
	for _, def in Treasures.List do
		local entry = discovered[def.id]
		if entry then
			normal += 1
			if entry.shiny then
				shiny += 1
			end
			if entry.golden then
				golden += 1
			end
		end
	end
	return normal, shiny, golden, #Treasures.List
end

-- Permanent cash multiplier from collection sets (rebirths join in Phase 4).
function Collection.cashMultiplier(discovered: Discovered): number
	return 1 + #Collection.completedSets(discovered) * CollectionConfig.setBonus
end

-- A comparable score for a find: rarity first, then value with mutation.
function Collection.findScore(find: BestFind): number
	local def = Treasures.ById[find.id]
	if not def then
		return 0
	end
	return Rarities.rank(def.rarity) * 1e9 + def.value * LootRoller.mutationMultiplier(find.m)
end

function Collection.isBetter(candidate: BestFind, current: BestFind?): boolean
	return current == nil or Collection.findScore(candidate) > Collection.findScore(current)
end

return Collection
