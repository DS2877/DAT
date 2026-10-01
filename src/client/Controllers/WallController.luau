--!strict
-- One-way area walls: the invisible walls along the cliffs (and the Jungle |
-- Ruins ridge) stop players climbing INTO an area, but a player who is
-- inside can walk or jump straight out. Collision is switched off locally
-- for this player while they're on the inside of a wall (this client
-- moves its own character, so only this player passes through).

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local WallController = {}

-- Studs: past this far inside, the wall opens; it closes again only once
-- the player is this far outside (so it never closes while they're in it).
local OPEN_INSIDE = 0.5
local CLOSE_OUTSIDE = 3

type Wall = { part: BasePart, inside: Vector3, plane: Vector3, open: boolean }

local walls: { Wall } = {}

local function collect(folder: Instance)
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("OneWay") then
			table.insert(walls, {
				part = child,
				inside = Vector3.new(
					child:GetAttribute("InsideX") :: number,
					0,
					child:GetAttribute("InsideZ") :: number
				),
				plane = Vector3.new(
					child:GetAttribute("PlaneX") :: number,
					0,
					child:GetAttribute("PlaneZ") :: number
				),
				open = false,
			})
		end
	end
end

local function update()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local position = Vector3.new(root.Position.X, 0, root.Position.Z)
	for _, wall in walls do
		local depth = (position - wall.plane):Dot(wall.inside)
		local open = if depth > OPEN_INSIDE then true elseif depth < -CLOSE_OUTSIDE then false else wall.open
		if open ~= wall.open then
			wall.open = open
			wall.part.CanCollide = not open
		end
	end
end

-- True if this player can currently pass through the wall (tests).
function WallController.isOpen(part: BasePart): boolean
	for _, wall in walls do
		if wall.part == part then
			return wall.open
		end
	end
	return false
end

function WallController.init()
	task.spawn(function()
		local folder = workspace:WaitForChild("Walls", 30)
		if not folder then
			return
		end
		collect(folder)
		while true do
			update()
			task.wait(0.1)
		end
	end)
end

return WallController
