--!strict
-- A simple signal: other code can "subscribe" and is notified on Fire().

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local listeners: { [number]: (T...) -> () } = {}
	local nextId = 0
	local self = {}

	function self.Connect(_: any, fn: (T...) -> ()): Connection
		nextId += 1
		local id = nextId
		listeners[id] = fn
		local connection = {}
		function connection.Disconnect(_: any)
			listeners[id] = nil
		end
		return connection :: any
	end

	function self.Fire(_: any, ...: T...)
		for _, fn in listeners do
			task.spawn(fn, ...)
		end
	end

	return self :: any
end

return Signal
