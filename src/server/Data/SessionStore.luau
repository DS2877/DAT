--!strict
-- Session-locked DataStore profiles (a small ProfileStore-style store).
--
-- Stored record per key:
--   { data = <profile>, lock = { jobId, token, time } | nil, savedAt = unix }
--
-- * Load takes the lock with UpdateAsync. If another live server holds it,
--   we retry for a while; stale locks (server crashed) are taken over.
-- * Every save checks the lock token is still ours, so a server that lost the
--   session can never overwrite newer data.
-- * Release clears the lock on leave / shutdown.
-- * In Studio without API access it falls back to an in-memory store.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local SessionStore = {}
SessionStore.__index = SessionStore

-- A lock not refreshed for this long belongs to a dead server.
SessionStore.LOCK_STALE_SECONDS = 150
SessionStore.LOAD_RETRIES = 6
SessionStore.LOAD_RETRY_DELAY = 4
SessionStore.SAVE_RETRIES = 3

export type Session = {
	key: string,
	data: { [string]: any },
	token: string,
	lost: boolean,
	released: boolean,
}

-- In-memory stand-in with UpdateAsync semantics (Studio without API access).
local MockStore = {}
MockStore.__index = MockStore

function MockStore.new()
	return setmetatable({ _data = {} :: { [string]: any } }, MockStore)
end

function MockStore.UpdateAsync(self: any, key: string, transform: (any) -> any)
	local current = self._data[key]
	local copy = if current then HttpService:JSONDecode(HttpService:JSONEncode(current)) else nil
	local result = transform(copy)
	if result ~= nil then
		self._data[key] = HttpService:JSONDecode(HttpService:JSONEncode(result))
	end
	return result
end

function SessionStore.new(storeName: string)
	local self = setmetatable({}, SessionStore)
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	self._store = if ok then store else nil
	self._mock = false
	if not ok or RunService:IsStudio() then
		-- Probe access once; Studio without "API Services" enabled errors here.
		local probeOk = ok and pcall(function()
			(store :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			if RunService:IsStudio() then
				warn(
					"[SessionStore] DataStores unavailable in Studio; using an in-memory store (nothing will save)."
				)
				self._store = MockStore.new()
				self._mock = true
			else
				warn("[SessionStore] DataStores unavailable: " .. tostring(store))
			end
		end
	end
	return self
end

local function lockIsFresh(lock: any, now: number): boolean
	return type(lock) == "table"
		and type(lock.time) == "number"
		and now - lock.time < SessionStore.LOCK_STALE_SECONDS
end

-- Loads and locks a profile. `migrate(storedData)` must return the data to use
-- (and may error to refuse the profile). Returns (session, nil) on success or
-- (nil, reason) where reason is "Locked" | "Error" | "Refused".
function SessionStore.load(self: any, key: string, migrate: (any) -> { [string]: any }): (Session?, string?)
	if not self._store then
		return nil, "Error"
	end
	local token = HttpService:GenerateGUID(false)
	for attempt = 1, SessionStore.LOAD_RETRIES do
		local status: string = "Error"
		local storedData: any = nil
		local ok, err = pcall(function()
			self._store:UpdateAsync(key, function(record: any)
				record = if type(record) == "table" then record else {}
				local now = os.time()
				local lock = record.lock
				if lock and lock.jobId ~= game.JobId and lockIsFresh(lock, now) then
					status = "Locked"
					return nil -- cancel the write
				end
				record.lock = { jobId = game.JobId, token = token, time = now }
				status = "Ok"
				storedData = record.data
				return record
			end)
		end)
		if ok and status == "Ok" then
			local migrateOk, dataOrErr = pcall(migrate, storedData)
			if not migrateOk then
				warn("[SessionStore] Refused profile " .. key .. ": " .. tostring(dataOrErr))
				self:_releaseLockOnly(key, token)
				return nil, "Refused"
			end
			return {
				key = key,
				data = dataOrErr,
				token = token,
				lost = false,
				released = false,
			},
				nil
		end
		if not ok then
			warn(string.format("[SessionStore] Load %s attempt %d failed: %s", key, attempt, tostring(err)))
		end
		if attempt < SessionStore.LOAD_RETRIES then
			task.wait(SessionStore.LOAD_RETRY_DELAY)
		end
		if attempt == SessionStore.LOAD_RETRIES then
			return nil, if status == "Locked" then "Locked" else "Error"
		end
	end
	return nil, "Error"
end

function SessionStore._releaseLockOnly(self: any, key: string, token: string)
	pcall(function()
		self._store:UpdateAsync(key, function(record: any)
			if type(record) == "table" and type(record.lock) == "table" and record.lock.token == token then
				record.lock = nil
				return record
			end
			return nil
		end)
	end)
end

-- Saves the session's data. With `release`, also clears the lock.
-- Returns true on success. Marks the session lost if another server owns it.
function SessionStore.save(self: any, session: Session, release: boolean): boolean
	if session.lost or session.released then
		return false
	end
	for attempt = 1, SessionStore.SAVE_RETRIES do
		local lost = false
		local ok, err = pcall(function()
			self._store:UpdateAsync(session.key, function(record: any)
				if
					type(record) ~= "table"
					or type(record.lock) ~= "table"
					or record.lock.token ~= session.token
				then
					lost = true
					return nil
				end
				local now = os.time()
				record.data = session.data
				record.savedAt = now
				record.lock = if release
					then nil
					else { jobId = game.JobId, token = session.token, time = now }
				return record
			end)
		end)
		if ok then
			if lost then
				session.lost = true
				warn(
					"[SessionStore] Session for "
						.. session.key
						.. " was taken by another server; not saving."
				)
				return false
			end
			if release then
				session.released = true
			end
			return true
		end
		warn(
			string.format("[SessionStore] Save %s attempt %d failed: %s", session.key, attempt, tostring(err))
		)
		if attempt < SessionStore.SAVE_RETRIES then
			task.wait(2 ^ attempt)
		end
	end
	return false
end

function SessionStore.isMock(self: any): boolean
	return self._mock
end

return SessionStore
