--!strict
-- An admin's message to every server (MessagingService): filtered by
-- Roblox's text filter, published once, and every server (this one too)
-- shows it to all its players as a speech bubble from the admin's avatar.
-- If cross-server messaging is down, it still reaches this server.

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Admin = require(ReplicatedStorage.Shared.Config.Admin)
local Net = require(script.Parent.Parent.Net)

local GlobalMessageService = {}

local TOPIC = "AdminMessage"

local seen: { [string]: boolean } = {}
local lastSent: { [number]: number } = {}

-- Text everyone may see (Roblox's broadcast filter), or nil if the filter
-- couldn't run (then nothing is shown).
function GlobalMessageService.filter(text: string, userId: number): string?
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, userId):GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(result) == "string" then result else nil
end

local function deliver(payload: any)
	if type(payload) ~= "table" or type(payload.id) ~= "string" or type(payload.text) ~= "string" then
		return
	end
	if seen[payload.id] then
		return
	end
	seen[payload.id] = true
	Net.fireAll("GlobalMessage", {
		text = payload.text,
		userId = tonumber(payload.userId) or 0,
		name = tostring(payload.name or "Admin"),
	})
end

-- Sends `text` from `admin` to every server. Returns a status line.
function GlobalMessageService.send(admin: Player, text: string): string
	local cfg = Admin.globalMessage
	text = string.sub(text, 1, cfg.maxLength)
	if text:match("^%s*$") then
		return "Type a message first"
	end
	local now = os.clock()
	if now - (lastSent[admin.UserId] or -math.huge) < cfg.cooldown then
		return "Wait a few seconds between messages"
	end
	local filtered = GlobalMessageService.filter(text, admin.UserId)
	if not filtered then
		return "The text filter is busy, try again"
	end
	lastSent[admin.UserId] = now
	local payload = {
		id = HttpService:GenerateGUID(false),
		text = filtered,
		userId = admin.UserId,
		name = admin.DisplayName,
	}
	-- This server shows it right away; the copy that comes back from
	-- MessagingService is skipped by its id.
	deliver(payload)
	local ok = pcall(function()
		MessagingService:PublishAsync(TOPIC, payload)
	end)
	return if ok then "Sent to every server" else "Sent to this server only (other servers unreachable)"
end

function GlobalMessageService.init()
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message: any)
				deliver(message.Data)
			end)
		end)
		if not ok then
			print("[GlobalMessage] cross-server messages unavailable: " .. tostring(err))
		end
	end)
end

return GlobalMessageService
