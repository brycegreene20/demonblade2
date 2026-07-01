local EnemyProgressionModule = {}

EnemyProgressionModule.LEVEL_MULTIPLIER_STEP = 0.12
EnemyProgressionModule.BOSS_MULTIPLIER_BONUS = 1.0
EnemyProgressionModule.BASE_MASTERY_XP = 3
EnemyProgressionModule.MASTERY_XP_PER_LEVEL = 2
EnemyProgressionModule.BOSS_MASTERY_BONUS = 20
EnemyProgressionModule.BASE_HEALTH = 80
EnemyProgressionModule.BASE_DAMAGE = 5
EnemyProgressionModule.BASE_KILL_XP = 30
EnemyProgressionModule.HEALTH_SCALE_PER_LEVEL = 0.55
EnemyProgressionModule.DAMAGE_SCALE_PER_LEVEL = 0.55
EnemyProgressionModule.XP_SCALE_PER_LEVEL = 0.65
EnemyProgressionModule.DAMAGE_REDUCTION_PER_LEVEL = 0.015
EnemyProgressionModule.MAX_DAMAGE_REDUCTION = 0.45
EnemyProgressionModule.BOSS_HEALTH_MULTIPLIER = 2.25
EnemyProgressionModule.BOSS_DAMAGE_MULTIPLIER = 1.25
EnemyProgressionModule.BOSS_XP_MULTIPLIER = 1.5
EnemyProgressionModule.BOSS_DAMAGE_REDUCTION_BONUS = 0.08

local function normalizeLevel(enemyLevel)
	return math.max(1, math.floor(tonumber(enemyLevel) or 1))
end

local function rounded(value)
	return math.max(1, math.floor(value + 0.5))
end

function EnemyProgressionModule.getCombatStats(enemyLevel, isBoss, variantMultiplier)
	local level = normalizeLevel(enemyLevel)
	local variant = math.max(0.1, tonumber(variantMultiplier) or 1)
	local levelOffset = level - 1
	local health = EnemyProgressionModule.BASE_HEALTH
		* (1 + EnemyProgressionModule.HEALTH_SCALE_PER_LEVEL * levelOffset)
		* variant
	local damage = EnemyProgressionModule.BASE_DAMAGE
		* (1 + EnemyProgressionModule.DAMAGE_SCALE_PER_LEVEL * levelOffset)
		* variant
	local xp = EnemyProgressionModule.BASE_KILL_XP
		* (1 + EnemyProgressionModule.XP_SCALE_PER_LEVEL * levelOffset)
		* variant
	local damageReduction = math.min(
		EnemyProgressionModule.MAX_DAMAGE_REDUCTION,
		levelOffset * EnemyProgressionModule.DAMAGE_REDUCTION_PER_LEVEL
	)

	if isBoss then
		health *= EnemyProgressionModule.BOSS_HEALTH_MULTIPLIER
		damage *= EnemyProgressionModule.BOSS_DAMAGE_MULTIPLIER
		xp *= EnemyProgressionModule.BOSS_XP_MULTIPLIER
		damageReduction = math.min(
			EnemyProgressionModule.MAX_DAMAGE_REDUCTION,
			damageReduction + EnemyProgressionModule.BOSS_DAMAGE_REDUCTION_BONUS
		)
	end

	return {
		level = level,
		hp = rounded(health),
		damage = rounded(damage),
		xp = rounded(xp),
		damageReduction = damageReduction,
	}
end

function EnemyProgressionModule.applyDamageReduction(amount, damageReduction)
	local reduction = math.clamp(tonumber(damageReduction) or 0, 0, EnemyProgressionModule.MAX_DAMAGE_REDUCTION)
	return math.max(0, (tonumber(amount) or 0) * (1 - reduction))
end

function EnemyProgressionModule.getKillMultiplier(enemyLevel, isBoss)
	local level = normalizeLevel(enemyLevel)
	local multiplier = 1 + (level - 1) * EnemyProgressionModule.LEVEL_MULTIPLIER_STEP
	if isBoss then
		multiplier += EnemyProgressionModule.BOSS_MULTIPLIER_BONUS
	end
	return multiplier
end

function EnemyProgressionModule.scaleStateXP(baseXP, enemyLevel, isBoss)
	local base = math.max(0, tonumber(baseXP) or 0)
	return math.max(0, math.floor(base * EnemyProgressionModule.getKillMultiplier(enemyLevel, isBoss) + 0.5))
end

function EnemyProgressionModule.getMasteryXP(enemyLevel, isBoss)
	local level = normalizeLevel(enemyLevel)
	local reward = EnemyProgressionModule.BASE_MASTERY_XP
		+ (level - 1) * EnemyProgressionModule.MASTERY_XP_PER_LEVEL
	if isBoss then
		reward += EnemyProgressionModule.BOSS_MASTERY_BONUS
	end
	return reward
end

return EnemyProgressionModule
