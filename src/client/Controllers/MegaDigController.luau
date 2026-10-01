--!strict
-- The Mega Dig on this client:
--   * the clock tower's four faces: a ticking red hand and the countdown
--     ("DIG NOW!" with the progress while a site is open), with clock ticks
--     you can hear in the last 10 seconds
--   * the HUD line under the rush timer
--   * the Mega Dig panel at the top of the screen while a site is open: a
--     big progress bar with milestones, time left, how many are digging,
--     your hits and your chance in the draw
--   * a sign over the site for finding it from afar
--   * dirt flying with every hit, the ground shaking at 25/50/75%, and
--     fireworks when the chest comes out
--   * the winner draw: a slot-machine reel of the helpers' names that
--     slows down and stops on the winner, then the winner's treasure reveal

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MegaDig = require(ReplicatedStorage.Shared.Config.MegaDig)
local MegaDigClock = require(ReplicatedStorage.Shared.Logic.MegaDigClock)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local Effects = require(script.Parent.Parent.Effects)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)
local PartyController = require(script.Parent.PartyController)
local RevealController = require(script.Parent.RevealController)

local C = Ui.Colors
local player = Players.LocalPlayer

local MegaDigController = {}

local faces: { SurfaceGui } = {}
local siteSign: BillboardGui? = nil
local siteFill: Frame? = nil
local siteText: TextLabel? = nil
local lastTickSecond = -1

local function attr(name: string): any
	return workspace:GetAttribute(name)
end

local function findSite(): Model?
	local spots = workspace:FindFirstChild("DigSpots")
	if not spots then
		return nil
	end
	for _, spot in spots:GetChildren() do
		if spot:IsA("Model") and spot:GetAttribute("Mega") then
			return spot
		end
	end
	return nil
end

-- Where the open site is (its center on the ground), and its soil color.
local function siteCenter(): (Vector3?, Color3)
	local site = findSite()
	local center = site and site:FindFirstChild("Center") :: BasePart?
	local soil = site and site:GetAttribute("Soil")
	return if center then center.Position else nil,
		if type(soil) == "string" then Color3.fromHex(soil) else Color3.fromRGB(150, 110, 70)
end

local function distanceTo(position: Vector3): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return math.huge
	end
	local offset = root.Position - position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

---------------------------------------------------------------------------
-- The Mega Dig panel (top of the screen, for everyone while a site is open)
---------------------------------------------------------------------------

local panel: Frame
local fill: Frame
local percentLabel: TextLabel
local timerLabel: TextLabel
local infoLabel: TextLabel
local flashUntil = 0

local function buildPanel()
	panel = Ui.new("Frame", {
		Name = "MegaDigPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(480, 92),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = HudController.root(),
	}, {
		Ui.corner(UDim.new(0, 20)),
		Ui.stroke(4),
		Ui.gradient(Color3.fromRGB(255, 249, 232), Color3.fromRGB(255, 226, 170)),
	})
	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -150, 0, 30),
		Font = Ui.TitleFont,
		Text = "⛏️ MEGA DIG",
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local pill = Ui.new("Frame", {
		Name = "TimerPill",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 7),
		Size = UDim2.fromOffset(112, 28),
		BackgroundColor3 = C.Dark,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	timerLabel = Ui.label({
		Name = "Timer",
		Position = UDim2.fromOffset(6, 3),
		Size = UDim2.new(1, -12, 1, -6),
		Font = Ui.TitleFont,
		Text = "",
		Parent = pill,
	})
	local bar = Ui.new("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(14, 40),
		Size = UDim2.new(1, -28, 0, 26),
		BackgroundColor3 = Color3.fromRGB(60, 40, 22),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(3) })
	fill = Ui.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bar,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.gradient(Color3.fromRGB(255, 226, 110), Color3.fromRGB(255, 160, 40)),
	})
	-- Milestones at 25 / 50 / 75%.
	for _, at in { 0.25, 0.5, 0.75 } do
		Ui.new("Frame", {
			Name = "Notch",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(at, 0),
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.35,
			ZIndex = 3,
			Parent = bar,
		})
	end
	percentLabel = Ui.label({
		Name = "Percent",
		Size = UDim2.fromScale(1, 1),
		Font = Ui.TitleFont,
		Text = "0%",
		ZIndex = 4,
		Parent = bar,
	})
	infoLabel = Ui.plainLabel({
		Name = "Info",
		Position = UDim2.fromOffset(14, 68),
		Size = UDim2.new(1, -28, 0, 20),
		Text = "",
		TextColor3 = C.Ink,
		Parent = panel,
	})
end

local function updatePanel(active: boolean, progress: number, left: number)
	local drawing = attr("MegaDigDrawing") == true
	panel.Visible = active and not drawing
	if not panel.Visible then
		return
	end
	fill.Size = UDim2.fromScale(math.max(progress, 0.04), 1)
	percentLabel.Text = string.format("%d%%", math.floor(progress * 100))
	timerLabel.Text = "⏱ " .. MegaDigClock.format(left)
	timerLabel.TextColor3 = if left <= 30 then Color3.fromRGB(255, 110, 110) else C.White
	if os.clock() < flashUntil then
		return -- a milestone message is showing
	end
	local center = siteCenter()
	local distance = if center then distanceTo(center) else math.huge
	local diggers = (attr("MegaDigDiggers") :: number?) or 0
	local total = (attr("MegaDigTotal") :: number?) or 0
	local mine = (player:GetAttribute("MegaDigHits") :: number?) or 0
	if distance > MegaDig.digRange + 25 then
		infoLabel.Text = string.format(
			"📍 %d studs away · %d digging · follow the golden beam!",
			math.floor(distance),
			diggers
		)
	elseif mine == 0 then
		infoLabel.Text = string.format("👥 %d digging · tap DIG to join the draw!", diggers)
	else
		local chance = if total > 0 then mine / total else 0
		infoLabel.Text = string.format(
			"👥 %d digging · your hits: %d · win chance %d%%%s",
			diggers,
			mine,
			math.floor(chance * 100 + 0.5),
			if mine < MegaDig.minHitsToEnter then " (dig " .. MegaDig.minHitsToEnter .. " to enter)" else ""
		)
	end
end

-- The sign over the site, for finding it from afar (hidden up close: the
-- panel shows everything then).
local function updateSiteSign(active: boolean, progress: number)
	local site = if active then findSite() else nil
	local center = site and site:FindFirstChild("Center") :: BasePart?
	if not center then
		if siteSign then
			siteSign:Destroy()
			siteSign, siteFill, siteText = nil, nil, nil
		end
		return
	end
	if not siteSign or siteSign.Adornee ~= center then
		if siteSign then
			siteSign:Destroy()
		end
		local gui = Ui.new("BillboardGui", {
			Name = "MegaDigSign",
			Adornee = center,
			Size = UDim2.fromOffset(230, 66),
			StudsOffsetWorldSpace = Vector3.new(0, 22, 0),
			AlwaysOnTop = true,
			MaxDistance = 1500,
			LightInfluence = 0,
			Parent = player:WaitForChild("PlayerGui"),
		})
		Ui.label({
			Size = UDim2.new(1, 0, 0, 30),
			Font = Ui.TitleFont,
			Text = "⛏️ MEGA DIG",
			TextColor3 = C.Gold,
			Parent = gui,
		})
		local bar = Ui.new("Frame", {
			Position = UDim2.fromOffset(12, 34),
			Size = UDim2.new(1, -24, 0, 20),
			BackgroundColor3 = Color3.fromRGB(60, 40, 22),
			Parent = gui,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(3) })
		siteFill = Ui.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = C.Gold,
			Parent = bar,
		}, { Ui.corner(UDim.new(1, 0)) })
		siteText = Ui.label({
			Size = UDim2.fromScale(1, 1),
			Font = Ui.TitleFont,
			Text = "",
			ZIndex = 2,
			Parent = bar,
		})
		siteSign = gui
	end
	local sign = siteSign :: BillboardGui
	sign.Enabled = distanceTo(center.Position) > MegaDig.digRange + 25
	if siteFill then
		siteFill.Size = UDim2.fromScale(math.max(progress, 0.04), 1)
	end
	if siteText then
		siteText.Text = string.format("%d%%", math.floor(progress * 100))
	end
end

---------------------------------------------------------------------------
-- Feeling it: dirt flies with every hit, milestones shake the ground
---------------------------------------------------------------------------

local MILESTONES = {
	{ at = 0.25, text = "⛏️ 25%! The ground is giving way!" },
	{ at = 0.5, text = "💎 50%! The chest is coming up!" },
	{ at = 0.75, text = "🔥 75%! Almost there, keep digging!" },
}
local lastProgress = 0
local lastPuff = 0

local function onProgress()
	local progress = (attr("MegaDigProgress") :: number?) or 0
	local before = lastProgress
	lastProgress = progress
	if progress <= before then
		return
	end
	local center, soil = siteCenter()
	if not center then
		return
	end
	local near = distanceTo(center) < 90
	-- Dirt flies off the mound (for everyone's hits, a few times a second).
	if near and os.clock() - lastPuff > 0.12 then
		lastPuff = os.clock()
		local a = math.random() * math.pi * 2
		local d = MegaDig.radius * (0.3 + math.random() * 0.5)
		Effects.dirtBurst(
			center + Vector3.new(math.cos(a) * d, 3 + (1 - progress) * 4, math.sin(a) * d),
			5,
			soil
		)
	end
	for _, m in MILESTONES do
		if before < m.at and progress >= m.at then
			flashUntil = os.clock() + 2.5
			infoLabel.Text = m.text
			Ui.pop(panel, 0.12)
			if near then
				Effects.cameraNudge(1.4)
				Effects.dirtBurst(center + Vector3.new(0, 4, 0), 40, soil)
				Sound.play("DeepDig", 0.7)
			end
			Sound.play("Streak", 0.9, 1 + m.at * 0.4)
		end
	end
end

local function update()
	local now = workspace:GetServerTimeNow()
	local active = attr("MegaDigActive") == true
	local progress = (attr("MegaDigProgress") :: number?) or 0
	local ends = (attr("MegaDigEnds") :: number?) or now
	local nextStart = (attr("MegaDigNext") :: number?) or MegaDigClock.nextStart(now)
	local untilNext = nextStart - now

	-- Clock faces: the hand ticks once a second.
	local second = math.floor(now)
	local timeText = if active
		then string.format("%d%%", math.floor(progress * 100))
		else MegaDigClock.format(untilNext)
	for _, face in faces do
		local dial = face:FindFirstChild("Dial")
		if dial then
			local hand = dial:FindFirstChild("Hand") :: Frame?
			if hand then
				hand.Rotation = (second % 60) * 6
			end
			local time = dial:FindFirstChild("Time") :: TextLabel?
			if time then
				time.Text = timeText
				time.TextColor3 = if active then Color3.fromRGB(220, 40, 40) else Color3.fromRGB(45, 28, 12)
			end
			local title = dial:FindFirstChild("Title") :: TextLabel?
			if title then
				title.Text = if active then "DIG NOW!" else "MEGA DIG"
			end
		end
	end
	-- Tick-tock for the last 10 seconds.
	if not active and untilNext <= 10.5 and untilNext > 0 and second ~= lastTickSecond then
		lastTickSecond = second
		Sound.play("UiClick", 1.4, if second % 2 == 0 then 0.7 else 0.85)
	end

	if active then
		HudController.setMegaText("⛏️ MEGA DIG NOW!", true)
	else
		HudController.setMegaText("Mega Dig in " .. MegaDigClock.format(untilNext), false)
	end
	updateSiteSign(active, progress)
	updatePanel(active, progress, ends - now)
end

---------------------------------------------------------------------------
-- The winner draw
---------------------------------------------------------------------------

local function showDraw(info: { [string]: any })
	-- Dug out! The chest bursts free: fireworks and a ground shake nearby.
	local position = info.position
	if typeof(position) == "Vector3" and distanceTo(position) < 140 then
		PartyController.fireworks(position, 6)
		Effects.cameraNudge(2)
		Effects.dirtBurst(position + Vector3.new(0, 4, 0), 60)
		Sound.play("DeepDig", 0.8)
	end
	local root = HudController.root()
	local entries = info.entries or {}
	if #entries == 0 then
		return
	end
	local frame = Ui.new("Frame", {
		Name = "MegaDraw",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(640, 170),
		BackgroundColor3 = C.Cream,
		ZIndex = 30,
		Parent = root,
	}, { Ui.corner(UDim.new(0, 22)), Ui.stroke(5) })
	Ui.plainLabel({
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 6),
		Font = Ui.TitleFont,
		Text = "⛏️ MEGA DIG DRAW",
		TextColor3 = C.Ink,
		ZIndex = 31,
		Parent = frame,
	})
	local window = Ui.new("Frame", {
		Name = "Window",
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 0, 70),
		BackgroundColor3 = C.Dark,
		ClipsDescendants = true,
		ZIndex = 31,
		Parent = frame,
	}, { Ui.corner(UDim.new(0, 14)), Ui.stroke(3) })
	-- A long strip of name tiles (weighted by hits), ending on the winner.
	local tileWidth = 200
	local pool = {}
	for _, entry in entries do
		for _ = 1, math.clamp(math.ceil(entry.hits / 20), 1, 5) do
			table.insert(pool, entry.name)
		end
	end
	local count = 34
	local strip = Ui.new("Frame", {
		Name = "Strip",
		Size = UDim2.new(0, tileWidth * (count + 2), 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 32,
		Parent = window,
	})
	local rng = Random.new()
	for i = 1, count + 2 do
		local name = if i == count then info.winnerName else pool[rng:NextInteger(1, #pool)]
		Ui.label({
			Position = UDim2.fromOffset((i - 1) * tileWidth + 4, 6),
			Size = UDim2.fromOffset(tileWidth - 8, 58),
			BackgroundTransparency = 0,
			BackgroundColor3 = if i % 2 == 0
				then Color3.fromRGB(255, 214, 90)
				else Color3.fromRGB(255, 170, 70),
			Font = Ui.TitleFont,
			Text = name,
			ZIndex = 33,
			Parent = strip,
		})
	end
	-- The pointer in the middle.
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = C.Red,
		ZIndex = 35,
		Parent = window,
	})
	local resultLabel = Ui.label({
		Position = UDim2.fromOffset(0, 130),
		Size = UDim2.new(1, 0, 0, 34),
		Font = Ui.TitleFont,
		Text = "",
		TextColor3 = C.Gold,
		ZIndex = 31,
		Parent = frame,
	})
	-- Spin: the winner's tile ends under the pointer.
	local windowWidth = 600
	local finalX = -((count - 1) * tileWidth + tileWidth / 2 - windowWidth / 2)
	local spin = MegaDig.drawSeconds - 1.6
	local tween = TweenService:Create(
		strip,
		TweenInfo.new(spin, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(finalX, 0) }
	)
	tween:Play()
	task.spawn(function()
		-- Clicks as tiles pass the pointer (slowing down with the reel).
		local lastTile = -1
		local started = os.clock()
		while os.clock() - started < spin do
			local tile = math.floor((-strip.Position.X.Offset + windowWidth / 2) / tileWidth)
			if tile ~= lastTile then
				lastTile = tile
				Sound.play("UiClick", 0.8, 1.2)
			end
			task.wait()
		end
		local find = info.find
		local def = Treasures.ById[find.id]
		local rarity = Rarities.Info[find.rarity]
		local won = info.winnerUserId == player.UserId
		resultLabel.Text = string.format(
			"%s: %s!",
			if won then "YOU WIN" else info.winnerName .. " wins",
			(if def then def.name else find.id)
				.. (if rarity then " (" .. string.upper(rarity.displayName) .. ")" else "")
		)
		Ui.pop(frame, 0.15)
		Sound.play(if find.rarity == "Secret" then "StingSecret" else "StingLegendary")
		if won then
			-- Out of the way quickly so the winner sees the treasure come
			-- out of the ground (the reveal shows it big, with its rarity).
			task.wait(1)
			TweenService:Create(
				frame,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.new(0.5, 0, 0, -200) }
			):Play()
			task.wait(0.3)
			frame:Destroy()
			RevealController.reveal(info.position, find)
			return
		end
		task.wait(4)
		frame:Destroy()
	end)
end

function MegaDigController.init()
	task.spawn(function()
		local base = workspace:WaitForChild("Base", 30)
		local clock = base and base:WaitForChild("MegaClock", 30)
		local box = clock and clock:FindFirstChild("ClockBox")
		if box then
			for _, child in box:GetChildren() do
				if child:IsA("SurfaceGui") then
					table.insert(faces, child)
				end
			end
		end
	end)
	buildPanel()
	workspace:GetAttributeChangedSignal("MegaDigProgress"):Connect(onProgress)
	workspace:GetAttributeChangedSignal("MegaDigActive"):Connect(function()
		lastProgress = 0
	end)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MegaDigDraw") :: RemoteEvent
	remote.OnClientEvent:Connect(showDraw)
	task.spawn(function()
		while true do
			update()
			task.wait(0.2)
		end
	end)
end

return MegaDigController
