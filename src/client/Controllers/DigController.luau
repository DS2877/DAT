--!strict
-- Digging on the client: finds the nearest dig spot, shows the big DIG
-- button, turns taps / clicks into paced hit intents, and plays the instant
-- local feedback (swing, dirt, thunk, camera nudge, growing hole).
-- The server validates every hit and decides the loot.
--
-- Every press digs once (a press during the swing is remembered and lands
-- right after it, so fast tapping keeps full speed). With the Auto Dig pass,
-- holding DIG keeps digging.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local DigAnimation = require(ReplicatedStorage.Shared.Config.DigAnimation)
local DigConfig = require(ReplicatedStorage.Shared.Config.Dig)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Effects = require(script.Parent.Parent.Effects)
local ImpactFx = require(script.Parent.Parent.ImpactFx)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)
local RevealController = require(script.Parent.RevealController)
local ShopController = require(script.Parent.ShopController)

local C = Ui.Colors
local player = Players.LocalPlayer

local DigController = {}

-- Each area's ground has its own dig sound.
local DIG_SOUND = {
	Beach = "DigHitSand",
	Ruins = "DigHitSand",
	Jungle = "DigHitDirt",
	Volcano = "DigHitRock",
}

local spotsFolder: Folder
-- Client-only spots (the player's daily Golden X), created by RewardsController.
local localSpots: Folder
local digHit: RemoteEvent
local target: Model? = nil
local holding = false
local holdInput: InputObject? = nil -- the touch/click that is holding the DIG button
local pressedAt = 0
local queued = false -- a press that came during the swing; lands when it ends
local offerChecked = false -- this hold already considered the Auto Dig offer
local nextHitAt = 0
local highlight: Highlight
local button: TextButton
-- Perfect hits (Config/Dig.perfect): a ring shrinks onto the DIG button;
-- a tap while it's on the button is PERFECT.
local ring: Frame
local ringStroke: UIStroke
local cycleStart = 0
local lastPerfectTap = -math.huge
local pendingPerfect = false -- the press that queued the next hit was perfect

-- Local-only hole visuals per spot model: { part, hits }.
local holes: { [Model]: { part: Part, hits: number, required: number, spotId: number } } = {}

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function spotPosition(spot: Model): Vector3
	local mound = spot.PrimaryPart
	return if mound then mound.Position else spot:GetPivot().Position
end

local function spotId(spot: Model): number?
	return spot:GetAttribute("SpotId") :: number?
end

local function isUnlocked(spot: Model): boolean
	local data = ClientState.data
	local areaId = spot:GetAttribute("AreaId") :: string?
	return data ~= nil and areaId ~= nil and Progression.isAreaUnlocked(areaId, data.shovelLevel)
end

---------------------------------------------------------------------------
-- Hole visuals
---------------------------------------------------------------------------

local function clearHole(spot: Model)
	local hole = holes[spot]
	if hole then
		hole.part:Destroy()
		holes[spot] = nil
	end
end

local function setHoleProgress(spot: Model, hits: number, required: number)
	local id = spotId(spot)
	if not id then
		return
	end
	local hole = holes[spot]
	if hole and hole.spotId ~= id then
		clearHole(spot)
		hole = nil
	end
	if not hole then
		local part = Instance.new("Part")
		part.Name = "Hole"
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Color = Color3.fromRGB(60, 38, 20)
		part.Material = Enum.Material.Ground
		part.Parent = Effects.folder()
		hole = { part = part, hits = 0, required = required, spotId = id }
		holes[spot] = hole
	end
	local h = hole :: { part: Part, hits: number, required: number, spotId: number }
	h.hits = hits
	h.required = required
	local progress = math.clamp(hits / math.max(required, 1), 0, 1)
	local diameter = 1.4 + 3.4 * progress
	h.part.Size = Vector3.new(0.3, diameter, diameter)
	h.part.CFrame = CFrame.new(spotPosition(spot) + Vector3.new(0, 0.62, 0))
		* CFrame.Angles(0, 0, math.rad(90))
end

---------------------------------------------------------------------------
-- Targeting
---------------------------------------------------------------------------

local function findNearest(): Model?
	local root = rootPart()
	if not root then
		return nil
	end
	local best, bestDistance = nil, math.huge
	local pos = root.Position
	local all = spotsFolder:GetChildren()
	for _, spot in localSpots:GetChildren() do
		table.insert(all, spot)
	end
	for _, spot in all do
		if spot:IsA("Model") and spot.PrimaryPart then
			local p = spotPosition(spot)
			local d = Zones.flatDistance(pos.X, pos.Z, p.X, p.Z)
			-- Big spots (the Mega Dig) can be dug from further away; they
			-- count as nearer so their edge works like a normal spot.
			local range = (spot:GetAttribute("Range") :: number?) or DigConfig.promptRange
			local score = d - (range - DigConfig.promptRange)
			if d < range and score < bestDistance and math.abs(pos.Y - p.Y) < 10 and isUnlocked(spot) then
				best, bestDistance = spot, score
			end
		end
	end
	return best
end

local function refreshButton()
	local visible = target ~= nil
	button.Visible = visible
	if not visible then
		return
	end
	if ClientState.isBagFull() and not (target :: Model):GetAttribute("Mega") then
		button.BackgroundColor3 = C.Grey
		button.Text = "FULL"
	else
		button.BackgroundColor3 = C.Gold
		button.Text = "DIG!"
	end
end

---------------------------------------------------------------------------
-- Hitting
---------------------------------------------------------------------------

local function tryHit(perfect: boolean?)
	local spot = target
	local id = spot and spotId(spot)
	local character = player.Character
	if not spot or not id or not character then
		return
	end
	local now = os.clock()
	if now < nextHitAt then
		return
	end
	local mega = spot:GetAttribute("Mega") == true
	if ClientState.isBagFull() and not mega then
		holding = false
		queued = false
		HudController.flashBagFull()
		return
	end
	-- The VIP dig spot: say so (and mention VIP) instead of digging.
	if spot:GetAttribute("Vip") and not ClientState.hasPass("VIP") then
		holding = false
		queued = false
		nextHitAt = now + 1
		HudController.toast("👑 VIP dig spot - VIPs only", Ui.Colors.Gold)
		ShopController.offer("VIP", "dig", true)
		return
	end
	local shovel = ClientState.shovel()
	local interval = ClientState.hitInterval()
	nextHitAt = now + interval

	-- Instant local feedback; the server confirms progress in DigResult.
	local position = spotPosition(spot)
	-- The dig animation: a full swing (never shorter than minDuration, so a
	-- fast shovel lands several hits per swing). Dirt, shake and sound land
	-- when the shovel hits the ground.
	local swing = math.clamp(interval * 0.95, DigAnimation.minDuration, DigAnimation.maxDuration)
	if Effects.swing(character, swing) then
		local hitSound = DIG_SOUND[spot:GetAttribute("AreaId") :: string? or "Beach"] or "DigHitSand"
		local impact = shovel.impact
		task.delay(swing * DigAnimation.impact, function()
			Effects.dirtBurst(position, 6)
			ImpactFx.play(impact, position)
			Effects.cameraNudge()
			Sound.play(hitSound)
		end)
	end
	local hole = holes[spot]
	local current = hole and hole.spotId == id and hole
	local areaId = spot:GetAttribute("AreaId") :: string?
	local required = if current
		then current.required
		else shovel.hits + (DigConfig.areaExtraHits[areaId or "Beach"] or 0)
	local predicted = (if current then current.hits else 0)
		+ 1
		+ (if perfect and not mega then DigConfig.perfect.bonusHits else 0)
	if not mega then
		setHoleProgress(spot, math.min(predicted, required), required)
	end

	-- Face the spot so the swing lands on it.
	local root = rootPart()
	if root then
		local look = Vector3.new(position.X, root.Position.Y, position.Z)
		if (look - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, look)
		end
	end

	digHit:FireServer(id, perfect == true)
end

local function findSpotById(id: number): Model?
	for _, spot in localSpots:GetChildren() do
		if spot:IsA("Model") and spotId(spot) == id then
			return spot
		end
	end
	for _, spot in spotsFolder:GetChildren() do
		if spot:IsA("Model") and spotId(spot) == id then
			return spot
		end
	end
	return nil
end

local function onDigResult(result: { [string]: any })
	local spot = findSpotById(result.spotId)
	if result.rejected then
		local reason = result.rejected
		if reason == "BagFull" then
			holding = false
			HudController.flashBagFull()
		elseif reason == "TooFast" then
			-- Server saw hits too close together; undo the predicted one.
			if spot and holes[spot] then
				local hole = holes[spot]
				setHoleProgress(spot, math.max(0, hole.hits - 1), hole.required)
			end
		elseif reason == "VipOnly" then
			holding = false
			HudController.toast("👑 VIP dig spot - VIPs only", Ui.Colors.Gold)
		elseif reason == "Taken" then
			holding = false
			HudController.toast("Someone is Deep Digging here!", Ui.Colors.Orange)
		elseif spot then
			clearHole(spot)
		end
		return
	end

	if result.perfect then
		DigController.showPerfect(spot)
	end
	if result.deepDig then
		-- The ground rumbles: this spot needs extra hits, and the reward is big.
		Sound.play("DeepDig")
		HudController.bigText("SOMETHING IS BURIED DEEP...", Ui.Colors.Orange, 2.6)
		local data = ClientState.data
		if data and (data.instantDeepDigs or 0) > 0 then
			HudController.toast("Using your saved Instant Deep Dig!", Ui.Colors.Gold, 2.6)
		else
			HudController.toast("Keep digging!", Ui.Colors.Gold, 2.6)
			ShopController.offer("InstantDeepDig", "dig")
		end
		for i = 0, 4 do
			task.delay(i * 0.18, function()
				Effects.cameraNudge(0.3)
			end)
		end
		if spot then
			Effects.dirtBurst(spotPosition(spot), 20)
		end
	end
	if spot and not result.done then
		setHoleProgress(spot, result.hits, result.required)
		return
	end
	if result.done then
		local position = if spot
			then spotPosition(spot)
			else (rootPart() and (rootPart() :: BasePart).Position or Vector3.zero)
		if spot then
			clearHole(spot)
		end
		Effects.dirtBurst(position, 12)
		Sound.play("DigBurst")
		RevealController.reveal(position, result.find)
		HudController.showStreak(result.find.streak, result.find.streakBonus)
	end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

local DIG_KEYS = {
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.ButtonX] = true,
	[Enum.KeyCode.ButtonR2] = true,
}

-- Where the ring is in its cycle (0 = just appeared, 1 = on the button).
local function ringPhase(): number
	return ((os.clock() - cycleStart) % DigConfig.perfect.cycle) / DigConfig.perfect.cycle
end

-- Is this tap PERFECT? (The ring is on the button; one per cycle.)
local function judgeTap(): boolean
	local cfg = DigConfig.perfect
	local now = os.clock()
	local phase = ringPhase()
	local onButton = phase >= 1 - cfg.window / cfg.cycle or phase <= 0.05
	if onButton and now - lastPerfectTap >= cfg.cycle * 0.8 then
		lastPerfectTap = now
		return true
	end
	return false
end

local function press()
	holding = true
	pressedAt = os.clock()
	offerChecked = false
	local perfect = target ~= nil and not (target :: Model):GetAttribute("Mega") and judgeTap()
	if os.clock() < nextHitAt then
		queued = true
		pendingPerfect = pendingPerfect or perfect
	else
		tryHit(perfect)
	end
end

local function release()
	holding = false
	holdInput = nil
end

local function buildButton()
	button = Ui.new("TextButton", {
		Name = "DigButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -190),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = C.Gold,
		Font = Ui.TitleFont,
		Text = "DIG!",
		TextColor3 = C.White,
		TextScaled = true,
		AutoButtonColor = true,
		Visible = false,
		Parent = HudController.root(),
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.stroke(5),
		Ui.textStroke(3),
		Ui.shade(),
		Ui.new("UIPadding", {
			PaddingTop = UDim.new(0, 34),
			PaddingBottom = UDim.new(0, 34),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
		}),
	})
	Ui.label({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 40),
		Size = UDim2.fromOffset(170, 28),
		Text = "Click or [E]",
		Visible = not UserInputService.TouchEnabled,
		Parent = button,
	})

	-- The perfect-hit ring, centered on the button (a sibling, so the
	-- button's padding doesn't move it).
	ring = Ui.new("Frame", {
		Name = "PerfectRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -28 - 75, 1, -190 - 75),
		Size = UDim2.fromOffset(150, 150),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = HudController.root(),
	}, {
		Ui.corner(UDim.new(1, 0)),
	})
	ringStroke = Ui.new("UIStroke", {
		Thickness = 6,
		Color = Color3.new(1, 1, 1),
		Transparency = 0.2,
		Parent = ring,
	})

	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			holdInput = input
			press()
		end
	end)
	-- Gamepad selection / accessibility activation.
	button.Activated:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			press()
			release()
		end
	end)
end

local function bindInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if DIG_KEYS[input.KeyCode] or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if target then
				press()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		-- Only the finger holding DIG stops digging (not the thumbstick finger).
		if
			input == holdInput
			or DIG_KEYS[input.KeyCode]
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			release()
		end
	end)
end

---------------------------------------------------------------------------

function DigController.init()
	spotsFolder = workspace:WaitForChild("DigSpots") :: Folder
	localSpots = Instance.new("Folder")
	localSpots.Name = "LocalSpots"
	localSpots.Parent = workspace
	digHit = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DigHit") :: RemoteEvent
	local digResult = ReplicatedStorage.Remotes:WaitForChild("DigResult") :: RemoteEvent
	digResult.OnClientEvent:Connect(onDigResult)

	highlight = Instance.new("Highlight")
	highlight.Name = "DigTarget"
	highlight.FillColor = C.Gold
	highlight.FillTransparency = 0.65
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = Effects.folder()

	buildButton()
	bindInput()

	for _, folder in { spotsFolder, localSpots } do
		folder.ChildRemoved:Connect(function(child)
			if child:IsA("Model") then
				clearHole(child)
			end
		end)
	end
	ClientState.Changed:Connect(refreshButton)

	-- Retarget ~10x per second; hits are paced every frame.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			accumulator = 0
			local nearest = findNearest()
			if nearest ~= target then
				if nearest and not target then
					cycleStart = os.clock() -- a fresh ring for a new spot
				end
				target = nearest
				highlight.Adornee = nearest
				highlight.Enabled = nearest ~= nil
				queued = false
				refreshButton()
			end
		end
		-- The ring: shrinks onto the button, gold while a tap is PERFECT.
		local showRing = target ~= nil
			and button.Visible
			and button.Text == "DIG!"
			and not (target :: Model):GetAttribute("Mega")
			and not (holding and ClientState.perkOn("AutoDig"))
		ring.Visible = showRing
		if showRing then
			local cfg = DigConfig.perfect
			local phase = ringPhase()
			local scale = 1 + (1 - phase) * 0.8
			ring.Size = UDim2.fromOffset(150 * scale, 150 * scale)
			local perfectNow = phase >= 1 - cfg.window / cfg.cycle or phase <= 0.05
			ringStroke.Color = if perfectNow then C.Gold else Color3.new(1, 1, 1)
			ringStroke.Thickness = if perfectNow then 9 else 5
			ringStroke.Transparency = if perfectNow then 0 else 0.15 + phase * 0.25
		end
		if not target then
			return
		end
		local now = os.clock()
		if queued and now >= nextHitAt then
			queued = false
			local perfect = pendingPerfect
			pendingPerfect = false
			tryHit(perfect)
		elseif holding and ClientState.perkOn("AutoDig") then
			tryHit()
		elseif holding and not offerChecked and now - pressedAt >= Monetization.Offers.autoDigHoldSeconds then
			-- Holding without the pass digs once; mention Auto Dig (rate-limited).
			offerChecked = true
			if not ClientState.hasPass("AutoDig") then
				ShopController.offer("AutoDig", "dig")
			end
		end
	end)
end

-- PERFECT! over the DIG button, a golden burst at the spot and a ding.
function DigController.showPerfect(spot: Model?)
	Sound.play("Streak", 1, 1.25)
	local label = Ui.label({
		Name = "PerfectText",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(1, -103, 1, -350),
		Size = UDim2.fromOffset(220, 46),
		Font = Ui.TitleFont,
		Text = "PERFECT!",
		TextColor3 = C.Gold,
		Rotation = math.random(-8, 8),
		ZIndex = 5,
		Parent = HudController.root(),
	})
	Ui.pop(label, 0.25)
	Ui.tween(label, 0.7, { Position = UDim2.new(1, -103, 1, -390), TextTransparency = 1 })
	task.delay(0.75, function()
		label:Destroy()
	end)
	if spot then
		Effects.sparkles(spotPosition(spot) + Vector3.new(0, 1.5, 0), C.Gold, 18)
	end
end

-- The on-screen DIG button (for the tutorial's pointer).
function DigController.button(): TextButton?
	return button
end

-- True while a dig spot is in reach (the DIG button is showing).
function DigController.hasTarget(): boolean
	return target ~= nil
end

return DigController
