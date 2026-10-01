--!strict
-- The treasure reveal. The item pops out of the hole, shows its name, rarity
-- and value, then flies into the bag icon and the bag counter ticks up.
--
-- Presentation escalates with rarity (Config/Rarities fxTier) and mutation:
--   0  Common / Uncommon      small pop
--   1  Rare / Epic, Shiny     bigger pop, light pillar, sparkles, stronger sound
--   2  Legendary / Mythic,    slow-motion rise, camera focus, big text, screen
--      Golden                 flash, mild shake, music sting
--   3  Secret                 all of the above, longer, rainbow colors

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local TreasureBuilder = require(ReplicatedStorage.Shared.Builders.TreasureBuilder)
local Treasures = require(ReplicatedStorage.Shared.Config.Treasures)
local Effects = require(script.Parent.Parent.Effects)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)

local RevealController = {}

local MAX_ACTIVE = 4
local active = 0
local focusing = false

local GOLD = Color3.fromRGB(255, 201, 51)

type Find = {
	id: string,
	rarity: string,
	value: number,
	mutation: string?,
	isNew: boolean,
	isNewVariant: boolean,
	streak: number,
	streakBonus: number,
	deep: boolean?,
	firstFindBonus: boolean?,
}

type Style = {
	tier: number,
	rise: number, -- seconds to rise out of the ground
	hold: number, -- seconds on display before flying to the bag
	scale: number, -- final model scale
	height: number, -- studs above the hole
}

local STYLES: { [number]: Style } = {
	[0] = { tier = 0, rise = 0.45, hold = 0.9, scale = 1.15, height = 3.2 },
	[1] = { tier = 1, rise = 0.5, hold = 1.4, scale = 1.35, height = 3.6 },
	[2] = { tier = 2, rise = 1.3, hold = 2.0, scale = 1.7, height = 4.4 },
	[3] = { tier = 3, rise = 1.6, hold = 2.8, scale = 2.1, height = 5.2 },
}

local function rainbow(t: number): Color3
	return Color3.fromHSV((t * 0.35) % 1, 0.75, 1)
end

local function styleFor(find: Find): Style
	local info = Rarities.Info[find.rarity]
	local tier = if info then info.fxTier else 0
	if find.mutation == "Shiny" then
		tier = math.max(tier, 1)
	elseif find.mutation == "Golden" or find.deep then
		tier = math.max(tier, 2)
	end
	if find.deep then
		-- A Deep Dig find emerges huge.
		local base = STYLES[tier]
		return {
			tier = base.tier,
			rise = base.rise + 0.4,
			hold = base.hold,
			scale = base.scale * 1.8,
			height = base.height + 2,
		}
	end
	return STYLES[tier]
end

local function displayName(find: Find): string
	local def = Treasures.ById[find.id]
	local name = if def then def.name else find.id
	if find.mutation == "Shiny" then
		return "Shiny " .. name
	elseif find.mutation == "Golden" then
		return "GOLDEN " .. name
	end
	return name
end

local function infoCard(adornee: BasePart, find: Find, color: Color3, style: Style): (BillboardGui, TextLabel)
	local big = style.tier >= 2
	local gui = Ui.new("BillboardGui", {
		Adornee = adornee,
		Size = UDim2.fromOffset(if big then 340 else 270, if big then 150 else 118),
		StudsOffsetWorldSpace = Vector3.new(0, 2.4 + style.scale, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = Effects.folder(),
	})
	local list = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui }, {
		Ui.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tag: string? = nil
	if find.isNew then
		tag = if find.firstFindBonus then "NEW! x2 VALUE" else "NEW!"
	elseif find.isNewVariant and find.mutation then
		tag = "NEW " .. string.upper(find.mutation) .. "!"
	end
	if tag then
		Ui.label({
			LayoutOrder = 0,
			Size = UDim2.fromOffset(200, 24),
			Font = Ui.TitleFont,
			Text = tag,
			TextColor3 = Ui.Colors.Green,
			Parent = list,
		})
	end
	local info = Rarities.Info[find.rarity]
	local rarityLabel = Ui.label({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(200, if big then 28 else 22),
		Font = if big then Ui.TitleFont else Ui.Font,
		Text = string.upper(info and info.displayName or find.rarity),
		TextColor3 = color,
		Parent = list,
	})
	Ui.label({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(if big then 340 else 270, if big then 44 else 34),
		Font = Ui.TitleFont,
		Text = displayName(find),
		TextColor3 = if find.mutation == "Golden" then GOLD else Ui.Colors.White,
		Parent = list,
	})
	Ui.label({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(220, if big then 38 else 30),
		Font = Ui.TitleFont,
		Text = Format.cash(find.value),
		TextColor3 = Ui.Colors.Gold,
		Parent = list,
	})
	Ui.pop(list, 0.35)
	return gui, rarityLabel
end

-- A tall glowing column over the hole (tier 1+). Returned for color cycling.
local function lightPillar(position: Vector3, color: Color3, duration: number, width: number): Part
	local pillar = Instance.new("Part")
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = color
	pillar.Transparency = 0.35
	pillar.Size = Vector3.new(40, width, width)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Parent = Effects.folder()
	Ui.tween(
		pillar,
		duration,
		{ Transparency = 1, Size = Vector3.new(40, width * 0.3, width * 0.3) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(duration + 0.1, function()
		pillar:Destroy()
	end)
	return pillar
end

local function screenFlash(color: Color3)
	local flash = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 40,
		Parent = HudController.screenGui(),
	})
	Ui.tween(flash, 0.5, { BackgroundTransparency = 1 })
	task.delay(0.55, function()
		flash:Destroy()
	end)
end

-- Swings the camera to frame the treasure, with a mild shake at the start,
-- then hands control back to the normal camera.
local function focusCamera(target: Vector3, duration: number)
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if focusing or not camera or not root then
		return
	end
	focusing = true
	local away = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
	away = if away.Magnitude > 0.1 then away.Unit else -camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	local eye = target + away * 11 + Vector3.new(0, 4, 0)
	local focus = CFrame.lookAt(eye, target + Vector3.new(0, 1.5, 0))

	camera.CameraType = Enum.CameraType.Scriptable
	local start = camera.CFrame
	local t0 = os.clock()
	local rng = Random.new()
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local alpha = math.min(1, t / 0.45)
		local eased = 1 - (1 - alpha) ^ 3
		local cf = start:Lerp(focus, eased)
		if t < 0.5 then
			local shake = 0.12 * (1 - t / 0.5)
			cf *= CFrame.new(rng:NextNumber(-shake, shake), rng:NextNumber(-shake, shake), 0)
		end
		camera.CFrame = cf
	end)
	task.delay(duration, function()
		connection:Disconnect()
		camera.CameraType = Enum.CameraType.Custom
		focusing = false
	end)
end

local function flyToBag(from: Vector2, color: Color3, onLanded: () -> ())
	local orb = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = color,
		ZIndex = 50,
		Parent = HudController.screenGui(),
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(4) })
	local target = HudController.bagIconPosition()
	local tween = Ui.tween(
		orb,
		0.45,
		{ Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(22, 22) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	tween.Completed:Once(function()
		orb:Destroy()
		onLanded()
	end)
end

function RevealController.reveal(position: Vector3, find: Find)
	local info = Rarities.Info[find.rarity]
	local style = styleFor(find)
	local color = Color3.fromHex(if info then info.color else "#FFFFFF")
	if find.mutation == "Golden" then
		color = GOLD
	end

	-- Hold the bag counter until the find lands in it.
	HudController.holdBag(true)
	if active >= MAX_ACTIVE then
		HudController.holdBag(false)
		return
	end
	active += 1

	local model = TreasureBuilder.build(find.id)
	TreasureBuilder.applyMutation(model, find.mutation)
	model:PivotTo(CFrame.new(position + Vector3.new(0, 0.6, 0)))
	TreasureBuilder.scaleTo(model, 0.3)
	model.Parent = Effects.folder()
	local card, rarityLabel = infoCard(model.PrimaryPart :: BasePart, find, color, style)

	-- Tiered effects.
	local pillar: Part? = nil
	if style.tier == 0 then
		Sound.play("RevealCommon", 0.6)
	else
		Sound.play("RevealRare", 0.7, 1.1 + style.tier * 0.1)
		Effects.sparkles(position + Vector3.new(0, 2.5, 0), color, 15 + style.tier * 20)
		pillar = lightPillar(position, color, style.rise + style.hold, 2 + style.tier)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10 + style.tier * 5
		light.Brightness = 2
		light.Parent = model.PrimaryPart
	end
	if style.tier >= 2 then
		Sound.play(if style.tier >= 3 then "StingSecret" else "StingLegendary", 0.8)
		screenFlash(if style.tier >= 3 then Color3.new(1, 1, 1) else color)
		focusCamera(position + Vector3.new(0, style.height, 0), style.rise + style.hold * 0.8)
		local headline = if find.mutation == "Golden" and (info == nil or info.fxTier < 2)
			then "GOLDEN!"
			else string.upper(if info then info.displayName else find.rarity) .. "!"
		HudController.bigText(headline, color, style.rise + style.hold)
		task.delay(0.4, function()
			Effects.sparkles(position + Vector3.new(0, style.height, 0), color, 60)
		end)
	end

	-- Rise (slow motion for the big ones), spin, bob.
	local t0 = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local rise = math.min(1, t / style.rise)
		local eased = 1 - (1 - rise) ^ 3
		local overshoot = if rise < 1 then 1 + math.sin(rise * math.pi) * 0.25 else 1
		local height = 0.6 + style.height * eased + math.sin(t * 3) * 0.12
		local spin = if style.tier >= 2 then t * 1.4 else t * 2.4
		model:PivotTo(CFrame.new(position + Vector3.new(0, height, 0)) * CFrame.Angles(0, spin, 0))
		local scale = 0.3 + (style.scale - 0.3) * eased * overshoot
		if math.abs(model:GetScale() - scale) > 0.01 then
			TreasureBuilder.scaleTo(model, math.max(0.05, scale))
		end
		if style.tier >= 3 then
			local c = rainbow(t)
			rarityLabel.TextColor3 = c
			if pillar and pillar.Parent then
				pillar.Color = c
			end
		end
	end)

	task.delay(style.rise + style.hold, function()
		connection:Disconnect()
		local camera = workspace.CurrentCamera
		local screenPoint = camera and camera:WorldToScreenPoint(model:GetPivot().Position)
		card:Destroy()
		model:Destroy()
		active -= 1
		local from = if screenPoint and screenPoint.Z > 0
			then Vector2.new(screenPoint.X, screenPoint.Y)
			else HudController.bagIconPosition() + Vector2.new(200, 0)
		flyToBag(from, color, function()
			HudController.holdBag(false)
		end)
	end)
end

return RevealController
