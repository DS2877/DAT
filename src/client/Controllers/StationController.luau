--!strict
-- Upgrade stations: stepping onto the shovel or bag pad opens a panel with
-- the current and next level, what improves, the price, and a BUY button
-- (or exactly how much cash is missing). Purchases are validated server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Effects = require(script.Parent.Parent.Effects)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors
local player = Players.LocalPlayer

local StationController = {}

type Station = { kind: string, pad: BasePart, radius: number }

local stations: { Station } = {}
local openKind: string? = nil
local buyUpgrade: RemoteEvent

local panel: Frame
local titleLabel: TextLabel
local fromToLabel: TextLabel
local statLabel: TextLabel
local buyButton: TextButton
local header: Frame

local function describe(kind: string, level: number): (string, string?)
	if kind == "Shovel" then
		local current = Progression.getShovel(level)
		local nextDef = Progression.nextUpgrade("Shovel", level) :: any
		if not nextDef then
			return current.name, nil
		end
		local now = current.hits * current.hitInterval
		local after = nextDef.hits * nextDef.hitInterval
		return current.name,
			string.format(
				"Dig time: %.2fs -> %.2fs (%d%% faster)",
				now,
				after,
				math.floor((1 - after / now) * 100 + 0.5)
			)
	else
		local current = Progression.getBag(level)
		local nextDef = Progression.nextUpgrade("Bag", level) :: any
		if not nextDef then
			return current.name, nil
		end
		return current.name,
			string.format("Bag space: %d -> %d treasures", current.capacity, nextDef.capacity)
	end
end

local function refreshPanel()
	local data = ClientState.data
	local kind = openKind
	if not data or not kind then
		panel.Visible = false
		return
	end
	local level = if kind == "Shovel" then data.shovelLevel else data.bagLevel
	local nextDef = Progression.nextUpgrade(kind :: any, level) :: any
	local currentName, stat = describe(kind, level)
	titleLabel.Text = if kind == "Shovel" then "⛏  SHOVEL SHOP" else "🎒  BAG SHOP"
	local accent = if kind == "Shovel" then C.Blue else C.Purple
	local gradient = header:FindFirstChildOfClass("UIGradient") :: UIGradient
	gradient.Color = ColorSequence.new(Ui.lighten(accent, 0.3), Ui.darken(accent, 0.1))
	if not nextDef then
		fromToLabel.Text = currentName
		statLabel.Text = "You have the best one!"
		buyButton.Text = "MAXED OUT"
		Ui.setButtonColor(buyButton, C.Purple)
		buyButton.AutoButtonColor = false
		return
	end
	fromToLabel.Text = currentName .. "  ->  " .. nextDef.name
	statLabel.Text = stat or ""
	local missing = nextDef.cost - data.cash
	if missing <= 0 then
		buyButton.Text = "BUY  " .. Format.cash(nextDef.cost)
		Ui.setButtonColor(buyButton, C.Green)
		buyButton.AutoButtonColor = true
	else
		buyButton.Text = "Need " .. Format.cash(missing) .. " more"
		Ui.setButtonColor(buyButton, C.Grey)
		buyButton.AutoButtonColor = false
	end
end

local function build()
	local p = Ui.panel({
		name = "UpgradePanel",
		title = "SHOP",
		accent = C.Blue,
		width = 500,
		height = 270,
		parent = HudController.root(),
		position = UDim2.new(0.5, 0, 1, -20),
		anchor = Vector2.new(0.5, 1),
	})
	panel = p.root
	titleLabel = p.title
	header = p.header
	p.close.Visible = false

	fromToLabel = Ui.plainLabel({
		Name = "FromTo",
		Size = UDim2.new(1, 0, 0, 36),
		Font = Ui.TitleFont,
		TextColor3 = C.Ink,
		Parent = p.body,
	})
	statLabel = Ui.plainLabel({
		Name = "Stat",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = Color3.fromRGB(110, 80, 50),
		Parent = p.body,
	})
	buyButton = Ui.button({
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, -20, 0, 70),
		Text = "BUY",
		Parent = p.body,
	}, C.Green)
	buyButton.Activated:Connect(function()
		local kind = openKind
		local data = ClientState.data
		if not kind or not data then
			return
		end
		local level = if kind == "Shovel" then data.shovelLevel else data.bagLevel
		local ok, reason, missing = Progression.canBuy(kind :: any, level, data.cash)
		if ok then
			buyUpgrade:FireServer(kind)
		elseif reason == "NotEnoughCash" then
			Sound.play("Denied")
			HudController.toast("You need " .. Format.cash(missing) .. " more!", C.Red)
			Ui.pop(buyButton, 0.08)
		end
	end)
end

local function onUpgradeResult(result: { [string]: any })
	if result.ok then
		Sound.play("Upgrade")
		HudController.bigText(
			string.upper(result.name) .. "!",
			if result.kind == "Shovel" then C.Blue else C.Purple
		)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Effects.sparkles(root.Position, C.Gold, 40)
		end
		-- A new shovel can open a new area: celebrate it right after.
		if result.kind == "Shovel" then
			for _, areaId in Areas.Order do
				local def = Areas.Defs[areaId]
				if def.enabled and def.requiredShovel == result.level then
					task.delay(1.7, function()
						Sound.play("AreaUnlocked")
						HudController.bigText(string.upper(def.displayName) .. " UNLOCKED!", C.Green, 2.4)
						HudController.toast("The gate is open - go explore!", C.Green, 4)
					end)
				end
			end
		end
	elseif result.reason == "NotEnoughCash" then
		HudController.toast("You need " .. Format.cash(result.missing or 0) .. " more!", C.Red)
	elseif result.reason == "TooFar" then
		HudController.toast("Step onto the shop pad to buy!", C.Red)
	end
end

local function findStations()
	local base = workspace:WaitForChild("Base")
	for _, child in base:GetChildren() do
		local kind = child:GetAttribute("Station")
		if child:IsA("BasePart") and (kind == "Shovel" or kind == "Bag") then
			table.insert(stations, {
				kind = kind :: string,
				pad = child,
				radius = (child:GetAttribute("Radius") :: number?) or 10,
			})
		end
	end
end

function StationController.init()
	buyUpgrade = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyUpgrade") :: RemoteEvent;
	(ReplicatedStorage.Remotes:WaitForChild("UpgradeResult") :: RemoteEvent).OnClientEvent:Connect(
		onUpgradeResult
	)
	build()
	findStations()
	ClientState.Changed:Connect(refreshPanel)

	task.spawn(function()
		while true do
			task.wait(0.2)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local inside: string? = nil
			if root then
				for _, station in stations do
					local offset = root.Position - station.pad.Position
					if
						Vector3.new(offset.X, 0, offset.Z).Magnitude <= station.radius
						and math.abs(offset.Y) < 8
					then
						inside = station.kind
						break
					end
				end
			end
			if inside ~= openKind then
				openKind = inside
				if inside then
					panel.Visible = true
					Ui.pop(panel, 0.1)
				end
				refreshPanel()
			end
		end
	end)
end

-- The pad of a station kind ("Shovel" | "Bag"), used by the guide arrow.
function StationController.padFor(kind: string): BasePart?
	for _, station in stations do
		if station.kind == kind then
			return station.pad
		end
	end
	return nil
end

return StationController
