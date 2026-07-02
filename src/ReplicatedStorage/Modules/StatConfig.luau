local StatConfig = {}

StatConfig.STAT_KEYS = {
	"Damage",
	"Health",
	"Defense",
	"StaminaStat",
	"MovementSpeed",
}

StatConfig.DISPLAY_NAMES = {
	Damage         = "Damage",
	Health         = "Health",
	Defense        = "Defense",
	StaminaStat    = "Stamina",
	MovementSpeed  = "Movement Speed",
}

StatConfig.FACTION_LOCK = {}

StatConfig.VALID_STATS = {}
for _, key in ipairs(StatConfig.STAT_KEYS) do
	StatConfig.VALID_STATS[key] = true
end

StatConfig.BASE = {
	MaxHP       = 150,
	MaxStamina  = 100,
	StaminaRegen = 12,
	WalkSpeed   = 24,
	DamageMult  = 1.0,
	DefenseMult = 0.0,
}

StatConfig.STAMINA_REGEN_PER_POINT = 0.8
StatConfig.STAMINA_CAPACITY_PER_POINT = 5

StatConfig.LEGACY_KEY_MAP = {
	BreathDamage = "Damage",
	DemonArtDamage = "Damage",
	DemonDamage = "Damage",
	Strength    = nil,
	Speed       = nil,
	BreathPower = nil,
}

function StatConfig.getDamageMultiplier(points)
	return 1.0 + math.max(0, tonumber(points) or 0) * 0.03
end

function StatConfig.getStaminaRegen(points)
	return StatConfig.BASE.StaminaRegen
		+ math.max(0, tonumber(points) or 0) * StatConfig.STAMINA_REGEN_PER_POINT
end

function StatConfig.getMaxStamina(points)
	return StatConfig.BASE.MaxStamina
		+ math.max(0, tonumber(points) or 0) * StatConfig.STAMINA_CAPACITY_PER_POINT
end

StatConfig.STAT_POINTS_PER_LEVEL = 5

return StatConfig
