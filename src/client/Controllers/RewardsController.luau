--!strict
-- Free rewards on the client:
--   * Daily button + 7-day calendar panel (with the group reward, if set up)
--   * Playtime gift widget ("🎁 Gift in 3:12" / CLAIM)
--   * Invite button (Roblox's official invite prompt)
--   * Chips for active boosts, friends bonus and guaranteed-dig charges
--   * The player's daily Golden X dig spot (client-only; the server knows
--     where it is and validates digs on it)

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local Bonuses = require(ReplicatedStorage.Shared.Logic.Bonuses)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors
local player = Players.LocalPlayer

local RewardsController = {}

local remotes: Instance
local dailyButton: TextButton
local dailyPanel: Frame
local dayCells: { Frame } = {}
local claimButton: TextButton
local groupButton: TextButton?
local giftButton: TextButton
local goldenModel: Model? = nil
local goldenKey = ""
local openedDailyThisSession = false

local function fire(name: string, ...: any)
	(remotes:WaitForChild(name) :: RemoteEvent):FireServer(...)
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function describeReward(reward: { [string]: any }): string
	local kind = reward.kind
	if kind == "Cash" then
		local data = ClientState.data
		return if data then Format.cash(Bonuses.rewardCash(reward, data :: any)) else "Cash"
	elseif kind == "Boost" then
		return string.format("%s %dm", Retention.boosts[reward.boost].displayName, reward.seconds // 60)
	elseif kind == "RareDig" then
		return reward.count .. "x Rare dig"
	elseif kind == "EpicDig" then
		return reward.count .. "x Epic dig"
	elseif kind == "Bundle" then
		local parts = {}
		for _, item in reward.items do
			table.insert(parts, describeReward(item))
		end
		return table.concat(parts, " + ")
	end
	return ""
end

---------------------------------------------------------------------------
-- Daily panel
---------------------------------------------------------------------------

local function refreshDaily()
	local data = ClientState.data
	if not data then
		return
	end
	HudController.setBadge(dailyButton, data.dailyCanClaim)
	for day, cell in dayCells do
		local label = cell:FindFirstChild("Reward") :: TextLabel
		label.Text = describeReward(Retention.daily[day])
		local claimedToday = not data.dailyCanClaim and day == data.dailyStreak
		local isNext = data.dailyCanClaim and day == data.dailyDay
		cell.BackgroundColor3 = if isNext
			then C.Gold
			elseif claimedToday then C.Green
			else Color3.fromRGB(255, 252, 240)
	end
	if data.dailyCanClaim then
		claimButton.Text = "CLAIM DAY " .. data.dailyDay
		claimButton.BackgroundColor3 = C.Green
	else
		claimButton.Text = "Come back in " .. clock((os.time() // 86400 + 1) * 86400 - os.time())
		claimButton.BackgroundColor3 = C.Grey
	end
	if groupButton then
		groupButton.Visible = not data.groupRewardClaimed
	end
end

local function buildDaily()
	dailyPanel = Ui.new("Frame", {
		Name = "Daily",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(760, 400),
		BackgroundColor3 = C.Cream,
		Visible = false,
		ZIndex = 20,
		Parent = HudController.root(),
	}, { Ui.corner(UDim.new(0, 24)), Ui.stroke(5) })
	Ui.label({
		Position = UDim2.fromOffset(24, 10),
		Size = UDim2.new(0, 400, 0, 44),
		Font = Ui.TitleFont,
		Text = "DAILY REWARDS",
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = dailyPanel,
	})
	local close = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = C.Red,
		Font = Ui.TitleFont,
		Text = "X",
		TextScaled = true,
		TextColor3 = C.White,
		Parent = dailyPanel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(4), Ui.textStroke(2) })
	close.Activated:Connect(function()
		dailyPanel.Visible = false
	end)

	local row = Ui.new("Frame", {
		Position = UDim2.fromOffset(20, 70),
		Size = UDim2.new(1, -40, 0, 150),
		BackgroundTransparency = 1,
		Parent = dailyPanel,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	})
	for day = 1, #Retention.daily do
		local cell = Ui.new("Frame", {
			LayoutOrder = day,
			Size = UDim2.fromOffset(94, if day == #Retention.daily then 150 else 130),
			BackgroundColor3 = Color3.fromRGB(255, 252, 240),
			Parent = row,
		}, { Ui.corner(UDim.new(0, 12)), Ui.stroke(3) })
		Ui.label({
			Size = UDim2.new(1, 0, 0, 34),
			Font = Ui.TitleFont,
			Text = "DAY " .. day,
			Parent = cell,
		})
		local reward = Ui.label({
			Name = "Reward",
			Position = UDim2.fromOffset(4, 38),
			Size = UDim2.new(1, -8, 1, -44),
			TextColor3 = C.Ink,
			Parent = cell,
		})
		local outline = reward:FindFirstChildOfClass("UIStroke")
		if outline then
			outline:Destroy()
		end
		dayCells[day] = cell
	end
	Ui.label({
		Position = UDim2.fromOffset(20, 226),
		Size = UDim2.new(1, -40, 0, 24),
		Text = "Come back every day! Missing a day starts the calendar again at day 1.",
		TextColor3 = C.Ink,
		Parent = dailyPanel,
	})

	claimButton = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 262),
		Size = UDim2.fromOffset(360, 60),
		BackgroundColor3 = C.Green,
		Font = Ui.TitleFont,
		TextScaled = true,
		TextColor3 = C.White,
		Text = "CLAIM",
		Parent = dailyPanel,
	}, { Ui.corner(UDim.new(0, 16)), Ui.stroke(4), Ui.textStroke(3) })
	claimButton.Activated:Connect(function()
		local data = ClientState.data
		if data and data.dailyCanClaim then
			fire("ClaimDaily")
		end
	end)

	-- Group reward (only when a group is configured).
	local groupId = Retention.group.groupId
	if groupId ~= 0 then
		local button = Ui.new("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 330),
			Size = UDim2.fromOffset(460, 48),
			BackgroundColor3 = C.Blue,
			Font = Ui.Font,
			TextScaled = true,
			TextColor3 = C.White,
			Text = "Join our group for a free " .. describeReward(Retention.group.reward) .. "!",
			Parent = dailyPanel,
		}, { Ui.corner(UDim.new(0, 14)), Ui.stroke(3), Ui.textStroke(2) })
		button.Activated:Connect(function()
			task.spawn(function()
				local ok, status = pcall(function()
					return GroupService:PromptJoinAsync(groupId)
				end)
				if
					ok
					and (
						status == Enum.GroupMembershipStatus.Joined
						or status == Enum.GroupMembershipStatus.AlreadyMember
					)
				then
					fire("ClaimGroupReward")
				end
			end)
		end)
		groupButton = button
	end
end

---------------------------------------------------------------------------
-- Playtime gifts
---------------------------------------------------------------------------

-- The next unclaimed gift index and seconds until it's ready (<= 0 = ready).
local function nextGift(): (number?, number)
	local data = ClientState.data
	if not data then
		return nil, 0
	end
	local elapsed = workspace:GetServerTimeNow() - data.giftStart
	for index, gift in Retention.playtimeGifts do
		if not data.giftsClaimed[tostring(index)] then
			return index, gift.minutes * 60 - elapsed
		end
	end
	return nil, 0
end

local function refreshGift()
	local index, remaining = nextGift()
	if not index then
		giftButton.Visible = false
		return
	end
	giftButton.Visible = true
	if remaining <= 0 then
		giftButton.Text = "🎁 CLAIM GIFT!"
		giftButton.BackgroundColor3 = C.Green
	else
		giftButton.Text = "🎁 Gift in " .. clock(remaining)
		giftButton.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
	end
end

---------------------------------------------------------------------------
-- Chips (boosts, friends, charges)
---------------------------------------------------------------------------

local function refreshChips()
	local data = ClientState.data
	if not data then
		return
	end
	local chips = {}
	local now = os.time()
	for id, def in Retention.boosts do
		local left = Boosts.secondsLeft(data.activeBoosts, id, now)
		if left > 0 then
			table.insert(chips, { text = def.displayName .. " " .. clock(left), color = C.Gold })
		end
	end
	local friends = (player:GetAttribute("FriendsInServer") :: number?) or 0
	if friends > 0 then
		local bonus = math.floor(Bonuses.friendsBonus(friends) * 100 + 0.5)
		table.insert(chips, { text = string.format("Friends +%d%%", bonus), color = C.Green })
	end
	if data.digCharges.Epic > 0 then
		table.insert(chips, { text = data.digCharges.Epic .. "x Epic dig ready", color = C.Purple })
	end
	if data.digCharges.Rare > 0 then
		table.insert(chips, { text = data.digCharges.Rare .. "x Rare dig ready", color = C.Blue })
	end
	HudController.setChips(chips)
end

---------------------------------------------------------------------------
-- Golden X (client-only spot model, id -1)
---------------------------------------------------------------------------

local function buildGoldenX(position: Vector3, areaId: string): Model
	local model = Instance.new("Model")
	model.Name = "GoldenX"
	model:SetAttribute("SpotId", -1)
	model:SetAttribute("AreaId", areaId)
	local mound = Instance.new("Part")
	mound.Name = "Mound"
	mound.Shape = Enum.PartType.Cylinder
	mound.Size = Vector3.new(0.9, 6.5, 6.5)
	mound.CFrame = CFrame.new(position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	mound.Color = Color3.fromRGB(255, 201, 51)
	mound.Material = Enum.Material.Metal
	mound.Anchored = true
	mound.CanCollide = false
	mound.Parent = model
	model.PrimaryPart = mound
	for _, angle in { 45, -45 } do
		local mark = Instance.new("Part")
		mark.Size = Vector3.new(0.9, 0.25, 4.6)
		mark.CFrame = CFrame.new(position + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, math.rad(angle), 0)
		mark.Color = Color3.fromRGB(255, 240, 160)
		mark.Material = Enum.Material.Neon
		mark.Anchored = true
		mark.CanCollide = false
		mark.CanQuery = false
		mark.Parent = model
	end
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 214, 80))
	sparkles.LightEmission = 1
	sparkles.Rate = 20
	sparkles.Lifetime = NumberRange.new(1, 1.6)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.Parent = mound
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 201, 51)
	light.Range = 16
	light.Brightness = 2
	light.Parent = mound
	local label = Ui.new("BillboardGui", {
		Size = UDim2.fromScale(10, 2.4),
		StudsOffsetWorldSpace = Vector3.new(0, 5, 0),
		MaxDistance = 400,
		LightInfluence = 0,
		AlwaysOnTop = true,
		Adornee = mound,
		Parent = mound,
	})
	Ui.label({
		Size = UDim2.fromScale(1, 1),
		Font = Ui.TitleFont,
		Text = "✦ GOLDEN X ✦",
		TextColor3 = C.Gold,
		Parent = label,
	})
	return model
end

local function refreshGoldenX()
	local data = ClientState.data
	local golden = data and data.goldenX
	local key = if golden
		then string.format("%s|%.1f|%.1f", golden.areaId, golden.position.X, golden.position.Z)
		else ""
	if key == goldenKey then
		return
	end
	goldenKey = key
	if goldenModel then
		goldenModel:Destroy()
		goldenModel = nil
	end
	if golden then
		goldenModel = buildGoldenX(golden.position, golden.areaId)
		goldenModel.Parent = workspace:WaitForChild("LocalSpots")
	end
end

---------------------------------------------------------------------------

local function onChanged()
	refreshDaily()
	refreshGift()
	refreshChips()
	refreshGoldenX()
	local data = ClientState.data
	-- Show the calendar once per session when today's reward is waiting.
	if data and data.dailyCanClaim and not openedDailyThisSession then
		openedDailyThisSession = true
		task.delay(3, function()
			dailyPanel.Visible = true
			Ui.pop(dailyPanel, 0.06)
		end)
	end
end

function RewardsController.init()
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	dailyButton = HudController.addTopButton("DailyButton", "📅", "Daily", C.Orange, 2)
	buildDaily()
	dailyButton.Activated:Connect(function()
		dailyPanel.Visible = not dailyPanel.Visible
		if dailyPanel.Visible then
			Sound.play("UiClick", 0.5)
			refreshDaily()
		end
	end)

	local inviteButton = HudController.addTopButton("InviteButton", "💌", "Invite", C.Blue, 4)
	inviteButton.Activated:Connect(function()
		task.spawn(function()
			local ok, canInvite = pcall(function()
				return SocialService:CanSendGameInviteAsync(player)
			end)
			if ok and canInvite then
				pcall(function()
					SocialService:PromptGameInvite(player)
				end)
			else
				HudController.toast("Invites aren't available right now", C.Red)
			end
		end)
	end)

	giftButton = Ui.new("TextButton", {
		Name = "Gift",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 158),
		Size = UDim2.fromOffset(230, 44),
		BackgroundColor3 = Color3.fromRGB(35, 30, 40),
		Font = Ui.TitleFont,
		TextScaled = true,
		TextColor3 = C.White,
		Text = "🎁",
		Visible = false,
		Parent = HudController.root(),
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.stroke(3),
		Ui.textStroke(2),
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	})
	giftButton.Activated:Connect(function()
		local index, remaining = nextGift()
		if index and remaining <= 0 then
			fire("ClaimGift", index)
		end
	end)

	ClientState.Changed:Connect(onChanged)
	player:GetAttributeChangedSignal("FriendsInServer"):Connect(refreshChips)

	-- Timers tick once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			refreshGift()
			refreshChips()
			if dailyPanel.Visible then
				refreshDaily()
			end
		end
	end)
end

return RewardsController
