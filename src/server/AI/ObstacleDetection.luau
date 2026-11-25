--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-9CB8D748CF877A9181DA

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UP = Vector3.new(0, 1, 0)

return function(ctx)
	ctx.rayParams = function(character, ignore)
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		local exclude = { ctx.npc }
		-- Characters are moving entities, not static navigation geometry.
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(exclude, player.Character)
			end
		end

		if character then
			table.insert(exclude, character)
		end

		if ignore then
			table.insert(exclude, ignore)
		end

		p.FilterDescendantsInstances = exclude
		p.RespectCanCollide = true
		p.IgnoreWater = true
		p.CollisionGroup = ctx.NPC_GROUP
		return p
	end

	ctx.obstacle = function(goal, character)
		local delta = goal - ctx.root.Position
		-- Copyright (c) 2026 ZakirGG | APFAI-9CB8D748CF877A9181DA/01 | Proprietary source.
		if delta.Magnitude < 0.01 then
			return nil
		end
		return Workspace:Raycast(ctx.root.Position, delta, ctx.rayParams(character, nil))
	end

	ctx.groundAt = function(position, character, ignore)
		local hit = Workspace:Raycast(position + UP * 2, -UP * 10, ctx.rayParams(character, ignore))
		if hit and hit.Normal.Y >= 0.65 then
			return hit.Position
		end
		return nil
	end

	ctx.directClear = function(goal, character, ignore)
		local origin = ctx.root.Position
		local delta = goal - origin
		local horizontal = ctx.flat(delta)
		local length = horizontal.Magnitude
		local s = ctx.SETTINGS
		if length > s.MaxDirectDistance or math.abs(delta.Y) > 6 then
			return false
		end

		local p = ctx.rayParams(character, ignore)
		local first = Workspace:Raycast(origin + UP * 0.2, -UP * 8, p)
		if not first or first.Normal.Y < 0.65 then
			return false
		end

		local height = math.clamp(origin.Y - first.Position.Y, 1.5, 4.5)
		if length < 0.05 then
			return math.abs(delta.Y) <= s.VerticalReach
		end
		-- Cheap center-line rejection before the more expensive body/ground checks.
		if Workspace:Raycast(origin, delta, p) then
			return false
		end

		local direction = horizontal.Unit
		-- Copyright (c) 2026 ZakirGG | APFAI-9CB8D748CF877A9181DA/02 | Proprietary source.
		local samples = math.max(1, math.ceil(length / s.GroundSampleSpacing))
		local prev = origin
		local lastGround = first.Position.Y
		local width = math.max(0.5, s.AgentRadius * 2 - 0.3)
		for i = 1, samples do
			local sample = origin:Lerp(goal, i / samples)
			local ground = Workspace:Raycast(sample + UP * 2, -UP * 10, p)
			if not ground or ground.Normal.Y < 0.65 or math.abs(ground.Position.Y - lastGround) > s.MaxGroundStep then
				return false
			end

			local nextPoint = Vector3.new(sample.X, ground.Position.Y + height, sample.Z)
			local travel = nextPoint - prev
			local center = prev + UP * 0.2
			if Workspace:Raycast(center, travel, p) then
				return false
			end

			local cf = CFrame.lookAt(center, center + direction)
			if Workspace:Blockcast(cf, Vector3.new(width, 3.2, 1.0), travel, p) then
				return false
			end
			lastGround = ground.Position.Y
			prev = nextPoint
		end
		return math.abs(prev.Y - goal.Y) <= s.VerticalReach
	end
end
