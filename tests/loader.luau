-- Mounts src/shared as a virtual instance tree (ReplicatedStorage.Shared) so
-- shared modules load unchanged in Lune, including `require(script.Parent.X)`.
-- Only pure modules (no Roblox services) can be loaded this way.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local baseEnv = getfenv()

---------------------------------------------------------------------------
-- Virtual instance tree
---------------------------------------------------------------------------

local NodeMethods = {}
local NodeMeta = {}

local function newNode(name: string, parent: any, file: string?)
	return setmetatable({ Name = name, Parent = parent, _file = file, _children = {} }, NodeMeta)
end

NodeMeta.__index = function(self, key)
	local method = NodeMethods[key]
	if method then
		return method
	end
	local child = rawget(self, "_children")[key]
	if child then
		return child
	end
	error(string.format("%s is not a valid member of %s", tostring(key), rawget(self, "Name")), 2)
end
NodeMeta.__tostring = function(self)
	return rawget(self, "Name")
end

function NodeMethods.FindFirstChild(self, name)
	return rawget(self, "_children")[name]
end
function NodeMethods.WaitForChild(self, name)
	local child = rawget(self, "_children")[name]
	assert(child, "WaitForChild would hang: " .. name)
	return child
end
function NodeMethods.GetChildren(self)
	local list = {}
	for _, child in rawget(self, "_children") do
		table.insert(list, child)
	end
	return list
end

local function mount(dir: string, name: string, parent: any)
	local initFile = dir .. "/init.luau"
	local node = newNode(name, parent, if fs.isFile(initFile) then initFile else nil)
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			rawget(node, "_children")[entry] = mount(path, entry, node)
		elseif
			entry ~= "init.luau"
			and entry:match("%.luau$")
			and not entry:match("%.server%.luau$")
			and not entry:match("%.client%.luau$")
		then
			local childName = entry:gsub("%.luau$", "")
			rawget(node, "_children")[childName] = newNode(childName, node, path)
		end
	end
	return node
end

-- A module loader with its own cache. `globals` are extra globals the
-- modules see (e.g. a `workspace` saying which world this is).
local function newLoader(globals: { [string]: any }?)
	local moduleCache = {}
	local function requireNode(node)
		local cached = moduleCache[node]
		if cached ~= nil then
			return cached.value
		end
		local file = rawget(node, "_file")
		assert(file, "Cannot require non-module " .. rawget(node, "Name"))
		-- (luau.load only sees the env's own keys, so globals are copied in.)
		local env = setmetatable({ script = node, require = requireNode }, { __index = baseEnv })
		for key, value in globals or {} do
			env[key] = value
		end
		local chunk = luau.load(fs.readFile(file), { debugName = file, environment = env })
		local value = chunk()
		moduleCache[node] = { value = value }
		return value
	end
	return requireNode
end

local Shared = mount("src/shared", "Shared", nil)

local function requirer(requireNode)
	return function(path: string)
		local node = Shared
		for part in path:gmatch("[^/]+") do
			node = node[part]
		end
		return requireNode(node)
	end
end

-- The island (no world set).
local requireShared = requirer(newLoader())

-- Shared modules as another world's servers and clients load them
-- (Logic/CurrentWorld reads the workspace's WorldId).
local function requireSharedIn(worldId: string)
	local workspace = {
		GetAttribute = function(_self, key: string)
			return if key == "WorldId" then worldId else nil
		end,
	}
	return requirer(newLoader({ workspace = workspace }))
end

return {
	requireShared = requireShared,
	requireSharedIn = requireSharedIn,
	baseEnv = baseEnv,
}
