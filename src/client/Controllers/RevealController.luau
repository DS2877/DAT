--!strict
-- The treasure reveal: the item pops out of the hole, spins with its name,
-- rarity color and value, then flies into the bag icon and the bag counter
-- ticks up. Presentation scales with rarity (Phase 1: pop + sparkles; the
-- slow-motion / camera moments for Legendary+ arrive in Phase 2).

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

type Find = { id: string, rarity: string, value: number, isNew: boolean }

local function infoCard(adornee: BasePart, find: Find, color: Color3): BillboardGui
	local def = Treasures.ById[find.id]
	local gui = Ui.new("BillboardGui", {
		Adornee = adornee,
		Size = UDim2.fromOffset(260, 110),
		StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
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
	if find.isNew then
		Ui.label({
			LayoutOrder = 0,
			Size = UDim2.fromOffset(120, 24),
			Font = Ui.TitleFont,
			Text = "NEW!",
			TextColor3 = Ui.Colors.Green,
			Parent = list,
		})
	end
	local info = Rarities.Info[find.rarity]
	Ui.label({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(160, 22),
		Text = string.upper(info and info.displayName or find.rarity),
		TextColor3 = color,
		Parent = list,
	})
	Ui.label({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(260, 34),
		Font = Ui.TitleFont,
		Text = if def then def.name else find.id,
		TextColor3 = Ui.Colors.White,
		Parent = list,
	})
	Ui.label({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(180, 30),
		Font = Ui.TitleFont,
		Text = Format.cash(find.value),
		TextColor3 = Ui.Colors.Gold,
		Parent = list,
	})
	Ui.pop(list, 0.35)
	return gui
end

local function flyToBag(from: Vector2, color: Color3, onLanded: () -> ())
	local gui = HudController.screenGui()
	local orb = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = color,
		ZIndex = 50,
		Parent = gui,
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
	local tier = if info then info.fxTier else 0
	local color = Color3.fromHex(if info then info.color else "#FFFFFF")

	-- Hold the bag counter until the find lands in it.
	HudController.holdBag(true)
	if active >= MAX_ACTIVE then
		HudController.holdBag(false)
		return
	end
	active += 1

	local model = TreasureBuilder.build(find.id)
	local startCf = CFrame.new(position + Vector3.new(0, 0.6, 0))
	model:PivotTo(startCf)
	model:ScaleTo(0.3)
	model.Parent = Effects.folder()
	local card = infoCard(model.PrimaryPart :: BasePart, find, color)

	Sound.play(if tier >= 1 then "RevealRare" else "RevealCommon", 0.6, if tier >= 1 then 1.25 else 1.0)
	if tier >= 1 then
		Effects.sparkles(position + Vector3.new(0, 2.5, 0), color, 20 + tier * 15)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10 + tier * 4
		light.Brightness = 2
		light.Parent = model.PrimaryPart
	end

	-- Pop up and spin.
	local riseTime = 0.45
	local holdTime = if tier >= 1 then 1.4 else 0.9
	local t0 = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local rise = math.min(1, t / riseTime)
		local eased = 1 - (1 - rise) ^ 3
		local overshoot = if rise < 1 then 1 + math.sin(rise * math.pi) * 0.25 else 1
		local height = 0.6 + 3.2 * eased + math.sin(t * 3) * 0.12
		model:PivotTo(CFrame.new(position + Vector3.new(0, height, 0)) * CFrame.Angles(0, t * 2.4, 0))
		local scale = 0.3 + 0.85 * eased * overshoot
		if math.abs(model:GetScale() - scale) > 0.01 then
			model:ScaleTo(math.max(0.05, scale))
		end
	end)

	task.delay(riseTime + holdTime, function()
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
