--!strict
-- Pure pet rules (Config/Pets). Saved in the profile:
--   pets = { owned = { [petId] = level }, equipped = petId or "",
--            digsSinceEgg = digs since the last egg, eggs = eggs ever found }

local Config = require(script.Parent.Parent.Config.Pets)

local Pets = {}

local byId: { [string]: Config.Pet } = {}
for _, pet in Config.list do
	byId[pet.id] = pet
end
Pets.byId = byId

local function state(data: { [string]: any }): { [string]: any }?
	local pets = data.pets
	return if type(pets) == "table" and type(pets.owned) == "table" then pets else nil
end

function Pets.level(data: { [string]: any }, id: string): number
	local pets = state(data)
	local level = pets and pets.owned[id]
	return if type(level) == "number" then level else 0
end

function Pets.count(data: { [string]: any }): number
	local pets = state(data)
	local n = 0
	if pets then
		for id in pets.owned do
			if byId[id] then
				n += 1
			end
		end
	end
	return n
end

-- The pet that's out ("" for none).
function Pets.equipped(data: { [string]: any }): string
	local pets = state(data)
	local id = pets and pets.equipped
	return if type(id) == "string" and byId[id] and Pets.level(data, id) > 0 then id else ""
end

-- The cash bonus of `id` at `level` (0.08 = +8%).
function Pets.bonusAt(id: string, level: number): number
	local pet = byId[id]
	if not pet or level <= 0 then
		return 0
	end
	return (Config.bonus[pet.rarity] or 0) + Config.perLevel * (math.min(level, Config.maxLevel) - 1)
end

-- The equipped pet's cash bonus (0 without one).
function Pets.cashBonus(data: { [string]: any }): number
	local id = Pets.equipped(data)
	return if id == "" then 0 else Pets.bonusAt(id, Pets.level(data, id))
end

-- "+8% cash".
function Pets.describe(id: string, level: number): string
	return string.format("+%d%% cash", math.floor(Pets.bonusAt(id, level) * 100 + 0.5))
end

-- Chance of an egg on this dig. `ctx`: deep / moonlit / meteor flags.
function Pets.eggChance(data: { [string]: any }, ctx: { [string]: any }): number
	local pets = state(data)
	local since = if pets and type(pets.digsSinceEgg) == "number" then pets.digsSinceEgg else 0
	local eggs = if pets and type(pets.eggs) == "number" then pets.eggs else 0
	if (eggs == 0 and since + 1 >= Config.firstEggAt) or since + 1 >= Config.pity then
		return 1
	end
	local chance = Config.eggChance
	for flag, multiplier in Config.multipliers do
		if ctx[flag] then
			chance *= multiplier
		end
	end
	return math.min(1, chance)
end

-- Counts a dig; true when it turned up an egg (`roll` in [0, 1)).
function Pets.rollEgg(data: { [string]: any }, ctx: { [string]: any }, roll: number): boolean
	local pets = state(data)
	if not pets then
		return false
	end
	local egg = roll < Pets.eggChance(data, ctx)
	if egg then
		pets.digsSinceEgg = 0
		pets.eggs = (if type(pets.eggs) == "number" then pets.eggs else 0) + 1
	else
		pets.digsSinceEgg = (if type(pets.digsSinceEgg) == "number" then pets.digsSinceEgg else 0) + 1
	end
	return egg
end

-- The pets an area's eggs hatch into.
function Pets.pool(world: string, area: string): { Config.Pet }
	local list = {}
	for _, pet in Config.list do
		if pet.world == world and pet.area == area then
			table.insert(list, pet)
		end
	end
	return list
end

-- Which pet hatches (`roll` in [0, 1)); nil if the area has none.
function Pets.pick(world: string, area: string, roll: number): string?
	local list = Pets.pool(world, area)
	local total = 0
	for _, pet in list do
		total += Config.weights[pet.rarity] or 0
	end
	local x = roll * total
	for _, pet in list do
		x -= Config.weights[pet.rarity] or 0
		if x < 0 then
			return pet.id
		end
	end
	return if #list > 0 then list[#list].id else nil
end

-- Adds a hatched pet: "New", "LevelUp" or "Maxed" (already at max level).
-- The first pet comes out by itself.
function Pets.hatch(data: { [string]: any }, id: string): string
	local pets = state(data)
	if not pets or not byId[id] then
		return "Maxed"
	end
	local level = Pets.level(data, id)
	if level >= Config.maxLevel then
		return "Maxed"
	end
	pets.owned[id] = level + 1
	if Pets.equipped(data) == "" then
		pets.equipped = id
	end
	return if level == 0 then "New" else "LevelUp"
end

-- Puts a pet out ("" puts it away). False if it isn't yours.
function Pets.equip(data: { [string]: any }, id: string): boolean
	local pets = state(data)
	if not pets then
		return false
	end
	if id ~= "" and Pets.level(data, id) <= 0 then
		return false
	end
	pets.equipped = id
	return true
end

return Pets
