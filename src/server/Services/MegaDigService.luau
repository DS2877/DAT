--!strict
-- The Mega Dig (Config/MegaDig): every 15 minutes a huge dig site appears at
-- a random spot on the beach. Everyone can help dig; when it's dug out, one
-- helper wins its Mythic+ treasure in a draw (one ticket per hit), shown to
-- the whole server, and the other helpers get some cash.
--
-- Clients read the state from workspace attributes:
--   MegaDigNext      server time of the next scheduled start
--   MegaDigActive    a site is open right now
--   MegaDigEnds      when it collapses if not dug out
--   MegaDigProgress  0..1
--   MegaDigPos       the site's position

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local MegaDig = require(ReplicatedStorage.Shared.Config.MegaDig)
local MegaDigClock = require(ReplicatedStorage.Shared.Logic.MegaDigClock)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Analytics = require(script.Parent.Analytics)
local AnnouncementService = require(script.Parent.AnnouncementService)
local CollectionService = require(script.Parent.CollectionService)
local DigSpotService = require(script.Parent.DigSpotService)
local EconomyService = require(script.Parent.EconomyService)
local LootService = require(script.Parent.LootService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.Parent.World.World)

local MegaDigService = {}

type Site = {
	spot: DigSpotService.Spot,
	required: number,
	hits: number,
	ends: number,
	helpers: { [Player]: number },
	lastHit: { [Player]: number },
	mound: BasePart,
	moundTop: CFrame,
	done: boolean,
}

local site: Site? = nil
local scheduled = true
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function tell(text: string, color: string)
	AnnouncementService.announce({ text = text, color = color, secret = false })
	Net.fireAll("Notify", text, "Big")
end

-- The big site: a wide mound with a dirt ring, flags, and a light beam
-- seen from across the island.
local function buildSite(position: Vector3): (Model, BasePart)
	local r = MegaDig.radius
	local model = Instance.new("Model")
	model.Name = "MegaDigSite"
	local function piece(props: { [string]: any }): BasePart
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for key, value in props do
			(p :: any)[key] = value
		end
		p.Parent = model
		return p
	end
	local mound = piece({
		Name = "Mound",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, r * 2, r * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(140, 90, 48),
		Material = Enum.Material.Ground,
		CanQuery = true,
	})
	model.PrimaryPart = mound
	piece({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, r * 2 + 4, r * 2 + 4),
		CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 201, 51),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanQuery = false,
	})
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local at = position + Vector3.new(math.cos(a) * (r + 1.5), 0, math.sin(a) * (r + 1.5))
		piece({
			Name = "Stake",
			Size = Vector3.new(0.4, 4, 0.4),
			CFrame = CFrame.new(at + Vector3.new(0, 2, 0)),
			Color = Color3.fromRGB(120, 80, 40),
			Material = Enum.Material.Wood,
			CanQuery = false,
		})
		piece({
			Name = "Flag",
			Size = Vector3.new(0.1, 1, 1.6),
			CFrame = CFrame.new(at + Vector3.new(0, 3.5, 0.8)),
			Color = if i % 2 == 0 then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(255, 201, 51),
			CanQuery = false,
		})
	end
	piece({
		Name = "Beam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(160, 3, 3),
		CFrame = CFrame.new(position + Vector3.new(0, 80, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 220, 90),
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CastShadow = false,
		CanQuery = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 120)
	light.Range = 30
	light.Brightness = 2
	light.Parent = mound
	model:SetAttribute("Mega", true)
	model:SetAttribute("Range", MegaDig.digRange)
	return model, mound
end

-- A random open point on the beach for the site.
local function pickPosition(): Vector3?
	local candidates = World.get().candidates[MegaDig.area]
	if not candidates or #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

local function setState()
	local s = site
	workspace:SetAttribute("MegaDigActive", s ~= nil)
	workspace:SetAttribute("MegaDigProgress", if s then math.clamp(s.hits / s.required, 0, 1) else nil)
	workspace:SetAttribute("MegaDigEnds", if s then s.ends else nil)
	workspace:SetAttribute("MegaDigPos", if s then s.spot.position else nil)
end

-- Opens a Mega Dig site now (the schedule, or an admin). Returns false if
-- one is already open.
function MegaDigService.start(position: Vector3?): boolean
	if site then
		return false
	end
	local at = position or pickPosition()
	if not at then
		return false
	end
	local model, mound = buildSite(at)
	local spot = DigSpotService.addSpecial(model, at, MegaDig.area, { mega = true, range = MegaDig.digRange })
	local players = #Players:GetPlayers()
	site = {
		spot = spot,
		required = math.min(
			MegaDig.maxRequiredHits,
			MegaDig.requiredHits + math.max(0, players - 1) * MegaDig.hitsPerExtraPlayer
		),
		hits = 0,
		ends = now() + MegaDig.timeLimit,
		helpers = {},
		lastHit = {},
		mound = mound,
		moundTop = mound.CFrame,
		done = false,
	}
	setState()
	local areaId = Zones.areaAt(at.X, at.Z)
	local area = Areas.Defs[areaId]
	tell(
		string.format(
			"⛏️ A MEGA DIG SITE appeared %s the %s! Everyone dig! A MYTHIC+ treasure is inside!",
			if areaId == "Beach" then "on" else "in",
			string.upper(if area then area.displayName else "island")
		),
		"#FFC933"
	)
	return true
end

local function close()
	local s = site
	if not s then
		return
	end
	site = nil
	DigSpotService.remove(s.spot.id)
	setState()
end

-- Picks the winner: one ticket per hit, among helpers with enough hits.
local function draw(s: Site): (Player?, { { name: string, userId: number, hits: number } })
	local entries = {}
	local total = 0
	for player, hits in s.helpers do
		if player.Parent and hits >= MegaDig.minHitsToEnter and PlayerData.get(player) then
			table.insert(
				entries,
				{ name = player.DisplayName, userId = player.UserId, hits = hits, player = player }
			)
			total += hits
		end
	end
	if total == 0 then
		return nil, {}
	end
	local roll = rng:NextNumber(0, total)
	local winner = entries[#entries].player
	for _, entry in entries do
		roll -= entry.hits
		if roll <= 0 then
			winner = entry.player
			break
		end
	end
	local list = {}
	for _, entry in entries do
		table.insert(list, { name = entry.name, userId = entry.userId, hits = entry.hits })
	end
	return winner, list
end

local function finish(s: Site)
	s.done = true
	local position = s.spot.position
	local winner, entries = draw(s)
	close()
	if not winner then
		tell("⛏️ The Mega Dig was dug out, but nobody dug enough to win.", "#FFC933")
		return
	end
	local data = PlayerData.get(winner) :: { [string]: any }
	local find = LootService.rollFor(data, {
		areaId = MegaDig.lootArea,
		clue = nil,
		streak = 0,
		deep = false,
		goldenX = false,
		friends = 0,
		jackpot = MegaDig.minRarity,
	})
	-- The prize goes straight into the bag (even if it's full).
	table.insert(data.bagContents, { id = find.id, v = find.value, m = find.mutation })
	data.stats.finds += 1
	Analytics.custom(winner, "MegaDigWin_" .. find.rarity, find.value)

	Net.fireAll("MegaDigDraw", {
		entries = entries,
		winnerUserId = winner.UserId,
		winnerName = winner.DisplayName,
		find = find,
		position = position,
	})
	-- After the draw animation: tell everyone, pay the other helpers.
	task.delay(MegaDig.drawSeconds, function()
		local def = Treasures.ById[find.id]
		local info = Rarities.Info[find.rarity]
		tell(
			string.format(
				"🏆 %s won the MEGA DIG treasure: %s%s!",
				winner.DisplayName,
				if find.mutation then string.upper(find.mutation) .. " " else "",
				if def then def.name else find.id
			),
			if info then info.color else "#FFC933"
		)
		if winner.Parent then
			CollectionService.onFind(winner, data, find)
			PlayerData.changed(winner)
		end
		for player, hits in s.helpers do
			local helperData = PlayerData.get(player)
			if player ~= winner and player.Parent and helperData and hits >= MegaDig.minHitsToEnter then
				local share = math.min(1, hits / MegaDig.fullShareHits)
				local amount = math.floor(Bonuses.rewardCash(MegaDig.consolation, helperData) * share)
				EconomyService.addCash(player, helperData, amount, "Gameplay", "MegaDigHelp")
				Net.fire("Notify", player, "⛏️ Thanks for helping! +" .. amount .. " cash", "Reward")
			end
		end
	end)
end

-- A dig hit on the Mega site (from DigService, already range-checked).
function MegaDigService.onHit(player: Player, data: { [string]: any }): boolean
	local s = site
	if not s or s.done then
		return false
	end
	local clock = os.clock()
	local interval = Bonuses.hitInterval(data, os.time())
	if clock - (s.lastHit[player] or -math.huge) < interval * 0.75 then
		return false
	end
	s.lastHit[player] = clock
	s.helpers[player] = (s.helpers[player] or 0) + 1
	s.hits += 1
	-- The mound sinks as it's dug out.
	local progress = math.clamp(s.hits / s.required, 0, 1)
	s.mound.CFrame = s.moundTop - Vector3.new(0, progress * 1.8, 0)
	workspace:SetAttribute("MegaDigProgress", progress)
	if s.hits >= s.required then
		finish(s)
	end
	return true
end

-- Closes the open site without a winner (admin). Returns false if none.
function MegaDigService.cancel(): boolean
	if not site then
		return false
	end
	close()
	return true
end

function MegaDigService.isActive(): boolean
	return site ~= nil
end

-- How many hits each helper has (tests, admin).
function MegaDigService.helpers(): { [Player]: number }
	return if site then site.helpers else {}
end

-- Turns the 15-minute schedule on or off (tests; admins can still start one).
function MegaDigService.setScheduled(on: boolean)
	scheduled = on
end

-- Runs the 15-minute schedule (and collapses sites that run out of time).
function MegaDigService.run()
	local lastScheduled = MegaDigClock.nextStart(now()) - MegaDig.interval -- not one already past
	task.spawn(function()
		while true do
			local t = now()
			local nextStart = MegaDigClock.nextStart(t)
			workspace:SetAttribute("MegaDigNext", nextStart)
			local s = site
			if s and not s.done and t > s.ends then
				close()
				tell("⛏️ The Mega Dig site collapsed! The next one comes in 15 minutes.", "#FF8A3D")
			end
			local previous = nextStart - MegaDig.interval
			if previous > lastScheduled then
				lastScheduled = previous
				if not site and scheduled then
					MegaDigService.start()
				end
			end
			task.wait(1)
		end
	end)
end

return MegaDigService
