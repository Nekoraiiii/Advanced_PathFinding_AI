--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-B1C4E9838479C6661233

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

local MAX_DISTANCE, NEAR_DISTANCE = 45, 3

local intensity, elapsed = 0, 0
local random = Random.new()
local seeds = { random:NextNumber(-1000, 1000), random:NextNumber(-1000, 1000), random:NextNumber(-1000, 1000) }
local previousCamera: Camera? = nil
local previousBase: CFrame? = nil
local previousApplied: CFrame? = nil

local PRE, POST = "NoobShakeRestore", "NoobProximityCamera"

local function distance(): number
	local character = player.Character
	local npc = Workspace:FindFirstChild("Noob")

	if not character or not npc or not npc:IsA("Model") then
		return math.huge
	end
	if npc:GetAttribute("AI_ConfirmedTarget") ~= true or npc:GetAttribute("AI_AggroUserId") ~= player.UserId then
		return math.huge
	end

	local human = character:FindFirstChildWhichIsA("Humanoid")
	local enemy = npc:FindFirstChildWhichIsA("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	-- Copyright (c) 2026 ZakirGG | APFAI-B1C4E9838479C6661233/01 | Proprietary source.
	local enemyRoot = npc:FindFirstChild("HumanoidRootPart")

	if
		not human
		or human.Health <= 0
		or not enemy
		or enemy.Health <= 0
		or not root
		or not root:IsA("BasePart")
		or not enemyRoot
		or not enemyRoot:IsA("BasePart")
	then
		return math.huge
	end

	return (root.Position - enemyRoot.Position).Magnitude
end

local function restore()
	local camera = previousCamera
	-- Never overwrite a camera another controller has since moved.
	if camera and camera.Parent and previousBase and previousApplied and camera.CFrame == previousApplied then
		camera.CFrame = previousBase
	end

	previousCamera = nil
	previousBase = nil
	previousApplied = nil
end

RunService:UnbindFromRenderStep(PRE)
RunService:UnbindFromRenderStep(POST)
RunService:BindToRenderStep(PRE, Enum.RenderPriority.Camera.Value - 1, restore)
RunService:BindToRenderStep(POST, Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = Workspace.CurrentCamera

	if not camera then
		return
	end

	elapsed += dt

	local d = distance()
	local target = math.clamp((MAX_DISTANCE - d) / (MAX_DISTANCE - NEAR_DISTANCE), 0, 1) ^ 2
	-- Copyright (c) 2026 ZakirGG | APFAI-B1C4E9838479C6661233/02 | Proprietary source.
	if player:GetAttribute("ReduceCameraShake") == true then
		intensity = 0
		return
	end
	-- No residual shake when the target has died, respawned or been released.
	if d == math.huge then
		intensity = 0
		return
	end

	intensity += (target - intensity) * (1 - math.exp(-9 * dt))

	if intensity < 0.001 then
		intensity = 0
		return
	end

	local t = elapsed * 28
	local x = math.noise(t, seeds[1], 0) * 2
	local y = math.noise(t, seeds[2], 0) * 2
	local z = math.noise(t, seeds[3], 0) * 2
	local rotation = math.rad(6) * intensity

	previousCamera = camera
	previousBase = camera.CFrame
	camera.CFrame = camera.CFrame
		* CFrame.new(Vector3.new(x, y, z * 0.4) * 0.85 * intensity)
		* CFrame.Angles(y * rotation, x * rotation, z * rotation)
	previousApplied = camera.CFrame
end)

local characterConnection = player.CharacterAdded:Connect(function()
	intensity = 0
	restore()
end)

script.Destroying:Connect(function()
	RunService:UnbindFromRenderStep(PRE)
	RunService:UnbindFromRenderStep(POST)
	characterConnection:Disconnect()
	restore()
end)
