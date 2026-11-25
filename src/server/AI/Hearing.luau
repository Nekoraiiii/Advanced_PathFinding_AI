--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-7BB0594C5D80C1C3F2CE

local Config = require(script.Parent.Configuration)
local Workspace = game:GetService("Workspace")
local Hearing = {}
local samples = setmetatable({}, { __mode = "k" })

local function rootOf(model)
	if not model then
		return nil
	end

	local root = model:FindFirstChild("HumanoidRootPart")

	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getSample(character, root, now)
	local sample = samples[character]

	if not sample then
		sample = { position = root.Position, time = now, event = nil, lastStep = -math.huge, air = false }
		samples[character] = sample
	end
	return sample
end
-- Server-side game systems may emit an intentional sound (e.g. door slam or landing).
-- Never expose this directly to untrusted RemoteEvent payloads.
function Hearing.Emit(character, position, radius)
	local root = rootOf(character)

	if
		not root
		or typeof(position) ~= "Vector3"
		or type(radius) ~= "number"
		or radius <= 0
		or radius ~= radius
		or position.Magnitude ~= position.Magnitude
		or position.Magnitude == math.huge
	then
		return
	end

	local now = os.clock()
	local sample = getSample(character, root, now)
	sample.event = { position = position, range = math.clamp(radius, 0, Config.HearingRange), time = now }
end
-- Copyright (c) 2026 ZakirGG | APFAI-7BB0594C5D80C1C3F2CE/01 | Proprietary source.
function Hearing.Get(npc, character)
	local origin, target = rootOf(npc), rootOf(character)
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")

	if not origin or not target or not humanoid or humanoid.Health <= 0 then
		return false, nil
	end

	local now = os.clock()
	local sample = getSample(character, target, now)
	local dt = now - sample.time
	local state = humanoid:GetState()
	local air = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
	local supportVelocity = Vector3.zero
	-- A standing player carried by a moving floor is not producing footsteps.
	if not air and (target.Position - origin.Position).Magnitude <= Config.HearingRange + 5 then
		local groundParams = RaycastParams.new()
		groundParams.FilterType = Enum.RaycastFilterType.Exclude
		groundParams.FilterDescendantsInstances = { character, npc }
		groundParams.RespectCanCollide = true
		groundParams.CollisionGroup = target.CollisionGroup

		local floor = Workspace:Raycast(target.Position, Vector3.new(0, -6, 0), groundParams)
		if floor and floor.Instance:IsA("BasePart") and typeof(floor.Instance.AssemblyLinearVelocity) == "Vector3" then
			supportVelocity = floor.Instance.AssemblyLinearVelocity
		end
	end

	local velocity = target.AssemblyLinearVelocity - supportVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	if dt >= 0.08 then
		local delta = target.Position - sample.position - supportVelocity * dt
		local measured = Vector3.new(delta.X, 0, delta.Z).Magnitude / dt
		if measured <= 45 then
			speed = math.max(speed, measured)
		end
		sample.position = target.Position
		sample.time = now
	end

	-- Copyright (c) 2026 ZakirGG | APFAI-7BB0594C5D80C1C3F2CE/02 | Proprietary source.
	local range = 0
	local airTransition = air ~= sample.air

	if airTransition then
		range = Config.JumpingNoiseRange
	end
	sample.air = air

	if not air and not humanoid.Sit and not humanoid.PlatformStand and speed >= 1.5 and speed <= 45 then
		range = math.max(range, speed >= Config.RunningThreshold and Config.HearingRange or Config.WalkingNoiseRange)
	end

	if range > 0 and (airTransition or now - sample.lastStep >= Config.FootstepInterval) then
		sample.lastStep = now
		Hearing.Emit(character, target.Position, range)
	end

	local event = sample.event
	if not event or now - event.time > Config.SoundLifetime then
		return false, nil
	end

	local delta = event.position - origin.Position
	if delta.Magnitude > event.range then
		return false, nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npc, character }
	params.RespectCanCollide = true
	params.IgnoreWater = true
	params.CollisionGroup = origin.CollisionGroup
	local effective = event.range

	if delta.Magnitude > 0.01 and Workspace:Raycast(origin.Position, delta, params) then
		effective = effective * Config.SoundWallMultiplier
	end

	if delta.Magnitude <= effective then
		return true, event.position
	end
	return false, nil
end
return Hearing
