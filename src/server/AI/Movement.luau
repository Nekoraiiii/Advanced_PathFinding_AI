--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-6AC00A40274AC19B422C

return function(ctx)
	-- The only module allowed to send NPC movement/jump commands.
	ctx.halt = function()
		if ctx.humanoid.Parent and ctx.root.Parent then
			if ctx.lastCommand or ctx.humanoid.MoveDirection.Magnitude > 0.01 then
				ctx.humanoid:Move(Vector3.zero)
				ctx.humanoid:MoveTo(ctx.root.Position)
			end
		end
		ctx.lastCommand = nil
		ctx.lastCommandTime = 0
		ctx.commandKind = nil
		ctx.npc:SetAttribute("AI_MovementActive", false)
		ctx.npc:SetAttribute("AI_MoveGoal", nil)
	end

	ctx.move = function(goal, force)
		if not ctx.running or ctx.humanoid.Health <= 0 or not ctx.root.Parent then
			return
		end

		if goal.X ~= goal.X or goal.Y ~= goal.Y or goal.Z ~= goal.Z or goal.Magnitude == math.huge then
			return
		end

		local now = os.clock()
		if ctx.humanoid.Sit then
			ctx.humanoid.Sit = false
		end

		if ctx.humanoid.PlatformStand then
			ctx.humanoid.PlatformStand = false
		end

		if
			force
			or ctx.commandKind ~= "MoveTo"
			or not ctx.lastCommand
			or (goal - ctx.lastCommand).Magnitude >= ctx.SETTINGS.MovementThreshold
			or now - ctx.lastCommandTime >= ctx.SETTINGS.MovementRefresh
		then
			if not ctx.lastCommand then
				ctx.commandStartedAt = now
			end
			-- Copyright (c) 2026 ZakirGG | APFAI-6AC00A40274AC19B422C/01 | Proprietary source.
			ctx.humanoid:MoveTo(goal)
			ctx.commandKind = "MoveTo"
			ctx.lastCommand = goal
			ctx.lastCommandTime = now
		end
		ctx.npc:SetAttribute("AI_MovementActive", true)
		ctx.npc:SetAttribute("AI_MoveGoal", goal)
	end

	ctx.steer = function(goal)
		if not ctx.running or ctx.humanoid.Health <= 0 then
			return
		end

		local direction = ctx.flat(goal - ctx.root.Position)
		if direction.Magnitude < 0.05 then
			ctx.halt()
			return
		end

		if not ctx.lastCommand then
			ctx.commandStartedAt = os.clock()
		end

		ctx.humanoid:Move(direction.Unit, false)
		ctx.commandKind = "Steer"
		ctx.lastCommand = goal
		ctx.lastCommandTime = os.clock()
		ctx.npc:SetAttribute("AI_MovementActive", true)
		ctx.npc:SetAttribute("AI_MoveGoal", goal)
	end

	ctx.jump = function()
		if ctx.running and ctx.humanoid.Health > 0 and ctx.humanoid.FloorMaterial ~= Enum.Material.Air then
			ctx.humanoid.Jump = true
			return true
		end
		return false
	end
end
