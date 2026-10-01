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
--   * a party at the site while you're there (searchlights, confetti,
--     rainbow lanterns, fireworks, upbeat music), and a big finale
--   * the winner draw: a slot-machine reel of the helpers' names that
--     slows down and stops on the winner, then the winner's treasure reveal

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MegaDig = require(ReplicatedStorage.Shared.Config.MegaDig)
local MegaDigClock = require(ReplicatedStorage.Shared.Logic.MegaDigClock)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local Effects = require(script.Parent.Parent.Effects)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)
local AudioController = require(script.Parent.AudioController)
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
	-- A dug-out site stays up (outside the dig spots) for its finale.
	local finished = workspace:FindFirstChild("MegaDigSite")
	return if finished and finished:IsA("Model") then finished else nil
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
	-- Slim and see-through: the game stays visible behind it.
	panel = Ui.new("Frame", {
		Name = "MegaDigPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(330, 54),
		BackgroundColor3 = Color3.fromRGB(34, 24, 14),
		BackgroundTransparency = 0.35,
		Visible = false,
		Parent = HudController.root(),
	}, { Ui.corner(UDim.new(0, 14)), Ui.stroke(2, Color3.fromRGB(255, 201, 51)) })
	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(10, 3),
		Size = UDim2.fromOffset(120, 20),
		Font = Ui.TitleFont,
		Text = "⛏️ MEGA DIG",
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	percentLabel = Ui.label({
		Name = "Percent",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.fromOffset(70, 20),
		Font = Ui.TitleFont,
		Text = "0%",
		Parent = panel,
	})
	timerLabel = Ui.label({
		Name = "Timer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 3),
		Size = UDim2.fromOffset(90, 20),
		Font = Ui.TitleFont,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	local bar = Ui.new("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(10, 25),
		Size = UDim2.new(1, -20, 0, 10),
		BackgroundColor3 = Color3.fromRGB(20, 14, 8),
		BackgroundTransparency = 0.2,
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	fill = Ui.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bar,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.gradient(Color3.fromRGB(255, 226, 110), Color3.fromRGB(255, 160, 40)),
	})
	for _, at in { 0.25, 0.5, 0.75 } do
		Ui.new("Frame", {
			Name = "Notch",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(at, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.5,
			ZIndex = 3,
			Parent = bar,
		})
	end
	infoLabel = Ui.label({
		Name = "Info",
		Position = UDim2.fromOffset(10, 37),
		Size = UDim2.new(1, -20, 0, 14),
		Text = "",
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
		infoLabel.Text = string.format("📍 %d studs away · follow the golden beam!", math.floor(distance))
	elseif mine == 0 then
		infoLabel.Text = string.format("👥 %d digging · tap DIG to join the draw!", diggers)
	else
		local chance = if total > 0 then mine / total else 0
		infoLabel.Text = string.format(
			"👥 %d digging · your hits: %d · chance %d%%%s",
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
-- The party at the site: searchlights sweep the sky, confetti falls
-- (more as it gets dug out), the lanterns cycle through colors, fireworks
-- go up and the upbeat music plays while you're there. While it's drawing
-- its winner, all of it goes up a notch.
---------------------------------------------------------------------------

type SiteParty = {
	site: Model,
	beams: { Part },
	host: Part,
	confetti: ParticleEmitter,
	lanterns: { BasePart },
	nextFirework: number,
	-- Lights up in the air: a disco ball with its rays, glowing orbs
	-- circling the site, and sky lanterns floating up.
	ball: Part,
	ballLight: PointLight,
	rays: { Part },
	orbs: { Part },
	nextSkyLantern: number,
	parts: { BasePart }, -- everything to clean up
	dug: boolean, -- this player dug it (keeps the music through the draw)
}

local PARTY_RANGE = 160
local siteParty: SiteParty? = nil

local function stopSiteParty()
	local p = siteParty
	if not p then
		return
	end
	siteParty = nil
	for _, part in p.parts do
		part:Destroy()
	end
	AudioController.setUpbeat("MegaDig", false)
	AudioController.setSpecialMusic(nil)
end

local function partyPart(name: string, size: Vector3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = size
	part.Transparency = transparency
	part.Parent = Effects.folder()
	return part
end

local function startSiteParty(site: Model)
	local beams = {}
	for _ = 1, 4 do
		table.insert(beams, partyPart("Searchlight", Vector3.new(1.8, 150, 1.8), 0.6))
	end
	local host = partyPart("SiteConfetti", Vector3.new(34, 1, 34), 1)
	local confetti = PartyController.confettiEmitter(host)
	confetti.Rate = 6
	local lanterns = {}
	for _, child in site:GetChildren() do
		if child.Name == "Lantern" and child:IsA("BasePart") then
			table.insert(lanterns, child)
		end
	end
	local ball = partyPart("DiscoBall", Vector3.new(4.5, 4.5, 4.5), 0)
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Glass
	ball.Color = Color3.fromRGB(225, 230, 240)
	ball.Reflectance = 0.6
	local ballLight = Instance.new("PointLight")
	ballLight.Range = 45
	ballLight.Brightness = 3
	ballLight.Parent = ball
	local rays = {}
	for _ = 1, 8 do
		table.insert(rays, partyPart("DiscoRay", Vector3.new(0.35, 34, 0.35), 0.45))
	end
	local orbs = {}
	for i = 1, 10 do
		local orb = partyPart("SkyOrb", Vector3.new(1.4, 1.4, 1.4), 0.1)
		orb.Shape = Enum.PartType.Ball
		if i % 2 == 0 then
			local light = Instance.new("PointLight")
			light.Range = 14
			light.Brightness = 1.6
			light.Parent = orb
		end
		table.insert(orbs, orb)
	end
	local parts: { BasePart } = { host, ball }
	for _, list in { beams, rays, orbs } do
		for _, part in list do
			table.insert(parts, part)
		end
	end
	siteParty = {
		site = site,
		beams = beams,
		host = host,
		confetti = confetti,
		lanterns = lanterns,
		nextFirework = os.clock() + 1,
		ball = ball,
		ballLight = ballLight,
		rays = rays,
		orbs = orbs,
		nextSkyLantern = os.clock(),
		parts = parts,
		dug = false,
	}
	AudioController.setUpbeat("MegaDig", true)
end

local function updateSiteParty(t: number)
	local drawing = attr("MegaDigDrawing") == true
	local site = if attr("MegaDigActive") == true or drawing then findSite() else nil
	local center = site and site:FindFirstChild("Center") :: BasePart?
	if not site or not center or distanceTo(center.Position) > PARTY_RANGE then
		stopSiteParty()
		return
	end
	if siteParty and siteParty.site ~= site then
		stopSiteParty()
	end
	if not siteParty then
		startSiteParty(site)
	end
	local p = siteParty :: SiteParty
	-- The players digging it get the Mega Dig's own party music.
	local digging = ((player:GetAttribute("MegaDigHits") :: number?) or 0) > 0
	AudioController.setSpecialMusic(if digging or (drawing and p.dug) then "MegaDig" else nil)
	if digging then
		p.dug = true
	end
	local progress = if drawing then 1 else (attr("MegaDigProgress") :: number?) or 0
	local energy = if drawing then 2.2 else 0.5 + progress
	local position = center.Position
	local ring = MegaDig.radius + 10
	for i, beam in p.beams do
		local a = i / #p.beams * math.pi * 2 + math.pi / 4
		local base = position + Vector3.new(math.cos(a) * ring, 0, math.sin(a) * ring)
		local turn = t * (0.5 + energy * 0.45) + i * 1.3
		local tilt = math.rad(16 + 14 * math.sin(t * (0.9 + energy * 0.5) + i))
		beam.CFrame = CFrame.new(base)
			* CFrame.Angles(0, turn, 0)
			* CFrame.Angles(tilt, 0, 0)
			* CFrame.new(0, beam.Size.Y / 2, 0)
		beam.Color = Color3.fromHSV((t * 0.12 + i / #p.beams) % 1, 0.7, 1)
	end
	p.host.CFrame = CFrame.new(position + Vector3.new(0, 30, 0))
	p.confetti.Rate = if drawing then 160 else 6 + progress * 60
	for i, lantern in p.lanterns do
		local color = Color3.fromHSV((t * 0.35 + i / #p.lanterns) % 1, 0.65, 1)
		lantern.Color = color
		local light = lantern:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = color
		end
	end
	if t >= p.nextFirework then
		p.nextFirework = t + (if drawing then 0.5 else math.max(1.4, 7 - progress * 5.6))
		PartyController.fireworks(position, 1)
	end

	-- The disco ball turns high above the pit, throwing colored rays.
	local ballAt = position + Vector3.new(0, 30 + math.sin(t * 1.2) * 0.6, 0)
	local spin = CFrame.Angles(0, t * (0.8 + energy * 0.4), 0)
	p.ball.CFrame = CFrame.new(ballAt) * spin
	p.ballLight.Color = Color3.fromHSV((t * 0.2) % 1, 0.6, 1)
	for i, ray in p.rays do
		local a = i / #p.rays * math.pi * 2
		local tilt = math.rad(38 + 10 * math.sin(t * 1.5 + i))
		ray.CFrame = CFrame.new(ballAt)
			* spin
			* CFrame.Angles(0, a, 0)
			* CFrame.Angles(tilt, 0, 0)
			* CFrame.new(0, -ray.Size.Y / 2, 0)
		ray.Color = Color3.fromHSV((t * 0.15 + i / #p.rays) % 1, 0.75, 1)
	end
	-- Glowing orbs circle the site, bobbing.
	for i, orb in p.orbs do
		local a = t * (0.35 + energy * 0.15) + i / #p.orbs * math.pi * 2
		local d = MegaDig.radius + 4 + (i % 3) * 2
		orb.Position = position
			+ Vector3.new(math.cos(a) * d, 13 + (i % 4) * 2 + math.sin(t * 2 + i) * 1.2, math.sin(a) * d)
		orb.Color = Color3.fromHSV((i / #p.orbs + t * 0.1) % 1, 0.65, 1)
	end
	-- Sky lanterns float up from the fence.
	if t >= p.nextSkyLantern then
		p.nextSkyLantern = t + (if drawing then 0.25 else 1.4 - progress * 0.8)
		local a = math.random() * math.pi * 2
		local from = position + Vector3.new(math.cos(a) * ring, 6, math.sin(a) * ring)
		local lantern = partyPart("SkyLantern", Vector3.new(1.2, 1.6, 1.2), 0.05)
		lantern.Color = Color3.fromHSV(0.06 + math.random() * 0.06, 0.7, 1)
		lantern.Position = from
		local drift = Vector3.new(math.random() * 16 - 8, 70, math.random() * 16 - 8)
		TweenService:Create(lantern, TweenInfo.new(9, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = from + drift,
			Transparency = 1,
		}):Play()
		task.delay(9.1, function()
			lantern:Destroy()
		end)
	end
end

---------------------------------------------------------------------------
-- The winner draw
---------------------------------------------------------------------------

local function showDraw(info: { [string]: any })
	-- Dug out! The chest bursts free: fireworks and a ground shake nearby.
	local position = info.position
	if typeof(position) == "Vector3" and distanceTo(position) < 220 then
		PartyController.celebrate(position, MegaDig.radius + 6)
		Effects.cameraNudge(2.2)
		Effects.dirtBurst(position + Vector3.new(0, 4, 0), 60)
		Sound.play("DeepDig", 0.8)
		Sound.play("AreaUnlocked", 0.8)
		-- A golden flash.
		local flash = Ui.new("Frame", {
			Name = "MegaFlash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 220, 120),
			BackgroundTransparency = 0.35,
			ZIndex = 50,
			Parent = HudController.root(),
		})
		TweenService:Create(flash, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
		task.delay(1, function()
			flash:Destroy()
		end)
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
	local partyClock = 0
	RunService.Heartbeat:Connect(function(dt)
		partyClock += dt
		if partyClock >= 1 / 30 then
			partyClock = 0
			updateSiteParty(os.clock())
		end
	end)
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
