--!strict
-- Builds the island at server start and returns the facts gameplay needs
-- (spawn, sell zone, stations, gates, dig spot candidates, shelf slots).
--
-- The world is assembled from focused modules in Build/:
--   Terrain   lighting, sky, the stepped island, cliffs, ridges, volcano
--   Base      the deck hub: sell pad, shops, altar, boards, trophy shelf
--   Gates     invisible boundaries, gates with ramps, treasure glimpses
--   Beach / Jungle / Ruins / Volcano   each area's props and landmarks
--   Candidates  where dig spots may appear
--
-- Everything is deterministic (fixed seeds). A hand-built map can replace
-- this later by providing the same named parts (workspace.Base pads,
-- workspace.Gates barriers) and the same BuiltWorld fields.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local CollectionConfig = require(ReplicatedStorage.Shared.Config.Collection)
local Drinks = require(ReplicatedStorage.Shared.Config.Drinks)
local Build = script.Parent.Build
local BaseBuilder = require(Build.Base)
local BeachBuilder = require(Build.Beach)
local Candidates = require(Build.Candidates)
local GatesBuilder = require(Build.Gates)
local JungleBuilder = require(Build.Jungle)
local Kit = require(Build.Kit)
local RuinsBuilder = require(Build.Ruins)
local TerrainBuilder = require(Build.Terrain)
local VolcanoBuilder = require(Build.Volcano)

local L = Kit.L

local MapBuilder = {}

export type BuiltWorld = {
	spawnPosition: Vector3,
	sellZone: { cframe: CFrame, size: Vector3 },
	stations: { [string]: { position: Vector3, radius: number } },
	gates: { [string]: GatesBuilder.GateInfo },
	candidates: { [string]: { Vector3 } },
	baseFront: Vector3,
	shelfSlots: { CFrame },
	vipSpot: Vector3,
}

local function shelfSlots(deckTop: number): { CFrame }
	local shelf = L.trophyShelf
	local slots = {}
	for i = 1, CollectionConfig.shelfSlots do
		local x = shelf.minX
			+ (i - 1) * (shelf.maxX - shelf.minX) / math.max(1, CollectionConfig.shelfSlots - 1)
		table.insert(slots, CFrame.new(x, deckTop + 2.8, shelf.z))
	end
	return slots
end

function MapBuilder.build(): BuiltWorld
	local started = os.clock()
	local rng = Random.new(20260930)
	Kit.folder("Decor", workspace)

	TerrainBuilder.lighting()
	TerrainBuilder.build(rng)
	-- Everything below measures the real ground: wait for terrain collision.
	local probes = {}
	for _, p in
		{
			{ 0, 120 },
			{ -140, 60 },
			{ 140, 60 },
			{ 0, 240 },
			{ -120, -120 },
			{ 120, -120 },
			{ -200, -200 },
			{ 200, -200 },
			{ 0, -320 },
			{ -150, -360 },
			{ 150, -360 },
			{ L.volcano.x, L.volcano.z + L.volcano.radius * 0.5 },
		}
	do
		table.insert(probes, Vector2.new(p[1], p[2]))
	end
	Kit.waitForTerrain(probes)
	local base = BaseBuilder.build(rng)
	-- The base clears the sand under its deck; let that settle too.
	local b = L.base
	Kit.waitForTerrain({
		Vector2.new(b.minX - 12, b.minZ - 12),
		Vector2.new(b.maxX + 12, b.maxZ + 12),
		Vector2.new(b.minX - 12, b.maxZ + 12),
		Vector2.new(b.maxX + 12, b.minZ - 12),
	})
	local deckTop = base.deckTop
	local gates = GatesBuilder.build()
	local beach = BeachBuilder.build(rng)
	JungleBuilder.build(rng)
	RuinsBuilder.build(rng)
	VolcanoBuilder.build(rng)

	local candidates = {}
	local candidateRng = Random.new(1337)
	for _, areaId in Areas.Order do
		candidates[areaId] = Candidates.generate(areaId, candidateRng)
		-- Never start an area without dig spots: if the ground couldn't be
		-- read yet, give the terrain more time and try again.
		local tries = 0
		while #candidates[areaId] == 0 and tries < 30 do
			tries += 1
			task.wait(1)
			candidates[areaId] = Candidates.generate(areaId, candidateRng)
		end
	end

	local counts = {}
	for _, areaId in Areas.Order do
		table.insert(counts, areaId .. " " .. #candidates[areaId])
	end
	print(
		string.format(
			"[MapBuilder] Island built in %.2fs (dig points: %s)",
			os.clock() - started,
			table.concat(counts, ", ")
		)
	)

	local sp = L.sellPad
	local function station(kind: string, radius: number)
		return { position = base.pads[kind].Position, radius = radius }
	end
	return {
		spawnPosition = Vector3.new(L.spawn.x, deckTop + 3, L.spawn.z),
		sellZone = { cframe = CFrame.new(sp.x, deckTop + 4, sp.z), size = Vector3.new(sp.size, 10, sp.size) },
		stations = {
			Shovel = station("Shovel", L.shovelStation.radius),
			Bag = station("Bag", L.bagStation.radius),
			Rebirth = station("Rebirth", L.rebirthAltar.radius),
			-- The Tiki Bar's drinks pad (missing only if the beach had no ground there).
			Drinks = if beach.tikiPad
				then { position = beach.tikiPad.Position, radius = Drinks.stationRadius }
				else nil,
		},
		gates = gates,
		candidates = candidates,
		shelfSlots = shelfSlots(deckTop),
		baseFront = Vector3.new((L.base.minX + L.base.maxX) / 2, deckTop, L.base.minZ),
		vipSpot = base.vipSpot,
	}
end

return MapBuilder
