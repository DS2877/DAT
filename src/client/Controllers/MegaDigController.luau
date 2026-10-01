--!strict
-- The Mega Dig on this client:
--   * the clock tower's four faces: a ticking red hand and the countdown
--     ("DIG NOW!" with the progress while a site is open), with clock ticks
--     you can hear in the last 10 seconds
--   * the HUD line under the rush timer
--   * a big progress sign over the open site (seen from far away)
--   * the winner draw: a slot-machine reel of the helpers' names that
--     slows down and stops on the winner, then the winner's treasure reveal

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MegaDig = require(ReplicatedStorage.Shared.Config.MegaDig)
local MegaDigClock = require(ReplicatedStorage.Shared.Logic.MegaDigClock)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)
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

-- The big sign over the open site.
local function updateSiteSign(active: boolean, progress: number, left: number)
	if not active then
		if siteSign then
			siteSign:Destroy()
			siteSign, siteFill, siteText = nil, nil, nil
		end
		return
	end
	local site = findSite()
	if not site or not site.PrimaryPart then
		return
	end
	if not siteSign or siteSign.Adornee ~= site.PrimaryPart then
		if siteSign then
			siteSign:Destroy()
		end
		local gui = Ui.new("BillboardGui", {
			Name = "MegaDigSign",
			Adornee = site.PrimaryPart,
			Size = UDim2.fromOffset(260, 90),
			StudsOffsetWorldSpace = Vector3.new(0, 12, 0),
			AlwaysOnTop = true,
			MaxDistance = 1000,
			LightInfluence = 0,
			Parent = player:WaitForChild("PlayerGui"),
		})
		Ui.label({
			Size = UDim2.new(1, 0, 0, 36),
			Font = Ui.TitleFont,
			Text = "⛏️ MEGA DIG",
			TextColor3 = C.Gold,
			Parent = gui,
		})
		local bar = Ui.new("Frame", {
			Position = UDim2.fromOffset(10, 40),
			Size = UDim2.new(1, -20, 0, 22),
			BackgroundColor3 = C.Dark,
			Parent = gui,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(3) })
		siteFill = Ui.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = C.Gold,
			Parent = bar,
		}, { Ui.corner(UDim.new(1, 0)) })
		siteText = Ui.label({
			Position = UDim2.fromOffset(0, 64),
			Size = UDim2.new(1, 0, 0, 24),
			Text = "",
			Parent = gui,
		})
		siteSign = gui
	end
	if siteFill then
		siteFill.Size = UDim2.fromScale(math.max(progress, 0.03), 1)
	end
	if siteText then
		siteText.Text = string.format(
			"%d%% dug · %s left · everyone dig!",
			math.floor(progress * 100),
			MegaDigClock.format(left)
		)
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
		HudController.setMegaText(
			string.format(
				"⛏️ MEGA DIG! %d%% · %s left",
				math.floor(progress * 100),
				MegaDigClock.format(ends - now)
			),
			true
		)
	else
		HudController.setMegaText("Mega Dig in " .. MegaDigClock.format(untilNext), false)
	end
	updateSiteSign(active, progress, ends - now)
end

---------------------------------------------------------------------------
-- The winner draw
---------------------------------------------------------------------------

local function showDraw(info: { [string]: any })
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
		resultLabel.Text = string.format(
			"%s wins: %s!",
			info.winnerName,
			(if def then def.name else find.id)
				.. (if rarity then " (" .. string.upper(rarity.displayName) .. ")" else "")
		)
		Ui.pop(frame, 0.15)
		Sound.play(if find.rarity == "Secret" then "StingSecret" else "StingLegendary")
		if info.winnerUserId == player.UserId then
			HudController.bigText("YOU WON THE MEGA DIG!", C.Gold, 3)
			task.delay(0.8, function()
				RevealController.reveal(info.position, find)
			end)
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
