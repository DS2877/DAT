-- Pass perks: VIP bundles, on/off switches, bag size, dig speed, cash.
local Bonuses = requireShared("Logic/Bonuses")
local DataSchema = requireShared("Logic/DataSchema")
local Monetization = requireShared("Config/Monetization")
local Perks = requireShared("Logic/Perks")
local Progression = requireShared("Logic/Progression")

local function fresh()
	return DataSchema.migrate(nil)
end

test("passes are off until owned; VIP includes Auto Dig and Auto Sell", function()
	local data = fresh()
	expect.eq(Perks.has(data, "AutoDig"), false)
	data.passes.VIP = true
	expect.eq(Perks.has(data, "AutoDig"), true)
	expect.eq(Perks.has(data, "AutoSell"), true)
	expect.eq(Perks.has(data, "CashX2"), false)
	expect.eq(Perks.includedBy("AutoSell"), "VIP")
end)

test("perks with a switch can be turned off", function()
	local data = fresh()
	data.passes.AutoSell = true
	expect.eq(Perks.enabled(data, "AutoSell"), true)
	data.settings.autoSell = false
	expect.eq(Perks.enabled(data, "AutoSell"), false)
	expect.eq(Perks.has(data, "AutoSell"), true)
	-- Passes without a switch are always on.
	data.passes.CashX2 = true
	expect.eq(Perks.enabled(data, "CashX2"), true)
end)

test("a disabled pass (2x Luck) never counts, even if owned", function()
	local data = fresh()
	data.passes.Luck2x = true
	expect.eq(Monetization.Passes.Luck2x.enabled, false)
	expect.eq(Perks.has(data, "Luck2x"), false)
	expect.eq(Perks.luckMultipliers(data), nil)
end)

test("+50% Bag", function()
	local data = fresh()
	expect.eq(Perks.bagCapacity(data), Progression.bagCapacity(1))
	data.passes.BigBag = true
	expect.eq(Perks.bagCapacity(data), 15)
	data.bagLevel = Progression.MaxBagLevel
	expect.eq(Perks.bagCapacity(data), 150)
end)

test("dig speed: pass and boost add up, capped at 3x", function()
	local data = fresh()
	local base = Progression.getShovel(1).hitInterval
	expect.near(Bonuses.hitInterval(data, 0), base, 1e-9)
	data.passes.FastDig = true
	expect.near(Bonuses.hitInterval(data, 0), base / 2, 1e-9)
	data.activeBoosts.DigSpeed2x = 100
	expect.near(Bonuses.hitInterval(data, 0), base / 3, 1e-9)
	expect.eq(Perks.digSpeed(data, 0), Monetization.Perks.maxDigSpeed)
end)

test("cash: 2x Cash pass, VIP +10%, server boost doesn't stack with a personal boost", function()
	local data = fresh()
	expect.near(Bonuses.cashMultiplier(data, 0, 0), 1, 1e-9)
	data.passes.CashX2 = true
	expect.near(Bonuses.cashMultiplier(data, 0, 0), 2, 1e-9)
	data.passes.VIP = true
	expect.near(Bonuses.cashMultiplier(data, 0, 0), 2.2, 1e-9)
	expect.near(Bonuses.cashMultiplier(data, 0, 0, true), 4.4, 1e-9)
	data.activeBoosts.Cash2x = 100
	expect.near(Bonuses.cashMultiplier(data, 0, 0, true), 4.4, 1e-9)
end)

test("skins: bought, from a pass, or not owned", function()
	local data = fresh()
	expect.eq(Perks.ownsSkin(data, "Pirate"), false)
	data.ownedCosmetics.Pirate = true
	expect.eq(Perks.ownsSkin(data, "Pirate"), true)
	expect.eq(Perks.ownsSkin(data, "VIPGold"), false)
	data.passes.VIP = true
	expect.eq(Perks.ownsSkin(data, "VIPGold"), true)
	data.equippedSkin = "Lava"
	expect.eq(Perks.equippedSkin(data), nil)
	data.equippedSkin = "Pirate"
	expect.eq(Perks.equippedSkin(data), "Pirate")
end)

test("every product grant and skin is well formed", function()
	local kinds =
		{ Cash = true, Boost = true, ServerBoost = true, InstantDeepDig = true, Skin = true, Bundle = true }
	for key, product in Monetization.Products do
		expect.truthy(kinds[product.grant.kind], key .. " has a known grant kind")
		expect.truthy(
			product.tab == "Boosts" or product.tab == "Cash" or product.tab == "Skins",
			key .. " tab"
		)
		local items = if product.grant.kind == "Bundle" then product.grant.items else { product.grant }
		for _, item in items do
			if item.kind == "Skin" then
				expect.truthy(Monetization.Skins[item.skin], key .. " grants a skin that exists")
			end
		end
	end
	for id, skin in Monetization.Skins do
		expect.truthy(
			Monetization.Passes[skin.source] or Monetization.Products[skin.source],
			id .. " has a source"
		)
	end
	expect.truthy(
		Monetization.Passes.AutoSell.price > Monetization.Passes.AutoDig.price,
		"Auto Sell costs more than Auto Dig"
	)
end)
