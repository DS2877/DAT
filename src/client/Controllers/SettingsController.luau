--!strict
-- The ⚙️ Settings panel: music and sound effects on/off. Saved in the
-- player's profile (SetSetting), applied right away by AudioController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors

local SettingsController = {}

type Toggle = { key: string, button: TextButton }

local panel: Frame
local toggles: { Toggle } = {}
local pending: { [string]: boolean } = {}

local function current(key: string): boolean
	if pending[key] ~= nil then
		return pending[key]
	end
	local data = ClientState.data
	local settings = data and data.settings
	return not settings or (settings :: any)[key] ~= false
end

local function refresh()
	for _, t in toggles do
		local on = current(t.key)
		t.button.Text = if on then "ON" else "OFF"
		Ui.setButtonColor(t.button, if on then C.Green else C.Grey)
	end
end

local function build()
	local p = Ui.panel({
		name = "Settings",
		title = "SETTINGS",
		icon = "⚙️",
		accent = C.Blue,
		width = 480,
		height = 290,
		parent = HudController.root(),
		dim = true,
	})
	panel = p.root
	HudController.registerModal(panel)
	local list = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = p.body,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, entry in { { "music", "🎵  Music" }, { "sounds", "🔊  Sounds" } } do
		local row = Ui.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.3,
			Parent = list,
		}, { Ui.corner(UDim.new(0, 16)), Ui.stroke(3) })
		Ui.plainLabel({
			Position = UDim2.fromOffset(18, 14),
			Size = UDim2.new(1, -180, 1, -28),
			Font = Ui.TitleFont,
			Text = entry[2],
			TextColor3 = C.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local button = Ui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 52),
			Text = "ON",
			Parent = row,
		}, C.Green)
		local key = entry[1]
		button.Activated:Connect(function()
			local on = not current(key)
			pending[key] = on
			-- Apply at once; the server saves it.
			if key == "music" then
				Sound.setGroupEnabled("Music", on)
			else
				Sound.setGroupEnabled("Effects", on)
				Sound.setGroupEnabled("Ambience", on)
			end
			Sound.play("UiClick")
			refresh()
			local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSetting") :: RemoteEvent
			remote:FireServer(key, on)
		end)
		table.insert(toggles, { key = key, button = button })
	end
	refresh()
end

function SettingsController.init()
	build()
	local button = HudController.addTopButton("SettingsButton", "⚙️", "Settings", C.Grey, 5)
	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			Sound.play("UiClick")
			refresh()
		end
	end)
	ClientState.Changed:Connect(function()
		-- The server's copy wins once it arrives.
		table.clear(pending)
		refresh()
	end)
end

return SettingsController
