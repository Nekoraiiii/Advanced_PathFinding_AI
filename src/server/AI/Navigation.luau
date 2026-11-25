--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-CCB1CA4364402F4F075D

-- Orchestration only: planner, waypoint follower and recovery own their own lifecycle.
return function(ctx)
	require(script.Parent.WaypointFollower)(ctx)
	require(script.Parent.PathPlanner)(ctx)
	require(script.Parent.Recovery)(ctx)
	local s = ctx.SETTINGS
	local fallbackHoldUntil = 0
	ctx.resetPath = function()
		ctx.cancelPlan()
		ctx.clearRoute()
		ctx.nextPath = 0
		fallbackHoldUntil = 0
		ctx.npc:SetAttribute("AI_PathStatus", "Reset")
		ctx.npc:SetAttribute("AI_RouteDestination", nil)
	end

	ctx.setMode = function(mode)
		if ctx.mode == mode then
			return
		end
		ctx.resetPath()
		ctx.mode = mode
		ctx.modeSince = os.clock()
		ctx.directSince = nil
		if mode ~= "Breach" then
			ctx.committedWall = nil
			ctx.wallPoint = nil
			ctx.strikeAt = 0
		end
		ctx.npc:SetAttribute("AI_Mode", mode)
	end

	ctx.resetMovement = function()
		if ctx.mode ~= "None" then
			ctx.setMode("None")
		else
			ctx.resetPath()
		end
		ctx.halt()
		ctx.navigationGoal = nil
		ctx.navigationCharacter = nil
		ctx.failedPaths = 0
		ctx.npc:SetAttribute("AI_FailedPaths", 0)
		ctx.resetRecovery()
	end
	-- Copyright (c) 2026 ZakirGG | APFAI-CCB1CA4364402F4F075D/01 | Proprietary source.
	ctx.navigate = function(goal, character)
		if not ctx.running then
			return false
		end

		local now = os.clock()
		local oldGoal = ctx.navigationGoal
		ctx.navigationGoal = goal
		ctx.navigationCharacter = character
		if oldGoal and (oldGoal - goal).Magnitude >= s.TargetShift then
			fallbackHoldUntil = 0
		end

		ctx.checkPathTimeout(now)
		if ctx.updateRecovery(now, character) then
			return false
		end

		local clear = ctx.directClear(goal, character, nil)
		local distance = ctx.distance2D(ctx.root.Position, goal)
		if clear and distance <= s.ArrivalReach and math.abs(ctx.root.Position.Y - goal.Y) <= s.VerticalReach then
			ctx.resetMovement()
			return true
		end

		local direct = clear and now >= ctx.recoveryUntil
		if direct then
			ctx.directSince = ctx.directSince or now
		else
			ctx.directSince = nil
		end

		if
			direct
			and (
				ctx.mode == "Direct"
				or ctx.mode == "None"
				or (
					ctx.directSince
					and now - ctx.directSince >= s.DirectConfirm
					and now - ctx.modeSince >= s.ModeCommit
				)
			)
		then
			ctx.setMode("Direct")
			ctx.move(goal)
			return false
		end

		if ctx.mode ~= "Path" then
			ctx.setMode("Path")
			ctx.halt()
		end

		if ctx.blocked then
			ctx.clearRoute()
			ctx.halt()
		end

		if ctx.path then
			local result = ctx.followPath()
			if result == "Completed" then
				local wasFallback = ctx.routeFallback
				ctx.clearRoute()
				ctx.halt()
				-- Copyright (c) 2026 ZakirGG | APFAI-CCB1CA4364402F4F075D/02 | Proprietary source.
				if wasFallback or not clear then
					-- Do not treat arrival at an approximate endpoint as reaching the real target.
					ctx.failedPaths = ctx.failedPaths + 1
					fallbackHoldUntil = now + s.FallbackRetry
					ctx.nextPath = fallbackHoldUntil
					ctx.npc:SetAttribute("AI_PathStatus", "FallbackReached")
					ctx.npc:SetAttribute("AI_FailedPaths", ctx.failedPaths)
				else
					ctx.nextPath = now + s.RetryDelay
					ctx.npc:SetAttribute("AI_PathStatus", "Completed")
				end
			end
		end

		local targetMoved = ctx.pathGoal and (goal - ctx.pathGoal).Magnitude >= s.TargetShift
		if (not ctx.path or targetMoved) and not ctx.computing and now >= ctx.nextPath and now >= fallbackHoldUntil then
			ctx.computePath(goal)
		end

		if not ctx.path then
			if direct then
				ctx.move(goal)
			else
				ctx.halt()
			end
		end
		return false
	end
end
