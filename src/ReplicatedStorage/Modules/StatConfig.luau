local StatConfig = {}

StatConfig.STAT_KEYS = {
	"BreathDamage",
	"DemonArtDamage",
	"Health",
	"Defense",
	"StaminaStat",
	"MovementSpeed",
}

StatConfig.DISPLAY_NAMES = {
	BreathDamage   = "Breath Damage",
	DemonArtDamage = "Demon Art Damage",
	Health         = "Health",
	Defense        = "Defense",
	StaminaStat    = "Stamina",
	MovementSpeed  = "Movement Speed",
}

StatConfig.FACTION_LOCK = {
	BreathDamage   = "Slayer",
	DemonArtDamage = "Demon",
}

StatConfig.VALID_STATS = {}
for _, key in ipairs(StatConfig.STAT_KEYS) do
	StatConfig.VALID_STATS[key] = true
end

StatConfig.BASE = {
	MaxHP       = 150,
	MaxStamina  = 100,
	WalkSpeed   = 24,
	DamageMult  = 1.0,
	DefenseMult = 0.0,
}

StatConfig.LEGACY_KEY_MAP = {
	DemonDamage = "DemonArtDamage",
	Strength    = nil,
	Speed       = nil,
	BreathPower = nil,
}

StatConfig.STAT_POINTS_PER_LEVEL = 5

return StatConfig