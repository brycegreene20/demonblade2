local TitleModule = {}

-- Level 1 = +5% buff, each level adds +1%, rebirth raises cap and multiplies XP gain
TitleModule.TITLES = {
	DemonSlayer = {
		Id = "DemonSlayer",
		Name = "Demon Slayer",
		Icon = "⚔",
		SortOrder = 10,
		Color = Color3.fromRGB(50, 120, 220),
		Description = "Sworn protector of humanity. Increases Breath technique damage.",
		BuffType = "BreathDamage",
		BaseBuff = 0.05,
		BuffPerLevel = 0.01,
		BaseMaxBuff = 0.30,
		RebirthBuffBonus = 0.15,
		RebirthBaseBuffBonus = 0.03,
		LevelsPerRebirth = 25,
		RebirthXPScale = 1.65,
		XPPerLevel = 100,
		LevelExponent = 1.4,
		MaxLevel = 50,
		Faction = "Slayer",
		StartingScroll = "WaterBreathingScroll",
	},
	Demon = {
		Id = "Demon",
		Name = "Demon",
		Icon = "👹",
		SortOrder = 20,
		Color = Color3.fromRGB(180, 40, 60),
		Description = "Creature of the night. Increases Blood Demon Art damage.",
		BuffType = "DemonArtDamage",
		BaseBuff = 0.05,
		BuffPerLevel = 0.01,
		BaseMaxBuff = 0.30,
		RebirthBuffBonus = 0.15,
		RebirthBaseBuffBonus = 0.03,
		LevelsPerRebirth = 25,
		RebirthXPScale = 1.65,
		XPPerLevel = 100,
		LevelExponent = 1.4,
		MaxLevel = 50,
		Faction = "Demon",
		StartingScroll = "DemonArtFruit",
	},
}

function TitleModule.getTitle(titleId)
	return TitleModule.TITLES[titleId]
end

function TitleModule.getAllTitles()
	local titles = {}
	for _, title in pairs(TitleModule.TITLES) do
		table.insert(titles, title)
	end
	table.sort(titles, function(a, b)
		local aOrder = a.SortOrder or 9999
		local bOrder = b.SortOrder or 9999
		if aOrder == bOrder then
			return (a.Name or a.Id) < (b.Name or b.Id)
		end
		return aOrder < bOrder
	end)
	return titles
end

function TitleModule.getMaxLevel(titleId, rebirthCount)
	local title = TitleModule.TITLES[titleId]
	if not title then return 50 end
	return title.MaxLevel + math.max(0, tonumber(rebirthCount) or 0) * (title.LevelsPerRebirth or 25)
end

-- XP required to advance from `level` to `level + 1`.
function TitleModule.xpForLevel(titleId, level, rebirthCount)
	local title = TitleModule.TITLES[titleId]
	if not title then return 100 end
	local rebirths = math.max(0, tonumber(rebirthCount) or 0)
	local tierScale = (title.RebirthXPScale or 1.65) ^ rebirths
	local exponent = title.LevelExponent + rebirths * 0.04
	return math.floor(title.XPPerLevel * tierScale * (math.max(1, level) ^ exponent))
end

-- Total damage buff (as a multiplier addend, e.g. 0.10 = +10%)
function TitleModule.computeBuff(titleId, level, rebirthCount)
	local title = TitleModule.TITLES[titleId]
	if not title then return 0 end
	local rc = math.max(0, tonumber(rebirthCount) or 0)
	local cap = title.BaseMaxBuff + rc * title.RebirthBuffBonus
	local base = title.BaseBuff + rc * (title.RebirthBaseBuffBonus or 0.03)
	local perLevel = title.BuffPerLevel * (1 + rc * 0.10)
	local buff = base + (math.max(1, level) - 1) * perLevel
	return math.min(buff, cap)
end

-- XP multiplier from rebirth: each rebirth gives +50% XP gain
function TitleModule.xpMultiplier(rebirthCount)
	return 1 + (rebirthCount or 0) * 0.5
end

return TitleModule
