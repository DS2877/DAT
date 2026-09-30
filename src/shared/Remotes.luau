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

	-- Server -> Client
	DataSync = "DataSync", -- (snapshot)
	DigResult = "DigResult", -- (result)
	Sold = "Sold", -- (saleInfo)
	UpgradeResult = "UpgradeResult", -- (result)
	Notify = "Notify", -- (text, kind?)
	Announce = "Announce", -- (announcement) to everyone
})
