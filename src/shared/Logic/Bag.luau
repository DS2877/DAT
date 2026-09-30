--!strict
-- Pure bag helpers. Bag contents are saved, so items are tiny records:
-- { id = treasureId, v = value }.

local Progression = require(script.Parent.Progression)

export type BagItem = { id: string, v: number }

local Bag = {}

function Bag.count(contents: { BagItem }): number
	return #contents
end

function Bag.totalValue(contents: { BagItem }): number
	local total = 0
	for _, item in contents do
		total += item.v
	end
	return total
end

function Bag.isFull(contents: { BagItem }, bagLevel: number): boolean
	return #contents >= Progression.bagCapacity(bagLevel)
end

-- Adds an item if there is room. Returns true when added.
function Bag.add(contents: { BagItem }, item: BagItem, bagLevel: number): boolean
	if Bag.isFull(contents, bagLevel) then
		return false
	end
	table.insert(contents, { id = item.id, v = item.v })
	return true
end

return Bag
