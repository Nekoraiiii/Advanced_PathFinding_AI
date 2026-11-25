--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-A96DA75480C75D5ABE04

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Server] Advanced_PathFinding_AI initializing...")

local remote = ReplicatedStorage:FindFirstChild("AggroEvent")

if remote and not remote:IsA("RemoteEvent") then
	error("[Server] AggroEvent exists but is not a RemoteEvent")
end
-- Copyright (c) 2026 ZakirGG | APFAI-A96DA75480C75D5ABE04/01 | Proprietary source.

if not remote then
	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = "AggroEvent"
	newRemote.Parent = ReplicatedStorage
	remote = newRemote
end

local controller = require(script:WaitForChild("AIController"))

controller.Initialize(remote :: RemoteEvent)

print("[Server] Advanced_PathFinding_AI initialized.")
