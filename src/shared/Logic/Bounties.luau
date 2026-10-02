--!strict
-- Pure Bounty Board rules (Config/Bounties): making bounties, counting
-- progress from game events, and describing them. The server owns the
-- state; the client only describes it.
--
-- A bounty: { kind, target, param?, progress, reward }
--   param: the area id (DigArea), rarity (Rarity) or treasure id (Treasure)

local Areas = require(script.Parent.Parent.Config.Areas)
local BountyConfig = require(script.Parent.Parent.Config.Bounties)
local Format = require(script.Parent.Parent.Util.Format)
local Goals = require(script.Parent.Goals)
local Progression = require(script.Parent.Progression)
local Rarities = require(script.Parent.Parent.Config.Rarities)
local Treasures = require(script.Parent.Parent.Config.Treasures)

export type Bounty = {
	kind: string,
	target: number,
	param: string?,
	progress: number,
	reward: { [string]: any },
}

export type Event =
	{ type: "Find", areaId: string, rarity: string, id: string, junk: boolean }
	| { type: "Perfect" }
	| { type: "Sell", amount: number }

local Bounties = {}

local function between(range: { number }?, rng: () -> number): number
	if not range then
		return 1
	end
	return range[1] + math.floor(rng() * (range[2] - range[1] + 1))
end

local function pickWeighted<T>(list: { T }, weightOf: (T) -> number, rng: () -> number): T?
	local total = 0
	for _, item in list do
		total += weightOf(item)
	end
	if total <= 0 then
		return nil
	end
	local x = rng() * total
	for _, item in list do
		x -= weightOf(item)
		if x < 0 then
			return item
		end
	end
	return list[#list]
end

-- A new bounty for this player. `avoid` holds "kind|param" keys already on
-- the board (no two of the same).
function Bounties.generate(data: { [string]: any }, rng: () -> number, avoid: { [string]: boolean }?): Bounty
	local unlocked = Progression.unlockedAreas(data.shovelLevel)
	local best = #unlocked
	for _ = 1, 20 do
		local template = pickWeighted(BountyConfig.templates, function(t)
			return if (t.minAreaOrder or 1) <= best then t.weight else 0
		end, rng) :: BountyConfig.Template
		local param: string? = nil
		local target = between(template.count, rng)
		if template.kind == "DigArea" then
			-- Usually the best area so far, sometimes an earlier one.
			param = if rng() < 0.6 then unlocked[best] else unlocked[1 + math.floor(rng() * best)]
		elseif template.kind == "Rarity" then
			param = template.rarity
		elseif template.kind == "Treasure" then
			local maxRank = Rarities.rank(template.maxRarity or "Uncommon")
			local options = {}
			for _, def in Treasures.List do
				local area = Areas.Defs[def.area]
				if
					area
					and area.order <= best
					and def.rebirths == nil
					and Rarities.rank(def.rarity) <= maxRank
				then
					table.insert(options, def)
				end
			end
			local def = options[1 + math.floor(rng() * #options)]
			if not def then
				continue
			end
			param = def.id
			target = 1
		elseif template.kind == "Sell" then
			local goal = Goals.current(data)
			target = math.max(500, math.floor(goal.cost * (template.goalShare or 0.4) / 100 + 0.5) * 100)
		end
		local key = template.kind .. "|" .. tostring(param)
		if not (avoid and avoid[key]) then
			return {
				kind = template.kind,
				target = target,
				param = param,
				progress = 0,
				reward = { kind = "Cash", goalPercent = template.reward, min = BountyConfig.rewardMin },
			}
		end
	end
	return {
		kind = "Dig",
		target = 10,
		progress = 0,
		reward = { kind = "Cash", goalPercent = 0.06, min = BountyConfig.rewardMin },
	}
end

function Bounties.key(b: Bounty): string
	return b.kind .. "|" .. tostring(b.param)
end

-- Fills the board up to its slots. The state: { slots = { Bounty }, completed }.
function Bounties.ensure(state: { [string]: any }, data: { [string]: any }, rng: () -> number)
	if type(state.slots) ~= "table" then
		state.slots = {}
	end
	if type(state.completed) ~= "number" then
		state.completed = 0
	end
	while #state.slots < BountyConfig.slots do
		local avoid = {}
		for _, b in state.slots do
			avoid[Bounties.key(b)] = true
		end
		table.insert(state.slots, Bounties.generate(data, rng, avoid))
	end
end

function Bounties.isDone(b: Bounty): boolean
	return b.progress >= b.target
end

-- Counts an event toward a bounty. True if its progress changed.
function Bounties.progress(b: Bounty, event: Event): boolean
	if Bounties.isDone(b) then
		return false
	end
	local add = 0
	if event.type == "Find" then
		local e = event :: any
		local counts = b.kind == "Dig"
			or (b.kind == "DigArea" and e.areaId == b.param)
			or (b.kind == "Rarity" and Rarities.rank(e.rarity) >= Rarities.rank(b.param or "Rare"))
			or (b.kind == "Treasure" and e.id == b.param)
			or (b.kind == "Junk" and e.junk)
		add = if counts then 1 else 0
	elseif event.type == "Perfect" and b.kind == "Perfect" then
		add = 1
	elseif event.type == "Sell" and b.kind == "Sell" then
		add = (event :: any).amount
	end
	if add <= 0 then
		return false
	end
	b.progress = math.min(b.target, b.progress + add)
	return true
end

-- "Find 2 Rare or better", "Dig up 8 treasures in the Jungle"...
function Bounties.describe(b: Bounty): string
	local n = b.target
	if b.kind == "Dig" then
		return string.format("Dig up %d treasures", n)
	elseif b.kind == "DigArea" then
		local area = b.param and Areas.Defs[b.param]
		return string.format("Dig up %d treasures in the %s", n, if area then area.displayName else "?")
	elseif b.kind == "Rarity" then
		local info = Rarities.Info[b.param or "Rare"]
		local name = if info then info.displayName else "Rare"
		return if n == 1
			then string.format("Find something %s or better", name)
			else string.format("Find %d %s or better", n, name)
	elseif b.kind == "Treasure" then
		local def = b.param and Treasures.ById[b.param]
		return string.format("Find a %s", if def then def.name else "treasure")
	elseif b.kind == "Perfect" then
		return string.format("Land %d PERFECT hits", n)
	elseif b.kind == "Junk" then
		return if n == 1 then "Dig up a piece of junk" else string.format("Dig up %d pieces of junk", n)
	elseif b.kind == "Sell" then
		return string.format("Sell treasure worth %s", Format.cash(n))
	end
	return "?"
end

-- "3 / 8" or "$1,200 / $4,000".
function Bounties.progressText(b: Bounty): string
	if b.kind == "Sell" then
		return Format.cash(b.progress) .. " / " .. Format.cash(b.target)
	end
	return string.format("%d / %d", b.progress, b.target)
end

return Bounties
