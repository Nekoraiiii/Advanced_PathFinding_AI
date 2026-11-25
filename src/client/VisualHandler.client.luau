--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-9775D4DFE147C106A35D

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local intensity = 0

local MAX_DISTANCE = 45
local MAX_REDNESS = 0.60
local SMOOTHING = 8

local oldGui = playerGui:FindFirstChild("AIEffects")

if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")

gui.Name = "AIEffects"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = playerGui

local overlay = Instance.new("Frame")

overlay.Name = "AggroOverlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Parent = gui

--==================================================
-- CHECK CONFIRMED AGGRESSION
--==================================================
-- Copyright (c) 2026 ZakirGG | APFAI-9775D4DFE147C106A35D/01 | Proprietary source.

local function getDistance(): number
	local character = player.Character
	local npc = Workspace:FindFirstChild("Noob")

	if not character or not npc or not npc:IsA("Model") then
		return math.huge
	end

	if npc:GetAttribute("AI_ConfirmedTarget") ~= true then
		return math.huge
	end

	if npc:GetAttribute("AI_AggroUserId") ~= player.UserId then
		return math.huge
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	local npcHumanoid = npc:FindFirstChildWhichIsA("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local npcRoot = npc:FindFirstChild("HumanoidRootPart")

	if
		not humanoid
		or humanoid.Health <= 0
		or not npcHumanoid
		or npcHumanoid.Health <= 0
		or not root
		or not root:IsA("BasePart")
		or not npcRoot
		or not npcRoot:IsA("BasePart")
	then
		return math.huge
	end

	return (root.Position - npcRoot.Position).Magnitude
end
-- Copyright (c) 2026 ZakirGG | APFAI-9775D4DFE147C106A35D/02 | Proprietary source.

--==================================================
-- SMOOTH RED OVERLAY
--==================================================

local connection = RunService.RenderStepped:Connect(function(dt)
	local distance = getDistance()
	local proximity = math.clamp(1 - distance / MAX_DISTANCE, 0, 1)

	proximity = proximity ^ 2

	local targetIntensity = proximity * MAX_REDNESS

	if distance == math.huge then
		intensity = 0
	end

	local alpha = 1 - math.exp(-SMOOTHING * dt)

	intensity += (targetIntensity - intensity) * alpha
	overlay.BackgroundTransparency = 1 - math.clamp(intensity, 0, 1)
end)

local characterConnection = player.CharacterAdded:Connect(function()
	intensity = 0
	overlay.BackgroundTransparency = 1
end)

script.Destroying:Connect(function()
	connection:Disconnect()
	characterConnection:Disconnect()
	gui:Destroy()
end)

print("[Client] Confirmed aggression visuals initialized")
