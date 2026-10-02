--!strict
-- Pets (PetService on the server):
--  * every player's pet that's out (character attribute "Pet") follows them
--    around, drawn here on each client: it trots behind them with a little
--    hop, or flutters at shoulder height for flying pets. Higher levels are
--    a bit bigger.
--  * the egg reveal when you dig one up (hatched / leveled up / maxed).
--  * the Pets window (top button, once you have a pet): all pets, which
--    ones you have and where the others hatch, and which one is out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Config = require(ReplicatedStorage.Shared.Config.Pets)
local CurrentWorld = require(ReplicatedStorage.Shared.Logic.CurrentWorld)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local PetBuilder = require(ReplicatedStorage.Shared.Builders.PetBuilder)
local Pets = require(ReplicatedStorage.Shared.Logic.Pets)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Effects = require(script.Parent.Parent.Effects)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors

local PetController = {}

type Follower = {
	id: string,
	level: number,
	model: Model,
	position: Vector3,
	look: Vector3,
	phase: number,
}

local followers: { [Model]: Follower } = {} -- character -> its pet
local folder: Folder
local button: TextButton
local panel: Frame? = nil
local grid: ScrollingFrame
local equipRemote: RemoteEvent

------------------------------------------------------------------ following

local function remove(character: Model)
	local f = followers[character]
	if f then
		f.model:Destroy()
		followers[character] = nil
	end
end

-- Builds / swaps / removes the pets to match every character's attributes.
local function sync()
	local seen: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			local id = character:GetAttribute("Pet")
			local level = character:GetAttribute("PetLevel")
			if type(id) == "string" and Pets.byId[id] then
				seen[character] = true
				local f = followers[character]
				local lvl = if type(level) == "number" then level else 1
				if not f or f.id ~= id or f.level ~= lvl then
					remove(character)
					local model = PetBuilder.build(id)
					if model then
						model:ScaleTo(1 + 0.06 * (math.min(lvl, Config.maxLevel) - 1))
						local start = root.Position + root.CFrame.RightVector * 2.6
						model:PivotTo(CFrame.new(start))
						model.Parent = folder
						followers[character] = {
							id = id,
							level = lvl,
							model = model,
							position = start,
							look = root.CFrame.LookVector,
							phase = math.random() * 6,
						}
					end
				end
			end
		end
	end
	for character in followers do
		if not seen[character] then
			remove(character)
		end
	end
end

local function step(dt: number)
	local alpha = 1 - math.exp(-dt * 7)
	local t = os.clock()
	for character, f in followers do
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not character.Parent then
			remove(character)
			continue
		end
		local pet = Pets.byId[f.id]
		-- Behind and to the right of the owner, feet on the ground.
		local cf = root.CFrame
		local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		local forward = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.new(0, 0, -1)
		local right = Vector3.new(-forward.Z, 0, forward.X)
		local ground = root.Position.Y - 3
		local target = root.Position + right * 2.8 - forward * 2.2
		target = Vector3.new(target.X, ground, target.Z)
		local before = f.position
		f.position = before:Lerp(target, alpha)
		local moved = Vector3.new(f.position.X - before.X, 0, f.position.Z - before.Z)
		local speed = moved.Magnitude / math.max(dt, 1e-3)
		if moved.Magnitude > 0.01 then
			f.look = moved.Unit
		elseif (f.look - forward).Magnitude > 0.01 then
			f.look = f.look:Lerp(forward, alpha).Unit
		end
		local y = f.position.Y
		if pet.fly then
			y += 3.2 + math.sin(t * 3 + f.phase) * 0.4
		elseif speed > 2 then
			y += math.abs(math.sin(t * 11 + f.phase)) * 0.5
		end
		local p = Vector3.new(f.position.X, y, f.position.Z)
		f.model:PivotTo(CFrame.lookAt(p, p + f.look))
	end
end

------------------------------------------------------------------ the window

local function areaText(pet: Config.Pet): string
	if pet.world ~= CurrentWorld.id() then
		return if pet.world == "Frost" then "Hatches in Frostbite Peaks" else "Hatches on the Island"
	end
	local def = Areas.Defs[pet.area]
	return "Hatches in the " .. (if def then def.displayName else pet.area)
end

local function card(pet: Config.Pet, order: number, data: { [string]: any })
	local level = Pets.level(data, pet.id)
	local owned = level > 0
	local out = Pets.equipped(data) == pet.id
	local rarity = Rarities.Info[pet.rarity]
	local frame = Ui.new("Frame", {
		Name = "Pet_" .. pet.id,
		LayoutOrder = order,
		BackgroundColor3 = if owned then Color3.new(1, 1, 1) else Color3.fromRGB(225, 218, 205),
		Parent = grid,
	}, {
		Ui.corner(UDim.new(0, 16)),
		Ui.stroke(if out then 5 else 3, if out then C.Gold else nil),
	})
	Ui.plainLabel({
		Name = "Icon",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 46),
		Text = if owned then pet.icon else "❓",
		TextScaled = true,
		Parent = frame,
	})
	Ui.plainLabel({
		Name = "Name",
		Position = UDim2.fromOffset(6, 54),
		Size = UDim2.new(1, -12, 0, 22),
		Font = Ui.TitleFont,
		Text = if owned then pet.name else "???",
		TextColor3 = C.Ink,
		TextScaled = true,
		Parent = frame,
	})
	Ui.plainLabel({
		Name = "Rarity",
		Position = UDim2.fromOffset(6, 76),
		Size = UDim2.new(1, -12, 0, 18),
		Text = string.upper(rarity.displayName),
		TextColor3 = Color3.fromHex(rarity.color):Lerp(Color3.new(0, 0, 0), 0.25),
		Parent = frame,
	})
	Ui.plainLabel({
		Name = "Info",
		Position = UDim2.fromOffset(6, 94),
		Size = UDim2.new(1, -12, 0, 30),
		Text = if owned
			then string.format("Lv %d · %s", level, Pets.describe(pet.id, level))
			else areaText(pet),
		TextColor3 = C.Ink,
		TextWrapped = true,
		TextScaled = true,
		Parent = frame,
	})
	if owned then
		local b = Ui.button({
			Name = "Equip",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -16, 0, 34),
			Text = if out then "OUT ✓" else "TAKE OUT",
			Parent = frame,
		}, if out then C.Gold else C.Green)
		b.Activated:Connect(function()
			Sound.play("UiClick")
			equipRemote:FireServer(if out then "" else pet.id)
		end)
	end
end

local function refresh()
	local data = ClientState.data :: any
	local count = if data then Pets.count(data) else 0
	button.Visible = count > 0
	HudController.setBadge(button, false)
	if not panel or not (panel :: Frame).Visible or not data then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	-- This world's pets first.
	local order = 0
	for _, pass in { true, false } do
		for _, pet in Config.list do
			if (pet.world == CurrentWorld.id()) == pass then
				order += 1
				card(pet, order, data)
			end
		end
	end
end

local function build()
	local p = Ui.panel({
		name = "Pets",
		title = "PETS",
		icon = "🐾",
		accent = C.Green,
		width = 640,
		height = 440,
		parent = HudController.root(),
		dim = true,
	})
	panel = p.root
	Ui.plainLabel({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 26),
		Text = "Pets hatch from eggs you dig up. The one that's out gives you bonus cash!",
		TextColor3 = C.Ink,
		Parent = p.body,
	})
	grid = Ui.new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Ink,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = p.body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(142, 176),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
	HudController.registerModal(panel :: Frame);
	(panel :: Frame):GetPropertyChangedSignal("Visible"):Connect(refresh)
end

function PetController.setOpen(open: boolean)
	if open and not panel then
		build()
	end
	local p = panel
	if not p then
		return
	end
	p.Visible = open
	if open then
		Sound.play("UiClick")
		Ui.pop(p, 0.1)
		refresh()
	end
end

------------------------------------------------------------------ hatching

local function onHatched(id: string, outcome: string, level: number, cash: number)
	local pet = Pets.byId[id]
	if not pet then
		return
	end
	local color = Color3.fromHex(Rarities.Info[pet.rarity].color)
	Sound.play("Squeak", 0.8, 0.7)
	HudController.bigText("🥚 You dug up an egg!", C.White, 1.2)
	task.delay(1.2, function()
		Sound.play("Reward")
		if outcome == "New" then
			HudController.bigText(pet.icon .. " " .. pet.name .. " hatched!", color, 3)
			HudController.toast(
				string.format(
					"New pet! %s while it's out. Tap 🐾 Pets to choose.",
					Pets.describe(id, level)
				),
				C.Gold,
				4.5
			)
		elseif outcome == "LevelUp" then
			HudController.bigText(
				string.format("%s %s is now level %d!", pet.icon, pet.name, level),
				color,
				3
			)
			HudController.toast("Level up: " .. Pets.describe(id, level) .. " while it's out", C.Gold, 4)
		else
			HudController.bigText(pet.icon .. " " .. pet.name .. " is maxed!", color, 3)
			HudController.toast("It turned into " .. Format.cash(cash) .. "!", C.Gold, 4)
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			Effects.sparkles(root.Position + Vector3.new(0, 1, 0), color, 30)
		end
		if outcome == "New" then
			HudController.setBadge(button, true)
			Ui.pop(button, 0.2)
		end
	end)
end

function PetController.init()
	folder = Instance.new("Folder")
	folder.Name = "PetModels"
	folder.Parent = workspace
	button = HudController.addTopButton("PetsButton", "🐾", "Pets", C.Green, 1)
	button.Visible = false
	button.Activated:Connect(function()
		PetController.setOpen(not (panel ~= nil and (panel :: Frame).Visible))
	end)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	equipRemote = remotes:WaitForChild("EquipPet") :: RemoteEvent
	local hatched = remotes:WaitForChild("PetHatched") :: RemoteEvent
	hatched.OnClientEvent:Connect(onHatched)
	ClientState.Changed:Connect(refresh)
	refresh()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.5 then
			accumulator = 0
			sync()
		end
		step(dt)
	end)
end

-- Pets being drawn right now, by owner name (tests).
function PetController.following(): { [string]: string }
	local out = {}
	for character, f in followers do
		out[character.Name] = f.id
	end
	return out
end

-- The Pets window (tests).
function PetController.panel(): Frame?
	return panel
end

return PetController
