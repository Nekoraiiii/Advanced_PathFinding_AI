--!nonstrict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-1006BD698772E2641A82

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local AI = script.Parent:WaitForChild("AI")
local Signal = require(ReplicatedStorage.Shared.Signal)
local Settings = require(AI.Settings)
local Config = require(AI.Configuration)
local Utilities = require(AI.Utilities)
local Destruction = require(AI.Destruction)
local Controller = { OnAggroChanged = Signal.new() }
local stopActive = nil
local NPC_GROUP, DEBRIS_GROUP = "NoobAICharacter", "NoobWallDebris"

function Controller.Initialize(remote)
	if stopActive then
		return
	end

	assert(remote and remote:IsA("RemoteEvent"), "[APFAI 1.0] AggroEvent must be a RemoteEvent")
	local npc = Workspace:FindFirstChild("Noob")
	assert(npc and npc:IsA("Model"), "[APFAI 1.0] Workspace.Noob is missing")
	local humanoid = npc:FindFirstChildWhichIsA("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root and root:IsA("BasePart") and humanoid.Health > 0, "[APFAI 1.0] Invalid Noob rig")

	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") then
			assert(not part.Anchored, "[APFAI 1.0] Anchored rig part: " .. part.Name)
		end
	end

	for _, group in ipairs({ NPC_GROUP, DEBRIS_GROUP }) do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end

	PhysicsService:CollisionGroupSetCollidable(NPC_GROUP, DEBRIS_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(DEBRIS_GROUP, DEBRIS_GROUP, false)

	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = NPC_GROUP
		end
	end

	local ownerOK, ownerError = pcall(function()
		if root:CanSetNetworkOwnership() then
			root:SetNetworkOwner(nil)
		else
			error("Cannot assign NPC network ownership")
		end
	end)

	if not ownerOK then
		warn("[APFAI 1.0]", ownerError)
	end

	humanoid.AutoRotate = true
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 45
	humanoid.WalkSpeed = 0
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator", humanoid)
	end

	local now = os.clock()
	local ctx = {
		npc = npc,
		root = root,
		humanoid = humanoid,
		remote = remote,
		Controller = Controller,
		SETTINGS = Settings,
		Config = Config,
		Perception = require(AI.Perception),
		Prediction = require(AI.Prediction),
		TargetMemory = require(AI.TargetMemory),
		Wander = require(AI.Wander),
		Debugger = require(AI.Debugger),
		NPC_GROUP = NPC_GROUP,
		DEBRIS_GROUP = DEBRIS_GROUP,
		flat = Utilities.flat,
		distance2D = Utilities.distance2D,
		getCharacter = Utilities.getCharacter,
		isBreakable = Destruction.isBreakable,
		shatter = Destruction.shatter,
		running = true,
		state = "Idle",
		mode = "None",
		confirmedTarget = false,
		visible = false,
		heard = false,
		-- Copyright (c) 2026 ZakirGG | APFAI-1006BD698772E2641A82/01 | Proprietary source.
		home = root.Position,
		idleUntil = now + 1,
		destinationUntil = 0,
		searchUntil = 0,
		attackUntil = 0,
		recoveryUntil = 0,
		waypoints = {},
		waypointIndex = 2,
		blocked = false,
		computing = false,
		pathGeneration = 0,
		nextPath = 0,
		failedPaths = 0,
		pathRequestedAt = 0,
		lastJumpIndex = -1,
		lastCommandTime = 0,
		modeSince = now,
		progressPosition = root.Position,
		progressTime = now,
		lastRouteTime = now,
		waypointProgressAt = now,
		breachStarted = 0,
		strikeAt = 0,
		breachExitUntil = 0,
		soundReacquireAt = 0,
	}

	ctx.memory = ctx.TargetMemory.New()
	require(AI.Aggression)(ctx)
	require(AI.StateMachine)(ctx)
	require(AI.Movement)(ctx)
	require(AI.ObstacleDetection)(ctx)
	require(AI.Navigation)(ctx)
	require(AI.Breaching)(ctx)
	require(AI.Combat)(ctx)
	require(AI.Targeting)(ctx)
	require(AI.Investigation)(ctx)
	require(AI.Behavior)(ctx)
	require(AI.Diagnostics)(ctx)

	local attrs = {
		AI_Version = "1.0",
		AI_State = "Idle",
		AI_Mode = "None",
		AI_ConfirmedTarget = false,
		AI_AggroUserId = 0,
		AI_BreachTraversing = false,
		AI_CanSee = false,
		AI_CanHear = false,
		AI_PathStatus = "Reset",
		AI_FailedPaths = 0,
		AI_ComputingPath = false,
		AI_Target = "None",
		AI_ErrorCount = 0,
		AI_MovementActive = false,
		AI_RecoveryActive = false,
		AI_NavigationStuckTime = 0,
	}

	for name, value in pairs(attrs) do
		npc:SetAttribute(name, value)
	end

	for _, name in ipairs({
		"AI_LastError",
		"AI_DebugError",
		"AI_PathError",
		"AI_MoveGoal",
		"AI_LastKnownPosition",
		"AI_RouteDestination",
		"AI_CurrentWaypointPosition",
		"AI_BlockedWaypoint",
		"AI_WaypointDistance",
	}) do
		npc:SetAttribute(name, nil)
	end

	ctx.resetRecovery()
	local connections = {}
	local function safe(label, fn)
		local ok, err = xpcall(fn, debug.traceback)
		if not ok then
			warn("[APFAI 1.0 " .. label .. "]", err)
		end
		return ok, err
	end

	local function stop(reason)
		if not ctx.running then
			return
		end
		ctx.running = false
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		table.clear(connections)
		safe("stop aggro", function()
			ctx.setAggro(nil)
		end)

		safe("stop breach", ctx.cancelBreach)
		safe("stop movement", ctx.resetMovement)
		safe("stop planner", ctx.cancelPlan)
		safe("stop state", function()
			humanoid.WalkSpeed = 0
			ctx.confirmedTarget = false
			npc:SetAttribute("AI_ConfirmedTarget", false)
			npc:SetAttribute("AI_AggroUserId", 0)
			-- Copyright (c) 2026 ZakirGG | APFAI-1006BD698772E2641A82/02 | Proprietary source.
			npc:SetAttribute("AI_BreachTraversing", false)
			npc:SetAttribute("AI_ComputingPath", false)
			npc:SetAttribute("AI_Target", "None")
			npc:SetAttribute("AI_State", reason or "Stopped")
		end)
		stopActive = nil
	end

	stopActive = stop
	table.insert(
		connections,
		humanoid.Died:Connect(function()
			stop("Stopped")
		end)
	)

	table.insert(
		connections,
		npc.DescendantAdded:Connect(function(part)
			if part:IsA("BasePart") then
				part.CollisionGroup = NPC_GROUP
				if part.Anchored then
					warn("[APFAI 1.0] Anchored rig descendant added:", part:GetFullName())
				end
			end
		end)
	)

	local errors = 0
	task.spawn(function()
		while
			ctx.running
			and npc:IsDescendantOf(Workspace)
			and root:IsDescendantOf(npc)
			and humanoid:IsDescendantOf(npc)
			and humanoid.Health > 0
		do
			local ok, err = xpcall(ctx.update, debug.traceback)
			if not ok then
				errors += 1
				npc:SetAttribute("AI_ErrorCount", errors)
				npc:SetAttribute("AI_LastError", tostring(err))
				warn("[APFAI 1.0 Behavior]", err)
				safe("recover breach", ctx.cancelBreach)
				safe("recover movement", ctx.resetMovement)
				if errors >= Settings.ErrorLimit then
					stop("Faulted")
					break
				end
			else
				if errors > 0 then
					npc:SetAttribute("AI_ErrorCount", 0)
				end
				errors = 0
			end

			if ctx.running then
				local debugOK, debugError = xpcall(ctx.updateDebug, debug.traceback)
				if not debugOK then
					npc:SetAttribute("AI_DebugError", tostring(debugError))
				end
				task.wait(if ok then Settings.UpdateInterval else math.min(2, 0.2 * 2 ^ errors))
			end
		end

		if ctx.running then
			stop("Stopped")
		end
	end)
	print("[AI 1.0] Initialized")
end

function Controller.Stop()
	if stopActive then
		stopActive("Stopped")
	end
end
return Controller
