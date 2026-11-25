--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-00CA1B604D593A7AC4FD

local Players = game:GetService("Players")
return function(ctx)
	ctx.setAggro = function(player)
		if ctx.aggroPlayer == player then
			return
		end

		local previous = ctx.aggroPlayer

		ctx.aggroPlayer = player
		ctx.npc:SetAttribute("AI_AggroUserId", if player then player.UserId else 0)

		local function send(who, active)
			-- Copyright (c) 2026 ZakirGG | APFAI-00CA1B604D593A7AC4FD/01 | Proprietary source.
			if who.Parent == Players then
				local ok, err = pcall(function()
					ctx.remote:FireClient(who, active)
				end)
				if not ok then
					warn("[APFAI 1.0 AggroEvent]", err)
				end
			end
			ctx.Controller.OnAggroChanged:Fire(who, active)
		end

		if previous then
			send(previous, false)
		end

		if player then
			send(player, true)
		end
	end
end
