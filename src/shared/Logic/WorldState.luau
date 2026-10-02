--!strict
-- Per-world runs. Each world has its own run: cash, shovel, bag, what's in
-- the bag and the Bounty Board. Everything else (collection, rebirths, purchases, dailies,
-- settings, stats) is shared by every world.
--
-- The stored profile keeps the island's run at the top level (as before
-- worlds existed) and other worlds' runs under worldSaves[worldId]. A server
-- for another world swaps its run in when the profile loads (`enter`), so the
-- game code only ever sees "the current run" at the top level, and swaps it
-- back out for every save (`stored`). Pure, so it's covered offline.

local WorldState = {}

WorldState.FIELDS = { "cash", "shovelLevel", "bagLevel", "bagContents", "bounties" }

-- A world's run before its first visit.
function WorldState.fresh(): { [string]: any }
	return { cash = 0, shovelLevel = 1, bagLevel = 1, bagContents = {}, bounties = {} }
end

local function pick(source: any): { [string]: any }
	local run = WorldState.fresh()
	if type(source) == "table" then
		for _, field in WorldState.FIELDS do
			if type(source[field]) == type(run[field]) then
				run[field] = source[field]
			end
		end
	end
	return run
end

-- Puts `worldId`'s run at the top level and keeps the island's aside (in
-- worldSaves.Island, never stored). No change on the island.
function WorldState.enter(data: { [string]: any }, worldId: string)
	if worldId == "Island" then
		return
	end
	local saves = if type(data.worldSaves) == "table" then data.worldSaves else {}
	data.worldSaves = saves
	local run = pick(saves[worldId])
	saves.Island = pick(data)
	saves[worldId] = nil
	for _, field in WorldState.FIELDS do
		data[field] = run[field]
	end
end

-- The profile as it's stored: the island's run back at the top level and
-- this world's run under worldSaves[worldId]. `data` itself isn't changed.
function WorldState.stored(data: { [string]: any }, worldId: string): { [string]: any }
	if worldId == "Island" then
		return data
	end
	local out = table.clone(data)
	local saves = if type(data.worldSaves) == "table" then table.clone(data.worldSaves) else {}
	-- No island run aside (the profile was reset here): a fresh island run.
	local island = pick(saves.Island)
	saves.Island = nil
	saves[worldId] = pick(data)
	for _, field in WorldState.FIELDS do
		out[field] = island[field]
	end
	out.worldSaves = saves
	return out
end

return WorldState
