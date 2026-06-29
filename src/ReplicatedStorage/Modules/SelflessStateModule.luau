--!strict
local SelflessStateModule = {}

SelflessStateModule.MAX_TIER = 10
SelflessStateModule.V1_BONUS  = 0.10  -- 10% base bonus at V1
SelflessStateModule.TIER_STEP = 0.05  -- +5% per additional tier

-- Absolute XP thresholds to reach each tier (floor ≠ roof of previous).
SelflessStateModule.TIER_XP = {
	0,      -- V1  (start)
	500,    -- V2
	1500,   -- V3
	3000,   -- V4
	5500,   -- V5
	9000,   -- V6
	14000,  -- V7
	20000,  -- V8
	30000,  -- V9
	45000,  -- V10
}

-- Dodge points pool
SelflessStateModule.MAX_DODGE_POINTS   = 100
SelflessStateModule.DODGE_REGEN_RATE   = 5   -- per second
SelflessStateModule.XP_DODGE_COST      = 10  -- dodge points spent per XP event

-- Returns 1-based tier (1 = V1) from accumulated XP.
function SelflessStateModule.getTier(xp: number): number
	local tier = 1
	for i, threshold in ipairs(SelflessStateModule.TIER_XP) do
		if xp >= threshold then
			tier = i
		end
	end
	return math.min(tier, SelflessStateModule.MAX_TIER)
end

-- Stat bonus multiplier for a given tier (e.g. 0.10 at V1, 0.15 at V2 …).
function SelflessStateModule.getBonusForTier(tier: number): number
	local t = math.clamp(tier, 1, SelflessStateModule.MAX_TIER)
	return SelflessStateModule.V1_BONUS + (t - 1) * SelflessStateModule.TIER_STEP
end

-- XP required to reach the next tier, or nil if already V10.
function SelflessStateModule.xpToNextTier(xp: number): number?
	local tier = SelflessStateModule.getTier(xp)
	local nextIdx = tier + 1
	if nextIdx > SelflessStateModule.MAX_TIER then return nil end
	return SelflessStateModule.TIER_XP[nextIdx] - xp
end

-- XP gain is capped once V10 is reached.
function SelflessStateModule.canGainXP(xp: number): boolean
	return SelflessStateModule.getTier(xp) < SelflessStateModule.MAX_TIER
end

return SelflessStateModule
