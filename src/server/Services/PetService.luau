--!strict
-- Pets you dig up (Config/Pets, Logic/Pets). Every dig may turn up an egg
-- (as well as the treasure); it hatches into one of the dug area's pets.
-- New pets come out by themselves the first time; a pet you already have
-- levels up. The pet that's out is shown on the character (attributes
-- "Pet" and "PetLevel"); every client draws it following its owner.
-- Remotes: EquipPet (petId or "") from the client; PetHatched (petId,
-- outcome, level, cash) to the finder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local Config = require(ReplicatedStorage.Shared.Config.Pets)
local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)
local Pets = require(ReplicatedStorage.Shared.Logic.Pets)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Analytics = require(script.Parent.Analytics)
local AnnouncementService = require(script.Parent.AnnouncementService)
local DigService = require(script.Parent.DigService)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local PetService = {}

local rng = Random.new()
local hatchDelay = 1.4 -- after the treasure's reveal

-- Shows the pet that's out on the character (every client draws it).
local function show(player: Player)
	local character = player.Character
	local data = PlayerData.get(player)
	if not character or not data then
		return
	end
	local id = Pets.equipped(data)
	character:SetAttribute("Pet", if id == "" then nil else id)
	character:SetAttribute("PetLevel", if id == "" then nil else Pets.level(data, id))
end

-- Hatches `id` for the player now (eggs; admins; tests).
function PetService.hatch(player: Player, id: string): string?
	local data = PlayerData.get(player)
	if not data or not Pets.byId[id] then
		return nil
	end
	local outcome = Pets.hatch(data, id)
	local cash = 0
	if outcome == "Maxed" then
		cash = Bonuses.rewardCash(Config.maxedReward, data)
		EconomyService.addCash(player, data, cash, "Gameplay", "PetMaxed")
	end
	local level = Pets.level(data, id)
	Analytics.custom(player, "PetHatched_" .. id)
	Net.fire("PetHatched", player, id, outcome, level, cash)
	local pet = Pets.byId[id]
	if outcome == "New" and Rarities.rank(pet.rarity) >= Rarities.rank("Rare") then
		AnnouncementService.announce({
			text = string.format("🐣 %s hatched a %s %s!", player.DisplayName, pet.name, pet.icon),
			color = Rarities.Info[pet.rarity].color,
			secret = false,
		})
	end
	show(player)
	PlayerData.changed(player)
	return outcome
end

local function onFound(
	player: Player,
	data: { [string]: any },
	find: { [string]: any },
	spot: { [string]: any }
)
	local ctx = { deep = find.deep, moonlit = spot.moonlit, meteor = spot.meteor }
	if not Pets.rollEgg(data, ctx, rng:NextNumber()) then
		return
	end
	local world = CurrentWorld.id()
	local id = Pets.pick(world, spot.lootArea or spot.areaId or "Beach", rng:NextNumber())
		or Pets.pick(world, "Beach", rng:NextNumber())
	if not id then
		return
	end
	task.delay(hatchDelay, function()
		if player.Parent then
			PetService.hatch(player, id)
		end
	end)
end

local function onEquip(player: Player, id: unknown)
	local data = PlayerData.get(player)
	if not data or type(id) ~= "string" then
		return
	end
	if Pets.equip(data, id) then
		show(player)
		PlayerData.changed(player)
	end
end

function PetService.init()
	DigService.Found:Connect(onFound)
	Net.on("EquipPet", 4, 6, onEquip)
	PlayerData.extendSnapshot(function(_player, data)
		return { pets = data.pets }
	end)
	PlayerData.Loaded:Connect(function(player)
		show(player)
	end)
	local function added(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(show, player)
		end)
	end
	Players.PlayerAdded:Connect(added)
	for _, player in Players:GetPlayers() do
		added(player)
	end
end

return PetService
