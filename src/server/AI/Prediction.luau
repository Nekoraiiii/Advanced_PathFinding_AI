--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-C0A3813097345D85D467

local Workspace = game:GetService("Workspace")
local Config = require(script.Parent.Configuration)
local Prediction = {}

function Prediction.GetPosition(npc: Model, target: BasePart): Vector3
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return target.Position
	end

	local velocity = target.AssemblyLinearVelocity
	velocity = Vector3.new(velocity.X, 0, velocity.Z)
	if velocity.Magnitude < 2 then
		return target.Position
	end

	local distance = (target.Position - root.Position).Magnitude
	-- Copyright (c) 2026 ZakirGG | APFAI-C0A3813097345D85D467/01 | Proprietary source.
	local leadTime = math.clamp(distance / Config.ChaseSpeed * 0.5, 0, Config.PredictionTime)
	local offset = velocity * leadTime
	if offset.Magnitude > Config.MaxPredictionDistance then
		offset = offset.Unit * Config.MaxPredictionDistance
	end

	local predicted = target.Position + offset
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { npc }
	if target.Parent then
		table.insert(exclude, target.Parent)
	end

	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	params.CollisionGroup = root.CollisionGroup
	-- Copyright (c) 2026 ZakirGG | APFAI-C0A3813097345D85D467/02 | Proprietary source.

	-- Do not predict through solid obstacles.

	local obstruction = Workspace:Raycast(target.Position, offset, params)
	if obstruction then
		return target.Position
	end

	-- Reject predictions over unsupported ground.

	local ground = Workspace:Raycast(predicted + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), params)
	if not ground or ground.Normal.Y < 0.7 then
		return target.Position
	end
	return predicted
end

return Prediction
