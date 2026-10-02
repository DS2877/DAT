--!strict
-- The wind (Config/Wind), entirely on this client: palms bend and their
-- fronds flutter, jungle canopies sway, grass, ferns and bamboo leaves
-- flutter, flags, sails and banners flap. One wind for the whole island,
-- leaning things downwind, with gusts that roll across it.
--
-- The world builder's parts are found by name when the client starts. Only
-- things near the camera move, a set number of times per second, all in one
-- BulkMoveTo, so it stays cheap on phones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)
local Wind = require(ReplicatedStorage.Shared.Config.Wind)

local WindController = {}

type Kind = "Palm" | "Canopy" | "Grass" | "Flag"

type Item = {
	kind: Kind,
	parts: { BasePart },
	base: { CFrame }, -- each part's resting CFrame
	weights: { number }, -- how much of the bend each part gets (palms)
	fronds: { Vector3? }, -- a frond's flutter axis (palms)
	pivot: Vector3, -- what it sways around
	crown: Vector3, -- where palm fronds attach
	center: Vector3,
	phase: number,
	along: number, -- distance along the wind (gusts roll across)
}

local GRASS = { BeachGrass = true, Fern = true, BambooLeaf = true }
local CANOPY = { Canopy = true, AncientCanopy = true }
local FLAG = { Flag = 1, Sail = 0.3, Banner = 0.25 }

local items: { Item } = {}
local lastMoved = 0
local up = Vector3.new(0, 1, 0)
local windDir = Vector3.new(Wind.direction.X, 0, Wind.direction.Z).Unit
local bendAxis = up:Cross(windDir).Unit -- turning about it leans things downwind
local rng = Random.new()

local function about(point: Vector3, axis: Vector3, angle: number): CFrame
	return CFrame.new(point) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-point)
end

local function newItem(kind: Kind, parts: { BasePart }, pivot: Vector3, center: Vector3): Item
	local base = {}
	for i, p in parts do
		base[i] = p.CFrame
	end
	return {
		kind = kind,
		parts = parts,
		base = base,
		weights = {},
		fronds = {},
		pivot = pivot,
		crown = pivot,
		center = center,
		phase = rng:NextNumber(0, math.pi * 2),
		along = center:Dot(windDir),
	}
end

-- A palm: it bends from the foot (more toward the top) and its fronds
-- flutter around the crown.
local function palm(model: Model)
	local parts: { BasePart } = {}
	local lowest, highest = nil :: BasePart?, nil :: BasePart?
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Ambient") == nil then
			table.insert(parts, d)
			if d.Name == "Trunk" then
				if not lowest or d.Position.Y < lowest.Position.Y then
					lowest = d
				end
				if not highest or d.Position.Y > highest.Position.Y then
					highest = d
				end
			end
		end
	end
	if not lowest or not highest or #parts == 0 then
		return
	end
	local foot = lowest.Position - Vector3.new(0, 1.5, 0)
	local crown = highest.Position + Vector3.new(0, 1.2, 0)
	local height = math.max(4, crown.Y - foot.Y)
	local item = newItem("Palm", parts, foot, crown)
	item.crown = crown
	for i, p in parts do
		item.weights[i] = math.clamp((p.Position.Y - foot.Y) / height, 0, 1.2) ^ 1.6
		if p.Name == "Leaf" then
			local out = p.Position - crown
			out = Vector3.new(out.X, 0, out.Z)
			if out.Magnitude > 0.1 then
				item.fronds[i] = out.Unit:Cross(up)
			end
		end
	end
	table.insert(items, item)
end

-- Spread over frames (a few hundred instances each) so joining doesn't hitch.
local function collect()
	for n, d in workspace:GetDescendants() do
		if n % 300 == 0 then
			task.wait()
		end
		if d:IsA("Model") and d.Name == "Palm" then
			palm(d)
		elseif d:IsA("BasePart") and d:GetAttribute("Ambient") == nil then
			local name = d.Name
			local pos = d.Position
			if CANOPY[name] then
				table.insert(items, newItem("Canopy", { d }, pos - Vector3.new(0, 10, 0), pos))
			elseif GRASS[name] then
				table.insert(items, newItem("Grass", { d }, pos - Vector3.new(0, 0.9, 0), pos))
			elseif FLAG[name] then
				table.insert(items, newItem("Flag", { d }, pos, pos))
			end
		end
	end
end

-- 1 normally, up to 1 + gustStrength while a gust passes over `along`.
local function gust(t: number, along: number): number
	local wave = math.sin(2 * math.pi * (t - along / Wind.gustSpeed) / Wind.gustEvery)
	return 1 + Wind.gustStrength * math.max(0, wave) ^ 4
end

local function pose(item: Item, t: number, parts: { BasePart }, cframes: { CFrame })
	local w = Wind.speed
	local g = gust(t, item.along)
	local phase = item.phase
	if item.kind == "Palm" then
		-- Leans downwind, swaying, a little more in gusts.
		local sway = math.sin(w * t + phase) * 0.65 + math.sin(1.7 * w * t + 2 * phase) * 0.35
		local lean = math.rad(Wind.palmBend) * g * (0.45 + 0.55 * sway)
		local flutter = math.rad(Wind.frondFlutter) * (0.6 + 0.4 * g)
		for i, p in item.parts do
			local cf = about(item.pivot, bendAxis, lean * item.weights[i])
			local frond = item.fronds[i]
			if frond then
				local flap = flutter * math.sin(2.4 * w * t + phase + i * 0.9)
				cf *= about(item.crown, frond, flap)
			end
			table.insert(parts, p)
			table.insert(cframes, cf * item.base[i])
		end
		return
	end
	local p = item.parts[1]
	local cf: CFrame
	if item.kind == "Canopy" then
		local sway = math.sin(0.8 * w * t + phase)
		cf = about(item.pivot, bendAxis, math.rad(Wind.canopySway) * g * (0.4 + 0.6 * sway))
	elseif item.kind == "Grass" then
		local sway = math.sin(2.2 * w * t + phase) * 0.7 + math.sin(3.7 * w * t + phase) * 0.3
		cf = about(item.pivot, bendAxis, math.rad(Wind.grassSway) * g * (0.35 + 0.65 * sway))
	else
		local strength = FLAG[p.Name] or 1
		local flap = math.sin(3.2 * w * t + phase) * 0.7 + math.sin(5.3 * w * t + phase) * 0.3
		cf = about(item.pivot, up, math.rad(Wind.flagFlap) * strength * g * flap)
	end
	table.insert(parts, p)
	table.insert(cframes, cf * item.base[1])
end

function WindController.init()
	if not Wind.worlds[CurrentWorld.id()] then
		return
	end
	task.spawn(function()
		-- The world is built by the server before anyone spawns; let the rest
		-- of the client start first.
		workspace:WaitForChild("Decor", 30)
		task.wait(2)
		collect()
		if #items == 0 then
			return
		end
		local start = os.clock()
		local nextAt = 0
		RunService.RenderStepped:Connect(function()
			local now = os.clock()
			if now < nextAt then
				return
			end
			nextAt = now + 1 / Wind.rate
			local t = now - start
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			local camPos = camera.CFrame.Position
			local parts: { BasePart } = {}
			local cframes: { CFrame } = {}
			for _, item in items do
				if (item.center - camPos).Magnitude < Wind.radius and item.parts[1].Parent then
					pose(item, t, parts, cframes)
				end
			end
			lastMoved = #parts
			if #parts == 0 then
				return
			end
			local ok = pcall(function()
				workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			end)
			if not ok then
				for i, p in parts do
					p.CFrame = cframes[i]
				end
			end
		end)
	end)
end

-- How many swaying things were found, and parts moved last update (tests).
function WindController.count(): number
	return #items
end

function WindController.moved(): number
	return lastMoved
end

return WindController
