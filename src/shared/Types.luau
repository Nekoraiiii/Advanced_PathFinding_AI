--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-E1F9B732DD5DBD2C338C

export type AIState =
	"Idle"
	| "Wandering"
	| "Investigating"
	| "Searching"
	| "Chasing"
	| "Breaking"
	| "Attacking"
	| "Recovering"

export type NavigationMode = "None" | "Direct" | "Path" | "Breach"

export type NoobConfig = {
	VisionRange: number,
	VisionAngle: number,
	PeripheralRange: number,
	PeripheralAngle: number,
	HearingRange: number,
	-- Copyright (c) 2026 ZakirGG | APFAI-E1F9B732DD5DBD2C338C/01 | Proprietary source.
	MemoryDuration: number,
	SearchDuration: number,
	WanderRadius: number,
	WanderSpeed: number,
	ChaseSpeed: number,
}

export type EntityComponent = {
	Name: string,
	Entity: Instance,
	Enabled: boolean,
}

export type PathSettings = {
	AgentRadius: number,
	AgentHeight: number,
	AgentCanJump: boolean,
}

return {}
