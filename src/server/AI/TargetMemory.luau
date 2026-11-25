--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-DC04510112050A762EC4

local Config = require(script.Parent.Configuration)
local TargetMemory = {}

export type Memory = {
	Player: Player?,
	Position: Vector3?,
	LastSeen: number,
	LastHeard: number,
	UpdatedAt: number,
}

function TargetMemory.New(): Memory
	return {

		Player = nil,
		Position = nil,
		LastSeen = 0,
		LastHeard = 0,
		UpdatedAt = 0,
	}
end

function TargetMemory.Remember(memory: Memory, player: Player, position: Vector3, visible: boolean)
	local now = os.clock()
	-- Copyright (c) 2026 ZakirGG | APFAI-DC04510112050A762EC4/01 | Proprietary source.

	memory.Player = player
	memory.Position = position
	memory.UpdatedAt = now

	if visible then
		memory.LastSeen = now
	else
		memory.LastHeard = now
	end
end

function TargetMemory.IsValid(memory: Memory): boolean
	return memory.Player ~= nil and memory.Position ~= nil and os.clock() - memory.UpdatedAt <= Config.MemoryDuration
end

function TargetMemory.Clear(memory: Memory)
	memory.Player = nil
	memory.Position = nil
	memory.LastSeen = 0
	memory.LastHeard = 0
	memory.UpdatedAt = 0
end
return TargetMemory
