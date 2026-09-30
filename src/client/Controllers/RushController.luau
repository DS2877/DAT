--!strict
-- Treasure Rush on the client: the accurate countdown under the goal bar
-- ("Treasure Rush in 3:12"), a big announcement when it starts, and extra
-- sparkles on every dig spot while it runs. The schedule is a global clock
-- shared with the server (Logic/Rush), so the countdown is exact.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Retention = require(ReplicatedStorage.Shared.Config.Retention)
local Rush = require(ReplicatedStorage.Shared.Logic.Rush)
local Sound = require(script.Parent.Parent.Sound)
local Ui = require(script.Parent.Parent.Ui)
local HudController = require(script.Parent.HudController)

local RushController = {}

local wasActive: boolean? = nil
local spotsFolder: Folder

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function setSparkles(spot: Instance, on: boolean)
	if not spot:IsA("Model") then
		return
	end
	local mound = spot:FindFirstChild("Mound")
	if not mound then
		return
	end
	local existing = mound:FindFirstChild("RushSparkles")
	if on and not existing then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "RushSparkles"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 214, 80), Color3.new(1, 1, 1))
		emitter.LightEmission = 1
		emitter.Rate = 10
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(2, 5)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		emitter.Parent = mound
	elseif not on and existing then
		existing:Destroy()
	end
end

local function update()
	local active, seconds = Rush.state(workspace:GetServerTimeNow())
	if active then
		HudController.setRushText("✨ TREASURE RUSH! " .. clock(seconds) .. " left ✨", true)
	else
		HudController.setRushText("Treasure Rush in " .. clock(seconds), false)
	end
	if active ~= wasActive then
		if active and wasActive == false then
			Sound.play("AreaUnlocked", 0.8)
			HudController.bigText("TREASURE RUSH!", Ui.Colors.Gold, 2.5)
			HudController.toast(
				string.format("Better treasure for %d minutes!", Retention.rush.duration // 60),
				Ui.Colors.Gold,
				4
			)
		end
		wasActive = active
		for _, spot in spotsFolder:GetChildren() do
			setSparkles(spot, active)
		end
	end
end

function RushController.init()
	spotsFolder = workspace:WaitForChild("DigSpots") :: Folder
	spotsFolder.ChildAdded:Connect(function(spot)
		if wasActive then
			setSparkles(spot, true)
		end
	end)
	task.spawn(function()
		while true do
			update()
			task.wait(0.5)
		end
	end)
end

return RushController
