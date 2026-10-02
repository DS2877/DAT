--!strict
-- Remote names, created by the server in ReplicatedStorage.Remotes.
-- Client -> server remotes carry intents only; the server decides everything.

return table.freeze({
	-- Client -> Server
	DigHit = "DigHit", -- (spotId: number)
	BuyUpgrade = "BuyUpgrade", -- (kind: "Shovel" | "Bag")
	RequestSync = "RequestSync", -- ()
	ClaimGift = "ClaimGift", -- (giftIndex: number)
	ClaimDaily = "ClaimDaily", -- ()
	ClaimGroupReward = "ClaimGroupReward", -- ()
	Rebirth = "Rebirth", -- ()
	SetSetting = "SetSetting", -- (key: settings key, on: boolean)
	PauseBoost = "PauseBoost", -- (boostId: string, paused: boolean)
	EquipSkin = "EquipSkin", -- (skinId: string, "" = none)
	SellAnywhere = "SellAnywhere", -- () Auto Sell's SELL button
	BuyDrink = "BuyDrink", -- (drinkId: string) at the Tiki Bar
	AdminAction = "AdminAction", -- (action, targetUserId?, ...args) admins only
	ChoosePerk = "ChoosePerk", -- (perkId: string) a rebirth perk card
	ClaimBounty = "ClaimBounty", -- (slot: number) a finished bounty's reward
	ShopEvent = "ShopEvent", -- (event: "ShopOpened" | "OfferShown" | "PurchasePrompted", key: string?)

	-- Server -> Client
	DataSync = "DataSync", -- (snapshot)
	DigResult = "DigResult", -- (result)
	Sold = "Sold", -- (saleInfo)
	UpgradeResult = "UpgradeResult", -- (result)
	Notify = "Notify", -- (text, kind?)
	Announce = "Announce", -- (announcement) to everyone
	AdminInfo = "AdminInfo", -- (info) players, uptime, hidden treasures
	MegaDigDraw = "MegaDigDraw", -- (draw) the Mega Dig's winner draw, to everyone
	GlobalMessage = "GlobalMessage", -- ({ text, userId, name }) an admin's message to every server
	Fireworks = "Fireworks", -- (position, count) to everyone
	CoinPicked = "CoinPicked", -- (amount, position) a money-rain coin
	Meteor = "Meteor", -- (from: Vector3, to: Vector3, flight: number) a fireball (to everyone)
	Seagull = "Seagull", -- (kind: "Steal" | "Perch" | "Return" | "GiveUp", userId, info) the hat thief (to everyone)
	BountyDone = "BountyDone", -- (slot: number, description: string) a bounty was just finished
	Portal = "Portal", -- (kind: "Locked" | "Attuned" | "ComingSoon" | "Teleporting", info) the Frost Portal
})
