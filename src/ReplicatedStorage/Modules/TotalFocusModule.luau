--!strict
local TotalFocusModule = {}

-- Absolute XP thresholds to reach each tier.
-- The gap between tiers grows — floor of next tier ≠ roof of previous.
TotalFocusModule.TIERS = {
	{ name = "V1", xp = 0,     damageBonus = 0.10, damageReduction = 0.00, speedBonus = 15, staminaDrainPerSecond = 6,  haloColor = Color3.fromRGB(0,   220,  80) },
	{ name = "V2", xp = 1000,  damageBonus = 0.20, damageReduction = 0.00, speedBonus = 15, staminaDrainPerSecond = 7,  haloColor = Color3.fromRGB(80,  140, 255) },
	{ name = "V3", xp = 10000, damageBonus = 0.20, damageReduction = 0.05, speedBonus = 15, staminaDrainPerSecond = 8,  haloColor = Color3.fromRGB(160,  80, 255) },
	{ name = "V4", xp = 25000, damageBonus = 0.20, damageReduction = 0.10, speedBonus = 15, staminaDrainPerSecond = 9,  haloColor = Color3.fromRGB(255, 200,   0) },
	{ name = "V5", xp = 50000, damageBonus = 0.20, damageReduction = 0.15, speedBonus = 15, staminaDrainPerSecond = 10, haloColor = Color3.fromRGB(220,  30,  30) },
}

TotalFocusModule.MAX_TIER_INDEX = #TotalFocusModule.TIERS
local XP_BY_EVENT: { [string]: number } = {
	DamageDealt = 2,
	DamageTaken = 1,
	Kill = 15,
}
TotalFocusModule.XP_BY_EVENT = XP_BY_EVENT

function TotalFocusModule.getXPForEvent(eventName: string): number
	return XP_BY_EVENT[eventName] or 0
end

-- Returns 1-based tier index from total accumulated XP.
function TotalFocusModule.getTierIndex(xp: number): number
	local index = 1
	for i, tier in ipairs(TotalFocusModule.TIERS) do
		if xp >= tier.xp then
			index = i
		end
	end
	return index
end

function TotalFocusModule.getTier(xp: number)
	return TotalFocusModule.TIERS[TotalFocusModule.getTierIndex(xp)]
end

function TotalFocusModule.getStaminaDrainPerSecond(xp: number): number
	return TotalFocusModule.getTier(xp).staminaDrainPerSecond
end

-- XP required to reach the next tier from current, or nil if already V5.
function TotalFocusModule.xpToNextTier(xp: number): number?
	local idx = TotalFocusModule.getTierIndex(xp)
	local next = TotalFocusModule.TIERS[idx + 1]
	if not next then return nil end
	return next.xp - xp
end

-- Display label for the Constant form after V5 rebirth.
function TotalFocusModule.getConstantLabel(rebirthCount: number): string
	if rebirthCount <= 0 then
		return "Total Focus Constant"
	end
	return "Total Focus Constant T" .. rebirthCount
end

-- Whether the player has reached V5 and is eligible to rebirth into Constant.
function TotalFocusModule.canRebirth(xp: number, _rebirthCount: number): boolean
	return TotalFocusModule.getTierIndex(xp) >= TotalFocusModule.MAX_TIER_INDEX
end

return TotalFocusModule
