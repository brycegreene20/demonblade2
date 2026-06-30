--!strict
local SelflessStateModule = {}

SelflessStateModule.MAX_TIER = 10
SelflessStateModule.V1_BONUS  = 0.10  -- 10% base bonus at V1
SelflessStateModule.TIER_STEP = 0.05  -- +5% per additional tier
SelflessStateModule.ACTIVE_DURATION = 20
SelflessStateModule.COOLDOWN_DURATION = 20
SelflessStateModule.MAX_DEFENSE_MULTIPLIER = 0.85

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

-- The old dodge-point pool only throttled XP and never dodged attacks.
-- Keep the persisted data field for compatibility, but do not gate progression on it.
SelflessStateModule.REQUIRES_DODGE_POINTS_FOR_XP = false
local XP_BY_EVENT: { [string]: number } = {
	DamageDealt = 1,
	DamageTaken = 3,
	Kill = 10,
}
SelflessStateModule.XP_BY_EVENT = XP_BY_EVENT

function SelflessStateModule.getXPForEvent(eventName: string): number
	return XP_BY_EVENT[eventName] or 0
end

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

function SelflessStateModule.getStaminaRegenMultiplier(tier: number): number
	return 1 + SelflessStateModule.getBonusForTier(tier)
end

function SelflessStateModule.getCooldownMultiplier(tier: number): number
	return math.max(0.45, 1 - SelflessStateModule.getBonusForTier(tier))
end

function SelflessStateModule.getDefenseBonusForTier(tier: number): number
	return SelflessStateModule.getBonusForTier(tier)
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
