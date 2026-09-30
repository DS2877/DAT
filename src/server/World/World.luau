--!strict
-- Holds the built world (filled once by the bootstrap from MapBuilder.build).

local MapBuilder = require(script.Parent.MapBuilder)

local World = {}

local built: MapBuilder.BuiltWorld? = nil

function World.set(world: MapBuilder.BuiltWorld)
	built = world
end

function World.get(): MapBuilder.BuiltWorld
	assert(built, "World not built yet")
	return built
end

return World
