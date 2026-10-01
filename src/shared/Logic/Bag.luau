--!strict
-- Pure bag helpers. Bag contents are saved, so items are tiny records:
-- { id = treasureId, v = value, m = mutation id or nil }.

export type BagItem = { id: string, v: number, m: string? }

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

-- `capacity` comes from Perks.bagCapacity (bag level + the +50% Bag pass).
function Bag.isFull(contents: { BagItem }, capacity: number): boolean
	return #contents >= capacity
end

-- Adds an item if there is room. Returns true when added.
function Bag.add(contents: { BagItem }, item: BagItem, capacity: number): boolean
	if Bag.isFull(contents, capacity) then
		return false
	end
	table.insert(contents, { id = item.id, v = item.v, m = item.m })
	return true
end

return Bag
