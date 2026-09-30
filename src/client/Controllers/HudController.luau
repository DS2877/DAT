--!strict
-- The always-on HUD: cash, bag (count + value), next-goal bar, BAG FULL
-- banner, toasts, and the sale popup. Mobile first: big, readable, and
-- nothing over the thumbstick or jump button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Loot = require(ReplicatedStorage.Shared.Config.Loot)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)

local C = Ui.Colors
local player = Players.LocalPlayer

local Hud = {}

local screenGui: ScreenGui
local root: Frame
local cashLabel: TextLabel
local cashPill: Frame
local bagLabel: TextLabel
local bagPill: Frame
local goalFrame: Frame
local goalFill: Frame
local goalLabel: TextLabel
local bagFullBanner: TextLabel
local toastHolder: Frame
local loadingLabel: TextLabel
local streakFrame: Frame
local streakCount: TextLabel
local streakBonus: TextLabel
local streakToken = 0

local shownCash = 0
local cashTweenToken = 0
local bagHeld = 0

---------------------------------------------------------------------------
-- Layout scaling: design at 720p height, scale down on phones.
---------------------------------------------------------------------------

local function applyScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local scale = math.clamp(viewport.Y / 650, 0.62, 1.3)
	local uiScale = root:FindFirstChildOfClass("UIScale") :: UIScale
	uiScale.Scale = scale
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function pill(name: string, position: UDim2, icon: string, color: Color3): (Frame, TextLabel)
	local frame = Ui.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0, 0),
		Position = position,
		Size = UDim2.fromOffset(250, 58),
		BackgroundColor3 = C.Cream,
		Parent = root,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(4) })
	Ui.new("Frame", {
		Name = "IconBg",
		Size = UDim2.fromOffset(58, 58),
		BackgroundColor3 = color,
		Parent = frame,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(4) })
	Ui.label({
		Name = "Icon",
		Size = UDim2.fromOffset(58, 58),
		Text = icon,
		Parent = frame,
	})
	local label = Ui.label({
		Name = "Value",
		Position = UDim2.fromOffset(66, 8),
		Size = UDim2.new(1, -80, 1, -16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Ink,
		Parent = frame,
	})
	-- Dark-on-cream text reads better without the outline.
	local outline = label:FindFirstChildOfClass("UIStroke")
	if outline then
		outline:Destroy()
	end
	return frame, label
end

local function build()
	screenGui = Ui.new("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	root = Ui.new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	}, { Ui.new("UIScale") })

	cashPill, cashLabel = pill("Cash", UDim2.fromOffset(14, 70), "💰", C.Gold)
	bagPill, bagLabel = pill("Bag", UDim2.fromOffset(14, 138), "🎒", C.Orange)

	-- Next-goal bar (top center).
	goalFrame = Ui.new("Frame", {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(440, 46),
		BackgroundColor3 = C.Dark,
		Parent = root,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(4) })
	goalFill = Ui.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Gold,
		Parent = goalFrame,
	}, { Ui.corner(UDim.new(1, 0)) })
	goalLabel = Ui.label({
		Name = "Text",
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -32, 1, -12),
		Parent = goalFrame,
	})

	bagFullBanner = Ui.label({
		Name = "BagFull",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(520, 52),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Red,
		Font = Ui.TitleFont,
		Text = "BAG FULL - RETURN TO SELL",
		Visible = false,
		Parent = root,
	})
	Ui.corner(UDim.new(0, 16)).Parent = bagFullBanner
	Ui.stroke(4).Parent = bagFullBanner
	Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = bagFullBanner,
	})

	toastHolder = Ui.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.fromOffset(560, 200),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Ui.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Dig streak counter (right side, above the DIG button area).
	streakFrame = Ui.new("Frame", {
		Name = "Streak",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.36, 0),
		Size = UDim2.fromOffset(210, 84),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	streakCount = Ui.label({
		Name = "Count",
		Size = UDim2.new(1, 0, 0, 52),
		Font = Ui.TitleFont,
		TextColor3 = C.Orange,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = streakFrame,
	})
	streakBonus = Ui.label({
		Name = "Bonus",
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = streakFrame,
	})

	loadingLabel = Ui.label({
		Name = "Loading",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 60),
		Font = Ui.TitleFont,
		Text = "Loading your treasure...",
		Parent = root,
	})

	applyScale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end
end

---------------------------------------------------------------------------
-- Updating
---------------------------------------------------------------------------

local function setCashText(amount: number)
	cashLabel.Text = Format.cash(amount)
end

-- Counts the cash label up to a new value.
local function animateCash(target: number)
	cashTweenToken += 1
	local token = cashTweenToken
	local from = shownCash
	if target <= from then
		shownCash = target
		setCashText(target)
		return
	end
	task.spawn(function()
		local duration = 0.7
		local t0 = os.clock()
		while token == cashTweenToken do
			local alpha = math.min(1, (os.clock() - t0) / duration)
			shownCash = math.floor(from + (target - from) * (1 - (1 - alpha) ^ 3))
			setCashText(shownCash)
			if alpha >= 1 then
				break
			end
			task.wait()
		end
	end)
end

local function refreshBag()
	local data = ClientState.data
	if not data or bagHeld > 0 then
		return
	end
	local capacity = ClientState.bagCapacity()
	local count = #data.bag
	bagLabel.Text = string.format("%d/%d · %s", count, capacity, Format.cash(ClientState.bagValue()))
	local full = count >= capacity
	bagLabel.TextColor3 = if full then C.Red else C.Ink
	bagFullBanner.Visible = full
end

local function refreshGoal()
	local data = ClientState.data
	if not data then
		return
	end
	local goal = Progression.nextGoal(data.cash, data.shovelLevel, data.bagLevel)
	if not goal then
		goalLabel.Text = "Max gear! Rebirth is coming soon"
		goalFill.Size = UDim2.fromScale(1, 1)
		goalFill.BackgroundColor3 = C.Purple
		return
	end
	local progress = math.clamp(data.cash / goal.cost, 0, 1)
	Ui.tween(goalFill, 0.4, { Size = UDim2.fromScale(math.max(progress, 0.08), 1) })
	if goal.affordable then
		goalFill.BackgroundColor3 = C.Green
		goalLabel.Text = goal.name .. ": READY! Visit the shop"
	else
		goalFill.BackgroundColor3 = C.Gold
		goalLabel.Text =
			string.format("%s: %s / %s", goal.name, Format.cash(data.cash), Format.cash(goal.cost))
	end
end

local function onChanged(data: ClientState.Snapshot, previous: ClientState.Snapshot?)
	loadingLabel.Visible = false
	if not previous then
		shownCash = data.cash
		setCashText(data.cash)
	elseif data.cash > previous.cash then
		animateCash(data.cash)
		Ui.pop(cashPill, 0.12)
	else
		cashTweenToken += 1
		shownCash = data.cash
		setCashText(data.cash)
	end
	refreshBag()
	refreshGoal()
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Hud.root(): Frame
	return root
end

function Hud.screenGui(): ScreenGui
	return screenGui
end

-- Center of the bag icon in screen coordinates (for fly-to-bag effects).
function Hud.bagIconPosition(): Vector2
	local icon = bagPill:FindFirstChild("IconBg") :: Frame
	return icon.AbsolutePosition + icon.AbsoluteSize / 2
end

-- While held, bag updates wait (so the counter ticks when a find lands).
function Hud.holdBag(hold: boolean)
	bagHeld = math.max(0, bagHeld + (if hold then 1 else -1))
	if not hold then
		refreshBag()
		Ui.pop(bagPill, 0.15)
		Sound.play("BagTick", 0.4, 1.2)
	end
end

function Hud.flashBagFull()
	bagFullBanner.Visible = true
	Ui.pop(bagFullBanner, 0.2)
	Sound.play("BagFull", 0.6)
end

function Hud.toast(text: string, color: Color3?, duration: number?)
	local label = Ui.label({
		Size = UDim2.fromOffset(540, 42),
		Font = Ui.TitleFont,
		Text = text,
		TextColor3 = color or C.White,
		Parent = toastHolder,
	})
	Ui.pop(label, 0.25)
	task.delay(duration or 2.5, function()
		local tween = Ui.tween(label, 0.3, { TextTransparency = 1 })
		Ui.tween(label:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.3, { Transparency = 1 })
		tween.Completed:Wait()
		label:Destroy()
	end)
end

-- Big centered text that pops and fades (upgrades, milestones).
function Hud.bigText(text: string, color: Color3?, duration: number?)
	local label = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(700, 90),
		Font = Ui.TitleFont,
		Text = text,
		TextColor3 = color or C.Gold,
		Parent = root,
	})
	Ui.pop(label, 0.5)
	task.delay(duration or 1.6, function()
		Ui.tween(label, 0.35, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.34) })
		Ui.tween(label:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.35, { Transparency = 1 })
		task.wait(0.4)
		label:Destroy()
	end)
end

-- Shows "x3 DIG STREAK" after chained digs; fades quietly when the window ends.
function Hud.showStreak(count: number, bonus: number)
	streakToken += 1
	local token = streakToken
	if count < 2 then
		streakFrame.Visible = false
		return
	end
	streakCount.Text = "x" .. count .. " DIG STREAK"
	streakBonus.Text = string.format("+%d%% value", math.floor(bonus * 100 + 0.5))
	for _, label in { streakCount, streakBonus } do
		label.TextTransparency = 0
		local outline = label:FindFirstChildOfClass("UIStroke")
		if outline then
			outline.Transparency = 0
		end
	end
	streakFrame.Visible = true
	Ui.pop(streakFrame, 0.2 + math.min(count, 10) * 0.02)
	Sound.play("Streak", 0.35, 1 + math.min(count, 10) * 0.05)
	task.delay(Loot.streak.window, function()
		if token ~= streakToken then
			return
		end
		for _, label in { streakCount, streakBonus } do
			Ui.tween(label, 0.4, { TextTransparency = 1 })
			Ui.tween(label:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.4, { Transparency = 1 })
		end
		task.wait(0.45)
		if token == streakToken then
			streakFrame.Visible = false
		end
	end)
end

-- Coin burst + counting "+$X" for a sale, then the next-goal nudge.
function Hud.showSale(info: { total: number, count: number, cash: number, goal: any, nearGoal: boolean })
	Sound.play("Sell", 0.7)
	local label = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(600, 100),
		Font = Ui.TitleFont,
		Text = "+$0",
		TextColor3 = C.Gold,
		Parent = root,
	})
	Ui.pop(label, 0.4)

	-- Coins burst out from the center.
	local rng = Random.new()
	for _ = 1, 14 do
		local coin = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = C.Gold,
			Parent = root,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(3, Color3.fromRGB(170, 110, 0)) })
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(120, 260)
		Ui.tween(coin, 0.6, {
			Position = UDim2.new(0.5, math.cos(angle) * dist, 0.42, math.sin(angle) * dist),
			BackgroundTransparency = 1,
		})
		task.delay(0.62, function()
			coin:Destroy()
		end)
	end

	task.spawn(function()
		local t0 = os.clock()
		local duration = 0.8
		while true do
			local alpha = math.min(1, (os.clock() - t0) / duration)
			label.Text = "+" .. Format.cash(math.floor(info.total * (1 - (1 - alpha) ^ 3)))
			if alpha >= 1 then
				break
			end
			task.wait()
		end
		task.wait(0.8)
		Ui.tween(label, 0.3, { TextTransparency = 1 })
		Ui.tween(label:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.3, { Transparency = 1 })
		task.wait(0.35)
		label:Destroy()
	end)

	local goal = info.goal
	if goal then
		task.delay(1.0, function()
			if goal.affordable then
				Hud.toast("You can afford the " .. goal.name .. "!", C.Green, 3.5)
			elseif info.nearGoal then
				Hud.toast("Only " .. Format.cash(goal.missing) .. " to go!", C.Gold, 3)
			end
		end)
	end
end

function Hud.init()
	build()
	ClientState.Changed:Connect(onChanged)

	local remotes = ReplicatedStorage:WaitForChild("Remotes");
	(remotes:WaitForChild("Sold") :: RemoteEvent).OnClientEvent:Connect(Hud.showSale);
	(remotes:WaitForChild("Notify") :: RemoteEvent).OnClientEvent:Connect(
		function(text: string, kind: string?)
			if kind == "Denied" then
				Sound.play("Denied", 0.5)
				Hud.toast(text, C.Red)
			else
				Hud.toast(text)
			end
		end
	)
end

return Hud
