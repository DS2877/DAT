--!strict
-- Player save schema: template, migrations and sanitizing. Pure (no Roblox
-- services) so migrations are covered by the offline tests.
--
-- To change the schema: bump CURRENT_VERSION, add a migration that upgrades
-- from the previous version, and extend the template.

local Progression = require(script.Parent.Progression)
local Economy = require(script.Parent.Parent.Config.Economy)

local DataSchema = {}

DataSchema.CURRENT_VERSION = 1

function DataSchema.template(): { [string]: any }
	return {
		schemaVersion = DataSchema.CURRENT_VERSION,
		cash = 0,
		shovelLevel = 1,
		bagLevel = 1,
		bagContents = {}, -- { { id = string, v = number } }
		rebirths = 0,
		discovered = {}, -- [treasureId] = { normal = true?, shiny = true?, golden = true? }
		dailyState = {}, -- Phase 4
		playtimeGiftState = {}, -- Phase 4
		processedPurchaseIds = {}, -- Phase 5
		ownedCosmetics = {}, -- Phase 5
		activeBoosts = {}, -- Phase 5: [boostId] = expiry unix time
		onboarding = {
			funnelStep = 0, -- highest analytics onboarding step logged
			guideDone = false, -- the new-player arrow has finished
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

-- Migrations keyed by the version they upgrade FROM.
-- Example for the future: [1] = function(data) data.newField = 0 end
local migrations: { [number]: (data: { [string]: any }) -> () } = {}

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
			table.insert(clean, { id = item.id, v = math.max(0, math.floor(item.v)) })
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
