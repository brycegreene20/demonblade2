local ClanModule = {}

ClanModule.MAX_MEMBERS = 40
ClanModule.MAX_LEVEL = 8
ClanModule.PROXIMITY_RADIUS = 180
ClanModule.XP_BONUS_PER_NEARBY_MEMBER = 0.05
ClanModule.DAMAGE_BONUS_PER_NEARBY_MEMBER = 0.04
ClanModule.MAX_XP_BONUS = 0.20
ClanModule.MAX_DAMAGE_BONUS = 0.16
ClanModule.INVITE_TTL_SECONDS = 30
ClanModule.MIN_NAME_LENGTH = 3
ClanModule.MAX_NAME_LENGTH = 20
ClanModule.MAX_DESCRIPTION_LENGTH = 160

ClanModule.LEVEL_THRESHOLDS = {
	0,
	5000,
	15000,
	40000,
	90000,
	180000,
	350000,
	650000,
}

ClanModule.LOGOS = {
	Blossom = "BLOSSOM",
	Flame = "FLAME",
	Wave = "WAVE",
	Moon = "MOON",
}

ClanModule.ACHIEVEMENTS = {
	{
		Id = "DemonHunters",
		Name = "Demon Hunters",
		Description = "Defeat 100 demons as a clan.",
		Stat = "EnemyKills",
		Goal = 100,
		PrestigeReward = 500,
		MemberReputationReward = 25,
	},
	{
		Id = "BossBreakers",
		Name = "Boss Breakers",
		Description = "Defeat 20 boss demons as a clan.",
		Stat = "BossKills",
		Goal = 20,
		PrestigeReward = 1000,
		MemberReputationReward = 50,
	},
	{
		Id = "UnitedFront",
		Name = "United Front",
		Description = "Complete 75 quests while representing the clan.",
		Stat = "QuestsCompleted",
		Goal = 75,
		PrestigeReward = 750,
		MemberReputationReward = 35,
	},
}

local function normalizeCount(value)
	return math.max(0, math.floor(tonumber(value) or 0))
end

function ClanModule.getLevel(prestige)
	local normalized = normalizeCount(prestige)
	local level = 1
	for index, threshold in ipairs(ClanModule.LEVEL_THRESHOLDS) do
		if normalized >= threshold then
			level = index
		end
	end
	return math.min(level, ClanModule.MAX_LEVEL)
end

function ClanModule.getNextLevelPrestige(prestige)
	local level = ClanModule.getLevel(prestige)
	if level >= ClanModule.MAX_LEVEL then return nil end
	return ClanModule.LEVEL_THRESHOLDS[level + 1]
end

function ClanModule.getProximityBonuses(nearbyClanMemberCount)
	local count = normalizeCount(nearbyClanMemberCount)
	return {
		XPMultiplier = 1 + math.min(ClanModule.MAX_XP_BONUS, count * ClanModule.XP_BONUS_PER_NEARBY_MEMBER),
		DamageMultiplier = 1
			+ math.min(ClanModule.MAX_DAMAGE_BONUS, count * ClanModule.DAMAGE_BONUS_PER_NEARBY_MEMBER),
	}
end

function ClanModule.isInProximity(distance)
	return (tonumber(distance) or math.huge) <= ClanModule.PROXIMITY_RADIUS
end

function ClanModule.isValidName(name)
	if type(name) ~= "string" then return false, "Enter a clan name." end
	local trimmed = name:match("^%s*(.-)%s*$") or ""
	if #trimmed < ClanModule.MIN_NAME_LENGTH or #trimmed > ClanModule.MAX_NAME_LENGTH then
		return false, ("Clan names must be %d-%d characters."):format(
			ClanModule.MIN_NAME_LENGTH,
			ClanModule.MAX_NAME_LENGTH
		)
	end
	if not trimmed:match("^[%w%s]+$") then
		return false, "Use letters, numbers, and spaces only."
	end
	return true, trimmed
end

function ClanModule.isValidLogo(logo)
	return type(logo) == "string" and ClanModule.LOGOS[logo] ~= nil
end

function ClanModule.getAchievementProgress(clan, achievement)
	local stats = clan and clan.Stats or {}
	return normalizeCount(stats and stats[achievement.Stat]), achievement.Goal
end

function ClanModule.getCompletedAchievementIds(clan)
	local completed = {}
	local existing = clan and clan.Achievements or {}
	for _, achievement in ipairs(ClanModule.ACHIEVEMENTS) do
		local progress = ClanModule.getAchievementProgress(clan, achievement)
		if existing[achievement.Id] == true or progress >= achievement.Goal then
			table.insert(completed, achievement.Id)
		end
	end
	return completed
end

return ClanModule
