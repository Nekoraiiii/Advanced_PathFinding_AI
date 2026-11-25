--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-EFEB511624B66BF00CD9

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

export type ConnectionType = {
	Connected: boolean,
	Disconnect: (self: ConnectionType) -> (),
}

export type SignalType = {
	Connections: { any },
	Connect: (self: SignalType, callback: (...any) -> ()) -> ConnectionType,
	Fire: (self: SignalType, ...any) -> (),
}

function Connection.new(signal, callback)
	return setmetatable({
		Signal = signal,
		Callback = callback,
		Connected = true,
	}, Connection)
end
-- Copyright (c) 2026 ZakirGG | APFAI-EFEB511624B66BF00CD9/01 | Proprietary source.

function Connection:Disconnect()
	if not self.Connected then
		return
	end

	self.Connected = false
	local index = table.find(self.Signal.Connections, self)
	if index then
		table.remove(self.Signal.Connections, index)
	end
end

function Signal.new(): SignalType
	return setmetatable({
		Connections = {},
	}, Signal) :: any
end

function Signal:Connect(callback: (...any) -> ()): ConnectionType
	assert(type(callback) == "function", "[Signal] Invalid callback")
	-- Copyright (c) 2026 ZakirGG | APFAI-EFEB511624B66BF00CD9/02 | Proprietary source.
	local connection = Connection.new(self, callback)
	table.insert(self.Connections, connection)
	return connection
end

function Signal:Fire(...: any)
	local snapshot = table.clone(self.Connections)
	for _, connection in ipairs(snapshot) do
		if connection.Connected then
			task.spawn(connection.Callback, ...)
		end
	end
end

return Signal
