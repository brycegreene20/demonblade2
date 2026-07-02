local CombatVFXConfigModule = {}

CombatVFXConfigModule.RENDER_DISTANCE = 260

CombatVFXConfigModule.STYLE_PROFILES = {
	Basic = {
		Primary = Color3.fromRGB(235, 245, 255),
		Secondary = Color3.fromRGB(115, 185, 255),
		CastTemplates = {
			{ Name = "Slashes-01", Count = 12, Lifetime = 0.5 },
			{ Name = "Wind-01", Count = 8, Lifetime = 0.45 },
		},
		ImpactTemplates = {
			{ Name = "Slash-Impact-01", Count = 18, Lifetime = 0.65 },
			{ Name = "Slash-01", Count = 10, Lifetime = 0.5 },
		},
	},
	WaterBreathing = {
		Primary = Color3.fromRGB(60, 205, 255),
		Secondary = Color3.fromRGB(225, 250, 255),
		CastTemplates = {
			{ Name = "Water-01", Count = 16, Lifetime = 0.65 },
			{ Name = "Shiny-01", Count = 8, Lifetime = 0.45 },
		},
		ImpactTemplates = {
			{ Name = "Water-02", Count = 24, Lifetime = 0.8 },
			{ Name = "Slash-Impact-01", Count = 16, Lifetime = 0.65 },
		},
	},
	FlameBreathing = {
		Primary = Color3.fromRGB(255, 85, 20),
		Secondary = Color3.fromRGB(255, 225, 75),
		CastTemplates = {
			{ Name = "Fire-01", Count = 16, Lifetime = 0.65 },
			{ Name = "Fire-Slash-01", Count = 10, Lifetime = 0.55 },
		},
		ImpactTemplates = {
			{ Name = "Fire-03", Count = 22, Lifetime = 0.75 },
			{ Name = "Slash-Impact-01", Count = 16, Lifetime = 0.65 },
		},
	},
	DemonArts = {
		Primary = Color3.fromRGB(210, 20, 55),
		Secondary = Color3.fromRGB(125, 20, 205),
		CastTemplates = {
			{ Name = "Blood-01", Count = 15, Lifetime = 0.6 },
			{ Name = "Lighting-02", Count = 8, Lifetime = 0.45 },
		},
		ImpactTemplates = {
			{ Name = "Blood-Punch-01", Count = 20, Lifetime = 0.7 },
			{ Name = "Slash-Impact-01", Count = 14, Lifetime = 0.6 },
		},
	},
	TemariDemonArts = {
		Primary = Color3.fromRGB(220, 65, 235),
		Secondary = Color3.fromRGB(255, 205, 90),
		CastTemplates = {
			{ Name = "Wind-01", Count = 14, Lifetime = 0.6 },
			{ Name = "Stars-01", Count = 10, Lifetime = 0.5 },
		},
		ImpactTemplates = {
			{ Name = "Punch-03", Count = 20, Lifetime = 0.65 },
			{ Name = "Stars-01", Count = 14, Lifetime = 0.6 },
		},
	},
}

CombatVFXConfigModule.COMBO_PROFILES = {
	{ Angle = -35, Scale = 0.9, ColorMix = 0.05 },
	{ Angle = 35, Scale = 1.0, ColorMix = 0.3 },
	{ Angle = -15, Scale = 1.12, ColorMix = 0.55 },
	{ Angle = 80, Scale = 1.4, ColorMix = 0.8, Finisher = true },
}

function CombatVFXConfigModule.getStyleProfile(style)
	return CombatVFXConfigModule.STYLE_PROFILES[style]
		or CombatVFXConfigModule.STYLE_PROFILES.Basic
end

function CombatVFXConfigModule.getComboProfile(comboIndex)
	local profiles = CombatVFXConfigModule.COMBO_PROFILES
	local index = math.clamp(math.floor(tonumber(comboIndex) or 1), 1, #profiles)
	return profiles[index]
end

return CombatVFXConfigModule
