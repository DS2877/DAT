-- Prints the store catalog (Config/Monetization) as JSON: every pass and
-- product with its kind, name, description, price and icon. Used by
-- scripts/store-sync.luau and scripts/preview/render-icons.mjs.
-- Usage: lune run scripts/store-catalog.luau [out.json]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Monetization = require("../src/shared/Config/Monetization")

local entries = {}
for key, pass in Monetization.Passes do
	table.insert(entries, {
		key = key,
		kind = "pass",
		id = pass.id,
		name = pass.name,
		description = pass.description,
		price = pass.price,
		icon = pass.icon,
		emoji = pass.emoji,
		enabled = pass.enabled ~= false,
	})
end
for key, product in Monetization.Products do
	table.insert(entries, {
		key = key,
		kind = "product",
		id = product.id,
		name = product.name,
		description = product.description,
		price = product.price,
		icon = product.icon,
		emoji = product.emoji,
		enabled = product.enabled ~= false,
	})
end
table.sort(entries, function(a, b)
	return a.kind .. a.key < b.kind .. b.key
end)

local json = serde.encode("json", entries, true)
if process.args[1] then
	fs.writeFile(process.args[1], json)
else
	print(json)
end
