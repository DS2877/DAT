local Format = requireShared("Util/Format")
local RateLimiter = requireShared("Util/RateLimiter")
local Zones = requireShared("Logic/Zones")
local MapLayout = requireShared("Config/MapLayout")

test("cash formatting", function()
	expect.eq(Format.cash(0), "$0")
	expect.eq(Format.cash(45), "$45")
	expect.eq(Format.cash(4823), "$4,823")
	expect.eq(Format.cash(99999), "$99,999")
	expect.eq(Format.cash(100000), "$100K")
	expect.eq(Format.cash(1500000), "$1.5M")
	expect.eq(Format.cash(2000000), "$2M")
	expect.eq(Format.cash(123456789), "$123M")
	expect.eq(Format.commas(1234567), "1,234,567")
	expect.eq(Format.commas(-1000), "-1,000")
end)

test("rate limiter allows a burst then refills over time", function()
	local now = 0
	local limiter = RateLimiter.new(2, 3, function()
		return now
	end)
	expect.eq(limiter:allow("p"), true)
	expect.eq(limiter:allow("p"), true)
	expect.eq(limiter:allow("p"), true)
	expect.eq(limiter:allow("p"), false)
	expect.eq(limiter:allow("other"), true)
	now = 0.5
	expect.eq(limiter:allow("p"), true)
	expect.eq(limiter:allow("p"), false)
end)

test("areaAt splits the island into the four areas", function()
	expect.eq(Zones.areaAt(0, 120), "Beach")
	expect.eq(Zones.areaAt(-60, -50), "Jungle")
	expect.eq(Zones.areaAt(60, -50), "Ruins")
	expect.eq(Zones.areaAt(0, -200), "Volcano")
end)

test("base, spawn, sell pad and stations are on the beach", function()
	for _, p in { MapLayout.spawn, MapLayout.sellPad, MapLayout.shovelStation, MapLayout.bagStation } do
		expect.eq(Zones.areaAt(p.x, p.z), "Beach")
		expect.truthy(Zones.inRect(p.x, p.z, MapLayout.base), "inside base deck")
		expect.truthy(Zones.inCircle(p.x, p.z, MapLayout.beach), "on beach land")
	end
end)

test("spot regions sit inside their own area", function()
	for areaId, rect in MapLayout.spotRegions do
		for _, corner in
			{
				{ rect.minX, rect.minZ },
				{ rect.maxX, rect.maxZ },
				{ rect.minX, rect.maxZ },
				{ rect.maxX, rect.minZ },
			}
		do
			expect.eq(Zones.areaAt(corner[1], corner[2]), areaId, areaId .. " region corner")
		end
	end
end)
