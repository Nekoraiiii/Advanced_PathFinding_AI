--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-6EE8CF7C21153635F2FE

local Players = game:GetService("Players")
local Policy = require(script.Parent.RoutePolicy)

return function(ctx)
	local function chase(character, humanoid, root)
		ctx.setAggro(ctx.target)
		ctx.visible = ctx.Perception.CanSee(ctx.npc, character)

		local heard, sound = ctx.Perception.CanHear(ctx.npc, character)
		ctx.heard = heard

		if ctx.visible then
			ctx.TargetMemory.Remember(ctx.memory, ctx.target, root.Position, true)
		elseif heard and sound then
			ctx.TargetMemory.Remember(ctx.memory, ctx.target, sound, false)
		end

		local distance = (root.Position - ctx.root.Position).Magnitude
		local hit = ctx.obstacle(root.Position, character)

		if distance <= ctx.SETTINGS.AttackRange and not hit then
			ctx.attack(root, humanoid)
			return
		end

		if ctx.updateBreachTraversal() then
			return
		end

		if ctx.mode == "Breach" and ctx.updateBreach() then
			return
		end

		ctx.setState("Chasing")
		if hit and ctx.beginBreach(hit, character) then
			return
		end

		local goal = root.Position

		if ctx.visible and distance > 10 then
			local predicted = ctx.Prediction.GetPosition(ctx.npc, root)
			if ctx.directClear(predicted, character, nil) then
				goal = predicted
			end
		end

		ctx.navigate(goal, character)
		ctx.monitorProgress()
	end

	ctx.update = function()
		local now = os.clock()
		-- Confirmed target lifetime does not depend on visibility, sound, paths or memory expiry.
		if ctx.confirmedTarget then
			local player, locked = ctx.target, ctx.lockedCharacter
			local humanoid = locked and locked:FindFirstChildWhichIsA("Humanoid")
			local present = player ~= nil and player.Parent == Players
			local replaced = present and player.Character ~= nil and player.Character ~= locked
			local dead = humanoid ~= nil and humanoid.Health <= 0
			-- Copyright (c) 2026 ZakirGG | APFAI-6EE8CF7C21153635F2FE/01 | Proprietary source.
			local removed = locked ~= nil and locked.Parent == nil and present and player.Character == nil

			if Policy.targetEnded(present, replaced == true, dead == true, removed == true) then
				ctx.forgetTarget()
			else
				if now < ctx.attackUntil then
					return
				end
				local character, h, root = ctx.getCharacter(player)
				if not character or not h or not root then
					-- Missing components are not evidence of death. Wait without dropping aggression.
					if not ctx.targetWaiting then
						ctx.cancelBreach()
						ctx.resetMovement()
						ctx.setState("Chasing")
						ctx.targetWaiting = true
					end
					ctx.visible = false
					ctx.heard = false
					ctx.npc:SetAttribute("AI_LastDecision", "Locked target temporarily unavailable")
					return
				end
				ctx.targetWaiting = false
				chase(character, h, root)
				return
			end
		end

		if now < ctx.attackUntil then
			return
		end

		ctx.visible = false
		ctx.heard = false
		ctx.setAggro(nil)

		local detection = ctx.Perception.Scan(ctx.npc, ctx.visualCandidate)

		if detection and detection.Visible then
			ctx.visible = true
			ctx.heard = detection.Heard
			if ctx.visualCandidate ~= detection.Player then
				ctx.visualCandidate = detection.Player
				ctx.visualSince = now
			end
			if now - ctx.visualSince >= ctx.Config.VisualConfirmTime then
				local character, humanoid, root = ctx.getCharacter(detection.Player)
				if character and humanoid and root then
					ctx.cancelRoomSearch()
					ctx.acquire(detection.Player)
					ctx.cancelBreach()
					ctx.resetMovement()
					ctx.confirmedTarget = true
					ctx.lockedCharacter = character
					ctx.targetWaiting = false
					ctx.searchCenter = nil
					ctx.searchUntil = 0
					ctx.destination = nil
					ctx.npc:SetAttribute("AI_ConfirmedTarget", true)
					-- Copyright (c) 2026 ZakirGG | APFAI-6EE8CF7C21153635F2FE/02 | Proprietary source.
					ctx.npc:SetAttribute("AI_LastDecision", "Visual confirmation; target locked")
					ctx.TargetMemory.Remember(ctx.memory, detection.Player, root.Position, true)
					ctx.setAggro(detection.Player)
					ctx.setState("Chasing")
					chase(character, humanoid, root)
					return
				end
			end
			-- Pause during a short confirmation; do not send competing path commands.
			ctx.halt()
			return
		end

		ctx.visualCandidate = nil

		if detection and detection.Heard and detection.Position then
			ctx.heard = true
			if not ctx.target and now >= (ctx.soundReacquireAt or 0) then
				ctx.acquire(detection.Player)
				ctx.TargetMemory.Remember(ctx.memory, detection.Player, detection.Position, false)
				ctx.searchCenter = nil
				ctx.destination = nil
				ctx.investigationUntil = now + ctx.Config.InvestigationTimeout
				ctx.resetMovement()
				ctx.npc:SetAttribute("AI_LastDecision", "Investigating fixed sound location")
			end
		end

		if ctx.target then
			if ctx.searchCenter then
				ctx.updateSearching(ctx.searchCenter)
			elseif ctx.memory.Position and now < (ctx.investigationUntil or 0) then
				ctx.setState("Investigating")
				if ctx.navigate(ctx.memory.Position, nil) then
					ctx.updateSearching(ctx.memory.Position)
				end
			elseif ctx.memory.Position then
				ctx.updateSearching(ctx.memory.Position)
			else
				ctx.forgetTarget()
			end
		else
			ctx.cancelRoomSearch()
			ctx.updateWandering()
		end
		if ctx.state ~= "Searching" then
			ctx.monitorProgress()
		end
	end
end
