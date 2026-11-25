--!strict
-- Advanced PathFinding AI | Version 1.0
-- Copyright (c) 2026 ZakirGG. All rights reserved.
-- Discord: zakir_playz_ | https://github.com/Nekoraiiii
-- Proprietary source; see LICENSE.txt. Third-party rights remain unaffected.
-- Source identifier: APFAI-0381AEAC37B450D276C6

-- Pure functions; no Roblox APIs. Also exercised by offline regression tests.
local Policy = {}

function Policy.retryDelay(failures, base, maximum)
	return math.min(maximum, base * (2 ^ math.min(math.max(failures - 1, 0), 5)))
end

function Policy.shouldRecover(
	now,
	lastProgress,
	commanded,
	lastRoute,
	lastRecovery,
	stuckTimeout,
	noRouteTimeout,
	cooldown
)
	-- Copyright (c) 2026 ZakirGG | APFAI-0381AEAC37B450D276C6/01 | Proprietary source.
	if now - lastRecovery < cooldown then
		return false
	end

	if commanded then
		return now - lastProgress >= stuckTimeout
	end
	return now - lastRoute >= noRouteTimeout
end

function Policy.targetEnded(present, replaced, dead, removed)
	return not present or replaced or dead or removed
end
return Policy
