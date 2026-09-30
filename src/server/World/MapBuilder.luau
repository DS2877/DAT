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
local DECK_TOP = Kit.DECK_TOP

local MapBuilder = {}

export type BuiltWorld = {
	spawnPosition: Vector3,
	sellZone: { cframe: CFrame, size: Vector3 },
	stations: { [string]: { position: Vector3, radius: number } },
	gates: { [string]: GatesBuilder.GateInfo },
	candidates: { [string]: { Vector3 } },
	baseFront: Vector3,
	shelfSlots: { CFrame },
}

local function shelfSlots(): { CFrame }
	local shelf = L.trophyShelf
	local slots = {}
	for i = 1, CollectionConfig.shelfSlots do
		local x = shelf.minX
			+ (i - 1) * (shelf.maxX - shelf.minX) / math.max(1, CollectionConfig.shelfSlots - 1)
		table.insert(slots, CFrame.new(x, DECK_TOP + 2.8, shelf.z))
	end
	return slots
end

function MapBuilder.build(): BuiltWorld
	local started = os.clock()
	local rng = Random.new(20260930)
	Kit.folder("Decor", workspace)

	TerrainBuilder.lighting()
	TerrainBuilder.build(rng)
	BaseBuilder.build(rng)
	local gates = GatesBuilder.build()
	BeachBuilder.build(rng)
	JungleBuilder.build(rng)
	RuinsBuilder.build(rng)
	VolcanoBuilder.build(rng)

	local candidates = {}
	local candidateRng = Random.new(1337)
	for _, areaId in Areas.Order do
		candidates[areaId] = Candidates.generate(areaId, candidateRng)
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
	return {
		spawnPosition = Vector3.new(L.spawn.x, DECK_TOP + 3, L.spawn.z),
		sellZone = { cframe = CFrame.new(sp.x, DECK_TOP + 4, sp.z), size = Vector3.new(sp.size, 10, sp.size) },
		stations = {
			Shovel = {
				position = Vector3.new(L.shovelStation.x, DECK_TOP, L.shovelStation.z),
				radius = L.shovelStation.radius,
			},
			Bag = {
				position = Vector3.new(L.bagStation.x, DECK_TOP, L.bagStation.z),
				radius = L.bagStation.radius,
			},
			Rebirth = {
				position = Vector3.new(L.rebirthAltar.x, L.beachHeight, L.rebirthAltar.z),
				radius = L.rebirthAltar.radius,
			},
		},
		gates = gates,
		candidates = candidates,
		shelfSlots = shelfSlots(),
		baseFront = Vector3.new((L.base.minX + L.base.maxX) / 2, DECK_TOP, L.base.minZ),
	}
end

return MapBuilder
