-- Structural check of the built place. Usage: lune run scripts/verify-build.luau <file.rbxl>
-- Fails (exit 1) if the place is missing its scripts or key settings.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1] or "build.rbxl"
local game = roblox.deserializePlace(fs.readFile(path))

local failures = 0
local function check(condition: boolean, message: string)
	if condition then
		print("ok    " .. message)
	else
		failures += 1
		print("FAIL  " .. message)
	end
end

local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
check(server ~= nil and server.ClassName == "Script", "ServerScriptService.Server is a Script")
local client = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
client = client and client:FindFirstChild("Client")
check(client ~= nil and client.ClassName == "LocalScript", "StarterPlayerScripts.Client is a LocalScript")
local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
check(shared ~= nil, "ReplicatedStorage.Shared exists")

check(game:GetService("Players").CharacterAutoLoads == false, "Players.CharacterAutoLoads is false")
check(game:GetService("Workspace").StreamingEnabled == false, "Workspace.StreamingEnabled is false")

local moduleCount = 0
for _, descendant in game:GetDescendants() do
	if descendant.ClassName == "ModuleScript" then
		moduleCount += 1
		check(#descendant.Source > 0, "module has source: " .. descendant:GetFullName())
	end
end
check(moduleCount >= 30, string.format("found %d ModuleScripts", moduleCount))

if failures > 0 then
	print(string.format("\n%d check(s) failed", failures))
	process.exit(1)
end
print("\nBuild looks good.")
