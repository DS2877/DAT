--!strict
-- The ⚙️ Settings panel: music and sound effects on/off, an on/off switch
-- for every pass the player owns, using saved Instant Deep Digs, and
-- pause / resume for every running timed boost (bought boosts, drinks,
-- rewards). Saved in the player's profile; audio applies at once. The
-- Shop's pass cards use the same switches (SettingsController.set).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors

local SettingsController = {}

-- Fired (key, on) when a setting is switched on this client.
SettingsController.Changed = Signal.new()

-- A row is a setting (`key`) or a timed boost (`boost`).
type Row = {
	key: string,
	pass: string?,
	boost: string?,
	label: string,
	frame: Frame,
	button: TextButton,
	text: TextLabel,
}

local ROWS: { { key: string, label: string, pass: string?, boost: string?, order: number } } = {
	{ key = "music", label = "🎵  Music", order = -2 },
	{ key = "sounds", label = "🔊  Sounds", order = -1 },
	{ key = "instantDeepDig", label = "🌋  Use saved Instant Deep Digs", order = 50 },
}
for boostId, def in Retention.boosts do
	table.insert(ROWS, { key = "boost:" .. boostId, label = def.displayName, boost = boostId, order = 100 })
end
for passKey, pass in Monetization.Passes do
	if pass.toggle and pass.enabled ~= false then
		table.insert(
			ROWS,
			{ key = pass.toggle, label = pass.emoji .. "  " .. pass.name, pass = passKey, order = pass.order }
		)
	end
end
table.sort(ROWS, function(a, b)
	return a.order < b.order
end)

local panel: Frame
local rows: { Row } = {}
local pending: { [string]: boolean } = {}

-- The current value of a setting (a switch not yet saved counts at once).
function SettingsController.current(key: string): boolean
	if pending[key] ~= nil then
		return pending[key]
	end
	local data = ClientState.data
	local settings = data and data.settings
	return not settings or (settings :: any)[key] ~= false
end

local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function refresh()
	local data = ClientState.data
	local now = os.time()
	for _, row in rows do
		if row.boost then
			-- Running (ON) or paused (OFF), with the time left.
			local left = if data then Boosts.secondsLeft(data.activeBoosts, row.boost, now) else 0
			local paused = if data and data.pausedBoosts then data.pausedBoosts[row.boost] or 0 else 0
			row.frame.Visible = left > 0 or paused > 0
			local on = left > 0
			row.text.Text = row.label .. "  " .. clock(math.floor(if on then left else paused))
			row.button.Text = if on then "ON" else "PAUSED"
			Ui.setButtonColor(row.button, if on then C.Green else C.Grey)
			continue
		end
		if row.pass then
			row.frame.Visible = ClientState.hasPass(row.pass)
		elseif row.key == "instantDeepDig" then
			row.frame.Visible = data ~= nil and (data.instantDeepDigs or 0) > 0
		end
		local on = SettingsController.current(row.key)
		row.button.Text = if on then "ON" else "OFF"
		Ui.setButtonColor(row.button, if on then C.Green else C.Grey)
	end
end

-- Switches a setting: applies it on this client right away and saves it.
function SettingsController.set(key: string, on: boolean)
	pending[key] = on
	if key == "music" then
		Sound.setGroupEnabled("Music", on)
	elseif key == "sounds" then
		Sound.setGroupEnabled("Effects", on)
		Sound.setGroupEnabled("Ambience", on)
	end
	Sound.play("UiClick")
	refresh()
	SettingsController.Changed:Fire(key, on)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSetting") :: RemoteEvent
	remote:FireServer(key, on)
end

local function build()
	local p = Ui.panel({
		name = "Settings",
		title = "SETTINGS",
		icon = "⚙️",
		accent = C.Blue,
		width = 480,
		height = 560,
		parent = HudController.root(),
		dim = true,
	})
	panel = p.root
	HudController.registerModal(panel)
	local list = Ui.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = p.body,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, entry in ROWS do
		local frame = Ui.new("Frame", {
			Name = entry.key,
			LayoutOrder = i,
			Size = UDim2.new(1, -10, 0, 72),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.3,
			Parent = list,
		}, { Ui.corner(UDim.new(0, 16)), Ui.stroke(3) })
		local text = Ui.plainLabel({
			Name = "Label",
			Position = UDim2.fromOffset(18, 14),
			Size = UDim2.new(1, -180, 1, -28),
			Font = Ui.TitleFont,
			Text = entry.label,
			TextColor3 = C.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local button = Ui.button({
			Name = "Toggle",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 52),
			Text = "ON",
			Parent = frame,
		}, C.Green)
		local key = entry.key
		local boost = entry.boost
		button.Activated:Connect(function()
			if boost then
				local data = ClientState.data
				local running = data ~= nil and Boosts.secondsLeft(data.activeBoosts, boost, os.time()) > 0
				Sound.play("UiClick")
				local remote =
					ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PauseBoost") :: RemoteEvent
				remote:FireServer(boost, running)
				return
			end
			SettingsController.set(key, not SettingsController.current(key))
		end)
		table.insert(rows, {
			key = key,
			pass = entry.pass,
			boost = boost,
			label = entry.label,
			frame = frame,
			button = button,
			text = text,
		})
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
	-- Boost timers tick while the panel is open.
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible then
				refresh()
			end
		end
	end)
end

return SettingsController
