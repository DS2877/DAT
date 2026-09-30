--!strict
-- Opens area gate barriers locally for players who have unlocked the area
-- (the server's AreaService remains the authority on where players may be).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Logic.Progression)
local ClientState = require(script.Parent.ClientState)

local GateController = {}

local barriers: { BasePart } = {}

local function refresh()
	local data = ClientState.data
	if not data then
		return
	end
	for _, barrier in barriers do
		local areaId = barrier:GetAttribute("AreaId") :: string
		local open = Progression.isAreaUnlocked(areaId, data.shovelLevel)
		barrier.CanCollide = not open
		barrier.Transparency = if open then 0.85 else 0.1
		-- The sign above the gate (built by the server) reads "UNLOCKED!" for us.
		local label = barrier:FindFirstChild("Label")
		local subtitle = label and label:FindFirstChild("Subtitle")
		if subtitle and subtitle:IsA("TextLabel") then
			if open then
				subtitle.Text = "UNLOCKED!"
				subtitle.TextColor3 = Color3.fromRGB(120, 255, 120)
			else
				local original = subtitle:GetAttribute("OriginalText")
				if original then
					subtitle.Text = original :: string
					subtitle.TextColor3 = Color3.new(1, 1, 1)
				end
			end
		end
	end
end

function GateController.init()
	local gates = workspace:WaitForChild("Gates")
	for _, descendant in gates:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("AreaId") then
			table.insert(barriers, descendant)
			local label = descendant:FindFirstChild("Label")
			local subtitle = label and label:FindFirstChild("Subtitle")
			if subtitle and subtitle:IsA("TextLabel") then
				subtitle:SetAttribute("OriginalText", subtitle.Text)
			end
		end
	end
	ClientState.Changed:Connect(refresh)
	refresh()
end

return GateController
