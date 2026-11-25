--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-F9B83875D12EE96A292C

return table.freeze({
	VisionRange = 65,
	VisionAngle = 90,
	PeripheralRange = 18,
	PeripheralAngle = 150,
	VerticalVisionAngle = 100,
	VisualConfirmTime = 0.2,
	HearingRange = 40,
	WalkingNoiseRange = 18,
	JumpingNoiseRange = 35,
	RunningThreshold = 10,
	-- Copyright (c) 2026 ZakirGG | APFAI-F9B83875D12EE96A292C/01 | Proprietary source.
	SoundWallMultiplier = 0.85,
	SoundLifetime = 1.1,
	FootstepInterval = 0.22,
	MemoryDuration = 10,
	SearchDuration = 40,
	SearchRadius = 24,
	SearchPause = 0.8,
	SearchMinStep = 3,
	SearchRetry = 0.6,
	InvestigationTimeout = 45,
	SearchRouteTimeout = 12,
	SearchRouteBudget = 65,
	SoundReacquireDelay = 1.5,
	WanderRadius = 60,
	WanderMinDistance = 8,
	WanderSpeed = 8,
	WanderPauseMin = 1,
	WanderPauseMax = 3,
	ChaseSpeed = 19,
	PredictionTime = 0.35,
	MaxPredictionDistance = 6,
	DebugEnabled = true,
	DebugInterval = 0.25,
})
