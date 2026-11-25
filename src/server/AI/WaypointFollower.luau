--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-DB8EC1174E8173DE0F57

return function(ctx)
	local best = math.huge
	local bestIndex = -1

	ctx.clearRoute = function()
		if ctx.blockedConnection then
			ctx.blockedConnection:Disconnect()
			ctx.blockedConnection = nil
		end

		if ctx.path then
			ctx.path:Destroy()
			ctx.path = nil
		end

		ctx.waypoints = {}
		ctx.waypointIndex = 2
		ctx.lastJumpIndex = -1
		ctx.blocked = false
		ctx.pathGoal = nil
		ctx.routeDestination = nil
		ctx.routeFallback = false
		ctx.waypointOffset = 0
		best = math.huge
		bestIndex = -1
		ctx.npc:SetAttribute("AI_CurrentWaypointPosition", nil)
		ctx.npc:SetAttribute("AI_WaypointDistance", nil)
		ctx.npc:SetAttribute("AI_BlockedWaypoint", nil)
	end

	ctx.waypointGoal = function(point, offset)
		return point.Position + Vector3.new(0, offset or ctx.waypointOffset or 0, 0)
	end

	ctx.acceptRoute = function(path, points, requested, destination, start, character, fallback)
		local drift = ctx.distance2D(ctx.root.Position, start)
		local offset = math.clamp(start.Y - points[1].Position.Y, 0, 4.5)
		local index = 2
		-- A moving NPC must join a forward, safely reachable segment, not blindly return to the old start.
		if drift > ctx.SETTINGS.WaypointReach then
			if drift > ctx.SETTINGS.MaxStartDrift then
				return false
			end

			local found = false
			for i = 2, math.min(#points, 6) do
				if points[i].Action == Enum.PathWaypointAction.Jump then
					break
				end

				local goal = ctx.waypointGoal(points[i], offset)
				if
					ctx.distance2D(ctx.root.Position, goal) <= math.max(4, drift + 2)
					and ctx.directClear(goal, character, nil)
				then
					index = i
					found = true
					-- Copyright (c) 2026 ZakirGG | APFAI-DB8EC1174E8173DE0F57/01 | Proprietary source.
				end
			end

			if not found then
				-- Small drift with the original first segment still usable, including jump routes.
				if drift > 2 then
					return false
				end
				index = 2
			end
		end

		ctx.clearRoute()
		ctx.path = path
		ctx.waypoints = points
		ctx.waypointIndex = index
		ctx.waypointOffset = offset
		ctx.pathGoal = requested
		ctx.routeDestination = destination
		ctx.routeFallback = fallback
		ctx.lastRouteTime = os.clock()
		ctx.waypointProgressAt = os.clock()
		ctx.blockedConnection = path.Blocked:Connect(function(i)
			if ctx.running and ctx.path == path and i >= ctx.waypointIndex then
				ctx.blocked = true
				ctx.nextPath = 0
				ctx.npc:SetAttribute("AI_BlockedWaypoint", i)
				ctx.npc:SetAttribute("AI_PathStatus", "Blocked")
			end
		end)
		return true
	end

	ctx.followPath = function()
		if not ctx.path or ctx.blocked then
			return "None"
		end

		while ctx.waypointIndex <= #ctx.waypoints do
			local i = ctx.waypointIndex
			local point = ctx.waypoints[i]
			local goal = ctx.waypointGoal(point)
			local distance = ctx.distance2D(ctx.root.Position, goal)
			local vertical = math.abs(ctx.root.Position.Y - goal.Y)
			if bestIndex ~= i or distance < best - 0.2 then
				bestIndex = i
				best = distance
				ctx.waypointProgressAt = os.clock()
			end
			-- Copyright (c) 2026 ZakirGG | APFAI-DB8EC1174E8173DE0F57/02 | Proprietary source.
			local jump = point.Action == Enum.PathWaypointAction.Jump
			if jump and ctx.lastJumpIndex ~= i then
				if ctx.jump() then
					ctx.lastJumpIndex = i
				end
				ctx.move(goal)
				return "Moving"
			end

			local reached = distance <= ctx.SETTINGS.WaypointReach and vertical <= ctx.SETTINGS.VerticalReach
			-- A non-jump waypoint may be slightly overshot at chase speed; only advance along the same corridor.
			if not reached and not jump and i < #ctx.waypoints and i > 1 and vertical <= ctx.SETTINGS.VerticalReach then
				local segment = ctx.flat(point.Position - ctx.waypoints[i - 1].Position)
				local beyond = ctx.flat(ctx.root.Position - point.Position)
				if segment.Magnitude > 0.1 and beyond.Magnitude <= 2.5 and beyond:Dot(segment.Unit) >= 0 then
					local lateral = (beyond - segment.Unit * beyond:Dot(segment.Unit)).Magnitude
					local nextPoint = ctx.waypoints[i + 1]
					reached = lateral <= 0.8
						and nextPoint.Action ~= Enum.PathWaypointAction.Jump
						and ctx.directClear(ctx.waypointGoal(nextPoint), ctx.navigationCharacter, nil)
				end
			end

			if not reached then
				ctx.npc:SetAttribute("AI_CurrentWaypointPosition", goal)
				ctx.npc:SetAttribute("AI_WaypointDistance", math.round(distance * 10) / 10)
				ctx.move(goal)
				return "Moving"
			end
			ctx.waypointIndex = ctx.waypointIndex + 1
		end
		return "Completed"
	end
end
