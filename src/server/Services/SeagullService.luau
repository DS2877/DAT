--!strict
-- The seagull hat thief (Config/Seagull). Now and then a seagull dives on a
-- player near the palms, grabs their hat and flies to the top of a palm.
-- Walking under that palm makes it bring the hat back (plus a small coin);
-- if nobody comes it gets bored and returns it anyway. One seagull per
-- server at a time. Purely for fun: nothing is ever lost.
-- Clients get the Seagull remote (to everyone):
--   "Steal"   (userId, { model, palm })  the hat is gone, the bird flies off
--   "Perch"   (userId, { model, palm })  it sits on the palm
--   "Return"  (userId, { model, cash })  hat back (walked under the palm)
--   "GiveUp"  (userId, { model })        hat back (the seagull got bored)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local Config = require(ReplicatedStorage.Shared.Config.Seagull)
local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local SeagullService = {}

type Bird = {
	model: Model,
	parts: { { part: BasePart, offset: CFrame, wing: number? } },
	cframe: CFrame,
	hat: Accessory?,
}

local scheduled = true
local busy = false
local palms: { Vector3 } = {} -- crowns (where a seagull sits)
local joinedAt: { [Player]: number } = {}
local lastRobbed: { [number]: number } = {} -- userId -> os.clock
local rng = Random.new()
local timing = {
	swoop = Config.swoop,
	toPalm = Config.toPalm,
	away = Config.away,
	giveUpAfter = Config.giveUpAfter,
}

local WHITE = Color3.fromRGB(246, 246, 240)
local GREY = Color3.fromRGB(170, 178, 186)
local BLACK = Color3.fromRGB(35, 35, 40)
local ORANGE = Color3.fromRGB(255, 170, 40)

------------------------------------------------------------------ the bird

local function addPart(
	bird: Bird,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	wing: number?
)
	local s = Config.scale
	local part = Instance.new(if shape == nil and name == "Beak" then "WedgePart" else "Part") :: BasePart
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	if shape and part:IsA("Part") then
		part.Shape = shape
	end
	part.Size = size * s
	part.Parent = bird.model
	local scaled = CFrame.new(offset.Position * s) * offset.Rotation
	table.insert(bird.parts, { part = part, offset = scaled, wing = wing })
end

local function newBird(at: Vector3): Bird
	local model = Instance.new("Model")
	model.Name = "Seagull"
	local bird: Bird = { model = model, parts = {}, cframe = CFrame.new(at), hat = nil }
	local ball = Enum.PartType.Ball
	addPart(bird, "Body", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 0, 0), WHITE, ball)
	addPart(bird, "Rear", Vector3.new(1, 1, 1), CFrame.new(0, 0.05, 0.75), WHITE, ball)
	addPart(bird, "Head", Vector3.new(0.85, 0.85, 0.85), CFrame.new(0, 0.6, -0.75), WHITE, ball)
	addPart(
		bird,
		"Beak",
		Vector3.new(0.18, 0.22, 0.6),
		CFrame.new(0, 0.55, -1.35) * CFrame.Angles(0, math.pi, 0),
		ORANGE
	)
	addPart(bird, "EyeL", Vector3.new(0.16, 0.16, 0.16), CFrame.new(-0.3, 0.75, -1.0), BLACK, ball)
	addPart(bird, "EyeR", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0.3, 0.75, -1.0), BLACK, ball)
	addPart(bird, "Tail", Vector3.new(0.7, 0.12, 0.6), CFrame.new(0, 0.15, 1.35), GREY)
	addPart(bird, "LegL", Vector3.new(0.1, 0.5, 0.1), CFrame.new(-0.25, -0.75, 0.1), ORANGE)
	addPart(bird, "LegR", Vector3.new(0.1, 0.5, 0.1), CFrame.new(0.25, -0.75, 0.1), ORANGE)
	-- Wings: grey with black tips; `wing` is the side (-1 left, 1 right).
	for _, side in { -1, 1 } do
		addPart(bird, "Wing", Vector3.new(1.8, 0.1, 0.9), CFrame.new(side * 0.9, 0, 0), GREY, nil, side)
		addPart(
			bird,
			"WingTip",
			Vector3.new(0.6, 0.1, 0.7),
			CFrame.new(side * 2.1, 0, 0.05),
			BLACK,
			nil,
			side
		)
	end
	local root = bird.parts[1].part
	model.PrimaryPart = root
	model:SetAttribute("Seagull", true)
	model.Parent = workspace
	return bird
end

-- Puts every part where it belongs: `flap` is the wing angle (radians),
-- `folded` tucks the wings along the body (sitting).
local function place(bird: Bird, cframe: CFrame, flap: number, folded: boolean)
	bird.cframe = cframe
	local s = Config.scale
	for _, item in bird.parts do
		local side = item.wing
		if side then
			local shoulder = CFrame.new(side * 0.55 * s, 0.25 * s, 0)
			local out = CFrame.new(item.offset.Position - Vector3.new(side * 0.55 * s, 0, 0))
			local turn = if folded
				then CFrame.Angles(0, -side * 1.45, 0) * CFrame.Angles(0, 0, -side * 0.12)
				else CFrame.Angles(0, 0, side * flap)
			item.part.CFrame = cframe * shoulder * turn * out
		else
			item.part.CFrame = cframe * item.offset
		end
	end
	local hat = bird.hat
	local handle = hat and hat:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.CFrame = cframe * CFrame.new(0, -1.5 * s, -0.2 * s)
	end
end

-- Flies along an arc to `target()` (re-read every step, so it can follow a
-- running player). `lift` raises the middle of the arc.
local function fly(bird: Bird, target: () -> Vector3, seconds: number, lift: number)
	local from = bird.cframe.Position
	local started = os.clock()
	while true do
		local t = math.min(1, (os.clock() - started) / math.max(0.05, seconds))
		local to = target()
		local eased = t * t * (3 - 2 * t)
		local p = from:Lerp(to, eased) + Vector3.new(0, math.sin(t * math.pi) * lift, 0)
		local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		local look = if flat.Magnitude > 0.1 then flat.Unit else bird.cframe.LookVector
		place(bird, CFrame.lookAt(p, p + look), math.sin(os.clock() * 18) * 0.7, false)
		if t >= 1 then
			return
		end
		task.wait(1 / 20)
	end
end

------------------------------------------------------------------ hats

local function hatOf(character: Model): Accessory?
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			-- (Rigid hats only: layered clothing stays where it is.)
			if
				handle
				and handle:FindFirstChild("HatAttachment")
				and not handle:FindFirstChildOfClass("WrapLayer")
			then
				return child
			end
		end
	end
	return nil
end

-- Takes the hat off (it rides under the seagull from now on).
local function grab(bird: Bird, hat: Accessory)
	local handle = hat:FindFirstChild("Handle") :: BasePart
	for _, d in handle:GetChildren() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	handle.Anchored = true
	handle.CanCollide = false
	hat.Parent = bird.model
	bird.hat = hat
end

-- Puts the hat back on (like Humanoid:AddAccessory does).
local function wear(character: Model, hat: Accessory): boolean
	local handle = hat:FindFirstChild("Handle")
	local own = handle and handle:FindFirstChild("HatAttachment")
	local head = character:FindFirstChild("Head")
	local target = head and head:FindFirstChild("HatAttachment")
	if not (handle and handle:IsA("BasePart") and own and own:IsA("Attachment")) then
		return false
	end
	if not (head and head:IsA("BasePart") and target and target:IsA("Attachment")) then
		return false
	end
	handle.Anchored = false
	hat.Parent = character
	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = handle
	weld.Part1 = head
	weld.C0 = own.CFrame
	weld.C1 = target.CFrame
	weld.Parent = handle
	handle.CFrame = head.CFrame * target.CFrame * own.CFrame:Inverse()
	return true
end

------------------------------------------------------------------ the theft

local function headOf(player: Player): BasePart?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function palmFor(position: Vector3): Vector3?
	local options = {}
	for _, crown in palms do
		local d = flat(crown, position)
		if d >= Config.palmRange.min and d <= Config.palmRange.max then
			table.insert(options, crown)
		end
	end
	return if #options > 0 then options[rng:NextInteger(1, #options)] else nil
end

local function flyAway(bird: Bird)
	local start = bird.cframe.Position
	local away = start + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * 120
	fly(bird, function()
		return away + Vector3.new(0, 60, 0)
	end, timing.away, 10)
	bird.model:Destroy()
end

-- The whole caper for one player (yields until it's over).
local function caper(player: Player, palm: Vector3)
	local head = headOf(player) :: BasePart
	local character = player.Character :: Model
	local hat = hatOf(character) :: Accessory
	local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(1, 0, 0)
	end
	local bird = newBird(head.Position + dir.Unit * 70 + Vector3.new(0, 40, 0))
	place(bird, bird.cframe, 0, false)

	-- Dive in, following the head.
	local lastHead = head.Position
	fly(bird, function()
		if head.Parent then
			lastHead = head.Position
		end
		return lastHead + Vector3.new(0, 1.8, 0)
	end, timing.swoop, -6)
	if player.Parent == nil or player.Character ~= character or hat.Parent ~= character then
		flyAway(bird)
		return
	end
	grab(bird, hat)
	local info = { model = bird.model, palm = palm }
	Net.fireAll("Seagull", "Steal", player.UserId, info)

	-- Off to the palm, then sit there.
	local perch = palm + Vector3.new(0, 1.2 * Config.scale, 0)
	fly(bird, function()
		return perch
	end, timing.toPalm, 14)
	local look = Vector3.new(lastHead.X - perch.X, 0, lastHead.Z - perch.Z)
	local facing = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	place(bird, CFrame.lookAt(perch, perch + facing), 0, true)
	Net.fireAll("Seagull", "Perch", player.UserId, info)

	local sitting = os.clock()
	local found = false
	while player.Parent and player.Character == character do
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and flat(root.Position, palm) <= Config.retrieveRadius then
			found = true
			break
		end
		if os.clock() - sitting >= timing.giveUpAfter then
			break
		end
		-- A little head bob now and then.
		local bob = if math.floor((os.clock() - sitting) * 2) % 6 == 0 then 0.12 else 0
		place(bird, CFrame.lookAt(perch, perch + facing) * CFrame.Angles(-bob, 0, 0), 0, true)
		task.wait(0.25)
	end

	if player.Parent == nil or player.Character ~= character then
		-- Left or respawned (a new character has its own hat): just leave.
		hat:Destroy()
		bird.hat = nil
		flyAway(bird)
		return
	end
	-- Bring it back.
	fly(bird, function()
		local h = headOf(player)
		return (if h then h.Position else lastHead) + Vector3.new(0, 1.8, 0)
	end, timing.swoop, 6)
	bird.hat = nil
	if not wear(character, hat) then
		hat:Destroy()
	end
	if found then
		local data = PlayerData.get(player)
		local cash = 0
		if data then
			cash = Bonuses.rewardCash(Config.reward, data)
			EconomyService.addCash(player, data, cash, "Gameplay", "Seagull")
		end
		Net.fireAll("Seagull", "Return", player.UserId, { model = bird.model, cash = cash })
	else
		Net.fireAll("Seagull", "GiveUp", player.UserId, { model = bird.model })
	end
	flyAway(bird)
end

------------------------------------------------------------------ choosing

local function eligible(player: Player, now: number, forced: boolean): Vector3?
	local data = PlayerData.get(player)
	local character = player.Character
	local head = headOf(player)
	if not (data and character and head and hatOf(character)) then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	if not forced then
		if not (data.onboarding and data.onboarding.guideDone) then
			return nil
		end
		if now - (joinedAt[player] or now) < Config.firstAfter then
			return nil
		end
		local last = lastRobbed[player.UserId]
		if last and now - last < Config.cooldown then
			return nil
		end
	end
	return palmFor(head.Position)
end

-- Sends a seagull after this player now (admins; tests). False when it
-- can't (another seagull is out, no hat, no palm around).
function SeagullService.steal(player: Player): boolean
	if busy or CurrentWorld.isFrost() then
		return false
	end
	local palm = eligible(player, os.clock(), true)
	if not palm then
		return false
	end
	busy = true
	lastRobbed[player.UserId] = os.clock()
	task.spawn(function()
		local ok, err = pcall(caper, player, palm :: Vector3)
		if not ok then
			warn("[Seagull] " .. tostring(err))
		end
		busy = false
	end)
	return true
end

function SeagullService.isBusy(): boolean
	return busy
end

function SeagullService.setScheduled(on: boolean)
	scheduled = on
end

-- Faster flights or a shorter wait (tests); nil fields keep the config.
function SeagullService.setTiming(overrides: { [string]: number }?)
	local o = overrides or {}
	timing.swoop = o.swoop or Config.swoop
	timing.toPalm = o.toPalm or Config.toPalm
	timing.away = o.away or Config.away
	timing.giveUpAfter = o.giveUpAfter or Config.giveUpAfter
end

function SeagullService.start()
	if CurrentWorld.isFrost() then
		return
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == "Palm" then
			local sum, n = Vector3.zero, 0
			for _, part in d:GetChildren() do
				if part:IsA("BasePart") and part.Name == "Coconut" then
					sum += part.Position
					n += 1
				end
			end
			if n > 0 then
				table.insert(palms, sum / n + Vector3.new(0, 0.6, 0))
			end
		end
	end
	local function added(player: Player)
		joinedAt[player] = os.clock()
	end
	Players.PlayerAdded:Connect(added)
	for _, player in Players:GetPlayers() do
		added(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		joinedAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.checkEvery)
			if scheduled and not busy then
				local now = os.clock()
				for _, player in Players:GetPlayers() do
					if rng:NextNumber() < Config.chance and eligible(player, now, false) then
						SeagullService.steal(player)
						break
					end
				end
			end
		end
	end)
end

-- A seagull standing (or flying, wings out) at `at` (3D previews).
function SeagullService.showcase(at: Vector3, flying: boolean): Model
	local bird = newBird(at)
	place(bird, CFrame.new(at) * CFrame.Angles(0, math.rad(200), 0), if flying then 0.35 else 0, not flying)
	return bird.model
end

-- Palm tops a seagull can sit on (tests).
function SeagullService.palmCount(): number
	return #palms
end

return SeagullService
