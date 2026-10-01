-- Creates / updates every pass and developer product in
-- src/shared/Config/Monetization.luau on Roblox (Open Cloud), so the store is
-- built from code like the rest of the game.
--
--   * an entry whose config id is set is updated in place (name, description,
--     price, on sale)
--   * otherwise an existing item with the same name is reused, or a new one
--     is created with its icon from store/icons/<icon>.png
--   * disabled entries (enabled = false) are skipped
--
-- Prints every id (paste them into Config/Monetization.luau) and writes them
-- to store-ids.json. Runs in the "Sync store" workflow; the API key comes
-- from the API_KEY environment variable and is never printed.
--
-- Usage: lune run scripts/store-sync.luau [apply|check]
--   check (default) lists what exists and what would change, without writing.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local Monetization = require("../src/shared/Config/Monetization")

local mode = process.args[1] or "check"
assert(mode == "check" or mode == "apply", "mode must be check or apply")
local apiKey = process.env.API_KEY
if not apiKey or apiKey == "" then
	print("::error::API_KEY is not set (the DAT_PUBLISHING_KEY secret).")
	process.exit(1)
end
local deploy = serde.decode("json", fs.readFile("deploy.config.json"))
local universeId = tostring(deploy.universeId)
local BASE = "https://apis.roblox.com"

local KINDS = {
	pass = {
		list = "/game-passes/v1/universes/" .. universeId .. "/game-passes/creator",
		listField = "gamePasses",
		idField = "gamePassId",
		create = "/game-passes/v1/universes/" .. universeId .. "/game-passes",
		update = "/game-passes/v1/universes/" .. universeId .. "/game-passes/",
		scope = "game-pass",
	},
	product = {
		list = "/developer-products/v2/universes/" .. universeId .. "/developer-products/creator",
		listField = "developerProducts",
		idField = "productId",
		create = "/developer-products/v2/universes/" .. universeId .. "/developer-products",
		update = "/developer-products/v2/universes/" .. universeId .. "/developer-products/",
		scope = "developer-product",
	},
}

local failed = false

local function explain(status: number, kind: string)
	if status == 401 or status == 403 then
		print(
			string.format(
				"::error::Roblox refused the request (%d). The API key needs the %s:read and %s:write permissions for universe %s, and its IP allowlist must include 0.0.0.0/0.",
				status,
				KINDS[kind].scope,
				KINDS[kind].scope,
				universeId
			)
		)
	end
end

-- One request with retries on rate limits / server errors.
local function request(
	method: string,
	path: string,
	headers: { [string]: string }?,
	body: string?
): (number, any)
	local h = { ["x-api-key"] = apiKey :: string }
	for k, v in headers or {} do
		h[k] = v
	end
	for attempt = 1, 4 do
		local ok, response =
			pcall(net.request, { url = BASE .. path, method = method, headers = h, body = body })
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
			print(string.format("  %s %s -> %d, retrying", method, path, status))
		else
			print(string.format("  %s %s failed (%s), retrying", method, path, tostring(response)))
		end
		task.wait(2 ^ attempt)
	end
	return 0, nil
end

local function multipart(
	fields: { { name: string, value: string, filename: string?, contentType: string? } }
): (string, string)
	local boundary = "----DigForCash" .. tostring(math.random(1e9, 2e9))
	local parts = {}
	for _, field in fields do
		local header = "--" .. boundary .. '\r\nContent-Disposition: form-data; name="' .. field.name .. '"'
		if field.filename then
			header ..= '; filename="' .. field.filename .. '"\r\nContent-Type: ' .. (field.contentType or "application/octet-stream")
		end
		table.insert(parts, header .. "\r\n\r\n" .. field.value .. "\r\n")
	end
	table.insert(parts, "--" .. boundary .. "--\r\n")
	return table.concat(parts), "multipart/form-data; boundary=" .. boundary
end

local function listAll(kind: string): { any }
	local spec = KINDS[kind]
	local items = {}
	local token = nil
	repeat
		local path = spec.list .. "?pageSize=100" .. (if token then "&pageToken=" .. token else "")
		local status, body = request("GET", path)
		if status ~= 200 then
			print(
				string.format(
					"::error::Listing %ss failed (%d): %s",
					kind,
					status,
					serde.encode("json", body)
				)
			)
			explain(status, kind)
			process.exit(1)
		end
		for _, item in body[spec.listField] or {} do
			table.insert(items, item)
		end
		token = body.nextPageToken
	until not token or token == ""
	return items
end

local function priceOf(item: any): number?
	local info = item.priceInformation
	if type(info) == "table" then
		return info.defaultPriceInRobux or info.priceInRobux or info.price
	end
	return nil
end

local catalog = {}
for key, pass in Monetization.Passes do
	table.insert(catalog, { key = key, kind = "pass", def = pass })
end
for key, product in Monetization.Products do
	table.insert(catalog, { key = key, kind = "product", def = product })
end
table.sort(catalog, function(a, b)
	return a.kind .. a.key < b.kind .. b.key
end)

local existing = { pass = listAll("pass"), product = listAll("product") }
print(string.format("Found %d passes and %d products on Roblox.", #existing.pass, #existing.product))
if existing.pass[1] then
	print("Price format: " .. serde.encode("json", existing.pass[1].priceInformation))
end

local ids: { [string]: { kind: string, id: number } } = {}

for _, entry in catalog do
	local def = entry.def
	local spec = KINDS[entry.kind]
	if def.enabled == false then
		print(string.format("skip    %-8s %-16s (disabled in config)", entry.kind, entry.key))
		continue
	end
	local found = nil
	for _, item in existing[entry.kind] do
		local itemId = item[spec.idField]
		if (def.id ~= 0 and itemId == def.id) or (def.id == 0 and item.name == def.name) then
			found = item
			break
		end
	end

	if found then
		local id = found[spec.idField]
		ids[entry.key] = { kind = entry.kind, id = id }
		local changes = {}
		if found.name ~= def.name then
			table.insert(changes, "name")
		end
		if found.description ~= def.description then
			table.insert(changes, "description")
		end
		if found.isForSale ~= true then
			table.insert(changes, "on sale")
		end
		if priceOf(found) ~= def.price then
			table.insert(changes, "price")
		end
		if #changes == 0 then
			print(string.format("ok      %-8s %-16s %d", entry.kind, entry.key, id))
		elseif mode == "check" then
			print(
				string.format(
					"change  %-8s %-16s %d (%s)",
					entry.kind,
					entry.key,
					id,
					table.concat(changes, ", ")
				)
			)
		else
			local body, contentType = multipart({
				{ name = "name", value = def.name },
				{ name = "description", value = def.description },
				{ name = "price", value = tostring(def.price) },
				{ name = "isForSale", value = "true" },
			})
			local status, response =
				request("PATCH", spec.update .. tostring(id), { ["Content-Type"] = contentType }, body)
			if status == 200 or status == 204 then
				print(
					string.format(
						"updated %-8s %-16s %d (%s)",
						entry.kind,
						entry.key,
						id,
						table.concat(changes, ", ")
					)
				)
			else
				failed = true
				print(
					string.format(
						"::error::Updating %s failed (%d): %s",
						entry.key,
						status,
						serde.encode("json", response)
					)
				)
				explain(status, entry.kind)
			end
		end
	elseif mode == "check" then
		print(string.format("create  %-8s %-16s (%d Robux)", entry.kind, entry.key, def.price))
	else
		local iconPath = "store/icons/" .. def.icon .. ".png"
		local fields = {
			{ name = "name", value = def.name },
			{ name = "description", value = def.description },
			{ name = "price", value = tostring(def.price) },
			{ name = "isForSale", value = "true" },
		}
		if fs.isFile(iconPath) then
			table.insert(fields, {
				name = "imageFile",
				value = fs.readFile(iconPath),
				filename = def.icon .. ".png",
				contentType = "image/png",
			})
		else
			print("::warning::No icon at " .. iconPath)
		end
		local body, contentType = multipart(fields)
		local status, response = request("POST", spec.create, { ["Content-Type"] = contentType }, body)
		local id = type(response) == "table" and response[spec.idField]
		if status == 200 and type(id) == "number" then
			ids[entry.key] = { kind = entry.kind, id = id }
			print(string.format("created %-8s %-16s %d", entry.kind, entry.key, id))
		else
			failed = true
			print(
				string.format(
					"::error::Creating %s failed (%d): %s",
					entry.key,
					status,
					serde.encode("json", response)
				)
			)
			explain(status, entry.kind)
		end
	end
	task.wait(0.5) -- stay under the per-key rate limits
end

-- The ids, ready to paste into Config/Monetization.luau.
print("\nIds:")
local summary = { "| Key | Kind | Id |", "|---|---|---|" }
for _, entry in catalog do
	local found = ids[entry.key]
	if found then
		print(string.format("  %s = %d -- %s", entry.key, found.id, found.kind))
		table.insert(summary, string.format("| %s | %s | %d |", entry.key, found.kind, found.id))
	end
end
fs.writeFile("store-ids.json", serde.encode("json", ids, true))
local summaryPath = process.env.GITHUB_STEP_SUMMARY
if summaryPath and summaryPath ~= "" then
	fs.writeFile(summaryPath, "## Store ids (" .. mode .. ")\n\n" .. table.concat(summary, "\n") .. "\n")
end
process.exit(if failed then 1 else 0)
