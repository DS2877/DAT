local Progression = requireShared("Logic/Progression")
local Bag = requireShared("Logic/Bag")
local Areas = requireShared("Config/Areas")

test("canBuy: affordable, short, maxed, bad kind", function()
	local ok, reason, missing = Progression.canBuy("Shovel", 1, 250)
	expect.eq(ok, true)
	expect.eq(reason, nil)
	expect.eq(missing, 0)

	ok, reason, missing = Progression.canBuy("Shovel", 1, 100)
	expect.eq(ok, false)
	expect.eq(reason, "NotEnoughCash")
	expect.eq(missing, 150)

	ok, reason = Progression.canBuy("Shovel", Progression.MaxShovelLevel, 1e12)
	expect.eq(ok, false)
	expect.eq(reason, "Maxed")

	ok, reason = Progression.canBuy("Hat" :: any, 1, 1e12)
	expect.eq(ok, false)
	expect.eq(reason, "BadKind")
end)

test("next goal is the next shovel, then the next bag, then nil", function()
	local golden = Progression.getShovel(4)
	local goal = Progression.nextGoal(golden.cost - 1800, 3, 1)
	expect.eq(goal.kind, "Shovel")
	expect.eq(goal.name, "Golden Shovel")
	expect.eq(goal.missing, 1800)
	expect.eq(goal.affordable, false)

	goal = Progression.nextGoal(10, Progression.MaxShovelLevel, 2)
	expect.eq(goal.kind, "Bag")
	expect.eq(goal.level, 3)

	expect.eq(Progression.nextGoal(0, Progression.MaxShovelLevel, Progression.MaxBagLevel), nil)
end)

test("near-goal nudge triggers only when close and not yet affordable", function()
	expect.eq(Progression.isNearGoal(Progression.nextGoal(200, 1, 1)), true) -- $50 short of $250
	expect.eq(Progression.isNearGoal(Progression.nextGoal(10, 1, 1)), false)
	expect.eq(Progression.isNearGoal(Progression.nextGoal(250, 1, 1)), false) -- affordable
end)

test("area unlocks follow shovel level and the enabled flag", function()
	expect.eq(Progression.isAreaUnlocked("Beach", 1), true)
	expect.eq(Progression.isAreaUnlocked("Nowhere", 8), false)
	for _, areaId in Areas.Order do
		local def = Areas.Defs[areaId]
		expect.eq(
			Progression.isAreaUnlocked(areaId, def.requiredShovel - 1),
			false,
			areaId .. " below requirement"
		)
		expect.eq(
			Progression.isAreaUnlocked(areaId, def.requiredShovel),
			def.enabled,
			areaId .. " at requirement"
		)
	end
end)

test("levels are clamped when looking up definitions", function()
	expect.eq(Progression.getShovel(0).level, 1)
	expect.eq(Progression.getShovel(99).level, Progression.MaxShovelLevel)
	expect.eq(Progression.bagCapacity(1), 5)
end)

test("bag fills up to capacity and totals values", function()
	local contents = {}
	for i = 1, 5 do
		expect.eq(Bag.add(contents, { id = "Shell", v = i }, Progression.bagCapacity(1)), true)
	end
	expect.eq(Bag.isFull(contents, Progression.bagCapacity(1)), true)
	expect.eq(Bag.add(contents, { id = "Shell", v = 100 }, Progression.bagCapacity(1)), false)
	expect.eq(Bag.count(contents), 5)
	expect.eq(Bag.totalValue(contents), 15)
	expect.eq(Bag.isFull(contents, Progression.bagCapacity(2)), false) -- bigger bag has room
end)

test("the shared goal is the next shovel, then the rebirth (never a bag)", function()
	local Goals = requireShared("Logic/Goals")
	local Rebirth = requireShared("Logic/Rebirth")
	local goal = Goals.current({ cash = 100, shovelLevel = 1, bagLevel = 1, rebirths = 0 })
	expect.eq(goal.kind, "Shovel")
	expect.eq(goal.name, "Stone Shovel")
	expect.eq(goal.missing, 150)
	expect.eq(Goals.isNear(goal), false)
	goal = Goals.current({ cash = 200, shovelLevel = 1, bagLevel = 1, rebirths = 0 })
	expect.eq(Goals.isNear(goal), true)
	goal = Goals.current({ cash = 0, shovelLevel = Progression.MaxShovelLevel, bagLevel = 1, rebirths = 2 })
	expect.eq(goal.kind, "Rebirth")
	expect.eq(goal.cost, Rebirth.cost(2))
end)
