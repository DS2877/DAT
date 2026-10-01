--!strict
-- Hidden treasures (Config/Jackpots): buries a Mythic / Secret under a random
-- dig spot in an area and announces the AREA only, so everyone races there.
-- The spot looks like any other; the server alone knows which it is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Jackpots = require(ReplicatedStorage.Shared.Config.Jackpots)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Analytics = require(script.Parent.Analytics)
local AnnouncementService = require(script.Parent.AnnouncementService)
local DigSpotService = require(script.Parent.DigSpotService)
local Net = require(script.Parent.Parent.Net)

local JackpotService = {}

type Hidden = { spotId: number, rarity: string, area: string, since: number, reminded: boolean }

local hidden: { [number]: Hidden } = {}
local rng = Random.new()

local function areaName(area: string): string
	local def = Areas.Defs[area]
	return string.upper(if def then def.displayName else area)
end

local function count(): number
	local n = 0
	for _ in hidden do
		n += 1
	end
	return n
end

local function pick(): Jackpots.Choice
	local total = 0
	for _, choice in Jackpots.choices do
		total += choice.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, choice in Jackpots.choices do
		roll -= choice.weight
		if roll <= 0 then
			return choice
		end
	end
	return Jackpots.choices[1]
end

local function tell(text: string, rarity: string)
	local info = Rarities.Info[rarity]
	AnnouncementService.announce({
		text = text,
		color = if info then info.color else "#FFD54A",
		secret = false,
	})
	Net.fireAll("Notify", text, "Big")
end

-- Buries a treasure of `rarity` in `area` (random if not given). Returns
-- true if a spot was found for it.
function JackpotService.hide(rarity: string?, area: string?): boolean
	local choice = pick()
	local r = rarity or choice.rarity
	local a = area or choice.area
	local spot = DigSpotService.pickHidden(a)
	if not spot then
		return false
	end
	spot.jackpot = r
	hidden[spot.id] = { spotId = spot.id, rarity = r, area = a, since = os.clock(), reminded = false }
	tell(
		string.format(
			"💎 A %s treasure is buried somewhere in the %s! Find it first!",
			string.upper(r),
			areaName(a)
		),
		r
	)
	return true
end

-- Called by DigService when a hidden treasure's spot is dug out.
function JackpotService.onFound(player: Player, spotId: number, find: { [string]: any })
	local entry = hidden[spotId]
	if not entry then
		return
	end
	hidden[spotId] = nil
	Analytics.custom(player, "HiddenTreasureFound_" .. entry.rarity)
	tell(
		string.format(
			"🏆 %s found the hidden %s treasure in the %s!",
			player.DisplayName,
			string.upper(find.rarity),
			areaName(entry.area)
		),
		find.rarity
	)
end

-- The hidden treasures right now (for the admin panel).
function JackpotService.list(): { Hidden }
	local list = {}
	for _, entry in hidden do
		table.insert(list, entry)
	end
	return list
end

function JackpotService.start()
	task.spawn(function()
		task.wait(Jackpots.firstDelay)
		while true do
			-- Forget spots that are gone; remind about long-hidden ones.
			for id, entry in hidden do
				if not DigSpotService.get(id) then
					hidden[id] = nil
				elseif not entry.reminded and os.clock() - entry.since > Jackpots.reminderAfter then
					entry.reminded = true
					tell(
						string.format(
							"💎 The %s treasure in the %s is still hidden!",
							string.upper(entry.rarity),
							areaName(entry.area)
						),
						entry.rarity
					)
				end
			end
			if count() < Jackpots.maxHidden then
				JackpotService.hide()
			end
			task.wait(rng:NextNumber(Jackpots.interval.min, Jackpots.interval.max))
		end
	end)
end

return JackpotService
