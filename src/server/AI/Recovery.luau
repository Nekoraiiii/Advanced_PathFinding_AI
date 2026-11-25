--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-6C9B023B79431E6C4453

local Policy = require(script.Parent.RoutePolicy)

return function(ctx)
	local escapeGoal = nil
	local escapeUntil = 0
	local attempts = 0
	local lastRecovery = -math.huge
	local s = ctx.SETTINGS
	ctx.resetRecovery = function()
		escapeGoal = nil
		escapeUntil = 0
		attempts = 0
		lastRecovery = -math.huge
		ctx.recoveryUntil = 0
		ctx.progressPosition = ctx.root.Position
		ctx.progressTime = os.clock()
		ctx.lastRouteTime = os.clock()
		ctx.npc:SetAttribute("AI_NavigationStuckTime", 0)
		ctx.npc:SetAttribute("AI_RecoveryAttempts", 0)
		ctx.npc:SetAttribute("AI_RecoveryActive", false)
	end

	ctx.isRecovering = function()
		return escapeGoal ~= nil or os.clock() < ctx.recoveryUntil
	end

	ctx.updateRecovery = function(now, character)
		if not escapeGoal then
			return false
		end

		if
			now >= escapeUntil
			or ctx.distance2D(ctx.root.Position, escapeGoal) <= 1.2
			or not ctx.directClear(escapeGoal, character, nil)
		then
			escapeGoal = nil
			ctx.halt()
			ctx.nextPath = 0
			ctx.progressPosition = ctx.root.Position
			ctx.progressTime = now
			ctx.lastRouteTime = now
			ctx.npc:SetAttribute("AI_RecoveryActive", false)
			return false
		end
		-- Copyright (c) 2026 ZakirGG | APFAI-6C9B023B79431E6C4453/01 | Proprietary source.
		ctx.move(escapeGoal)
		return true
	end

	ctx.monitorProgress = function()
		local now = os.clock()
		if
			not ctx.navigationGoal
			or ctx.mode == "Breach"
			or ctx.breachExitPoint
			or ctx.state == "Idle"
			or ctx.state == "Attacking"
		then
			return
		end

		if escapeGoal then
			return
		end

		local moved = (ctx.root.Position - ctx.progressPosition).Magnitude >= s.MinimumProgress
		if moved then
			ctx.progressPosition = ctx.root.Position
			ctx.progressTime = now
			ctx.lastRouteTime = now
		end

		local commanded = ctx.lastCommand ~= nil
		if commanded then
			ctx.lastRouteTime = now
		end

		local progressAt = math.max(ctx.progressTime, ctx.commandStartedAt or 0)
		local stuck = now - (commanded and progressAt or ctx.lastRouteTime)
		ctx.npc:SetAttribute("AI_NavigationStuckTime", math.round(stuck * 10) / 10)
		local waypointStuck = commanded
			and ctx.path
			and not ctx.blocked
			and now - (ctx.waypointProgressAt or now) >= s.StuckTimeout * 1.5
		if
			not waypointStuck
			and not Policy.shouldRecover(
				now,
				progressAt,
				commanded,
				ctx.lastRouteTime,
				lastRecovery,
				s.StuckTimeout,
				s.NoRouteTimeout,
				s.RecoveryCooldown
			)
		then
			return
		end

		if now - lastRecovery < s.RecoveryCooldown then
			return
		end
		-- Recovery is evaluated even during a request or its retry cooldown.
		lastRecovery = now
		attempts = attempts + 1
		ctx.setMode("Path")
		ctx.cancelPlan()
		ctx.clearRoute()
		ctx.halt()
		ctx.recoveryUntil = now + s.RecoveryDuration
		-- Copyright (c) 2026 ZakirGG | APFAI-6C9B023B79431E6C4453/02 | Proprietary source.
		ctx.nextPath = now + s.RetryDelay
		ctx.progressTime = now
		ctx.progressPosition = ctx.root.Position
		ctx.lastRouteTime = now
		ctx.npc:SetAttribute("AI_RecoveryAttempts", attempts)
		ctx.npc:SetAttribute("AI_LastDecision", "Recovery: seeking clearance")
		ctx.npc:SetAttribute("AI_PathStatus", "Recovering")
		local forward = ctx.flat(ctx.root.CFrame.LookVector)
		if forward.Magnitude < 0.1 then
			forward = Vector3.new(0, 0, -1)
		else
			forward = forward.Unit
		end

		local side = Vector3.new(-forward.Z, 0, forward.X)
		local choices = { -forward, side, -side, (-forward + side).Unit, (-forward - side).Unit }
		for j = 1, #choices do
			local dir = choices[(j + attempts - 2) % #choices + 1]
			local candidate = ctx.root.Position + dir * s.RecoveryDistance
			if ctx.directClear(candidate, ctx.navigationCharacter, nil) then
				escapeGoal = candidate
				escapeUntil = now + s.RecoveryDuration
				ctx.npc:SetAttribute("AI_RecoveryActive", true)
				ctx.move(candidate, true)
				return
			end
		end
        
		if attempts % 3 == 0 then
			ctx.jump()
		end
		ctx.npc:SetAttribute("AI_RecoveryActive", false)
		-- No safe displacement exists. Keep trying routes without dropping the target.
	end
end
