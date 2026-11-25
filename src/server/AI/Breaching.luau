--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-0EF12DB3E82D76549516

-- Wall approach, strike, and physical crossing are one committed action.
return function(ctx)
	local s = ctx.SETTINGS
	local failed = setmetatable({}, { __mode = "k" })
	local crossing = nil

	local function clearCrossing()
		crossing = nil
		ctx.breachExitPoint = nil
		ctx.breachExitUntil = 0
		ctx.npc:SetAttribute("AI_BreachTraversing", false)
	end
	ctx.cancelBreach = function()
		clearCrossing()
		ctx.committedWall = nil
		ctx.wallPoint = nil
		ctx.strikeAt = 0
	end

	local function abandon(wall, reason)
		if wall then
			failed[wall] = os.clock() + s.FailedWallCooldown
		end
		ctx.cancelBreach()
		ctx.resetMovement()
		ctx.recoveryUntil = os.clock() + 0.5
		ctx.npc:SetAttribute("AI_LastDecision", reason)
		return false
	end

	ctx.beginBreach = function(hit, character)
		if not ctx.confirmedTarget or ctx.isRecovering() then
			return false
		end
		local wall = hit.Instance
		local now = os.clock()
		if not ctx.isBreakable(wall) or (failed[wall] or 0) > now then
			return false
		end
		if math.abs(hit.Position.Y - ctx.root.Position.Y) > 2.5 then
			return false
		end
		local delta = ctx.flat(hit.Position - ctx.root.Position)
		if delta.Magnitude < 0.1 then
			return false
		end
		local approach = ctx.root.Position + delta.Unit * math.max(0, delta.Magnitude - (s.BreakDistance - 1.4))
		if delta.Magnitude > s.BreakDistance and not ctx.directClear(approach, character, nil) then
			return false
		end
		ctx.setMode("Breach")
		ctx.halt()
		ctx.committedWall = wall
		ctx.wallPoint = hit.Position
		ctx.breachStarted = now
		ctx.breachProgressAt = now
		ctx.breachBestDistance = delta.Magnitude
		ctx.strikeAt = 0
		ctx.setState("Breaking")
		ctx.npc:SetAttribute("AI_LastDecision", "Committed to breakable wall")
		return true
	end
	-- Compute intersection with the far boundary of the actual rotated rectangular wall.
	local function farBoundary(wall, hit, direction)
		local point = wall.CFrame:PointToObjectSpace(hit)
		local dir = wall.CFrame:VectorToObjectSpace(direction)
		local h = wall.Size / 2
		local far = math.huge

		for _, axis in ipairs({ { point.X, dir.X, h.X }, { point.Y, dir.Y, h.Y }, { point.Z, dir.Z, h.Z } }) do
			if math.abs(axis[2]) > 0.0001 then
				local boundary = axis[2] > 0 and axis[3] or -axis[3]
				local t = (boundary - axis[1]) / axis[2]
				if t >= -0.02 then
					far = math.min(far, math.max(0, t))
				end
			end
		end
		-- Copyright (c) 2026 ZakirGG | APFAI-0EF12DB3E82D76549516/01 | Proprietary source.
		if far == math.huge then
			return nil
		end
		return hit + direction * far
	end

	local function crossingGoal(data, character)
		-- Shorten the exit when a second solid wall is close. Never pass blindly through it.
		local side = Vector3.new(-data.direction.Z, 0, data.direction.X)

		for _, distance in ipairs({ s.BreachExitDistance, 1.6, 0.9 }) do
			for _, lateral in ipairs({ 0, 0.75, -0.75 }) do
				local candidate = data.far + data.direction * distance + side * lateral
				candidate = Vector3.new(candidate.X, ctx.root.Position.Y, candidate.Z)
				if ctx.directClear(candidate, character, nil) then
					return candidate
				end
			end
		end
		return nil
	end

	ctx.updateBreach = function()
		local wall, point = ctx.committedWall, ctx.wallPoint

		if not ctx.confirmedTarget or not wall or not wall.Parent or not point or not ctx.isBreakable(wall) then
			return abandon(nil, "Breach no longer valid")
		end

		local now = os.clock()

		if now - ctx.breachStarted >= s.BreakTimeout then
			return abandon(wall, "Breach timed out")
		end

		local character = ctx.lockedCharacter
		local delta = ctx.flat(point - ctx.root.Position)
		local distance = delta.Magnitude
		local direction = distance > 0.01 and delta.Unit or ctx.flat(ctx.root.CFrame.LookVector)

		if direction.Magnitude < 0.01 then
			return abandon(wall, "Invalid strike direction")
		end

		direction = direction.Unit
		ctx.setState("Breaking")

		if distance > s.BreakDistance then
			if distance < ctx.breachBestDistance - 0.3 then
				ctx.breachBestDistance = distance
				ctx.breachProgressAt = now
			elseif now - ctx.breachProgressAt >= s.StuckTimeout then
				return abandon(wall, "Wall approach obstructed")
			end
			ctx.strikeAt = 0
			local approach = ctx.root.Position + direction * math.max(0, distance - (s.BreakDistance - 1.4))
			if not ctx.directClear(approach, character, nil) then
				return abandon(wall, "Wall approach no longer clear")
			end
			ctx.move(approach)
			return true
		end
		-- Recast from the current root. Require this exact wall, not empty space or another part.
		local hit = ctx.obstacle(ctx.root.Position + direction * (distance + 0.7), character)

		if not hit or hit.Instance ~= wall or (hit.Position - ctx.root.Position).Magnitude > s.BreakDistance + 0.5 then
			return abandon(wall, "Wall strike obstructed")
		end

		if ctx.strikeAt == 0 then
			ctx.halt()
			ctx.strikeAt = now + s.BreakWindup
			return true
		end

		if now < ctx.strikeAt then
			return true
		end

		local far = farBoundary(wall, hit.Position, direction)

		if not far then
			return abandon(wall, "Cannot determine wall exit")
		end

		if not ctx.shatter(wall, direction) then
			return abandon(wall, "Wall destruction failed")
		end
		-- Copyright (c) 2026 ZakirGG | APFAI-0EF12DB3E82D76549516/02 | Proprietary source.
		ctx.resetMovement()
		ctx.setState("Chasing")

		local data = {
			far = far,
			direction = direction,
			untilTime = now + s.BreachTraverseTimeout,
			lastPosition = ctx.root.Position,
			lastProgress = now,
		}

		local goal = crossingGoal(data, character)

		if not goal then
			-- Geometry physically cannot fit the rig at this exit. Resume ordinary pathfinding.
			clearCrossing()
			ctx.npc:SetAttribute("AI_LastDecision", "Wall destroyed; exit blocked, replanning")
			return false
		end

		crossing = data

		ctx.breachExitPoint = goal
		ctx.breachExitUntil = data.untilTime
		ctx.setMode("Direct")
		ctx.npc:SetAttribute("AI_BreachTraversing", true)
		ctx.npc:SetAttribute("AI_LastDecision", "Wall destroyed; crossing opening")
		ctx.move(goal, true)
		return true
	end

	ctx.updateBreachTraversal = function()
		if not crossing or not ctx.breachExitPoint then
			return false
		end

		local data = crossing
		local now = os.clock()
		local beyond = ctx.flat(ctx.root.Position - data.far):Dot(data.direction)

		if not ctx.confirmedTarget or beyond >= 0.65 then
			clearCrossing()
			ctx.resetMovement()
			ctx.npc:SetAttribute("AI_LastDecision", "Opening crossed; resuming chase")
			return false
		end

		if (ctx.root.Position - data.lastPosition).Magnitude >= 0.45 then
			data.lastPosition = ctx.root.Position
			data.lastProgress = now
		end

		if now >= data.untilTime or now - data.lastProgress >= s.StuckTimeout then
			clearCrossing()
			ctx.resetMovement()
			ctx.recoveryUntil = now + 0.5
			ctx.npc:SetAttribute("AI_LastDecision", "Crossing obstructed; replanning")
			return false
		end

		local character = ctx.lockedCharacter
		local goal = ctx.breachExitPoint

		if not ctx.directClear(goal, character, nil) then
			goal = crossingGoal(data, character)
			if not goal then
				clearCrossing()
				ctx.resetMovement()
				return false
			end
			ctx.breachExitPoint = goal
		end

		ctx.setState("Chasing")
		if ctx.distance2D(ctx.root.Position, goal) <= 2 then
			ctx.steer(goal)
		else
			ctx.move(goal)
		end
		return true
	end
end
