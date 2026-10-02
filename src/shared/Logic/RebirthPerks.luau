--!strict
-- Pure rebirth perk rules (Config/RebirthPerks). Saved in the profile:
--   rebirthPerks = { [perkId] = level }
--   perkChoices  = { { perkId, perkId, perkId } }  card sets waiting to be picked
--   perksEarned  = how many card sets were ever given (one per rebirth)

local PerkConfig = require(script.Parent.Parent.Config.RebirthPerks)

local RebirthPerks = {}

local byId: { [string]: PerkConfig.Perk } = {}
for _, perk in PerkConfig.list do
	byId[perk.id] = perk
end
RebirthPerks.byId = byId

function RebirthPerks.level(data: { [string]: any }, id: string): number
	local perks = data.rebirthPerks
	local level = if type(perks) == "table" then perks[id] else nil
	return if type(level) == "number" then level else 0
end

-- What a perk adds right now (0 without it).
function RebirthPerks.value(data: { [string]: any }, id: string): number
	local perk = byId[id]
	return if perk then RebirthPerks.level(data, id) * perk.step else 0
end

-- "+10% cash on every treasure" at `level`.
function RebirthPerks.describe(id: string, level: number): string
	local perk = byId[id]
	if not perk then
		return "?"
	end
	local amount = level * perk.step
	local shown = if perk.percent
		then string.format("%d%%", math.floor(amount * 100 + 0.5))
		else (if amount == math.floor(amount) then tostring(amount) else string.format("%.1f", amount))
	return string.format(perk.text, shown)
end

-- Up to `choices` different perks that aren't maxed yet.
function RebirthPerks.roll(data: { [string]: any }, rng: () -> number): { string }
	local open = {}
	for _, perk in PerkConfig.list do
		if RebirthPerks.level(data, perk.id) < perk.max then
			table.insert(open, perk.id)
		end
	end
	local picked = {}
	while #picked < PerkConfig.choices and #open > 0 do
		local i = 1 + math.floor(rng() * #open)
		table.insert(picked, table.remove(open, i) :: string)
	end
	return picked
end

-- Gives a card set for every rebirth that hasn't had one (older saves get
-- theirs too). True if any were added.
function RebirthPerks.grantChoices(data: { [string]: any }, rng: () -> number): boolean
	if type(data.perkChoices) ~= "table" then
		data.perkChoices = {}
	end
	if type(data.rebirthPerks) ~= "table" then
		data.rebirthPerks = {}
	end
	local earned = if type(data.perksEarned) == "number" then data.perksEarned else 0
	local added = false
	while earned < (data.rebirths or 0) do
		earned += 1
		local set = RebirthPerks.roll(data, rng)
		if #set > 0 then
			table.insert(data.perkChoices, set)
			added = true
		end
	end
	data.perksEarned = earned
	return added
end

-- Picks `id` from the first waiting card set. True if it was allowed.
function RebirthPerks.choose(data: { [string]: any }, id: string): boolean
	local set = type(data.perkChoices) == "table" and data.perkChoices[1]
	if type(set) ~= "table" or not table.find(set, id) then
		return false
	end
	local perk = byId[id]
	if not perk or RebirthPerks.level(data, id) >= perk.max then
		return false
	end
	data.rebirthPerks[id] = RebirthPerks.level(data, id) + 1
	table.remove(data.perkChoices, 1)
	return true
end

return RebirthPerks
