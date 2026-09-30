--!strict
-- Remote names, created by the server in ReplicatedStorage.Remotes.
-- Client -> server remotes carry intents only; the server decides everything.

return table.freeze({
	-- Client -> Server
	DigHit = "DigHit", -- (spotId: number)
	BuyUpgrade = "BuyUpgrade", -- (kind: "Shovel" | "Bag")
	RequestSync = "RequestSync", -- ()

	-- Server -> Client
	DataSync = "DataSync", -- (snapshot)
	DigResult = "DigResult", -- (result)
	Sold = "Sold", -- (saleInfo)
	UpgradeResult = "UpgradeResult", -- (result)
	Notify = "Notify", -- (text, kind?)
})
