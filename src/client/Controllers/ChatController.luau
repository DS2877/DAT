--!strict
-- Chat tags: messages from VIPs (game pass) start with a gold [VIP].

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatController = {}

function ChatController.init()
	local ok, err = pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage)
			local source = message.TextSource
			local sender = source and Players:GetPlayerByUserId(source.UserId)
			if not sender or sender:GetAttribute("VIP") ~= true then
				return nil
			end
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = '<font color="#FFD24A">[VIP]</font> ' .. message.PrefixText
			return properties
		end
	end)
	if not ok then
		warn("[Chat] VIP tags unavailable: " .. tostring(err))
	end
end

return ChatController
