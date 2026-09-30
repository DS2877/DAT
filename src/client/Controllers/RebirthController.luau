--!strict
-- The rebirth altar panel: shows the requirement, exactly what resets and
-- what you keep, and asks for a second tap to confirm (it can't be undone).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors
local player = Players.LocalPlayer

local RebirthController = {}

local panel: Frame
local infoLabel: TextLabel
local button: TextButton
local pad: BasePart? = nil
local isOpen = false
local confirming = false

local function refresh()
	local data = ClientState.data
	if not data or not isOpen then
		return
	end
	local next = data.rebirths + 1
	local bonus = math.floor(next * Retention.rebirth.cashBonusPerRebirth * 100 + 0.5)
	local cost = Rebirth.cost(data.rebirths)
	infoLabel.Text = string.format(
		"Become a %s: +%d%% cash forever, a new title and shovel color.\n"
			.. "Resets: cash, shovel, bag and bag contents.\nKeeps: collection, trophies, rank and purchases.",
		Rebirth.title(next),
		bonus
	)
	local ok, reason, missing = Rebirth.canRebirth(data :: any)
	if ok then
		button.Text = if confirming then "TAP AGAIN TO CONFIRM" else "REBIRTH (" .. Format.cash(cost) .. ")"
		button.BackgroundColor3 = if confirming then C.Red else C.Purple
	elseif reason == "NeedShovel" then
		local shovel = Progression.getShovel(Retention.rebirth.requiredShovel)
		button.Text = "Needs the " .. shovel.name
		button.BackgroundColor3 = C.Grey
	else
		button.Text = "Need " .. Format.cash(missing) .. " more"
		button.BackgroundColor3 = C.Grey
	end
end

local function build()
	panel = Ui.new("Frame", {
		Name = "RebirthPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(480, 230),
		BackgroundColor3 = C.Cream,
		Visible = false,
		Parent = HudController.root(),
	}, { Ui.corner(UDim.new(0, 22)), Ui.stroke(5) })
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(300, 44),
		Font = Ui.TitleFont,
		Text = "REBIRTH",
		TextColor3 = C.Purple,
		Parent = panel,
	})
	infoLabel = Ui.label({
		Position = UDim2.fromOffset(16, 28),
		Size = UDim2.new(1, -32, 0, 100),
		TextColor3 = C.Ink,
		Parent = panel,
	})
	local outline = infoLabel:FindFirstChildOfClass("UIStroke")
	if outline then
		outline:Destroy()
	end
	button = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(1, -40, 0, 70),
		BackgroundColor3 = C.Purple,
		Font = Ui.TitleFont,
		TextScaled = true,
		TextColor3 = C.White,
		Parent = panel,
	}, {
		Ui.corner(UDim.new(0, 18)),
		Ui.stroke(4),
		Ui.textStroke(3),
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
	})
	button.Activated:Connect(function()
		local data = ClientState.data
		if not data or not Rebirth.canRebirth(data :: any) then
			return
		end
		if not confirming then
			confirming = true
			refresh()
			task.delay(4, function()
				confirming = false
				refresh()
			end)
			return
		end
		confirming = false
		local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth") :: RemoteEvent
		remote:FireServer()
	end)
end

function RebirthController.init()
	build()
	local base = workspace:WaitForChild("Base")
	for _, child in base:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Station") == "Rebirth" then
			pad = child
		end
	end
	ClientState.Changed:Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local inside = false
			if root and pad then
				local offset = root.Position - pad.Position
				local radius = (pad:GetAttribute("Radius") :: number?) or 9
				inside = Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) < 8
			end
			if inside ~= isOpen then
				isOpen = inside
				confirming = false
				panel.Visible = inside
				if inside then
					Ui.pop(panel, 0.1)
					refresh()
				end
			end
		end
	end)
end

return RebirthController
