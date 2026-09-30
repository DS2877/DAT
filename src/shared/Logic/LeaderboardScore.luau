--!strict
-- Encodes a treasure find as one integer for an OrderedDataStore so the
-- "Rarest Find" board sorts by rarity, then value, and can be decoded back.
--   score = rank * 1e13 + floor(value * mutation) * 1e3 + index * 3 + mutation

local LootRoller = require(script.Parent.LootRoller)
local Rarities = require(script.Parent.Parent.Config.Rarities)
local Treasures = require(script.Parent.Parent.Config.Treasures)

local LeaderboardScore = {}

local MUTATIONS = { [0] = nil :: string?, [1] = "Shiny", [2] = "Golden" }
local MUTATION_CODE = { Shiny = 1, Golden = 2 }

local indexOf: { [string]: number } = {}
for index, def in Treasures.List do
	indexOf[def.id] = index
end

function LeaderboardScore.encode(id: string, mutation: string?): number
	local def = Treasures.ById[id]
	local index = indexOf[id]
	if not def or not index then
		return 0
	end
	local value = math.floor(def.value * LootRoller.mutationMultiplier(mutation))
	return Rarities.rank(def.rarity) * 1e13 + value * 1e3 + index * 3 + (MUTATION_CODE[mutation or ""] or 0)
end

function LeaderboardScore.decode(score: number): (string?, string?)
	local low = score % 1000
	local def = Treasures.List[math.floor(low / 3)]
	if not def then
		return nil, nil
	end
	return def.id, MUTATIONS[low % 3]
end

return LeaderboardScore
