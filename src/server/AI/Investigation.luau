--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-34B31C24CCB71E31A478

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

type State = "Idle" | "Wandering" | "Investigating" | "Searching" | "Chasing" | "Breaking" | "Attacking" | "Recovering"
type Mode = "None" | "Direct" | "Path" | "Breach"

return function(ctx)
	ctx.updateWandering = function()
		local now = os.clock()

		if now < ctx.idleUntil then
			ctx.setState("Idle")
			return
		end

		if not ctx.destination then
			ctx.destination = ctx.Wander.GetPoint(ctx.npc, ctx.home, ctx.Config.WanderRadius)
			ctx.destinationUntil = now + ctx.SETTINGS.WanderTimeout

			if not ctx.destination then
				ctx.idleUntil = now + 2
				ctx.setState("Idle")
				return
			end
			ctx.resetMovement()
		end

		ctx.setState("Wandering")

		local goal = ctx.destination
		-- Copyright (c) 2026 ZakirGG | APFAI-34B31C24CCB71E31A478/01 | Proprietary source.
		if goal then
			local arrived = ctx.navigate(goal, nil)
			if arrived or now >= ctx.destinationUntil then
				ctx.destination = nil
				ctx.resetMovement()
				ctx.setState("Idle")
				ctx.idleUntil = now + ctx.Wander.GetPause()
			end
		end
	end

	--==================================================
	-- SEARCH BEHAVIOR
	--==================================================

	local random = Random.new()
	local visited, rejected = {}, {}
	local session, pending, route = nil, nil, nil
	local pauseUntil, nextPlan = 0, 0

	local function inside(point, center)
		return ctx.distance2D(point, center) <= ctx.Config.SearchRadius and math.abs(point.Y - center.Y) <= 5
	end

	local function clearRoute()
		if route then
			route.connection:Disconnect()
			route.path:Destroy()
			route = nil
		end
	end

	local function pickPoint(center)
		local origin = ctx.root.Position
		local ground = ctx.groundAt(origin, nil, nil)
		if not ground then
			return nil
		end
		local height = origin.Y - ground.Y
		local best, score = nil, -math.huge

		for i = 1, 32 do
			local angle = random:NextNumber(0, math.pi * 2)
			local radius = ctx.Config.SearchRadius * 0.9 * math.sqrt(random:NextNumber())
			local sample = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local floor = ctx.groundAt(sample, nil, nil)
			if not floor then
				continue
			end

			local point = floor + Vector3.new(0, height, 0)
			if not inside(point, center) or ctx.distance2D(origin, point) < ctx.Config.SearchMinStep then
				continue
			end

			local value = ctx.distance2D(origin, point)
			for _, v in ipairs(visited) do
				value = math.min(value, ctx.distance2D(v, point))
			end

			for _, v in ipairs(rejected) do
				value = math.min(value, ctx.distance2D(v, point) - 3)
			end

			if value > score and value >= ctx.Config.SearchMinStep then
				best, score = point, value
			end
		end
		return best
	end
	-- Copyright (c) 2026 ZakirGG | APFAI-34B31C24CCB71E31A478/02 | Proprietary source.
	local function plan(goal, token)
		if pending then
			return
		end

		pending = token
		local start = ctx.root.Position
		local path = nil
		task.spawn(function()
			local ok = pcall(function()
				path = PathfindingService:CreatePath({
					AgentRadius = ctx.SETTINGS.AgentRadius,
					AgentHeight = ctx.SETTINGS.AgentHeight,
					AgentCanJump = false,
					AgentCanClimb = false,
					WaypointSpacing = ctx.SETTINGS.WaypointSpacing,
				})
				path:ComputeAsync(start, goal)
			end)
			pending = nil
			if
				session ~= token
				or ctx.searchCenter ~= token.center
				or ctx.confirmedTarget
				or not ctx.running
				or ctx.state ~= "Searching"
			then
				if path then
					path:Destroy()
				end
				return
			end

			local points = ok and path and path.Status == Enum.PathStatus.Success and path:GetWaypoints() or {}
			local valid = #points >= 2 and (ctx.root.Position - start).Magnitude <= 2
			local offset = valid and math.clamp(start.Y - points[1].Position.Y, 0, 4.5) or 0
			local length = 0

			for i, point in ipairs(points) do
				local position = point.Position + Vector3.new(0, offset, 0)
				if not inside(position, token.center) or point.Action == Enum.PathWaypointAction.Jump then
					valid = false
				end
				if i > 1 then
					length += (point.Position - points[i - 1].Position).Magnitude
				end
			end
			if
				valid
				and length <= ctx.Config.SearchRouteBudget
				and ctx.distance2D(points[#points].Position, goal) <= 2
			then
				local r = {
					path = path,
					points = points,
					index = 2,
					offset = offset,
					goal = goal,
					deadline = os.clock() + ctx.Config.SearchRouteTimeout,
					blocked = false,
					best = math.huge,
					progress = os.clock(),
				}
				r.connection = path.Blocked:Connect(function(index)
					if index >= r.index then
						r.blocked = true
					end
				end)
				route = r
			else
				if path then
					path:Destroy()
				end
				table.insert(rejected, goal)
			end
		end)
	end

	ctx.cancelRoomSearch = function()
		session = nil
		clearRoute()
	end

	ctx.updateSearching = function(center)
		local now = os.clock()
		if not ctx.searchCenter then
			ctx.searchCenter = center
			ctx.searchUntil = now + ctx.Config.SearchDuration
			ctx.destination = nil
			ctx.resetMovement()
			clearRoute()
			session = { center = center }
			table.clear(visited)
			table.clear(rejected)
			pauseUntil = now
			nextPlan = now
		end

		if now >= ctx.searchUntil then
			ctx.cancelRoomSearch()
			ctx.forgetTarget()
			return
		end

		ctx.setState("Searching")
		if not inside(ctx.root.Position, ctx.searchCenter) then
			-- A failed investigation may finish outside the radius. Continue approaching the sound.
			ctx.navigate(ctx.searchCenter, nil)
			ctx.monitorProgress()
			return
		end

		if ctx.navigationGoal then
			ctx.resetMovement()
		end

		if route then
			local r = route
			local point = r.points[r.index]
			if r.blocked or now >= r.deadline or now - r.progress > 3 then
				table.insert(rejected, r.goal)
				clearRoute()
				ctx.halt()
				nextPlan = now + ctx.Config.SearchRetry
				return
			end

			if not point then
				table.insert(visited, r.goal)
				clearRoute()
				ctx.halt()
				pauseUntil = now + ctx.Config.SearchPause
				return
			end

			local goal = point.Position + Vector3.new(0, r.offset, 0)
			local distance = ctx.distance2D(ctx.root.Position, goal)
			if distance < r.best - 0.2 then
				r.best = distance
				r.progress = now
			end

			if
				distance <= ctx.SETTINGS.WaypointReach
				and math.abs(ctx.root.Position.Y - goal.Y) <= ctx.SETTINGS.VerticalReach
			then
				r.index += 1
				r.best = math.huge
				r.progress = now
				return
			end

			if not inside(goal, ctx.searchCenter) or not ctx.directClear(goal, nil, nil) then
				table.insert(rejected, r.goal)
				clearRoute()
				ctx.halt()
				nextPlan = now + ctx.Config.SearchRetry
				return
			end
			ctx.move(goal)
			return
		end
		ctx.halt()
		if pending or now < pauseUntil or now < nextPlan then
			return
		end
		nextPlan = now + ctx.Config.SearchRetry
		local goal = pickPoint(ctx.searchCenter)
		if goal then
			plan(goal, session)
		end
	end
end
