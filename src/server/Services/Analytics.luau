--!strict
-- Thin, failure-proof wrapper around Roblox AnalyticsService.
-- Every call is pcall'd: analytics must never break gameplay.

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnalyticsConfig = require(ReplicatedStorage.Shared.Config.Analytics)

local Analytics = {}

local stepIndex: { [string]: number } = {}
for index, name in AnalyticsConfig.FunnelSteps do
	stepIndex[name] = index
end

local function safe(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn("[Analytics] " .. label .. " failed: " .. tostring(err))
	end
end

-- Logs an onboarding funnel step once per player (persisted in the profile).
-- Earlier steps that were never logged are logged first, keeping order.
function Analytics.funnel(player: Player, data: { [string]: any }, stepName: string)
	local target = stepIndex[stepName]
	assert(target, "Unknown funnel step " .. stepName)
	local onboarding = data.onboarding
	while onboarding.funnelStep < target do
		local step = onboarding.funnelStep + 1
		onboarding.funnelStep = step
		safe("funnel " .. step, function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, AnalyticsConfig.FunnelSteps[step])
		end)
	end
end

-- flow: "Source" (cash in) or "Sink" (cash out).
-- transactionType: an Enum.AnalyticsEconomyTransactionType name, e.g. "Gameplay", "Shop".
function Analytics.economy(
	player: Player,
	flow: "Source" | "Sink",
	amount: number,
	endingBalance: number,
	transactionType: string,
	itemSku: string?
)
	if amount <= 0 then
		return
	end
	safe("economy", function()
		local flowType = if flow == "Source"
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		local txType = (Enum.AnalyticsEconomyTransactionType :: any)[transactionType]
		AnalyticsService:LogEconomyEvent(
			player,
			flowType,
			AnalyticsConfig.CurrencyName,
			amount,
			endingBalance,
			txType.Name,
			itemSku
		)
	end)
end

function Analytics.custom(player: Player, eventName: string, value: number?)
	safe("custom " .. eventName, function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1)
	end)
end

return Analytics
