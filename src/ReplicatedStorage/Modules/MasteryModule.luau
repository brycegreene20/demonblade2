local MasteryModule = {}

MasteryModule.BASE_MAX_LEVEL = 50
MasteryModule.LEVELS_PER_REBIRTH = 25
MasteryModule.BASE_XP_PER_LEVEL = 30
MasteryModule.BASE_LEVEL_EXPONENT = 1.25
MasteryModule.BASE_DAMAGE_PER_LEVEL = 0.005
MasteryModule.TIER_FLOOR_GAP = 0.05
MasteryModule.FULL_ABILITY_UNLOCK_LEVEL = 15

function MasteryModule.getTier(rebirthCount)
	return math.max(0, tonumber(rebirthCount) or 0) + 1
end

function MasteryModule.getMaxLevel(rebirthCount)
	return MasteryModule.BASE_MAX_LEVEL
		+ math.max(0, tonumber(rebirthCount) or 0) * MasteryModule.LEVELS_PER_REBIRTH
end

function MasteryModule.xpForLevel(level, rebirthCount)
	local rebirths = math.max(0, tonumber(rebirthCount) or 0)
	local xpScale = 1.45 ^ rebirths
	local exponent = MasteryModule.BASE_LEVEL_EXPONENT + rebirths * 0.03
	return math.floor(MasteryModule.BASE_XP_PER_LEVEL * xpScale * (math.max(1, level) ^ exponent))
end

local function getGrowthPerLevel(rebirthCount)
	return MasteryModule.BASE_DAMAGE_PER_LEVEL * (1 + rebirthCount * 0.12)
end

function MasteryModule.getTierFloor(rebirthCount)
	local targetRebirth = math.max(0, tonumber(rebirthCount) or 0)
	local floor = 1
	for rebirth = 1, targetRebirth do
		local previousRebirth = rebirth - 1
		local previousMax = MasteryModule.getMaxLevel(previousRebirth)
		local previousCeiling = floor + (previousMax - 1) * getGrowthPerLevel(previousRebirth)
		floor = previousCeiling + MasteryModule.TIER_FLOOR_GAP
	end
	return floor
end

function MasteryModule.computeDamageMultiplier(level, rebirthCount)
	local rebirths = math.max(0, tonumber(rebirthCount) or 0)
	local maxLevel = MasteryModule.getMaxLevel(rebirths)
	local clampedLevel = math.clamp(tonumber(level) or 1, 1, maxLevel)
	return MasteryModule.getTierFloor(rebirths)
		+ (clampedLevel - 1) * getGrowthPerLevel(rebirths)
end

function MasteryModule.getEffectiveUnlockLevel(level, rebirthCount)
	local currentLevel = math.max(1, tonumber(level) or 1)
	if (tonumber(rebirthCount) or 0) > 0 then
		return math.max(currentLevel, MasteryModule.FULL_ABILITY_UNLOCK_LEVEL)
	end
	return currentLevel
end

return MasteryModule
