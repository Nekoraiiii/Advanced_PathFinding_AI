--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-3A826C184333E9A38230

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

type State = "Idle" | "Wandering" | "Investigating" | "Searching" | "Chasing" | "Breaking" | "Attacking" | "Recovering"
type Mode = "None" | "Direct" | "Path" | "Breach"

return function(ctx)
	ctx.updateDebug = function()
		local distance = -1
		local _, _, victimRoot = ctx.getCharacter(ctx.target)

		if victimRoot then
			distance = (victimRoot.Position - ctx.root.Position).Magnitude
		end
		-- Copyright (c) 2026 ZakirGG | APFAI-3A826C184333E9A38230/01 | Proprietary source.
		ctx.Debugger.Update(
			ctx.npc,
			ctx.state,
			ctx.mode,
			ctx.target,
			distance,
			ctx.waypointIndex,
			#ctx.waypoints,
			ctx.visible,
			ctx.heard
		)

		ctx.npc:SetAttribute("AI_ComputingPath", ctx.computing)
		ctx.npc:SetAttribute(
			"AI_ActualSpeed",
			math.round(ctx.flat(ctx.root.AssemblyLinearVelocity).Magnitude * 10) / 10
		)
		ctx.npc:SetAttribute("AI_WalkSpeed", ctx.humanoid.WalkSpeed)
		ctx.npc:SetAttribute("AI_StuckTime", ctx.npc:GetAttribute("AI_NavigationStuckTime") or 0)
		ctx.npc:SetAttribute("AI_LastKnownPosition", ctx.memory.Position)
		ctx.npc:SetAttribute("AI_CommittedWall", if ctx.committedWall then ctx.committedWall.Name else "None")
	end
end
