--!strict
--[[
	Signal — minimal typed signal used for extension points between services.
	Listeners run via task.spawn, so a failing listener never breaks the emitter.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local listeners: { [Connection]: (T...) -> () } = {}
	local signal = {} :: any

	function signal.Connect(_self: Signal<T...>, fn: (T...) -> ()): Connection
		local connection = { Connected = true } :: any
		function connection.Disconnect(conn: Connection)
			conn.Connected = false
			listeners[conn] = nil
		end
		listeners[connection] = fn
		return connection :: Connection
	end

	function signal.Once(self: Signal<T...>, fn: (T...) -> ()): Connection
		local connection: Connection
		connection = self:Connect(function(...: T...)
			connection:Disconnect()
			fn(...)
		end)
		return connection
	end

	function signal.Fire(_self: Signal<T...>, ...: T...)
		local snapshot: { { conn: Connection, fn: (T...) -> () } } = {}
		for conn, fn in listeners do
			table.insert(snapshot, { conn = conn, fn = fn })
		end
		for _, entry in snapshot do
			if entry.conn.Connected then
				task.spawn(entry.fn, ...)
			end
		end
	end

	function signal.DisconnectAll(_self: Signal<T...>)
		for conn in listeners do
			conn.Connected = false
		end
		table.clear(listeners)
	end

	return signal :: Signal<T...>
end

return Signal
