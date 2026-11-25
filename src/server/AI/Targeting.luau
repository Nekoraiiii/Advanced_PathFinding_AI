--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-73E439AA158DB4F37A37

return function(ctx)
	ctx.forgetTarget = function()
		ctx.target = nil
		ctx.confirmedTarget = false
		ctx.lockedCharacter = nil
		ctx.targetWaiting = false
		ctx.visualCandidate = nil
		ctx.visible = false
		ctx.heard = false
		ctx.npc:SetAttribute("AI_ConfirmedTarget", false)
		ctx.setAggro(nil)
		ctx.TargetMemory.Clear(ctx.memory)
		ctx.searchCenter = nil
		ctx.searchUntil = 0
		ctx.destination = nil
		ctx.destinationUntil = 0
		ctx.cancelBreach()
		ctx.resetMovement()
		ctx.setState("Idle")
		-- Copyright (c) 2026 ZakirGG | APFAI-73E439AA158DB4F37A37/01 | Proprietary source.
		local now = os.clock()
		ctx.soundReacquireAt = now + ctx.Config.SoundReacquireDelay
		ctx.idleUntil = now + ctx.Wander.GetPause()
	end
    
	ctx.acquire = function(player)
		if ctx.target == player then
			return
		end
		ctx.target = player
		ctx.destination = nil
		ctx.searchCenter = nil
		ctx.searchUntil = 0
		ctx.resetMovement()
	end
end
