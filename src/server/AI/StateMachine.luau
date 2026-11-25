--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-3DE7C1992E3F1B1719D6

return function(ctx)
	local speeds = {
		Idle = 0,
		Wandering = ctx.Config.WanderSpeed,
		Investigating = ctx.SETTINGS.InvestigateSpeed,
		Searching = ctx.SETTINGS.SearchSpeed,
		Chasing = ctx.Config.ChaseSpeed,
		Breaking = ctx.Config.ChaseSpeed,
		Attacking = 0,
		Recovering = ctx.SETTINGS.SearchSpeed,
	}
	-- Copyright (c) 2026 ZakirGG | APFAI-3DE7C1992E3F1B1719D6/01 | Proprietary source.
	ctx.setState = function(state)
		assert(speeds[state] ~= nil, "Unknown AI state: " .. tostring(state))
		if ctx.state ~= state then
			ctx.state = state
			ctx.npc:SetAttribute("AI_State", state)
		end

		if ctx.humanoid.WalkSpeed ~= speeds[state] then
			ctx.humanoid.WalkSpeed = speeds[state]
		end
	end
end
