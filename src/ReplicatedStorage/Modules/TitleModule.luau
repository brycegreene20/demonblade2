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
		RebirthBuffBonus = 0.05,
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
		RebirthBuffBonus = 0.05,
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

-- XP required to advance from `level` to `level + 1`
function TitleModule.xpForLevel(titleId, level)
	local title = TitleModule.TITLES[titleId]
	if not title then return 100 end
	return math.floor(title.XPPerLevel * (level ^ title.LevelExponent))
end

-- Total damage buff (as a multiplier addend, e.g. 0.10 = +10%)
function TitleModule.computeBuff(titleId, level, rebirthCount)
	local title = TitleModule.TITLES[titleId]
	if not title then return 0 end
	local rc = rebirthCount or 0
	local cap = title.BaseMaxBuff + rc * title.RebirthBuffBonus
	local buff = title.BaseBuff + (level - 1) * title.BuffPerLevel
	return math.min(buff, cap)
end

-- XP multiplier from rebirth: each rebirth gives +50% XP gain
function TitleModule.xpMultiplier(rebirthCount)
	return 1 + (rebirthCount or 0) * 0.5
end

return TitleModule
