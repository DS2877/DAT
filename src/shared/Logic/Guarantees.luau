--!strict
-- Guaranteed early excitement (pure):
--   * the first Rare-or-better within a new player's first 10 digs
--   * the first Epic-or-better within their first ~5 minutes in the Jungle
-- State lives in the profile's `onboarding` table. After both have happened,
-- only normal odds apply.

local Loot = require(script.Parent.Parent.Config.Loot)
local Rarities = require(script.Parent.Parent.Config.Rarities)

export type Rng = () -> number

local Guarantees = {}

local function randomInRange(range: { min: number, max: number }, rng: Rng): number
	return range.min + math.floor(rng() * (range.max - range.min + 1))
end

-- Call before rolling a dig. `digNumber` is 1 for the player's first dig.
-- Returns the minimum rarity to force, or nil for normal odds.
function Guarantees.beforeRoll(
	onboarding: { [string]: any },
	areaId: string,
	digNumber: number,
	now: number,
	rng: Rng
): string?
	if not onboarding.firstRareFound then
		if onboarding.rareGuaranteeDig == 0 then
			onboarding.rareGuaranteeDig = randomInRange(Loot.guarantees.rareByDig, rng)
		end
		if digNumber >= onboarding.rareGuaranteeDig then
			return "Rare"
		end
	end

	if areaId == "Jungle" and not onboarding.firstEpicFound then
		if onboarding.epicGuaranteeAt == 0 then
			onboarding.epicGuaranteeAt = randomInRange(Loot.guarantees.jungleEpicSeconds, rng)
		end
		if onboarding.jungleLastDigAt > 0 then
			local gap = math.clamp(now - onboarding.jungleLastDigAt, 0, Loot.guarantees.jungleGapCap)
			onboarding.jungleSeconds += gap
		end
		onboarding.jungleLastDigAt = now
		if onboarding.jungleSeconds >= onboarding.epicGuaranteeAt then
			return "Epic"
		end
	end
	return nil
end

-- Call after the roll with the rarity found.
function Guarantees.afterRoll(onboarding: { [string]: any }, rarity: string)
	local rank = Rarities.rank(rarity)
	if rank >= Rarities.rank("Rare") then
		onboarding.firstRareFound = true
	end
	if rank >= Rarities.rank("Epic") then
		onboarding.firstEpicFound = true
	end
end

return Guarantees
