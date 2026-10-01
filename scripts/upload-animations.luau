-- Uploads the dig animations (built by scripts/build-dig-animation.luau) to
-- Roblox with the Open Cloud Assets API, owned by the experience's owner so
-- the game can play them. An animation whose id is already set in
-- src/shared/AssetIds.luau gets a new version instead of a new asset.
-- Prints the ids (put them in AssetIds.Animations) and writes
-- animation-ids.json. Runs in the "Upload animations" workflow; the API key
-- comes from the API_KEY environment variable and is never printed.
-- Usage: lune run scripts/upload-animations.luau [dir]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local dir = process.args[1] or "animations"
local apiKey = process.env.API_KEY
if not apiKey or apiKey == "" then
	print("::error::API_KEY is not set (the DAT_PUBLISHING_KEY secret).")
	process.exit(1)
end
local deploy = serde.decode("json", fs.readFile("deploy.config.json"))
local universeId = tostring(deploy.universeId)

-- Ids already in AssetIds (empty = create a new asset).
local assetIdsSource = fs.readFile("src/shared/AssetIds.luau")
local function configuredId(key: string): string?
	local id = assetIdsSource:match(key .. '%s*=%s*"rbxassetid://(%d+)"')
	return id
end

local function explain(status: number)
	if status == 401 or status == 403 then
		print(
			string.format(
				"::error::Roblox refused the request (%d). The API key needs the asset:read and asset:write permissions (Assets API), and its IP allowlist must include 0.0.0.0/0.",
				status
			)
		)
	end
end

local function request(options: { [string]: any }): (number, any)
	for attempt = 1, 4 do
		local ok, response = pcall(net.request, options)
		if ok then
			local status = response.statusCode
			if status ~= 429 and status < 500 then
				local decoded = nil
				if response.body ~= "" then
					local okJson, value = pcall(serde.decode, "json", response.body)
					decoded = if okJson then value else response.body
				end
				return status, decoded
			end
			print(string.format("  %s -> %d, retrying", options.url, status))
		else
			print(string.format("  %s failed (%s), retrying", options.url, tostring(response)))
		end
		task.wait(2 ^ attempt)
	end
	return 0, nil
end

-- The experience's owner (user or group): the animations must belong to it.
-- Open Cloud first (works for private games), the public API as a fallback.
local creationContext = nil
do
	local s, universe = request({
		url = "https://apis.roblox.com/cloud/v2/universes/" .. universeId,
		method = "GET",
		headers = { ["x-api-key"] = apiKey :: string },
	})
	if s == 200 and type(universe) == "table" then
		local user = type(universe.user) == "string" and universe.user:match("users/(%d+)")
		local group = type(universe.group) == "string" and universe.group:match("groups/(%d+)")
		if group then
			creationContext = { creator = { groupId = group } }
			print("Owner: group " .. group)
		elseif user then
			creationContext = { creator = { userId = user } }
			print("Owner: user " .. user)
		end
	else
		print(string.format("  universe lookup -> %d", s))
	end
	if not creationContext then
		local gs, games =
			request({ url = "https://games.roblox.com/v1/games?universeIds=" .. universeId, method = "GET" })
		local creator = gs == 200 and games and games.data and games.data[1] and games.data[1].creator
		if creator and tonumber(creator.id) and tonumber(creator.id) > 0 then
			creationContext = if creator.type == "Group"
				then { creator = { groupId = tostring(creator.id) } }
				else { creator = { userId = tostring(creator.id) } }
			print(string.format("Owner: %s %s", creator.type, tostring(creator.id)))
		end
	end
	if not creationContext then
		print(
			"::error::Couldn't find the owner of universe "
				.. universeId
				.. ". Give the API key the universe:read permission (Universes API) for it."
		)
		process.exit(1)
	end
end

local function multipart(requestJson: string, fileName: string, file: string): (string, string)
	local boundary = "----DigForCashAnim" .. tostring(math.random(1e9, 2e9))
	local body = table.concat({
		"--" .. boundary,
		'Content-Disposition: form-data; name="request"',
		"Content-Type: application/json",
		"",
		requestJson,
		"--" .. boundary,
		'Content-Disposition: form-data; name="fileContent"; filename="' .. fileName .. '"',
		"Content-Type: model/x-rbxm",
		"",
		file,
		"--" .. boundary .. "--",
		"",
	}, "\r\n")
	return body, "multipart/form-data; boundary=" .. boundary
end

-- Waits for an upload operation and returns the asset id.
local function await(operation: any): string?
	local path = operation and operation.path
	for _ = 1, 20 do
		if operation and operation.done then
			local response = operation.response
			return response and tostring(response.assetId)
		end
		if not path then
			return nil
		end
		task.wait(2)
		local s, polled = request({
			url = "https://apis.roblox.com/assets/v1/" .. path,
			method = "GET",
			headers = { ["x-api-key"] = apiKey :: string },
		})
		if s ~= 200 then
			print("  polling failed: " .. s)
			explain(s)
			return nil
		end
		operation = polled
	end
	return nil
end

local ANIMATIONS = {
	{ key = "DigR15", file = "dig-r15.rbxm", name = "Dig (R15)" },
	{ key = "DigR6", file = "dig-r6.rbxm", name = "Dig (R6)" },
}

local ids = {}
local failed = false
for _, anim in ANIMATIONS do
	local file = fs.readFile(dir .. "/" .. anim.file)
	local existing = configuredId(anim.key)
	local requestJson = serde.encode("json", {
		assetType = "Animation",
		displayName = anim.name,
		description = "Dig for Cash: the shovel dig (wind up, dig in, scoop, toss).",
		creationContext = creationContext,
	})
	local body, contentType = multipart(requestJson, anim.file, file)
	local s, result = request({
		url = "https://apis.roblox.com/assets/v1/assets" .. (if existing then "/" .. existing else ""),
		method = if existing then "PATCH" else "POST",
		headers = { ["x-api-key"] = apiKey :: string, ["content-type"] = contentType },
		body = body,
	})
	if s ~= 200 then
		print(
			string.format(
				"::error::%s: upload failed (%d) %s",
				anim.name,
				s,
				serde.encode("json", result or {})
			)
		)
		explain(s)
		failed = true
	else
		local id = await(result) or existing
		if id then
			ids[anim.key] = "rbxassetid://" .. id
			print(string.format("%s = %q  -- %s", anim.key, "rbxassetid://" .. id, anim.name))
		else
			print("::error::" .. anim.name .. ": no asset id came back")
			failed = true
		end
	end
end

fs.writeFile("animation-ids.json", serde.encode("json", ids, true))
local summary = process.env.GITHUB_STEP_SUMMARY
if summary and summary ~= "" then
	local lines =
		{ "## Animation ids", "", "Put these in `src/shared/AssetIds.luau` (Animations):", "", "```lua" }
	for key, id in ids do
		table.insert(lines, string.format("%s = %q,", key, id))
	end
	table.insert(lines, "```")
	fs.writeFile(summary, table.concat(lines, "\n") .. "\n")
end
process.exit(if failed then 1 else 0)
