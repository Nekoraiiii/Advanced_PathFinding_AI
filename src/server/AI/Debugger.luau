--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-EB82E05405051CEB8682

local Config = require(script.Parent.Configuration)
local Debugger = {}
local lastUpdate: { [Model]: number } = setmetatable({}, { __mode = "k" })

function Debugger.Update(
	npc: Model,
	state: string,
	mode: string,
	target: Player?,
	distance: number,
	waypoint: number,
	totalWaypoints: number,
	visible: boolean,
	heard: boolean
)
	if not Config.DebugEnabled then
		return
	end
	-- Copyright (c) 2026 ZakirGG | APFAI-EB82E05405051CEB8682/01 | Proprietary source.
	local now = os.clock()

	if now - (lastUpdate[npc] or 0) < Config.DebugInterval then
		return
	end

	lastUpdate[npc] = now

	npc:SetAttribute("AI_State", state)
	npc:SetAttribute("AI_Mode", mode)
	npc:SetAttribute("AI_Target", if target then target.Name else "None")
	npc:SetAttribute("AI_Distance", math.round(distance * 10) / 10)
	npc:SetAttribute("AI_Waypoint", waypoint)
	npc:SetAttribute("AI_TotalWaypoints", totalWaypoints)
	npc:SetAttribute("AI_CanSee", visible)
	npc:SetAttribute("AI_CanHear", heard)
end

return Debugger
