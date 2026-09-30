--!strict
-- Minimal synchronous signal for in-process events (server services and
-- client controllers). Handlers run in order; errors in one don't stop others.

export type Connection = { Disconnect: (self: Connection) -> () }

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} :: { (...any) -> () } }, Signal)
end

function Signal.Connect(self: any, handler: (...any) -> ()): Connection
	table.insert(self._handlers, handler)
	local connection = {}
	function connection.Disconnect()
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection :: any
end

function Signal.Fire(self: any, ...: any)
	for _, handler in table.clone(self._handlers) do
		local ok, err = pcall(handler, ...)
		if not ok then
			warn("[Signal] handler error: " .. tostring(err))
		end
	end
end

return Signal
