--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-B4283854CE5777DDB3E9

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Config = require(script.Parent.Configuration)
local Wander = {}
local random = Random.new()

function Wander.GetPoint(npc: Model, center: Vector3, radius: number?): Vector3?
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	local range = radius or Config.WanderRadius
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- Copyright (c) 2026 ZakirGG | APFAI-B4283854CE5777DDB3E9/01 | Proprietary source.

	local exclude: { Instance } = { npc }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end

	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	params.CollisionGroup = root.CollisionGroup

	for _ = 1, 12 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(random:NextNumber()) * range
		local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local candidate = center + offset
		local ground = Workspace:Raycast(candidate + Vector3.new(0, 12, 0), Vector3.new(0, -35, 0), params)

		if not ground or ground.Normal.Y < 0.7 or math.abs(ground.Position.Y + 3 - center.Y) > 5 then
			continue
		end

		local position = ground.Position + Vector3.new(0, 3, 0)
		local clearance = Workspace:Raycast(ground.Position + Vector3.new(0, 0.2, 0), Vector3.new(0, 5, 0), params)
		-- Copyright (c) 2026 ZakirGG | APFAI-B4283854CE5777DDB3E9/02 | Proprietary source.

		if clearance then
			continue
		end

		local difference = position - root.Position
		local horizontalDistance = Vector3.new(difference.X, 0, difference.Z).Magnitude

		if horizontalDistance < math.min(Config.WanderMinDistance, range * 0.5) then
			continue
		end
		return position
	end

	return nil
end

function Wander.GetPause(): number
	return random:NextNumber(Config.WanderPauseMin, Config.WanderPauseMax)
end

return Wander
