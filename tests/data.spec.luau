local DataSchema = requireShared("Logic/DataSchema")

test("new players get the template", function()
	local data = DataSchema.migrate(nil)
	expect.eq(data.schemaVersion, DataSchema.CURRENT_VERSION)
	expect.eq(data.cash, 0)
	expect.eq(data.shovelLevel, 1)
	expect.eq(data.bagLevel, 1)
	expect.eq(#data.bagContents, 0)
	expect.eq(data.onboarding.funnelStep, 0)
end)

test("templates are independent tables", function()
	local a, b = DataSchema.template(), DataSchema.template()
	table.insert(a.bagContents, { id = "Shell", v = 1 })
	expect.eq(#b.bagContents, 0)
end)

test("old / partial profiles are reconciled without losing values", function()
	local data = DataSchema.migrate({
		cash = 1234,
		shovelLevel = 3,
		bagContents = { { id = "Pearl", v = 150 } },
		stats = { digs = 42 },
	})
	expect.eq(data.schemaVersion, DataSchema.CURRENT_VERSION)
	expect.eq(data.cash, 1234)
	expect.eq(data.shovelLevel, 3)
	expect.eq(data.bagLevel, 1)
	expect.eq(#data.bagContents, 1)
	expect.eq(data.stats.digs, 42)
	expect.eq(data.stats.finds, 0)
	expect.eq(type(data.discovered), "table")
end)

test("corrupt values are sanitized", function()
	local data = DataSchema.migrate({
		schemaVersion = 1,
		cash = -50,
		shovelLevel = 42,
		bagLevel = 0,
		rebirths = -3,
		bagContents = {
			{ id = "Pearl", v = 150 },
			"junk",
			{ id = 5, v = 1 },
			{ id = "Gone", v = 0 / 0 },
			{ id = "OldThing", v = 77.6 },
		},
	})
	expect.eq(data.cash, 0)
	expect.eq(data.shovelLevel, 8)
	expect.eq(data.bagLevel, 1)
	expect.eq(data.rebirths, 0)
	expect.eq(#data.bagContents, 2)
	expect.eq(data.bagContents[2].id, "OldThing") -- unknown ids keep their value
	expect.eq(data.bagContents[2].v, 77)
end)

test("NaN cash is reset instead of saved", function()
	local data = DataSchema.migrate({ schemaVersion = 1, cash = 0 / 0 })
	expect.eq(data.cash, 0)
end)

test("wrong field types fall back to defaults", function()
	local data = DataSchema.migrate({ schemaVersion = 1, cash = "lots", onboarding = true })
	expect.eq(data.cash, 0)
	expect.eq(type(data.onboarding), "table")
end)

test("profiles from a newer schema are refused, not downgraded", function()
	expect.errors(function()
		DataSchema.migrate({ schemaVersion = DataSchema.CURRENT_VERSION + 1, cash = 5 })
	end)
end)
