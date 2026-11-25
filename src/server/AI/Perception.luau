--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-5CC17A3A1EBD5900A212

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Config = require(script.Parent.Configuration)
local Hearing = require(script.Parent.Hearing)
local Perception = {}

local function rootOf(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function clearVision(npc, character, origin, point, group)
	local delta = point - origin
	if delta.Magnitude < 0.01 then
		return true
	end

	local exclude = { npc, character }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = false
	params.IgnoreWater = true
	params.CollisionGroup = group
	-- Fully transparent or explicitly marked visual-only geometry does not hide players.
	-- Limit ray continuation to bound the cost in cluttered scenes.
	for _ = 1, 8 do
		params.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(origin, delta, params)
		if not hit then
			return true
		end

		local part = hit.Instance
		if
			part:IsA("BasePart")
			and (
				part:GetAttribute("AI_VisionTransparent") == true
				or (part.Transparency >= 0.95 and part:GetAttribute("AI_VisionTransparent") ~= false)
			)
		then
			table.insert(exclude, part)
		-- Copyright (c) 2026 ZakirGG | APFAI-5CC17A3A1EBD5900A212/01 | Proprietary source.
		else
			return false
		end
	end
	return false
end

function Perception.CanSee(npc, character)
	local root, target = rootOf(npc), rootOf(character)
	if not root or not target then
		return false
	end

	local head = npc:FindFirstChild("Head")
	local origin = head and head:IsA("BasePart") and head.Position or root.Position
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.01 then
		return false
	end

	forward = forward.Unit
	local points = { target.Position, target.Position + Vector3.new(0, 0.8, 0) }
	local targetHead = character:FindFirstChild("Head")
	if targetHead and targetHead:IsA("BasePart") then
		table.insert(points, targetHead.Position)
	end

	for _, point in ipairs(points) do
		local delta = point - origin
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local horizontal = flat.Magnitude > 0.01 and math.deg(math.acos(math.clamp(forward:Dot(flat.Unit), -1, 1))) or 0
		local vertical = math.deg(math.atan2(math.abs(delta.Y), math.max(0.01, flat.Magnitude)))
		local range = delta.Magnitude
		if
			vertical <= Config.VerticalVisionAngle / 2
			and (
				(range <= Config.VisionRange and horizontal <= Config.VisionAngle / 2)
				or (range <= Config.PeripheralRange and horizontal <= Config.PeripheralAngle / 2)
			)
		then
			if clearVision(npc, character, origin, point, root.CollisionGroup) then
				return true
			end
		end
	end
	return false
end
-- Copyright (c) 2026 ZakirGG | APFAI-5CC17A3A1EBD5900A212/02 | Proprietary source.
function Perception.CanHear(npc, character)
	return Hearing.Get(npc, character)
end

function Perception.Scan(npc, preferred)
	local root = rootOf(npc)
	if not root then
		return nil
	end

	local best = nil
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local target = character and rootOf(character)
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if target and humanoid and humanoid.Health > 0 then
			local distance = (target.Position - root.Position).Magnitude
			local visible = distance <= Config.VisionRange + 3 and Perception.CanSee(npc, character)
			local heard, sound = Hearing.Get(npc, character)
			if visible or heard then
				local score = visible and (1000 - distance + (player == preferred and 100 or 0)) or 100 - distance
				if not best or score > best.Score then
					best = {
						Player = player,
						Position = visible and target.Position or sound,
						Distance = distance,
						Visible = visible,
						Heard = heard,
						Score = score,
					}
				end
			end
		end
	end
	return best
end
return Perception
