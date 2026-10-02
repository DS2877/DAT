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
local PerkController = require(script.Parent.PerkController)

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
		"Become a %s: +%d%% cash forever, +%d%% walk speed, a new title and shovel color.\n"
			.. "Resets: cash, shovel, bag and bag contents.\nKeeps: collection, trophies, rank, perks and purchases.\n"
			.. "Every rebirth: pick a new PERK card!",
		Rebirth.title(next),
		bonus,
		math.floor(
			math.min(Retention.rebirth.maxWalkSpeedBonus, next * Retention.rebirth.walkSpeedPerRebirth) * 100
				+ 0.5
		)
	)
	local perks = PerkController.summary()
	if perks ~= "" then
		infoLabel.Text ..= "\nYour perks: " .. perks
	end
	local ok, reason, missing = Rebirth.canRebirth(data :: any)
	if reason == "IslandOnly" then
		infoLabel.Text = "A rebirth resets your island run, so it happens at the island's altar.\n"
			.. "Take the portal back to the island to rebirth. Your Frostbite Peaks progress stays."
	end
	if ok then
		button.Text = if confirming then "TAP AGAIN TO CONFIRM" else "REBIRTH (" .. Format.cash(cost) .. ")"
		Ui.setButtonColor(button, if confirming then C.Red else C.Purple)
	elseif reason == "IslandOnly" then
		button.Text = "Rebirth on the island"
		Ui.setButtonColor(button, C.Grey)
	elseif reason == "NeedShovel" then
		local shovel = Progression.getShovel(Retention.rebirth.requiredShovel)
		button.Text = "Needs the " .. shovel.name
		Ui.setButtonColor(button, C.Grey)
	else
		button.Text = "Need " .. Format.cash(missing) .. " more"
		Ui.setButtonColor(button, C.Grey)
	end
end

local function build()
	local p = Ui.panel({
		name = "RebirthPanel",
		title = "REBIRTH",
		icon = "✨",
		accent = C.Purple,
		width = 520,
		height = 340,
		parent = HudController.root(),
		position = UDim2.new(0.5, 0, 1, -20),
		anchor = Vector2.new(0.5, 1),
	})
	panel = p.root
	p.close.Visible = false
	infoLabel = Ui.plainLabel({
		Size = UDim2.new(1, 0, 1, -84),
		TextColor3 = C.Ink,
		TextWrapped = true,
		Parent = p.body,
	})
	button = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, -20, 0, 70),
		Parent = p.body,
	}, C.Purple)
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
