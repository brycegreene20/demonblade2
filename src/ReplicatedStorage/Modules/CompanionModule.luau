local CompanionModule = {}

CompanionModule.MAX_TIER = 4
CompanionModule.STARTING_SPECIES = "KasugaiCrow"

CompanionModule.CATALOG = {
	KasugaiCrow = {
		Id = "KasugaiCrow",
		Name = "Kasugai Crow",
		Category = "Crow",
		Description = "A vigilant messenger crow that sharpens its Slayer's training.",
		Icon = "rbxassetid://6031094678",
		Color = Color3.fromRGB(45, 52, 65),
		SetStat = { Key = "MasteryXP", Value = 0.05 },
	},
	PaperShikigami = {
		Id = "PaperShikigami",
		Name = "Paper Shikigami",
		Category = "Shikigami",
		Description = "A warded paper spirit that protects its chosen partner.",
		Icon = "rbxassetid://6034287594",
		Color = Color3.fromRGB(105, 185, 225),
		SetStat = { Key = "DefensePercent", Value = 0.04 },
	},
}

CompanionModule.BUFF_POOL = {
	{ Key = "HealthPercent", Name = "Health", Unit = "percent", Min = 0.025, Max = 0.08 },
	{ Key = "DamagePercent", Name = "Damage", Unit = "percent", Min = 0.02, Max = 0.065 },
	{ Key = "MovementSpeed", Name = "Movement Speed", Unit = "flat", Min = 0.5, Max = 2.5 },
	{ Key = "StaminaRegen", Name = "Stamina Regen", Unit = "percent", Min = 0.03, Max = 0.10 },
	{ Key = "PVPDamage", Name = "PvP Damage", Unit = "percent", Min = 0.015, Max = 0.05 },
	{ Key = "StaminaPercent", Name = "Stamina", Unit = "percent", Min = 0.025, Max = 0.08 },
	{ Key = "DefensePercent", Name = "Defense", Unit = "percent", Min = 0.015, Max = 0.05 },
	{ Key = "MasteryXP", Name = "Mastery XP", Unit = "percent", Min = 0.03, Max = 0.10 },
	{ Key = "LevelXP", Name = "Level XP", Unit = "percent", Min = 0.03, Max = 0.10 },
	{ Key = "DropRate", Name = "Drop Rate", Unit = "percent", Min = 0.02, Max = 0.075 },
}

local BUFF_BY_KEY = {}
for _, definition in CompanionModule.BUFF_POOL do
	BUFF_BY_KEY[definition.Key] = definition
end

local function round(value, places)
	local scale = 10 ^ (places or 4)
	return math.floor(value * scale + 0.5) / scale
end

local function nextInteger(randomSource, minimum, maximum)
	if randomSource and type(randomSource.NextInteger) == "function" then
		return randomSource:NextInteger(minimum, maximum)
	end
	return math.random(minimum, maximum)
end

local function nextNumber(randomSource)
	if randomSource and type(randomSource.NextNumber) == "function" then
		return randomSource:NextNumber()
	end
	return math.random()
end

function CompanionModule.getSpecies(speciesId)
	return CompanionModule.CATALOG[speciesId]
end

function CompanionModule.getBuffDefinition(buffKey)
	return BUFF_BY_KEY[buffKey]
end

function CompanionModule.getBuffSlotCount(tier)
	return math.clamp(math.floor(tonumber(tier) or 1) + 1, 2, 5)
end

function CompanionModule.rollBuff(randomSource, excludedKeys)
	local available = {}
	for _, definition in CompanionModule.BUFF_POOL do
		if not excludedKeys or not excludedKeys[definition.Key] then
			table.insert(available, definition)
		end
	end
	if #available == 0 then return nil end

	local definition = available[nextInteger(randomSource, 1, #available)]
	local value = definition.Min + (definition.Max - definition.Min) * nextNumber(randomSource)
	return {
		Key = definition.Key,
		Value = round(value, definition.Unit == "flat" and 2 or 4),
	}
end

function CompanionModule.createCompanion(speciesId, uniqueId, randomSource)
	local species = CompanionModule.getSpecies(speciesId)
	if not species or type(uniqueId) ~= "string" or uniqueId == "" then return nil end

	local companion = {
		Id = uniqueId,
		SpeciesId = speciesId,
		Tier = 1,
		Buffs = {},
	}
	local used = {}
	for _ = 1, CompanionModule.getBuffSlotCount(companion.Tier) do
		local buff = CompanionModule.rollBuff(randomSource, used)
		if not buff then break end
		used[buff.Key] = true
		table.insert(companion.Buffs, buff)
	end
	return companion
end

function CompanionModule.normalizeCompanion(companion)
	if type(companion) ~= "table" then return nil end
	if type(companion.Id) ~= "string" or companion.Id == "" then return nil end
	if not CompanionModule.getSpecies(companion.SpeciesId) then return nil end

	companion.Tier = math.clamp(math.floor(tonumber(companion.Tier) or 1), 1, CompanionModule.MAX_TIER)
	if type(companion.Buffs) ~= "table" then
		companion.Buffs = {}
	end

	local normalizedBuffs = {}
	local used = {}
	for _, buff in companion.Buffs do
		local definition = type(buff) == "table" and CompanionModule.getBuffDefinition(buff.Key)
		local value = type(buff) == "table" and tonumber(buff.Value)
		if definition and value and value >= 0 and not used[buff.Key] then
			used[buff.Key] = true
			table.insert(normalizedBuffs, {
				Key = buff.Key,
				Value = round(value, definition.Unit == "flat" and 2 or 4),
			})
			if #normalizedBuffs >= CompanionModule.getBuffSlotCount(companion.Tier) then break end
		end
	end
	companion.Buffs = normalizedBuffs
	return companion
end

function CompanionModule.canFuse(primary, material)
	primary = CompanionModule.normalizeCompanion(primary)
	material = CompanionModule.normalizeCompanion(material)
	if not primary or not material then return false, "Invalid companion" end
	if primary.Id == material.Id then return false, "Choose two different copies" end
	if primary.SpeciesId ~= material.SpeciesId then return false, "Companions must be the same type" end
	if primary.Tier ~= material.Tier then return false, "Companions must be the same tier" end
	if primary.Tier >= CompanionModule.MAX_TIER then return false, "Companion is already at maximum tier" end
	return true
end

function CompanionModule.fuse(primary, material, randomSource)
	local allowed, reason = CompanionModule.canFuse(primary, material)
	if not allowed then return false, reason end

	primary.Tier += 1
	local used = {}
	for _, buff in primary.Buffs do
		used[buff.Key] = true
	end
	while #primary.Buffs < CompanionModule.getBuffSlotCount(primary.Tier) do
		local buff = CompanionModule.rollBuff(randomSource, used)
		if not buff then break end
		used[buff.Key] = true
		table.insert(primary.Buffs, buff)
	end
	return true, primary
end

function CompanionModule.getBonuses(companion)
	local bonuses = {}
	companion = CompanionModule.normalizeCompanion(companion)
	if not companion then return bonuses end

	local species = CompanionModule.getSpecies(companion.SpeciesId)
	if species and species.SetStat then
		bonuses[species.SetStat.Key] = (bonuses[species.SetStat.Key] or 0) + species.SetStat.Value
	end
	for _, buff in companion.Buffs do
		bonuses[buff.Key] = (bonuses[buff.Key] or 0) + buff.Value
	end
	return bonuses
end

function CompanionModule.findCompanion(companions, companionId)
	if type(companions) ~= "table" or type(companionId) ~= "string" then return nil, nil end
	for index, companion in companions do
		if type(companion) == "table" and companion.Id == companionId then
			return companion, index
		end
	end
	return nil, nil
end

function CompanionModule.getEquippedCompanion(data)
	if type(data) ~= "table" then return nil end
	local companion = CompanionModule.findCompanion(data.Companions, data.EquippedCompanionId)
	return companion
end

function CompanionModule.formatBuff(buff)
	local definition = type(buff) == "table" and CompanionModule.getBuffDefinition(buff.Key)
	if not definition then return "Unknown buff" end
	if definition.Unit == "percent" then
		return ("+%g%% %s"):format(round((tonumber(buff.Value) or 0) * 100, 1), definition.Name)
	end
	return ("+%g %s"):format(round(tonumber(buff.Value) or 0, 2), definition.Name)
end

function CompanionModule.getPublicData(data, isStudio)
	local companions = {}
	if type(data) == "table" and type(data.Companions) == "table" then
		for _, rawCompanion in data.Companions do
			local companion = CompanionModule.normalizeCompanion(rawCompanion)
			if companion then
				local species = CompanionModule.getSpecies(companion.SpeciesId)
				local buffs = {}
				for _, buff in companion.Buffs do
					table.insert(buffs, {
						Key = buff.Key,
						Value = buff.Value,
						Display = CompanionModule.formatBuff(buff),
					})
				end
				table.insert(companions, {
					Id = companion.Id,
					SpeciesId = companion.SpeciesId,
					Name = species.Name,
					Category = species.Category,
					Description = species.Description,
					Icon = species.Icon,
					Color = species.Color,
					Tier = companion.Tier,
					MaxTier = CompanionModule.MAX_TIER,
					BuffSlots = CompanionModule.getBuffSlotCount(companion.Tier),
					SetStat = {
						Key = species.SetStat.Key,
						Value = species.SetStat.Value,
						Display = CompanionModule.formatBuff(species.SetStat),
					},
					Buffs = buffs,
				})
			end
		end
	end
	return {
		Companions = companions,
		EquippedCompanionId = type(data) == "table" and (data.EquippedCompanionId or "") or "",
		CanGrantPrototype = isStudio == true,
		Catalog = CompanionModule.CATALOG,
	}
end

return CompanionModule
