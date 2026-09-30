--!strict
-- Every audio / animation asset in one place. Empty strings are allowed: the
-- game must run fine with any id missing (sounds simply don't play and the
-- dig swing falls back to a procedural arm swing).
--
-- The rbxasset:// sounds below ship inside the Roblox client itself (they are
-- not third-party uploads). They are stand-ins until real sounds are chosen.

local AssetIds = {
	Sounds = {
		DigHit = "rbxasset://sounds/action_jump_land.mp3", -- TODO: replace (thunk)
		RevealCommon = "rbxasset://sounds/electronicpingshort.wav", -- TODO: replace (pop)
		RevealRare = "rbxasset://sounds/electronicpingshort.wav", -- TODO: replace (sparkle sting)
		StingLegendary = "", -- TODO: replace (short music sting, Legendary / Mythic / Golden)
		StingSecret = "", -- TODO: replace (bigger music sting, Secret)
		Streak = "rbxasset://sounds/electronicpingshort.wav", -- TODO: replace (combo tick)
		AreaUnlocked = "", -- TODO: replace (fanfare)
		BagTick = "rbxasset://sounds/electronicpingshort.wav", -- TODO: replace (soft tick)
		BagFull = "", -- TODO: replace (bag full thud)
		Sell = "rbxasset://sounds/electronicpingshort.wav", -- TODO: replace (cash register)
		Upgrade = "rbxasset://sounds/electronicpingshort.wav", -- TODO: replace (fanfare)
		Denied = "", -- TODO: replace (soft error)
		UiClick = "", -- TODO: replace (button click)
	},
	Music = {
		Beach = "", -- TODO: replace (tropical loop)
	},
	Animations = {
		DigSwing = "", -- TODO: replace (shovel swing). Empty = procedural swing.
	},
}

return table.freeze(AssetIds)
