--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-90DE865C86116C29DA74

return function(ctx)
	ctx.attack = function(root, humanoid)
		if
			not ctx.confirmedTarget
			or not ctx.lockedCharacter
			or not root:IsDescendantOf(ctx.lockedCharacter)
			or not humanoid:IsDescendantOf(ctx.lockedCharacter)
			or humanoid.Health <= 0
		then
			return
		end

		ctx.cancelBreach()
		ctx.resetMovement()
		ctx.setState("Attacking")
		ctx.attackUntil = os.clock() + ctx.SETTINGS.AttackCooldown

		local direction = ctx.flat(root.Position - ctx.root.Position)
		direction = if direction.Magnitude > 0.01 then direction.Unit else ctx.root.CFrame.LookVector

		local claimed = false
		local ok, err = pcall(function()
			if root:CanSetNetworkOwnership() then
				root:SetNetworkOwner(nil)
				claimed = true
			end

			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			-- Copyright (c) 2026 ZakirGG | APFAI-90DE865C86116C29DA74/01 | Proprietary source.
			root:ApplyImpulse(
				(direction * ctx.SETTINGS.Knockback + Vector3.new(0, ctx.SETTINGS.UpwardKnockback, 0))
					* root.AssemblyMass
			)
		end)

		if not ok then
			warn("[APFAI 1.0 Combat]", err)
		end

		-- Resolve the committed hit on the original humanoid only, even if the player respawns.
		local victimCharacter = ctx.lockedCharacter

		task.delay(ctx.SETTINGS.DeathDelay, function()
			if humanoid:IsDescendantOf(victimCharacter) and humanoid.Health > 0 then
				humanoid.Health = 0
			end

			if claimed and root.Parent then
				pcall(function()
					if root:CanSetNetworkOwnership() then
						root:SetNetworkOwnershipAuto()
					end
				end)
			end
		end)
	end
end
