--!strict
-- The seagull hat thief on screen (SeagullService on the server): squawks
-- and a "SQUAWK!" bubble for everyone nearby, and for the robbed player a
-- toast and a "YOUR HAT" marker over the bird until they get it back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Seagull)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)

local C = Ui.Colors

local SeagullController = {}

local player = Players.LocalPlayer
local marker: BillboardGui? = nil
local perchedSince: number? = nil
local rng = Random.new()

local function pick(lines: { string }): string
	return lines[rng:NextInteger(1, #lines)]
end

local function bodyOf(model: Instance?): BasePart?
	local body = model and model:FindFirstChild("Body")
	return if body and body:IsA("BasePart") then body else nil
end

local function myDistance(position: Vector3): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then (root.Position - position).Magnitude else math.huge
end

-- Squawk (louder the closer you are) with a little bubble over the bird.
local function squawk(body: BasePart, mine: boolean)
	local distance = myDistance(body.Position)
	if not mine and distance > 120 then
		return
	end
	Sound.play("Squawk", if mine then 1 else math.clamp(1 - distance / 120, 0.15, 1))
	local gui = Ui.new("BillboardGui", {
		Name = "Squawk",
		Adornee = body,
		Size = UDim2.fromOffset(130, 44),
		StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
		MaxDistance = 120,
		LightInfluence = 0,
		AlwaysOnTop = true,
		Parent = body,
	})
	Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = "SQUAWK!",
		TextColor3 = C.White,
		Parent = gui,
	})
	task.delay(1.4, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function clearMarker()
	if marker then
		marker:Destroy()
		marker = nil
	end
	perchedSince = nil
end

-- "🎩 YOUR HAT!" over the bird, with how far it is.
local function mark(body: BasePart)
	clearMarker()
	local gui = Ui.new("BillboardGui", {
		Name = "HatMarker",
		Adornee = body,
		Size = UDim2.fromOffset(200, 56),
		StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0),
		LightInfluence = 0,
		AlwaysOnTop = true,
		Parent = body,
	})
	local label = Ui.label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Text = "🎩 YOUR HAT!",
		TextColor3 = C.Gold,
		Parent = gui,
	})
	marker = gui
	task.spawn(function()
		while marker == gui and gui.Parent do
			local distance = math.floor(myDistance(body.Position))
			label.Text = if distance < 1000
				then string.format("🎩 YOUR HAT!\n%d studs", distance)
				else "🎩 YOUR HAT!"
			-- It taunts you now and then.
			if perchedSince and os.clock() - perchedSince > 6 and rng:NextNumber() < 0.08 then
				squawk(body, true)
			end
			task.wait(0.5)
		end
	end)
end

local function onEvent(kind: string, userId: number, info: { [string]: any })
	local mine = userId == player.UserId
	local body = bodyOf(info and info.model)
	if kind == "Steal" then
		if body then
			squawk(body, mine)
			if mine then
				Sound.play("Wings")
				mark(body)
			end
		end
		if mine then
			HudController.bigText(pick(Config.lines.steal), C.Orange, 2.5)
		end
	elseif kind == "Perch" then
		if mine then
			perchedSince = os.clock()
			HudController.toast("🌴 " .. Config.lines.perch, C.Gold, 5)
		end
		if body then
			squawk(body, mine)
		end
	elseif kind == "Return" then
		if mine then
			clearMarker()
			Sound.play("Reward")
			local cash = info and info.cash or 0
			HudController.toast(pick(Config.lines.back) .. " +" .. Format.cash(cash), C.Gold, 4)
		end
		if body then
			squawk(body, mine)
		end
	elseif kind == "GiveUp" then
		if mine then
			clearMarker()
			HudController.toast(Config.lines.giveUp, C.White, 4)
		end
	end
end

function SeagullController.init()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Seagull") :: RemoteEvent
	remote.OnClientEvent:Connect(onEvent)
	player.CharacterAdded:Connect(clearMarker)
end

-- The "YOUR HAT" marker is up (tests).
function SeagullController.marked(): boolean
	return marker ~= nil
end

return SeagullController
