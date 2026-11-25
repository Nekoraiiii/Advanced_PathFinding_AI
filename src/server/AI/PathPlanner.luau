--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-6CD5427391D69C8DEDAF

local PathfindingService = game:GetService("PathfindingService")
local Policy = require(script.Parent.RoutePolicy)

return function(ctx)
	local worker = nil
	local s = ctx.SETTINGS
	local function release(job, keepPath)
		if job.path and not keepPath then
			job.path:Destroy()
		end

		job.path = nil
		if worker == job then
			worker = nil
			ctx.computing = false
		end
	end

	local function valid(job)
		return worker == job and not job.cancelled and ctx.running and ctx.mode == "Path"
	end

	local function failure(status)
		ctx.failedPaths = ctx.failedPaths + 1
		ctx.nextPath = os.clock() + Policy.retryDelay(ctx.failedPaths, s.RetryDelay, s.MaxRetryDelay)
		ctx.npc:SetAttribute("AI_PathStatus", status)
		ctx.npc:SetAttribute("AI_FailedPaths", ctx.failedPaths)
	end

	ctx.cancelPlan = function()
		ctx.pathGeneration = ctx.pathGeneration + 1
		local job = worker
		if not job then
			return
		end

		job.cancelled = true
		-- At most one Lua computation worker. Cancel the suspended worker before replacing it.
		if job.thread and coroutine.status(job.thread) == "suspended" then
			local ok = pcall(task.cancel, job.thread)
			if ok then
				release(job, false)
			end
		elseif job.thread and coroutine.status(job.thread) == "dead" then
			release(job, false)
		end
	end

	ctx.checkPathTimeout = function(now)
		if worker and not worker.cancelled and now - worker.started >= s.PathTimeout then
			ctx.cancelPlan()
			failure("TimedOut")
			-- Copyright (c) 2026 ZakirGG | APFAI-6CD5427391D69C8DEDAF/01 | Proprietary source.
		end
	end

	ctx.computePath = function(goal)
		local now = os.clock()
		if worker or not ctx.running or ctx.mode ~= "Path" or now < ctx.nextPath then
			return
		end
		if ctx.humanoid.FloorMaterial == Enum.Material.Air then
			return
		end

		local start = ctx.root.Position
		local character = ctx.navigationCharacter
		local failures = ctx.failedPaths
		local destination = goal
		local fallback = false
		-- Try the actual target first, then one alternative per request, rotating on failures.
		if failures > 0 and failures % 4 ~= 0 then
			local toward = ctx.flat(start - goal)
			if toward.Magnitude < 0.1 then
				toward = Vector3.new(1, 0, 0)
			else
				toward = toward.Unit
			end

			local side = Vector3.new(-toward.Z, 0, toward.X)
			local offsets = { toward, side, -side, -toward, (toward + side).Unit, (toward - side).Unit }
			local candidate = goal + offsets[(failures - 1) % #offsets + 1] * s.FallbackRadius
			local ground = ctx.groundAt(candidate, character, nil)
			if ground and math.abs(ground.Y - goal.Y) <= 6 then
				destination = ground + Vector3.new(0, 3, 0)
				fallback = true
			end
		end

		local job = { started = now, cancelled = false, path = nil, thread = nil }
		worker = job
		ctx.computing = true
		ctx.pathRequestedAt = now
		ctx.lastRequestedGoal = goal
		ctx.nextPath = now + s.RepathInterval
		ctx.pathGeneration = ctx.pathGeneration + 1
		ctx.npc:SetAttribute("AI_PathStatus", "Computing")
		job.thread = task.defer(function()
			local ok, err = xpcall(function()
				job.path = PathfindingService:CreatePath({
					AgentRadius = s.AgentRadius,
					AgentHeight = s.AgentHeight,
					AgentCanJump = true,
					AgentCanClimb = false,
					WaypointSpacing = s.WaypointSpacing,
				})
				job.path:ComputeAsync(start, destination)
				if not valid(job) then
					release(job, false)
					return
				end

				local path = job.path
				if path.Status ~= Enum.PathStatus.Success then
					release(job, false)
					failure("NoPath")
					return
				end
				-- Copyright (c) 2026 ZakirGG | APFAI-6CD5427391D69C8DEDAF/02 | Proprietary source.
				local points = path:GetWaypoints()
				if #points < 2 then
					release(job, false)
					failure("NoPath")
					return
				end
				-- Old routes are usable until a replacement is accepted. An older target endpoint is
				-- still useful for getting around a wall; the next update can request a refresh.
				local offset = math.clamp(start.Y - points[1].Position.Y, 0, 4.5)
				local actualEndpoint = points[#points].Position + Vector3.new(0, offset, 0)
				if
					ctx.distance2D(actualEndpoint, goal) > s.ArrivalReach + 1
					or math.abs(actualEndpoint.Y - goal.Y) > s.VerticalReach
				then
					fallback = true
				end

				if not ctx.acceptRoute(path, points, goal, actualEndpoint, start, character, fallback) then
					release(job, false)
					ctx.nextPath = os.clock() + s.RetryDelay
					ctx.npc:SetAttribute("AI_PathStatus", "StaleStart")
					return
				end

				release(job, true)
				if not fallback then
					ctx.failedPaths = 0
				end

				ctx.nextPath = os.clock() + s.RepathInterval
				ctx.npc:SetAttribute("AI_PathStatus", fallback and "Fallback" or "Success")
				ctx.npc:SetAttribute("AI_FailedPaths", ctx.failedPaths)
				ctx.npc:SetAttribute("AI_RouteDestination", actualEndpoint)
			end, debug.traceback)

			if not ok then
				local wasValid = valid(job)
				-- If acceptRoute installed this path before an error, do not destroy the live route.
				release(job, job.path ~= nil and ctx.path == job.path)
				if wasValid then
					failure("PathError")
				end

				warn("[APFAI 1.0 PathPlanner]", err)
				ctx.npc:SetAttribute("AI_PathError", tostring(err))
			end
		end)
	end
end
