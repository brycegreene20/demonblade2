local RaceModule = {}

RaceModule.DEFAULT_RACE = "Human"
RaceModule.STARTING_SPINS = 5
RaceModule.REGEN_INTERVAL_SECONDS = 10

RaceModule.RACES = {
	Human = {
		Id = "Human",
		Name = "Human",
		Rarity = "Common",
		Weight = 75,
		AllStatsMultiplier = 1,
		HealthRegenPercent = 0,
		Description = "No innate stat modifier.",
	},
	DemonKing = {
		Id = "DemonKing",
		Name = "Demon King",
		Rarity = "Mythic",
		Weight = 20,
		AllStatsMultiplier = 1.5,
		HealthRegenPercent = 0.20,
		Description = "+50% all stats and restores 20% max health every 10 seconds.",
	},
	Sun = {
		Id = "Sun",
		Name = "Sun",
		Rarity = "Divine",
		Weight = 5,
		AllStatsMultiplier = 2,
		HealthRegenPercent = 0,
		Description = "+100% to all stats.",
	},
}

RaceModule.ROLL_ORDER = { "Human", "DemonKing", "Sun" }

function RaceModule.getRace(raceId)
	return RaceModule.RACES[raceId] or RaceModule.RACES[RaceModule.DEFAULT_RACE]
end

function RaceModule.roll(unitValue)
	local roll = math.clamp(tonumber(unitValue) or 0, 0, 0.999999)
	local cursor = 0
	for _, raceId in ipairs(RaceModule.ROLL_ORDER) do
		local race = RaceModule.RACES[raceId]
		cursor += race.Weight / 100
		if roll < cursor then
			return race
		end
	end
	return RaceModule.RACES[RaceModule.DEFAULT_RACE]
end

function RaceModule.applyToStats(stats, raceId)
	local race = RaceModule.getRace(raceId)
	local multiplier = race.AllStatsMultiplier or 1
	return {
		maxHP = stats.maxHP * multiplier,
		maxStamina = stats.maxStamina * multiplier,
		walkSpeed = stats.walkSpeed * multiplier,
		damageMultiplier = stats.damageMultiplier * multiplier,
		defenseMultiplier = math.min(stats.defenseMultiplier * multiplier, 0.85),
	}
end

function RaceModule.getPublicData(raceId, spins)
	local race = RaceModule.getRace(raceId)
	return {
		Id = race.Id,
		Name = race.Name,
		Rarity = race.Rarity,
		Description = race.Description,
		AllStatsMultiplier = race.AllStatsMultiplier,
		HealthRegenPercent = race.HealthRegenPercent,
		Spins = math.max(0, tonumber(spins) or 0),
	}
end

return RaceModule
