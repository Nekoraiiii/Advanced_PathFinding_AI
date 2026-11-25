--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-7A77FBF8D7384180235B

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function distance2D(a: Vector3, b: Vector3): number
	return flat(a - b).Magnitude
end

local function getCharacter(player: Player?)
	if not player or player.Parent ~= Players then
		return nil, nil, nil
	end

	local character = player.Character
	-- Copyright (c) 2026 ZakirGG | APFAI-7A77FBF8D7384180235B/01 | Proprietary source.
	if not character or not character:IsDescendantOf(Workspace) then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

return { flat = flat, distance2D = distance2D, getCharacter = getCharacter }
