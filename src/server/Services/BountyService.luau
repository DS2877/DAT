--!strict
-- The Bounty Board (Config/Bounties, Logic/Bounties): three small tasks at a
-- time, counted from digs, PERFECT hits and sales. Finishing one tells the
-- player; claiming it grants its reward and puts a new bounty in its slot.
-- Every few bounties there's a bonus. The board is per world (WorldState).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BountyConfig = require(ReplicatedStorage.Shared.Config.Bounties)
local Bounties = require(ReplicatedStorage.Shared.Logic.Bounties)
local Analytics = require(script.Parent.Analytics)
local DigService = require(script.Parent.DigService)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local RewardService = require(script.Parent.RewardService)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)

local BountyService = {}

local random = Random.new()
local function rng(): number
	return random:NextNumber()
end

local function board(data: { [string]: any }): { [string]: any }
	if type(data.bounties) ~= "table" then
		data.bounties = {}
	end
	Bounties.ensure(data.bounties, data, rng)
	return data.bounties
end

-- Counts an event on the player's board; tells them about finished ones.
function BountyService.record(player: Player, data: { [string]: any }, event: Bounties.Event)
	local state = board(data)
	local changed = false
	for slot, bounty in state.slots do
		local wasDone = Bounties.isDone(bounty)
		if Bounties.progress(bounty, event) then
			changed = true
			if not wasDone and Bounties.isDone(bounty) then
				Net.fire("BountyDone", player, slot, Bounties.describe(bounty))
			end
		end
	end
	if changed then
		PlayerData.changed(player)
	end
end

local function onClaim(player: Player, slot: any)
	local data = PlayerData.get(player)
	if not data or type(slot) ~= "number" then
		return
	end
	local state = board(data)
	local bounty = state.slots[slot]
	if not bounty or not Bounties.isDone(bounty) then
		return
	end
	local got = RewardService.grant(player, data, bounty.reward, "Bounty")
	state.completed += 1
	local avoid = {}
	for i, b in state.slots do
		if i ~= slot then
			avoid[Bounties.key(b)] = true
		end
	end
	state.slots[slot] = Bounties.generate(data, rng, avoid)
	Analytics.custom(player, "BountyClaimed")
	Net.fire("Notify", player, "📜 Bounty reward: " .. got, "Reward")
	if state.completed % BountyConfig.bonusEvery == 0 then
		local bonus = RewardService.grant(player, data, BountyConfig.bonus, "BountyBonus")
		task.delay(1.2, function()
			Net.fire(
				"Notify",
				player,
				string.format("🎁 %d bounties done! Bonus: %s", state.completed, bonus),
				"Big"
			)
		end)
	end
	PlayerData.changed(player)
end

-- Admin tools: finish every bounty on the board ("Finish"), deal a new
-- board ("New") or make the next claim the bonus one ("BonusNext").
function BountyService.adminAction(player: Player, data: { [string]: any }, what: string): string?
	local state = board(data)
	if what == "Finish" then
		for slot, bounty in state.slots do
			if not Bounties.isDone(bounty) then
				bounty.progress = bounty.target
				Net.fire("BountyDone", player, slot, Bounties.describe(bounty))
			end
		end
		PlayerData.changed(player)
		return "All bounties finished: claim them on the board"
	elseif what == "New" then
		state.slots = {}
		board(data)
		PlayerData.changed(player)
		return "A new Bounty Board"
	elseif what == "BonusNext" then
		local every = BountyConfig.bonusEvery
		state.completed = state.completed - state.completed % every + every - 1
		PlayerData.changed(player)
		return "The next claimed bounty gives the bonus"
	end
	return nil
end

function BountyService.init()
	PlayerData.Loaded:Connect(function(_player: Player, data: { [string]: any })
		board(data)
	end)
	PlayerData.extendSnapshot(function(_player, data)
		local state = board(data)
		return { bounties = { slots = state.slots, completed = state.completed } }
	end)
	DigService.Found:Connect(
		function(player: Player, data: { [string]: any }, find: { [string]: any }, spot: any)
			local def = Treasures.ById[find.id]
			BountyService.record(player, data, {
				type = "Find",
				areaId = spot and spot.areaId or "",
				rarity = find.rarity,
				id = find.id,
				junk = def ~= nil and def.set == "Junk",
			})
		end
	)
	DigService.Perfect:Connect(function(player: Player, data: { [string]: any })
		BountyService.record(player, data, { type = "Perfect" })
	end)
	EconomyService.Sold:Connect(function(player: Player, data: { [string]: any }, total: number)
		BountyService.record(player, data, { type = "Sell", amount = total })
	end)
	Net.on("ClaimBounty", 2, 4, onClaim)
end

return BountyService
