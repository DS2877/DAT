--!strict
-- Upgrade stations: stepping onto the shovel or bag pad opens a panel with
-- the current and next level, what improves, the price, and a BUY button
-- (or exactly how much cash is missing). Purchases are validated server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	titleLabel.Text = if kind == "Shovel" then "SHOVEL SHOP" else "BAG SHOP"
	if not nextDef then
		fromToLabel.Text = currentName
		statLabel.Text = "You have the best one!"
		buyButton.Text = "MAXED OUT"
		buyButton.BackgroundColor3 = C.Purple
		buyButton.AutoButtonColor = false
		return
	end
	fromToLabel.Text = currentName .. "  ->  " .. nextDef.name
	statLabel.Text = stat or ""
	local missing = nextDef.cost - data.cash
	if missing <= 0 then
		buyButton.Text = "BUY  " .. Format.cash(nextDef.cost)
		buyButton.BackgroundColor3 = C.Green
		buyButton.AutoButtonColor = true
	else
		buyButton.Text = "Need " .. Format.cash(missing) .. " more"
		buyButton.BackgroundColor3 = C.Grey
		buyButton.AutoButtonColor = false
	end
end

local function build()
	panel = Ui.new("Frame", {
		Name = "UpgradePanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(420, 200),
		BackgroundColor3 = C.Cream,
		Visible = false,
		Parent = HudController.root(),
	}, { Ui.corner(UDim.new(0, 22)), Ui.stroke(5) })

	titleLabel = Ui.label({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(300, 44),
		Font = Ui.TitleFont,
		TextColor3 = C.Gold,
		Parent = panel,
	})
	fromToLabel = Ui.label({
		Name = "FromTo",
		Position = UDim2.fromOffset(16, 30),
		Size = UDim2.new(1, -32, 0, 38),
		TextColor3 = C.Ink,
		Parent = panel,
	});
	(fromToLabel:FindFirstChildOfClass("UIStroke") :: UIStroke):Destroy()
	statLabel = Ui.label({
		Name = "Stat",
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.new(1, -32, 0, 30),
		TextColor3 = Color3.fromRGB(90, 70, 50),
		Parent = panel,
	});
	(statLabel:FindFirstChildOfClass("UIStroke") :: UIStroke):Destroy()

	buyButton = Ui.new("TextButton", {
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(1, -40, 0, 70),
		BackgroundColor3 = C.Green,
		Font = Ui.TitleFont,
		TextColor3 = C.White,
		TextScaled = true,
		Text = "BUY",
		Parent = panel,
	}, {
		Ui.corner(UDim.new(0, 18)),
		Ui.stroke(4),
		Ui.textStroke(3),
		Ui.new("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	})
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
			Sound.play("Denied", 0.5)
			HudController.toast("You need " .. Format.cash(missing) .. " more!", C.Red)
			Ui.pop(buyButton, 0.08)
		end
	end)
end

local function onUpgradeResult(result: { [string]: any })
	if result.ok then
		Sound.play("Upgrade", 0.8, 0.9)
		HudController.bigText(
			string.upper(result.name) .. "!",
			if result.kind == "Shovel" then C.Blue else C.Purple
		)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Effects.sparkles(root.Position, C.Gold, 40)
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
