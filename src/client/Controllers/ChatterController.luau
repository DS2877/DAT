--!strict
-- The island's people talk (Config/Chatter), only for you: speech bubbles
-- over their heads when you walk up to them, the merchant on what you just
-- sold (junk, big finds), and the shopkeepers on your upgrades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chatter = require(ReplicatedStorage.Shared.Config.Chatter)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Ui = require(script.Parent.Parent.Ui)

local ChatterController = {}

type Npc = { name: string, model: Model, head: BasePart, saidAt: number }

local npcs: { Npc } = {}
local byName: { [string]: { Npc } } = {}
local bubbles: { [Npc]: BillboardGui } = {}
local rng = Random.new()

local function pick(lines: { string }): string
	return lines[rng:NextInteger(1, #lines)]
end

-- Shows `text` in a bubble over the NPC (replacing what it was saying).
local function say(npc: Npc, text: string)
	local old = bubbles[npc]
	if old then
		old:Destroy()
	end
	npc.saidAt = os.clock()
	local gui = Ui.new("BillboardGui", {
		Name = "SpeechBubble",
		Adornee = npc.head,
		Size = UDim2.fromOffset(240, 72),
		StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0),
		MaxDistance = 90,
		LightInfluence = 0,
		AlwaysOnTop = true,
		Parent = npc.head,
	})
	local bubble = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, 0, 1, -10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = gui,
	}, {
		Ui.corner(UDim.new(0, 14)),
		Ui.new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(40, 30, 20) }),
		Ui.new("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})
	Ui.plainLabel({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Font = Ui.Font,
		Text = text,
		TextColor3 = Color3.fromRGB(40, 30, 20),
		TextScaled = true,
		TextWrapped = true,
		Parent = bubble,
	})
	-- The little tail under the bubble.
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(16, 16),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = gui,
	})
	Ui.pop(bubble, 0.15)
	bubbles[npc] = gui
	task.delay(Chatter.bubbleSeconds, function()
		-- (A newer line already replaced and destroyed this bubble otherwise.)
		if bubbles[npc] == gui then
			bubbles[npc] = nil
			gui:Destroy()
		end
	end)
end

-- The nearest NPC called `name` to the player (within `range`).
local function nearest(name: string, range: number): Npc?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best, bestDistance = nil, range
	for _, npc in byName[name] or {} do
		local d = (npc.head.Position - root.Position).Magnitude
		if d < bestDistance then
			best, bestDistance = npc, d
		end
	end
	return best
end

local function collect()
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and Chatter.greet[d.Name] then
			local head = d:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				local npc = { name = d.Name, model = d, head = head, saidAt = -math.huge }
				table.insert(npcs, npc)
				byName[d.Name] = byName[d.Name] or {}
				table.insert(byName[d.Name], npc)
			end
		end
	end
end

local function onSold(sale: { [string]: any })
	if sale.source ~= "Pad" then
		return
	end
	local npc = nearest("SellKeeper", 80)
	if not npc then
		return
	end
	local big = sale.best and Rarities.rank(sale.best) >= Rarities.rank("Legendary")
	local lines = if big
		then Chatter.sell.huge
		elseif (sale.junk or 0) > 0 then Chatter.sell.junk
		else Chatter.sell.normal
	say(npc, pick(lines))
end

local function onUpgrade(result: { [string]: any })
	local keeper = if result.kind == "Bag" then "BagKeeper" else "ShovelKeeper"
	local npc = nearest(keeper, 60)
	if not npc then
		return
	end
	if result.ok then
		local lines = Chatter.bought[result.kind] or Chatter.bought.Shovel
		say(npc, string.format(pick(lines), tostring(result.name)))
	elseif result.reason == "NotEnoughCash" then
		say(npc, pick(Chatter.broke))
	end
end

function ChatterController.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local sold = remotes:WaitForChild("Sold") :: RemoteEvent
	sold.OnClientEvent:Connect(onSold)
	local upgrade = remotes:WaitForChild("UpgradeResult") :: RemoteEvent
	upgrade.OnClientEvent:Connect(onUpgrade)
	task.spawn(function()
		workspace:WaitForChild("Base", 30)
		workspace:WaitForChild("Decor", 30)
		collect()
		-- Greetings: the nearest NPC in reach says hello now and then.
		while true do
			task.wait(0.5)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local now = os.clock()
				local best, bestDistance = nil, Chatter.greetDistance
				for _, npc in npcs do
					local d = (npc.head.Position - root.Position).Magnitude
					if d < bestDistance then
						best, bestDistance = npc, d
					end
				end
				if best and now - best.saidAt >= Chatter.greetCooldown then
					say(best, pick(Chatter.greet[best.name]))
				end
			end
		end
	end)
end

-- What an NPC is saying right now ("" if nothing; tests).
function ChatterController.saying(name: string): string
	for _, npc in byName[name] or {} do
		local gui = bubbles[npc]
		local label = gui and gui:FindFirstChild("Text", true)
		if label and label:IsA("TextLabel") then
			return label.Text
		end
	end
	return ""
end

return ChatterController
