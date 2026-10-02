--!strict
-- The Bounty Board on screen (BountyService on the server): a small tracker
-- on the left (the next bounty, or how many are ready to claim) that opens
-- the board: three bounties with progress, reward and a CLAIM button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local Bounties = require(ReplicatedStorage.Shared.Logic.Bounties)
local BountyConfig = require(ReplicatedStorage.Shared.Config.Bounties)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors

local BountyController = {}

type Row = {
	frame: Frame,
	text: TextLabel,
	fill: Frame,
	count: TextLabel,
	reward: TextLabel,
	claim: TextButton,
}

local tracker: TextButton
local trackerText: TextLabel
local panel: Frame
local footer: TextLabel
local rows: { Row } = {}
local claimRemote: RemoteEvent

local function slots(): { any }
	local data = ClientState.data
	local board = data and data.bounties
	return if board and type(board.slots) == "table" then board.slots else {}
end

local function refresh()
	local data = ClientState.data
	local list = slots()
	tracker.Visible = data ~= nil and #list > 0
	local ready = 0
	local next: any = nil
	for _, b in list do
		if Bounties.isDone(b) then
			ready += 1
		elseif not next then
			next = b
		end
	end
	if ready > 0 then
		trackerText.Text =
			string.format("📜 %d bount%s ready - claim!", ready, if ready == 1 then "y" else "ies")
		trackerText.TextColor3 = C.Gold
	elseif next then
		trackerText.Text = "📜 " .. Bounties.describe(next) .. " · " .. Bounties.progressText(next)
		trackerText.TextColor3 = C.White
	end
	if not panel.Visible or not data then
		return
	end
	for i, row in rows do
		local b = list[i]
		row.frame.Visible = b ~= nil
		if b then
			row.text.Text = Bounties.describe(b)
			row.count.Text = Bounties.progressText(b)
			row.fill.Size = UDim2.fromScale(math.clamp(b.progress / math.max(1, b.target), 0, 1), 1)
			local cash = Bonuses.rewardCash(b.reward, data :: any)
			row.reward.Text = "Reward: " .. Format.cash(cash)
			local done = Bounties.isDone(b)
			row.claim.Text = if done then "CLAIM" else "NOT YET"
			row.claim.AutoButtonColor = done
			Ui.setButtonColor(row.claim, if done then C.Green else C.Grey)
		end
	end
	local completed = (data.bounties and data.bounties.completed) or 0
	local toBonus = BountyConfig.bonusEvery - completed % BountyConfig.bonusEvery
	footer.Text =
		string.format("Bounties done: %d  ·  %d more for a bonus (Epic dig + 2x Cash)", completed, toBonus)
end

local function build()
	tracker = Ui.new("TextButton", {
		Name = "BountyTracker",
		Position = UDim2.fromOffset(12, 256),
		Size = UDim2.fromOffset(300, 30),
		BackgroundColor3 = C.Dark,
		BackgroundTransparency = 0.25,
		Text = "",
		Visible = false,
		Parent = HudController.root(),
	}, {
		Ui.corner(UDim.new(1, 0)),
	})
	trackerText = Ui.label({
		Name = "Text",
		Position = UDim2.fromOffset(10, 2),
		Size = UDim2.new(1, -20, 1, -4),
		Text = "",
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tracker,
	})

	local p = Ui.panel({
		name = "Bounties",
		title = "BOUNTY BOARD",
		icon = "📜",
		accent = C.Orange,
		width = 600,
		height = 420,
		parent = HudController.root(),
		dim = true,
	})
	panel = p.root
	local list = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		Parent = p.body,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i = 1, BountyConfig.slots do
		local frame = Ui.new("Frame", {
			Name = "Bounty" .. i,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 84),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = list,
		}, {
			Ui.corner(UDim.new(0, 16)),
			Ui.stroke(3),
		})
		local text = Ui.plainLabel({
			Name = "Text",
			Position = UDim2.fromOffset(14, 6),
			Size = UDim2.new(1, -170, 0, 30),
			Font = Ui.TitleFont,
			TextColor3 = C.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local bar = Ui.new("Frame", {
			Name = "Bar",
			Position = UDim2.fromOffset(14, 42),
			Size = UDim2.new(1, -250, 0, 16),
			BackgroundColor3 = Color3.fromRGB(230, 215, 190),
			Parent = frame,
		}, { Ui.corner(UDim.new(1, 0)) })
		local fill = Ui.new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = C.Gold,
			Parent = bar,
		}, { Ui.corner(UDim.new(1, 0)) })
		local count = Ui.plainLabel({
			Name = "Count",
			Position = UDim2.new(1, -230, 0, 38),
			Size = UDim2.fromOffset(80, 24),
			TextColor3 = C.Ink,
			Parent = frame,
		})
		local reward = Ui.plainLabel({
			Name = "Reward",
			Position = UDim2.fromOffset(14, 60),
			Size = UDim2.new(1, -170, 0, 20),
			TextColor3 = Color3.fromRGB(60, 140, 60),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local claim = Ui.button({
			Name = "Claim",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(140, 60),
			Text = "NOT YET",
			Parent = frame,
		}, C.Grey)
		claim.Activated:Connect(function()
			local b = slots()[i]
			if b and Bounties.isDone(b) then
				Sound.play("Reward")
				claimRemote:FireServer(i)
			else
				Sound.play("UiClick")
			end
		end)
		rows[i] = { frame = frame, text = text, fill = fill, count = count, reward = reward, claim = claim }
	end
	footer = Ui.plainLabel({
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = C.Ink,
		Parent = p.body,
	})
	HudController.registerModal(panel)

	tracker.Activated:Connect(function()
		Sound.play("UiClick")
		panel.Visible = not panel.Visible
		if panel.Visible then
			Ui.pop(panel, 0.1)
			refresh()
		end
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(refresh)
end

function BountyController.init()
	build()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	claimRemote = remotes:WaitForChild("ClaimBounty") :: RemoteEvent
	local done = remotes:WaitForChild("BountyDone") :: RemoteEvent
	done.OnClientEvent:Connect(function(_slot: number, description: string)
		Sound.play("Reward")
		HudController.toast("📜 Bounty done: " .. description .. "! Tap to claim", C.Gold, 3.5)
		Ui.pop(tracker, 0.15)
	end)
	ClientState.Changed:Connect(refresh)
	refresh()
end

-- The board (tests).
function BountyController.panel(): Frame
	return panel
end

return BountyController
