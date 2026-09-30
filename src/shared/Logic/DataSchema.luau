--!strict
-- Player save schema: template, migrations and sanitizing. Pure (no Roblox
-- services) so migrations are covered by the offline tests.
--
-- To change the schema: bump CURRENT_VERSION, add a migration that upgrades
-- from the previous version, and extend the template.

local Progression = require(script.Parent.Progression)
local Economy = require(script.Parent.Parent.Config.Economy)
local Rarities = require(script.Parent.Parent.Config.Rarities)
local Treasures = require(script.Parent.Parent.Config.Treasures)

local DataSchema = {}

DataSchema.CURRENT_VERSION = 2

function DataSchema.template(): { [string]: any }
	return {
		schemaVersion = DataSchema.CURRENT_VERSION,
		cash = 0,
		shovelLevel = 1,
		bagLevel = 1,
		bagContents = {}, -- { { id = string, v = number, m = "Shiny" | "Golden" | nil } }
		rebirths = 0,
		discovered = {}, -- [treasureId] = { normal = true?, shiny = true?, golden = true? }
		bestFind = {}, -- { id = treasureId, m = mutation? } shown on the trophy shelf; {} = none
		setsAwarded = {}, -- [areaId] = true once the set-complete reward was given
		dailyState = {
			lastDay = 0, -- UTC day number of the last daily claim (0 = never)
			streak = 0, -- calendar day (1..7) last claimed
			goldenXDay = 0, -- UTC day the Golden X was last dug
		},
		playtimeGiftState = {}, -- unused: playtime gifts are per session (kept for the schema)
		digCharges = { Rare = 0, Epic = 0 }, -- guaranteed-rarity digs from rewards
		groupRewardClaimed = false,
		weekly = { week = 0, cashEarned = 0, rebirths = 0, bestScore = 0 },
		processedPurchaseIds = {}, -- Phase 5
		ownedCosmetics = {}, -- Phase 5
		activeBoosts = {}, -- [boostId] = expiry unix time
		onboarding = {
			funnelStep = 0, -- highest analytics onboarding step logged
			guideDone = false, -- the new-player arrow has finished
			-- Guaranteed early finds (see Logic/Guarantees).
			firstRareFound = false,
			rareGuaranteeDig = 0, -- 0 = not picked yet
			firstEpicFound = false,
			epicGuaranteeAt = 0, -- Jungle seconds; 0 = not picked yet
			jungleSeconds = 0,
			jungleLastDigAt = 0,
		},
		stats = {
			digs = 0,
			finds = 0,
			sales = 0,
			cashEarned = 0,
			cashSpent = 0,
			playSeconds = 0,
			firstJoin = 0,
			lastJoin = 0,
			sessions = 0,
		},
	}
end

local function hasFoundRarity(data: { [string]: any }, minRarity: string): boolean
	if type(data.discovered) ~= "table" then
		return false
	end
	local minRank = Rarities.rank(minRarity)
	for id in data.discovered do
		local def = Treasures.ById[id]
		if def and Rarities.rank(def.rarity) >= minRank then
			return true
		end
	end
	return false
end

-- Migrations keyed by the version they upgrade FROM.
local migrations: { [number]: (data: { [string]: any }) -> () } = {
	-- v1 -> v2: guaranteed early finds. Players who already found a Rare /
	-- Epic, or are past their first 10 digs, don't get a forced one.
	[1] = function(data)
		local onboarding = if type(data.onboarding) == "table" then data.onboarding else {}
		data.onboarding = onboarding
		local digs = if type(data.stats) == "table" and type(data.stats.digs) == "number"
			then data.stats.digs
			else 0
		onboarding.firstRareFound = digs >= 10 or hasFoundRarity(data, "Rare")
		onboarding.firstEpicFound = hasFoundRarity(data, "Epic")
	end,
}

-- Fills in missing keys from the template. Only descends into record-like
-- tables that exist in the template with non-empty defaults.
local function reconcile(data: { [string]: any }, template: { [string]: any })
	for key, default in template do
		local current = data[key]
		if current == nil or type(default) ~= type(current) then
			data[key] = default
		elseif type(default) == "table" and next(default) ~= nil then
			reconcile(current, default)
		end
	end
end

local function sanitize(data: { [string]: any })
	if data.cash ~= data.cash or data.cash < 0 then -- NaN or negative
		data.cash = 0
	end
	data.cash = math.min(math.floor(data.cash), Economy.maxCash)
	data.shovelLevel = math.clamp(math.floor(data.shovelLevel), 1, Progression.MaxShovelLevel)
	data.bagLevel = math.clamp(math.floor(data.bagLevel), 1, Progression.MaxBagLevel)
	data.rebirths = math.max(0, math.floor(data.rebirths))

	-- Keep only well-formed bag items. Unknown treasure ids are kept (they
	-- still sell for their stored value) so a config change never eats loot.
	local clean = {}
	for _, item in data.bagContents do
		if
			type(item) == "table"
			and type(item.id) == "string"
			and type(item.v) == "number"
			and item.v == item.v
		then
			local mutation = if item.m == "Shiny" or item.m == "Golden" then item.m else nil
			table.insert(clean, { id = item.id, v = math.max(0, math.floor(item.v)), m = mutation })
		end
	end
	data.bagContents = clean
end

-- Upgrades any stored profile (or nil for a brand-new player) to the current
-- schema. Returns the data table to use.
function DataSchema.migrate(stored: { [string]: any }?): { [string]: any }
	if stored == nil or type(stored) ~= "table" then
		return DataSchema.template()
	end
	local data = stored
	local version = if type(data.schemaVersion) == "number" then data.schemaVersion else 0
	if version > DataSchema.CURRENT_VERSION then
		-- Saved by a newer server build. Leave it untouched; callers must not
		-- overwrite newer data with an older schema.
		error("Profile schemaVersion " .. version .. " is newer than " .. DataSchema.CURRENT_VERSION)
	end
	while version < DataSchema.CURRENT_VERSION do
		local step = migrations[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.schemaVersion = DataSchema.CURRENT_VERSION
	reconcile(data, DataSchema.template())
	sanitize(data)
	return data
end

return DataSchema
