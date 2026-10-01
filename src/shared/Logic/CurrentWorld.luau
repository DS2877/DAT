--!strict
-- Which world this server (and its clients) is: "Island" or "Frost". The
-- server decides it when it starts (WorldSelect) and stores it as the
-- workspace's "WorldId" attribute before anything else loads, so world-
-- dependent config (shovels, areas, treasures) is picked at require time.
-- Outside Roblox (unit tests) it's always the island.

local CurrentWorld = {}

function CurrentWorld.id(): string
	local ok, value = pcall(function()
		return (workspace :: any):GetAttribute("WorldId")
	end)
	return if ok and type(value) == "string" and value ~= "" then value else "Island"
end

function CurrentWorld.isFrost(): boolean
	return CurrentWorld.id() == "Frost"
end

return CurrentWorld
