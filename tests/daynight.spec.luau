-- The shared day/night clock (Logic/DayNight).

local DayNight = requireShared("Logic/DayNight")
local Config = requireShared("Config/DayNight")

local start = 1200 * 1000 - Config.offset -- the start of a day

test("the sun rises at dawn and sets at dusk", function()
	expect.near(DayNight.clockTime(start), Config.dawn, 1e-6)
	expect.near(DayNight.clockTime(start + Config.dayLength - 0.001), Config.dusk, 1e-3)
	expect.eq(DayNight.isNight(start + 10), false)
	expect.eq(DayNight.isNight(start + Config.dayLength + 1), true)
	-- Midnight is in the middle of the night (the clock wraps past 24).
	local nightLength = Config.cycle - Config.dayLength
	local midnight = DayNight.clockTime(
		start + Config.dayLength + nightLength * (24 - Config.dusk) / (24 - Config.dusk + Config.dawn)
	)
	local fromMidnight = math.min(midnight % 24, 24 - midnight % 24)
	expect.near(fromMidnight, 0, 1e-3)
end)

test("the lighting blends at dusk and dawn", function()
	expect.eq(DayNight.nightness(start + Config.dayLength / 2), 0)
	expect.eq(DayNight.nightness(start + Config.dayLength + Config.fade + 1), 1)
	local dusk = DayNight.nightness(start + Config.dayLength + Config.fade / 2)
	expect.truthy(dusk > 0 and dusk < 1, "blending at dusk")
	local dawn = DayNight.nightness(start + Config.fade / 2)
	expect.truthy(dawn > 0 and dawn < 1, "blending at dawn")
end)

test("the night countdown", function()
	expect.eq(DayNight.untilNight(start + 100), Config.dayLength - 100)
	expect.eq(DayNight.untilNight(start + Config.dayLength + 5), 0)
end)
