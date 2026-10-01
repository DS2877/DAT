-- Headless Roblox harness (Lune). Loads the built place and runs its real
-- scripts against a small emulation of the engine: instances are wrapped in
-- Lua proxies that add events, derived properties (Position), PivotTo /
-- ScaleTo, services (Players, DataStores, Analytics, Tween...), remotes, and a
-- terrain model built from the game's own terrain fill calls (for raycasts).
--
-- Real instance properties still go through Lune's Roblox reflection
-- database, so a misspelled property or class name fails here too.
--
-- This is a smoke test, not a simulator: physics, rendering and networking
-- aren't emulated. It proves the code runs and the systems connect.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local realTask = require("@lune/task")

local R = roblox
local H = {}

H.errors = {} :: { string }
H.warnings = {} :: { string }
H.clientLog = {} :: { { remote: string, player: any, args: { any } } }
H.clockOffset = 0
H.kicked = {} :: { [number]: string }
H.analytics = {} :: { { string } }
H.allowedWarnings = {} :: { string }

local function recordError(context: string, err: any)
	local message = string.format("[%s] %s", context, tostring(err))
	table.insert(H.errors, message)
	print("ERROR " .. message)
end

---------------------------------------------------------------------------
-- Task / clock wrappers (errors in spawned code are recorded, not lost)
---------------------------------------------------------------------------

local function traceback(err: any): string
	local ok, text = pcall(debug.traceback, tostring(err), 2)
	return if ok then text else tostring(err)
end
H.traceback = traceback

local function guarded(fn: any, context: string)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		local ok, err = xpcall(fn, traceback, ...)
		if not ok then
			recordError(context, err)
		end
	end
end

H.task = {
	spawn = function(fn, ...)
		return realTask.spawn(guarded(fn, "task.spawn"), ...)
	end,
	defer = function(fn, ...)
		return realTask.defer(guarded(fn, "task.defer"), ...)
	end,
	delay = function(t, fn, ...)
		return realTask.delay(t, guarded(fn, "task.delay"), ...)
	end,
	wait = realTask.wait,
	cancel = realTask.cancel,
}

local realOsClock = os.clock
H.os = setmetatable({
	clock = function()
		return realOsClock() + H.clockOffset
	end,
	time = function()
		return os.time() + math.floor(H.clockOffset)
	end,
}, { __index = os })

function H.serverTime(): number
	return os.time() + H.clockOffset
end

---------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new(name: string)
	return setmetatable({ name = name, handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handler = { fn = fn, connected = true }
	table.insert(self.handlers, handler)
	local connection = { Connected = true }
	function connection.Disconnect()
		handler.connected = false
		connection.Connected = false
	end
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		realTask.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Fire(...)
	for _, handler in table.clone(self.handlers) do
		if handler.connected then
			realTask.spawn(guarded(handler.fn, "signal " .. self.name), ...)
		end
	end
end

H.Signal = Signal

---------------------------------------------------------------------------
-- Instance proxies
---------------------------------------------------------------------------

local nextId = 0
local proxies: { [number]: any } = {}
local realOf = setmetatable({}, { __mode = "k" })
local states: { [number]: any } = {}

local ProxyMeta = {}

local function idOf(inst: any): number
	local id = inst:GetAttribute("HarnessId")
	if not id then
		nextId += 1
		id = nextId
		inst:SetAttribute("HarnessId", id)
	end
	return id
end

local function stateOf(inst: any)
	local id = idOf(inst)
	local s = states[id]
	if not s then
		s = { signals = {}, attrSignals = {}, propSignals = {}, extra = {} }
		states[id] = s
	end
	return s
end

local function wrap(value: any): any
	if typeof(value) == "Instance" then
		local id = idOf(value)
		local proxy = proxies[id]
		if not proxy then
			proxy = setmetatable({}, ProxyMeta)
			realOf[proxy] = value
			proxies[id] = proxy
		else
			realOf[proxy] = value
		end
		return proxy
	elseif type(value) == "table" and getmetatable(value) == nil then
		local out = {}
		for k, v in value do
			out[k] = wrap(v)
		end
		return out
	end
	return value
end

local function unwrap(value: any): any
	local inst = realOf[value]
	if inst then
		return inst
	end
	return value
end

H.wrap = wrap
H.unwrap = unwrap

local function signalFor(inst: any, name: string)
	local s = stateOf(inst)
	local signal = s.signals[name]
	if not signal then
		signal = Signal.new(inst.ClassName .. "." .. name)
		s.signals[name] = signal
	end
	return signal
end

function H.signal(proxy: any, name: string)
	return signalFor(unwrap(proxy), name)
end

local EVENTS = {
	PlayerAdded = true,
	PlayerRemoving = true,
	CharacterAdded = true,
	Died = true,
	OnServerEvent = true,
	OnClientEvent = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	Changed = true,
	Heartbeat = true,
	RenderStepped = true,
	Stepped = true,
	Activated = true,
	InputBegan = true,
	InputEnded = true,
	InputChanged = true,
	MouseButton1Click = true,
	Ended = true,
	Touched = true,
	AncestryChanged = true,
	Completed = true,
}

local function isA(inst: any, className: string): boolean
	return inst:IsA(className)
end

-- Methods emulated by the harness, by name. fn(proxy, inst, ...) -> ...
local methods: { [string]: (any, any, ...any) -> ...any } = {}
-- Property getters / setters emulated by the harness.
local getters: { [string]: (any, any) -> (boolean, any) } = {}
local setters: { [string]: (any, any, any) -> boolean } = {}

H.methods = methods
H.getters = getters
H.setters = setters

local function firePropertyChanged(inst: any, key: string)
	local s = states[inst:GetAttribute("HarnessId") or -1]
	if not s then
		return
	end
	local changed = s.signals.Changed
	if changed then
		changed:Fire(key)
	end
	local prop = s.propSignals[key]
	if prop then
		prop:Fire()
	end
end

ProxyMeta.__index = function(proxy, key)
	local inst = realOf[proxy]
	local method = methods[key]
	if method then
		return function(self, ...)
			return method(self, realOf[self] or inst, ...)
		end
	end
	local getter = getters[key]
	if getter then
		local handled, value = getter(proxy, inst)
		if handled then
			return value
		end
	end
	if EVENTS[key] then
		return signalFor(inst, key)
	end
	local ok, value = pcall(function()
		return inst[key]
	end)
	if not ok then
		-- Lune special-cases some names (e.g. "Terrain") as properties even on
		-- instances that merely have a child with that name.
		local okChild, child = pcall(function()
			return inst:FindFirstChild(key)
		end)
		if okChild and child then
			return wrap(child)
		end
		-- Roblox lets you read Parent (nil) on a destroyed instance.
		if string.find(tostring(value), "destroyed", 1, true) then
			if key == "Parent" then
				return nil
			end
			error(string.format("%s read on a destroyed %s", tostring(key), "instance"), 2)
		end
		local s = stateOf(inst)
		if s.extra[key] ~= nil then
			return s.extra[key]
		end
		error(
			string.format(
				"%s is not a valid member of %s (%s)",
				tostring(key),
				inst.ClassName,
				tostring(value)
			),
			2
		)
	end
	if type(value) == "function" then
		return function(self, ...)
			local args = table.pack(...)
			for i = 1, args.n do
				args[i] = unwrap(args[i])
			end
			local results = table.pack(value(realOf[self] or inst, table.unpack(args, 1, args.n)))
			for i = 1, results.n do
				results[i] = wrap(results[i])
			end
			return table.unpack(results, 1, results.n)
		end
	end
	return wrap(value)
end

ProxyMeta.__newindex = function(proxy, key, value)
	local inst = realOf[proxy]
	local setter = setters[key]
	if setter and setter(proxy, inst, value) then
		firePropertyChanged(inst, key)
		return
	end
	if key == "Parent" then
		local oldParent = inst.Parent
		inst.Parent = unwrap(value)
		if oldParent then
			local s = states[oldParent:GetAttribute("HarnessId") or -1]
			if s and s.signals.ChildRemoved then
				s.signals.ChildRemoved:Fire(proxy)
			end
		end
		if value then
			local newParent = unwrap(value)
			local s = states[newParent:GetAttribute("HarnessId") or -1]
			if s and s.signals.ChildAdded then
				s.signals.ChildAdded:Fire(proxy)
			end
		end
		firePropertyChanged(inst, key)
		return
	end
	local ok, err = pcall(function()
		inst[key] = unwrap(value)
	end)
	if not ok then
		-- Lune can't clear object references (Adornee = nil); Roblox can.
		if value == nil and string.find(tostring(err), "Ref", 1, true) then
			stateOf(inst).extra[key] = nil
			firePropertyChanged(inst, key)
			return
		end
		error(string.format("Cannot set %s.%s: %s", inst.ClassName, tostring(key), tostring(err)), 2)
	end
	firePropertyChanged(inst, key)
end

ProxyMeta.__tostring = function(proxy)
	local inst = realOf[proxy]
	return if inst then inst.Name else "<proxy>"
end

---------------------------------------------------------------------------
-- Emulated properties
---------------------------------------------------------------------------

getters.Position = function(_proxy, inst)
	if isA(inst, "BasePart") then
		return true, inst.CFrame.Position
	end
	return false, nil
end
setters.Position = function(_proxy, inst, value)
	if isA(inst, "BasePart") then
		local cf = inst.CFrame
		inst.CFrame = R.CFrame.new(value) * (cf - cf.Position)
		return true
	end
	return false
end

for _, name in { "AssemblyLinearVelocity", "AssemblyAngularVelocity" } do
	getters[name] = function(_proxy, inst)
		return true, stateOf(inst).extra[name] or R.Vector3.zero
	end
	setters[name] = function(_proxy, inst, value)
		stateOf(inst).extra[name] = value
		return true
	end
end

getters.JobId = function(_proxy, inst)
	if inst.ClassName == "DataModel" then
		return true, "harness-job"
	end
	return false, nil
end

getters.ViewportSize = function(_proxy, inst)
	if inst.ClassName == "Camera" then
		return true, R.Vector2.new(1280, 720)
	end
	return false, nil
end

getters.LocalPlayer = function(_proxy, inst)
	if inst.ClassName == "Players" then
		return true, H.localPlayer
	end
	return false, nil
end

getters.CurrentCamera = function(_proxy, inst)
	if inst.ClassName == "Workspace" then
		if not H.camera then
			local camera = R.Instance.new("Camera")
			camera.Parent = inst
			H.camera = wrap(camera)
		end
		return true, H.camera
	end
	return false, nil
end

getters.TouchEnabled = function(_proxy, inst)
	if inst.ClassName == "UserInputService" then
		return true, true
	end
	return false, nil
end

-- Read-only / engine-computed values that Lune can't provide.
for _, name in { "AbsolutePosition", "AbsoluteSize" } do
	getters[name] = function()
		return true, R.Vector2.new(100, 100)
	end
end

---------------------------------------------------------------------------
-- Emulated methods (generic)
---------------------------------------------------------------------------

-- Clones copy attributes, so give the copy (and its descendants) fresh ids.
methods.Clone = function(_proxy, inst)
	local copy = inst:Clone()
	copy:SetAttribute("HarnessId", nil)
	for _, d in copy:GetDescendants() do
		d:SetAttribute("HarnessId", nil)
	end
	return wrap(copy)
end

methods.GetService = function(_proxy, inst, name)
	return wrap(inst:GetService(name))
end

methods.WaitForChild = function(_proxy, inst, name, timeout)
	local deadline = realOsClock() + (timeout or 10)
	while realOsClock() < deadline do
		local child = inst:FindFirstChild(name)
		if child then
			return wrap(child)
		end
		realTask.wait(0.05)
	end
	if timeout then
		return nil
	end
	error("WaitForChild timed out: " .. inst:GetFullName() .. "." .. name, 2)
end

methods.SetAttribute = function(_proxy, inst, name, value)
	inst:SetAttribute(name, value)
	local s = stateOf(inst)
	local signal = s.attrSignals[name]
	if signal then
		signal:Fire()
	end
end

methods.GetAttributeChangedSignal = function(_proxy, inst, name)
	local s = stateOf(inst)
	local signal = s.attrSignals[name]
	if not signal then
		signal = Signal.new("attr " .. name)
		s.attrSignals[name] = signal
	end
	return signal
end

methods.GetPropertyChangedSignal = function(_proxy, inst, name)
	local s = stateOf(inst)
	local signal = s.propSignals[name]
	if not signal then
		signal = Signal.new("prop " .. name)
		s.propSignals[name] = signal
	end
	return signal
end

methods.Destroy = function(proxy, inst)
	local parent = inst.Parent
	inst:Destroy()
	if parent then
		local s = states[parent:GetAttribute("HarnessId") or -1]
		if s and s.signals.ChildRemoved then
			s.signals.ChildRemoved:Fire(proxy)
		end
	end
end

local function firstPart(inst: any): any
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

local function getPivot(inst: any): any
	if inst:IsA("BasePart") then
		return inst.CFrame
	end
	local primary = inst.PrimaryPart
	if primary then
		return primary.CFrame
	end
	local part = firstPart(inst)
	return if part then part.CFrame else R.CFrame.identity
end

methods.GetPivot = function(_proxy, inst)
	return getPivot(inst)
end

methods.PivotTo = function(_proxy, inst, cframe)
	if inst:IsA("BasePart") then
		inst.CFrame = cframe
		return
	end
	local delta = cframe * getPivot(inst):Inverse()
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end

methods.GetScale = function(_proxy, inst)
	return stateOf(inst).extra.Scale or 1
end

methods.ScaleTo = function(_proxy, inst, scale)
	assert(type(scale) == "number" and scale > 0, "ScaleTo expects a positive number")
	local s = stateOf(inst)
	local factor = scale / (s.extra.Scale or 1)
	local pivot = getPivot(inst)
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(d.CFrame)
			d.Size = d.Size * factor
			d.CFrame = pivot * (R.CFrame.new(rel.Position * factor) * (rel - rel.Position))
		end
	end
	s.extra.Scale = scale
end

methods.Emit = function() end

methods.Play = function(_proxy, inst)
	if inst:IsA("Sound") then
		realTask.delay(0.05, function()
			local s = states[inst:GetAttribute("HarnessId") or -1]
			if s and s.signals.Ended then
				s.signals.Ended:Fire()
			end
		end)
	end
end
methods.Stop = function() end

---------------------------------------------------------------------------
-- Terrain model (from the game's own fill calls)
---------------------------------------------------------------------------

type Op = {
	kind: string,
	x: number,
	y: number,
	z: number,
	a: number,
	b: number,
	c: number,
	mat: string,
	src: string?,
}
local terrainOps: { Op } = {}
H.terrainOps = terrainOps

-- Spatial index: ops bucketed by XZ cell (op order is kept inside a cell,
-- which matters because later fills overwrite earlier ones).
local CELL = 32
local cells: { [number]: { Op } } = {}
local function cellKey(cx: number, cz: number): number
	return (cx + 2048) * 4096 + (cz + 2048)
end
local function opExtent(op: Op): (number, number)
	if op.kind == "block" or op.kind == "replace" then
		return op.a, op.c
	end
	return op.a, op.a
end
local function addOp(op: Op)
	table.insert(terrainOps, op)
	local ex, ez = opExtent(op)
	for cx = math.floor((op.x - ex) / CELL), math.floor((op.x + ex) / CELL) do
		for cz = math.floor((op.z - ez) / CELL), math.floor((op.z + ez) / CELL) do
			local key = cellKey(cx, cz)
			local list = cells[key]
			if not list then
				list = {}
				cells[key] = list
			end
			table.insert(list, op)
		end
	end
end
local EMPTY: { Op } = {}
local function opsAt(x: number, z: number): { Op }
	return cells[cellKey(math.floor(x / CELL), math.floor(z / CELL))] or EMPTY
end

methods.FillBlock = function(_proxy, _inst, cframe, size, material)
	local p = cframe.Position
	addOp({
		kind = "block",
		x = p.X,
		y = p.Y,
		z = p.Z,
		a = size.X / 2,
		b = size.Y / 2,
		c = size.Z / 2,
		mat = material.Name,
	})
end
methods.FillCylinder = function(_proxy, _inst, cframe, height, radius, material)
	local p = cframe.Position
	addOp({ kind = "cyl", x = p.X, y = p.Y, z = p.Z, a = radius, b = height / 2, c = 0, mat = material.Name })
end
methods.FillBall = function(_proxy, _inst, center, radius, material)
	addOp({
		kind = "ball",
		x = center.X,
		y = center.Y,
		z = center.Z,
		a = radius,
		b = 0,
		c = 0,
		mat = material.Name,
	})
end
methods.ReplaceMaterial = function(_proxy, _inst, region, _resolution, source, target)
	local p, size = region.CFrame.Position, region.Size
	addOp({
		kind = "replace",
		x = p.X,
		y = p.Y,
		z = p.Z,
		a = size.X / 2,
		b = size.Y / 2,
		c = size.Z / 2,
		mat = target.Name,
		src = source.Name,
	})
end
methods.FillWedge = function() end
methods.SetMaterialColor = function() end
methods.Clear = function()
	table.clear(terrainOps)
	table.clear(cells)
end

local function covers(op: Op, x: number, y: number, z: number): boolean
	if op.kind == "block" or op.kind == "replace" then
		return math.abs(x - op.x) <= op.a and math.abs(y - op.y) <= op.b and math.abs(z - op.z) <= op.c
	elseif op.kind == "cyl" then
		local dx, dz = x - op.x, z - op.z
		return math.abs(y - op.y) <= op.b and dx * dx + dz * dz <= op.a * op.a
	elseif op.kind == "ball" then
		local dx, dy, dz = x - op.x, y - op.y, z - op.z
		return dx * dx + dy * dy + dz * dz <= op.a * op.a
	end
	return false
end

local function materialAt(x: number, y: number, z: number): string
	local mat = "Air"
	for _, op in opsAt(x, z) do
		if covers(op, x, y, z) then
			if op.kind == "replace" then
				if mat == op.src then
					mat = op.mat
				end
			else
				mat = op.mat
			end
		end
	end
	return mat
end
H.materialAt = materialAt

-- Roblox draws (and collides with) terrain a few studs above a fill's top
-- because voxels are 4 studs. The harness reproduces that so code that
-- trusts fill heights fails here too.
H.terrainOffset = 2.5

-- Straight-down raycast against the terrain model (fill heights).
local function terrainTopRaw(x: number, z: number, fromY: number): (number?, string?)
	local heights = {}
	for _, op in opsAt(x, z) do
		local top, bottom
		if op.kind == "block" then
			if math.abs(x - op.x) <= op.a and math.abs(z - op.z) <= op.c then
				top, bottom = op.y + op.b, op.y - op.b
			end
		elseif op.kind == "cyl" then
			local dx, dz = x - op.x, z - op.z
			if dx * dx + dz * dz <= op.a * op.a then
				top, bottom = op.y + op.b, op.y - op.b
			end
		elseif op.kind == "ball" then
			local dx, dz = x - op.x, z - op.z
			local d2 = dx * dx + dz * dz
			if d2 <= op.a * op.a then
				local h = math.sqrt(op.a * op.a - d2)
				top, bottom = op.y + h, op.y - h
			end
		end
		if top then
			table.insert(heights, top)
			table.insert(heights, bottom)
		end
	end
	table.sort(heights, function(a, b)
		return a > b
	end)
	for _, h in heights do
		if h <= fromY then
			local mat = materialAt(x, h - 0.05, z)
			if mat ~= "Air" then
				return h, mat
			end
		end
	end
	return nil, nil
end

local function terrainTop(x: number, z: number, fromY: number): (number?, string?)
	local y, mat = terrainTopRaw(x, z, fromY - H.terrainOffset)
	if y then
		return y + H.terrainOffset, mat
	end
	return nil, nil
end

H.terrainTop = terrainTop
H.terrainTopRaw = terrainTopRaw

methods.Raycast = function(_proxy, _inst, origin, direction)
	if math.abs(direction.X) > 1e-6 or math.abs(direction.Z) > 1e-6 or direction.Y >= 0 then
		return nil -- only straight-down rays are modeled
	end
	local y, mat = terrainTop(origin.X, origin.Z, origin.Y)
	if not y or origin.Y - y > -direction.Y then
		return nil
	end
	return {
		Position = R.Vector3.new(origin.X, y, origin.Z),
		Normal = R.Vector3.new(0, 1, 0),
		Material = (R.Enum.Material :: any)[mat],
		Instance = H.workspace.Terrain,
		Distance = origin.Y - y,
	}
end

methods.GetServerTimeNow = function()
	return H.serverTime()
end

---------------------------------------------------------------------------
-- Services
---------------------------------------------------------------------------

methods.IsStudio = function()
	return false
end
methods.IsServer = function()
	return true
end
methods.IsClient = function()
	return H.isClient == true
end

H.bindToClose = {} :: { () -> () }
methods.BindToClose = function(_proxy, _inst, fn)
	table.insert(H.bindToClose, fn)
end

-- DataStores (in-memory, with UpdateAsync semantics and JSON round trips)
H.stores = {} :: { [string]: { [string]: any } }
local function jsonCopy(value: any): any
	if value == nil then
		return nil
	end
	return serde.decode("json", serde.encode("json", value))
end

methods.GetDataStore = function(_proxy, _inst, name)
	H.stores[name] = H.stores[name] or {}
	local data = H.stores[name]
	local store = {}
	function store.UpdateAsync(_self, key, transform)
		local result = transform(jsonCopy(data[key]), nil)
		if result ~= nil then
			data[key] = jsonCopy(result)
		end
		return result
	end
	function store.GetAsync(_self, key)
		return jsonCopy(data[key])
	end
	function store.SetAsync(_self, key, value)
		data[key] = jsonCopy(value)
	end
	return store
end

H.ordered = {} :: { [string]: { [string]: number } }
methods.GetOrderedDataStore = function(_proxy, _inst, name)
	H.ordered[name] = H.ordered[name] or {}
	local data = H.ordered[name]
	local store = {}
	function store.SetAsync(_self, key, value)
		assert(
			type(value) == "number" and value == math.floor(value),
			"OrderedDataStore values must be integers"
		)
		data[key] = value
	end
	function store.GetSortedAsync(_self, ascending, pageSize)
		local rows = {}
		for key, value in data do
			table.insert(rows, { key = key, value = value })
		end
		table.sort(rows, function(a, b)
			return if ascending then a.value < b.value else a.value > b.value
		end)
		local page = {}
		for i = 1, math.min(pageSize, #rows) do
			page[i] = rows[i]
		end
		return {
			GetCurrentPage = function()
				return page
			end,
		}
	end
	return store
end

methods.LogOnboardingFunnelStepEvent = function(_proxy, _inst, player, step, name)
	assert(type(step) == "number", "funnel step must be a number")
	table.insert(H.analytics, { "funnel", tostring(step), tostring(name) })
end
methods.LogEconomyEvent = function(_proxy, _inst, player, flow, currency, amount, balance, txType, sku)
	assert(typeof(flow) == "EnumItem", "flow type must be an EnumItem")
	assert(
		type(currency) == "string" and type(amount) == "number" and type(balance) == "number",
		"bad economy args"
	)
	assert(type(txType) == "string", "transactionType must be a string")
	table.insert(H.analytics, { "economy", flow.Name, tostring(amount), txType, tostring(sku) })
end
methods.LogCustomEvent = function(_proxy, _inst, player, name, value)
	table.insert(H.analytics, { "custom", tostring(name), tostring(value) })
end

methods.UserHasBadgeAsync = function()
	return false
end
methods.AwardBadge = function()
	return true
end
methods.GetUserInfosByUserIdsAsync = function(_proxy, _inst, ids)
	local out = {}
	for _, id in ids do
		table.insert(out, { Id = id, Username = "user" .. id, DisplayName = "User" .. id })
	end
	return out
end

local guidCounter = 0
methods.GenerateGUID = function()
	guidCounter += 1
	return string.format("guid-%08d", guidCounter)
end
methods.JSONEncode = function(_proxy, _inst, value)
	return serde.encode("json", value)
end
methods.JSONDecode = function(_proxy, _inst, text)
	return serde.decode("json", text)
end

-- TweenService: goals are applied immediately; Completed fires next frame.
methods.Create = function(_proxy, inst, target, _info, goals)
	if inst.ClassName ~= "TweenService" then
		error("Create is not a valid member of " .. inst.ClassName)
	end
	local completed = Signal.new("Tween.Completed")
	local tween = { Completed = completed }
	function tween.Play()
		for key, value in goals do
			target[key] = value
		end
		realTask.defer(function()
			completed:Fire(R.Enum.PlaybackState.Completed)
		end)
	end
	function tween.Cancel() end
	function tween.Pause() end
	return tween
end

-- Players
methods.GetPlayers = function(_proxy, inst)
	local list = {}
	for _, child in inst:GetChildren() do
		if child:IsA("Player") then
			table.insert(list, wrap(child))
		end
	end
	return list
end

methods.IsFriendsWith = function(_proxy, inst, userId)
	return H.friends ~= nil and H.friends[inst.UserId .. ":" .. userId] == true
end
methods.IsInGroup = function()
	return true
end

methods.Kick = function(proxy, inst, message)
	H.kicked[inst.UserId] = tostring(message)
	H.removePlayer(proxy)
end

local function makeCharacter(player: any): any
	local character = R.Instance.new("Model")
	character.Name = player.Name
	local function part(name: string, size: any, offset: any)
		local p = R.Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = R.CFrame.new(offset)
		p.Parent = character
		return p
	end
	local root = part("HumanoidRootPart", R.Vector3.new(2, 2, 1), R.Vector3.new(0, 3, 0))
	part("Head", R.Vector3.new(1, 1, 1), R.Vector3.new(0, 4.5, 0))
	part("UpperTorso", R.Vector3.new(2, 1.6, 1), R.Vector3.new(0, 3.2, 0))
	local upperArm = part("RightUpperArm", R.Vector3.new(1, 1.2, 1), R.Vector3.new(1.5, 3.5, 0))
	part("RightHand", R.Vector3.new(1, 0.4, 1), R.Vector3.new(1.5, 2.2, 0))
	local shoulder = R.Instance.new("Motor6D")
	shoulder.Name = "RightShoulder"
	shoulder.C0 = R.CFrame.new(0, 0.5, 0)
	shoulder.Parent = upperArm
	local humanoid = R.Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.Parent = character
	character.PrimaryPart = root
	return character
end

methods.LoadCharacter = function(proxy, inst)
	local old = inst.Character
	if old then
		old:Destroy()
	end
	local character = makeCharacter(inst)
	local spawn = H.workspace:FindFirstChild("Base") and H.workspace.Base:FindFirstChild("Spawn")
	local at = if spawn then spawn.CFrame.Position + R.Vector3.new(0, 3, 0) else R.Vector3.new(0, 10, 0)
	wrap(character):PivotTo(R.CFrame.new(at))
	character.Parent = unwrap(H.workspace)
	inst.Character = character
	signalFor(inst, "CharacterAdded"):Fire(wrap(character))
end

-- Remotes
methods.FireClient = function(_proxy, inst, player, ...)
	table.insert(H.clientLog, { remote = inst.Name, player = player, args = table.pack(...) })
	if H.isClient and player == H.localPlayer then
		signalFor(inst, "OnClientEvent"):Fire(...)
	end
end
methods.FireAllClients = function(_proxy, inst, ...)
	table.insert(H.clientLog, { remote = inst.Name, player = "all", args = table.pack(...) })
	if H.isClient then
		signalFor(inst, "OnClientEvent"):Fire(...)
	end
end
methods.FireServer = function(_proxy, inst, ...)
	table.insert(H.clientLog, { remote = inst.Name, player = "toServer", args = table.pack(...) })
	if H.onFireServer then
		H.onFireServer(inst.Name, ...)
	end
end

-- Client-only services
methods.PromptGameInvite = function() end
methods.CanSendGameInviteAsync = function()
	return true
end
methods.PromptJoinAsync = function()
	return R.Enum.GroupMembershipStatus.AlreadyMember
end
methods.DisplaySystemMessage = function() end
methods.WorldToScreenPoint = function()
	return R.Vector3.new(640, 360, 10)
end
methods.WorldToViewportPoint = methods.WorldToScreenPoint

---------------------------------------------------------------------------
-- Globals for game scripts
---------------------------------------------------------------------------

local RandomMeta = {}
RandomMeta.__index = RandomMeta
function RandomMeta:NextNumber(min: number?, max: number?)
	self.state = (self.state * 48271) % 2147483647
	local f = (self.state - 1) / 2147483646
	if min and max then
		return min + (max - min) * f
	end
	return f
end
function RandomMeta:NextInteger(min: number, max: number)
	return min + math.floor(self:NextNumber() * (max - min + 1))
end
local randomSeed = 1
local Random = {
	new = function(seed: number?)
		randomSeed += 7919
		local s = math.floor(math.abs(seed or randomSeed)) % 2147483646 + 1
		return setmetatable({ state = s }, RandomMeta)
	end,
}

local RaycastParams = {
	new = function()
		return {
			FilterType = nil,
			FilterDescendantsInstances = {},
			IgnoreWater = false,
			RespectCanCollide = false,
		}
	end,
}

local TweenInfo = {
	new = function(...)
		return { ... }
	end,
}

local InstanceGlobal = {
	new = function(className: string, parent: any?)
		local inst = R.Instance.new(className)
		local proxy = wrap(inst)
		if parent then
			proxy.Parent = parent
		end
		return proxy
	end,
}

local baseGlobals = getfenv()
local ROBLOX_GLOBALS = {
	"Axes",
	"BrickColor",
	"CFrame",
	"Color3",
	"ColorSequence",
	"ColorSequenceKeypoint",
	"Enum",
	"Faces",
	"Font",
	"NumberRange",
	"NumberSequence",
	"NumberSequenceKeypoint",
	"PhysicalProperties",
	"Ray",
	"Rect",
	"Region3",
	"Region3int16",
	"UDim",
	"UDim2",
	"Vector2",
	"Vector2int16",
	"Vector3",
	"Vector3int16",
}
local modules = {}

local function makeEnv(scriptProxy: any)
	local env
	env = setmetatable({
		script = scriptProxy,
		game = H.game,
		workspace = H.workspace,
		Instance = InstanceGlobal,
		Random = Random,
		RaycastParams = RaycastParams,
		TweenInfo = TweenInfo,
		task = H.task,
		os = H.os,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring(select(i, ...))
			end
			local message = table.concat(parts, " ")
			table.insert(H.warnings, message)
			print("WARN  " .. message)
		end,
		require = function(target)
			return H.require(target)
		end,
		typeof = function(value)
			if realOf[value] then
				return "Instance"
			end
			return typeof(value)
		end,
	}, { __index = baseGlobals })
	-- Lune applies its own global lookup to chunk environments, so Roblox
	-- datatypes (Vector3, CFrame, Enum...) are copied in explicitly.
	for _, name in ROBLOX_GLOBALS do
		if rawget(env, name) == nil then
			rawset(env, name, (R :: any)[name])
		end
	end
	return env
end

function H.require(moduleProxy: any)
	local inst = unwrap(moduleProxy)
	assert(typeof(inst) == "Instance" and inst:IsA("ModuleScript"), "require expects a ModuleScript")
	local id = idOf(inst)
	local cached = modules[id]
	if cached then
		return cached.value
	end
	local chunk =
		luau.load(inst.Source, { debugName = inst:GetFullName(), environment = makeEnv(wrap(inst)) })
	local value = chunk()
	modules[id] = { value = value }
	return value
end

function H.runScript(scriptProxy: any)
	local inst = unwrap(scriptProxy)
	local chunk =
		luau.load(inst.Source, { debugName = inst:GetFullName(), environment = makeEnv(scriptProxy) })
	local ok, err = xpcall(chunk, traceback)
	if not ok then
		recordError(inst:GetFullName(), err)
	end
end

---------------------------------------------------------------------------
-- Setup and player helpers
---------------------------------------------------------------------------

function H.load(placePath: string)
	local game = R.deserializePlace(fs.readFile(placePath))
	H.game = wrap(game)
	H.workspace = wrap(game:GetService("Workspace"))
	if not game:GetService("Workspace"):FindFirstChildOfClass("Terrain") then
		local terrain = R.Instance.new("Terrain")
		terrain.Parent = game:GetService("Workspace")
	end
	return H.game
end

local nextUserId = 1000
function H.addPlayer(name: string, userId: number?): any
	nextUserId += 1
	local player = R.Instance.new("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = userId or nextUserId
	local players = unwrap(H.game:GetService("Players"))
	player.Parent = players
	local proxy = wrap(player)
	signalFor(players, "PlayerAdded"):Fire(proxy)
	return proxy
end

function H.removePlayer(proxy: any)
	local inst = unwrap(proxy)
	if not inst.Parent then
		return
	end
	local players = unwrap(H.game:GetService("Players"))
	signalFor(players, "PlayerRemoving"):Fire(proxy)
	realTask.wait()
	inst.Parent = nil
end

-- Moves a character so its root is at `position` (feet on the ground).
function H.moveTo(player: any, position: any)
	local character = player.Character
	assert(character, "player has no character")
	character:PivotTo(R.CFrame.new(position + R.Vector3.new(0, 3, 0)))
end

function H.waitFor(predicate: () -> boolean, timeout: number, what: string): boolean
	local deadline = realOsClock() + timeout
	while realOsClock() < deadline do
		if predicate() then
			return true
		end
		realTask.wait(0.05)
	end
	recordError("timeout", "waited " .. timeout .. "s for " .. what)
	return false
end

function H.lastClientEvent(remote: string, player: any?): { any }?
	for i = #H.clientLog, 1, -1 do
		local entry = H.clientLog[i]
		if entry.remote == remote and (player == nil or entry.player == player or entry.player == "all") then
			return entry.args
		end
	end
	return nil
end

function H.clientEvents(remote: string, player: any?): { { any } }
	local out = {}
	for _, entry in H.clientLog do
		if entry.remote == remote and (player == nil or entry.player == player or entry.player == "all") then
			table.insert(out, entry.args)
		end
	end
	return out
end

-- Fires a client -> server remote as `player`.
function H.fireServer(player: any, remote: string, ...: any)
	local remotes = unwrap(H.game:GetService("ReplicatedStorage")):FindFirstChild("Remotes")
	local event = remotes:FindFirstChild(remote)
	assert(event, "no remote " .. remote)
	signalFor(event, "OnServerEvent"):Fire(player, ...)
end

H.recordError = recordError

return H
