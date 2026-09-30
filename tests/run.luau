-- Offline test runner (Lune). Usage: lune run tests/run.luau
-- Runs every tests/*.spec.luau file against the real shared modules.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Loader = require("./loader")
local requireShared = Loader.requireShared
local baseEnv = Loader.baseEnv

---------------------------------------------------------------------------
-- Tiny test framework
---------------------------------------------------------------------------

local results = { passed = 0, failed = 0 }
local currentFile = ""

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		print(string.format("FAIL  %s > %s\n      %s", currentFile, name, tostring(err)))
	end
end

local function fmt(v)
	return if type(v) == "string" then string.format("%q", v) else tostring(v)
end

local expect = {}
function expect.eq(actual, expected, message: string?)
	if actual ~= expected then
		error(
			string.format(
				"%sexpected %s, got %s",
				if message then message .. ": " else "",
				fmt(expected),
				fmt(actual)
			),
			2
		)
	end
end
function expect.truthy(value, message: string?)
	if not value then
		error((message or "expected truthy value") .. ", got " .. fmt(value), 2)
	end
end
function expect.near(actual: number, expected: number, tolerance: number, message: string?)
	if math.abs(actual - expected) > tolerance then
		error(
			string.format(
				"%sexpected %s +/- %s, got %s",
				if message then message .. ": " else "",
				expected,
				tolerance,
				actual
			),
			2
		)
	end
end
function expect.errors(fn: () -> (), message: string?)
	if pcall(fn) then
		error(message or "expected an error", 2)
	end
end

-- Deterministic RNG (LCG) for reproducible rolls.
local function seededRng(seed: number)
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

-- A scripted RNG that returns the given values in order (then repeats the last).
local function scriptedRng(values: { number })
	local i = 0
	return function(): number
		i = math.min(i + 1, #values)
		return values[i]
	end
end

---------------------------------------------------------------------------
-- Run spec files
---------------------------------------------------------------------------

local specEnvBase = {
	readFile = fs.readFile,
	test = test,
	expect = expect,
	requireShared = requireShared,
	seededRng = seededRng,
	scriptedRng = scriptedRng,
}

local files = {}
for _, entry in fs.readDir("tests") do
	if entry:match("%.spec%.luau$") then
		table.insert(files, entry)
	end
end
table.sort(files)

for _, entry in files do
	currentFile = entry
	local env = setmetatable(table.clone(specEnvBase), { __index = baseEnv })
	local ok, err = pcall(function()
		luau.load(fs.readFile("tests/" .. entry), { debugName = entry, environment = env })()
	end)
	if not ok then
		results.failed += 1
		print(string.format("FAIL  %s (load error)\n      %s", entry, tostring(err)))
	end
end

print(string.format("\n%d passed, %d failed (%d spec files)", results.passed, results.failed, #files))
process.exit(if results.failed == 0 then 0 else 1)
