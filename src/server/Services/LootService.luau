--!strict
-- Server-side loot: rolls a treasure for a finished dig and records the find.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootRoller = require(ReplicatedStorage.Shared.Logic.LootRoller)

local LootService = {}

local random = Random.new()
local function rng(): number
	return random:NextNumber()
end

export type Find = {
	id: string,
	rarity: string,
	value: number,
	isNew: boolean,
}

function LootService.rollFor(data: { [string]: any }, areaId: string): Find
	local roll = LootRoller.roll(areaId, rng)
	local entry = data.discovered[roll.id]
	local isNew = entry == nil or not entry.normal
	if entry == nil then
		entry = {}
		data.discovered[roll.id] = entry
	end
	entry.normal = true
	return { id = roll.id, rarity = roll.rarity, value = roll.value, isNew = isNew }
end

return LootService
