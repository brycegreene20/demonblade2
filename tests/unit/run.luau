--!nolint BuiltinGlobalWrite
-- Lune test runner: stubs Roblox globals (Color3, Vector3, game) for offline testing.
local passed = 0
local failed = 0
local tests = {}

local function formatValue(value)
	local valueType = type(value)
	if valueType == "string" then
		return '"' .. value .. '"'
	end
	if valueType == "table" then
		local parts = {}
		for key, child in pairs(value) do
			table.insert(parts, tostring(key) .. "=" .. tostring(child))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function test(name, callback)
	table.insert(tests, { Name = name, Callback = callback })
end

local function expectEqual(actual, expected, context)
	if actual ~= expected then
		error((context or "value") .. " expected " .. formatValue(expected) .. ", got " .. formatValue(actual), 2)
	end
end

local function expectNear(actual, expected, epsilon, context)
	if math.abs(actual - expected) > epsilon then
		error((context or "value") .. " expected " .. formatValue(expected) .. ", got " .. formatValue(actual), 2)
	end
end

local function expectTruthy(value, context)
	if not value then
		error((context or "value") .. " expected truthy value, got " .. formatValue(value), 2)
	end
end

if not math.clamp then
	function math.clamp(value, minValue, maxValue)
		if value < minValue then
			return minValue
		end
		if value > maxValue then
			return maxValue
		end
		return value
	end
end

Color3 = { -- selene: allow(incorrect_standard_library_use)
	fromRGB = function(red, green, blue)
		return {
			R = red / 255,
			G = green / 255,
			B = blue / 255,
		}
	end,
	new = function(red, green, blue)
		return {
			R = red,
			G = green,
			B = blue,
		}
	end,
}

Vector3 = { -- selene: allow(incorrect_standard_library_use)
	new = function(x, y, z)
		return {
			X = x,
			Y = y,
			Z = z,
		}
	end,
}

local function makeInstance(name)
	local instance = {
		Name = name,
		_children = {},
	}

	function instance:WaitForChild(childName)
		local child = self._children[childName]
		if not child then
			child = makeInstance(childName)
			self._children[childName] = child
		end
		return child
	end

	function instance:FindFirstChild(childName)
		return self._children[childName]
	end

	function instance:GetFullName()
		return self.Name
	end

	return instance
end

local services = {
	ReplicatedStorage = makeInstance("ReplicatedStorage"),
}
services.ReplicatedStorage._children.Remotes = makeInstance("Remotes")
services.ReplicatedStorage._children.Modules = makeInstance("Modules")

game = { -- selene: allow(incorrect_standard_library_use)
	GetService = function(_self, serviceName)
		if not services[serviceName] then
			services[serviceName] = makeInstance(serviceName)
		end
		return services[serviceName]
	end,
}

local function loadModule(path)
	local withoutExtension = path:gsub("%.luau$", "")
	local attempts = {
		path,
		withoutExtension,
		"./" .. path,
		"./" .. withoutExtension,
		"../../" .. path,
		"../../" .. withoutExtension,
	}
	local errors = {}
	for _, modulePath in ipairs(attempts) do
		local ok, result = pcall(require, modulePath)
		if ok then
			return result
		end
		table.insert(errors, modulePath .. ": " .. tostring(result))
	end
	error("Could not require " .. path .. "\n" .. table.concat(errors, "\n"), 2)
end

local TitleModule = loadModule("src/ReplicatedStorage/Modules/TitleModule.luau")
local ItemsModule = loadModule("src/ReplicatedStorage/Modules/ItemsModule.luau")
local StatConfig = loadModule("src/ReplicatedStorage/Modules/StatConfig.luau")
local MasteryModule = loadModule("src/ReplicatedStorage/Modules/MasteryModule.luau")
local RaceModule = loadModule("src/ReplicatedStorage/Modules/RaceModule.luau")
local SkillSystemModule = loadModule("src/ReplicatedStorage/Modules/SkillSystemModule.luau")
local QuestDataModule = loadModule("src/ReplicatedStorage/Modules/QuestDataModule.luau")
local MusicModule = loadModule("src/ReplicatedStorage/Modules/MusicModule.luau")
local BountyModule = loadModule("src/ReplicatedStorage/Modules/BountyModule.luau")
local TeamModule = loadModule("src/ReplicatedStorage/Modules/TeamModule.luau")
local CombatModule = loadModule("src/ReplicatedStorage/Modules/CombatModule.luau")
local TotalFocusModule = loadModule("src/ReplicatedStorage/Modules/TotalFocusModule.luau")
local SelflessStateModule = loadModule("src/ReplicatedStorage/Modules/SelflessStateModule.luau")
local MovementPhysicsModule = loadModule("src/ReplicatedStorage/Modules/MovementPhysicsModule.luau")
local QuestTargetModule = loadModule("src/ReplicatedStorage/Modules/QuestTargetModule.luau")
local WorldSpawnConfigModule = loadModule("src/ReplicatedStorage/Modules/WorldSpawnConfigModule.luau")
local CombatVFXConfigModule = loadModule("src/ReplicatedStorage/Modules/CombatVFXConfigModule.luau")
local EnemyProgressionModule = loadModule("src/ReplicatedStorage/Modules/EnemyProgressionModule.luau")
local DataPersistencePolicyModule = loadModule("src/ReplicatedStorage/Modules/DataPersistencePolicyModule.luau")
local ClanModule = loadModule("src/ReplicatedStorage/Modules/ClanModule.luau")
local CompanionModule = loadModule("src/ReplicatedStorage/Modules/CompanionModule.luau")

test("persistence policy permits writes only after a successful load", function()
	expectEqual(DataPersistencePolicyModule.canWrite(true), true, "successful load can save")
	expectEqual(DataPersistencePolicyModule.canWrite(false), false, "failed load cannot overwrite stored data")
	expectEqual(DataPersistencePolicyModule.canWrite(nil), false, "unknown load state cannot save")
end)

test("persistence snapshots are isolated from live player data", function()
	local liveData = {
		Level = 8,
		Inventory = { "WaterBreathingScroll" },
		Mastery = {
			WaterBreathing = { Level = 4, XP = 72 },
		},
	}
	local snapshot = DataPersistencePolicyModule.copySnapshot(liveData)

	liveData.Level = 9
	liveData.Inventory[1] = "FlameBreathingScroll"
	liveData.Mastery.WaterBreathing.XP = 99

	expectEqual(snapshot.Level, 8, "snapshot scalar")
	expectEqual(snapshot.Inventory[1], "WaterBreathingScroll", "snapshot list")
	expectEqual(snapshot.Mastery.WaterBreathing.XP, 72, "snapshot nested table")
end)

test("persistence policy keeps autosave active for play-test sessions", function()
	expectTruthy(DataPersistencePolicyModule.AUTO_SAVE_INTERVAL > 0, "autosave interval")
	expectTruthy(DataPersistencePolicyModule.MIN_WRITE_INTERVAL > 0, "write throttle")
end)

test("default Demon Slayer title maps to a playable Slayer identity", function()
	local title = TitleModule.getTitle("DemonSlayer")
	expectTruthy(title, "DemonSlayer title")
	expectEqual(title.Faction, "Slayer", "DemonSlayer faction")
	expectEqual(title.StartingScroll, "WaterBreathingScroll", "DemonSlayer starting scroll")

	local scroll = ItemsModule.getScroll(title.StartingScroll)
	expectTruthy(scroll, "DemonSlayer starting scroll data")
	expectEqual(scroll.Style, "WaterBreathing", "starting scroll style")
	expectEqual(scroll.Faction, title.Faction, "starting scroll faction")
end)

test("title catalog returns ordered choices with icons", function()
	local titles = TitleModule.getAllTitles()
	expectTruthy(#titles >= 2, "title catalog size")
	expectEqual(titles[1].Id, "DemonSlayer", "first title choice")
	expectEqual(titles[2].Id, "Demon", "second title choice")
	expectTruthy(titles[1].Icon, "DemonSlayer icon")
	expectTruthy(titles[2].Icon, "Demon icon")
	expectEqual(titles[1].SortOrder < titles[2].SortOrder, true, "title sort order")
end)

test("title buff math respects base value, cap, and rebirth multiplier", function()
	expectNear(TitleModule.computeBuff("DemonSlayer", 1, 0), 0.05, 0.000001, "level 1 title buff")
	expectNear(TitleModule.computeBuff("DemonSlayer", 50, 0), 0.30, 0.000001, "capped title buff")
	expectNear(TitleModule.xpMultiplier(2), 2, 0.000001, "rebirth XP multiplier")
end)

test("title rebirth tiers increase level requirements and buff ceilings", function()
	expectEqual(TitleModule.getMaxLevel("DemonSlayer", 0), 50, "tier 1 max level")
	expectEqual(TitleModule.getMaxLevel("DemonSlayer", 1), 75, "tier 2 max level")
	expectEqual(TitleModule.getMaxLevel("DemonSlayer", 2), 100, "tier 3 max level")
	expectTruthy(
		TitleModule.computeBuff("DemonSlayer", 75, 1) > TitleModule.computeBuff("DemonSlayer", 50, 0),
		"tier 2 title ceiling exceeds tier 1"
	)
	expectTruthy(
		TitleModule.xpForLevel("DemonSlayer", 1, 1) > TitleModule.xpForLevel("DemonSlayer", 1, 0),
		"rebirth tier XP is harder"
	)
end)

test("inventory helpers find starting scrolls and styles", function()
	expectTruthy(ItemsModule.hasItem({ "WaterBreathingScroll" }, "WaterBreathingScroll"), "Water scroll should be present")
	expectEqual(ItemsModule.hasItem({ "WaterBreathingScroll" }, "DemonArtFruit"), false, "missing item lookup")
	expectEqual(ItemsModule.getScrollByStyle("WaterBreathing").Id, "WaterBreathingScroll", "WaterBreathing scroll lookup")
	expectEqual(ItemsModule.getScrollByStyle("DemonArts").Id, "DemonArtFruit", "DemonArts scroll lookup")
	expectTruthy(ItemsModule.hasItem(ItemsModule.STARTER_STYLE_ITEMS, "FlameBreathingScroll"), "Flame scroll starter item")
	expectTruthy(ItemsModule.hasItem(ItemsModule.STARTER_STYLE_ITEMS, "TemariDemonFruit"), "Temari fruit starter item")
end)

test("inventory helper allows title-independent style equips", function()
	expectEqual(ItemsModule.canEquipForFaction("WaterBreathingScroll", "Slayer"), true, "Slayer can equip WaterBreathingScroll")
	expectEqual(ItemsModule.canEquipForFaction("WaterBreathingScroll", "Demon"), true, "Demon title can equip WaterBreathingScroll")
	expectEqual(ItemsModule.canEquipForFaction("DemonArtFruit", "Demon"), true, "Demon can equip DemonArtFruit")
	expectEqual(ItemsModule.canEquipForFaction("DemonArtFruit", "Slayer"), true, "Slayer title can equip DemonArtFruit")
	expectEqual(ItemsModule.canEquipForFaction("MissingItem", "Slayer"), false, "missing item rejected")
end)

test("Water Breathing skills are unlocked by the default equipped style", function()
	local waterQ = SkillSystemModule.getSkillForSlot("WaterBreathing", "Q")
	expectTruthy(waterQ, "WaterBreathing Q skill")
	expectEqual(waterQ.Id, "WaterSurfaceSlash", "WaterBreathing Q skill id")

	local canUse, reason = SkillSystemModule.canUseSkill({}, waterQ.Id, {
		Level = 1,
		Stamina = 100,
		EquippedStyle = "WaterBreathing",
		Mastery = {
			WaterBreathing = { Level = 1 },
		},
	})
	expectEqual(canUse, true, "Water skill should be usable with WaterBreathing equipped")
	expectEqual(reason, nil, "usable skill rejection reason")
end)

test("skill gating rejects wrong style and low stamina", function()
	local canUseWrongStyle, wrongStyleReason = SkillSystemModule.canUseSkill({}, "WaterSurfaceSlash", {
		Level = 1,
		Stamina = 100,
		EquippedStyle = "FlameBreathing",
		Mastery = {
			FlameBreathing = { Level = 10 },
			WaterBreathing = { Level = 10 },
		},
	})
	expectEqual(canUseWrongStyle, false, "wrong style should be rejected")
	expectEqual(wrongStyleReason, "Style not equipped", "wrong style reason")

	local canUseLowStamina, lowStaminaReason = SkillSystemModule.canUseSkill({}, "WaterSurfaceSlash", {
		Level = 1,
		Stamina = 0,
		EquippedStyle = "WaterBreathing",
		Mastery = {
			WaterBreathing = { Level = 10 },
		},
	})
	expectEqual(canUseLowStamina, false, "low stamina should be rejected")
	expectEqual(lowStaminaReason, "Not enough stamina", "low stamina reason")
end)

test("advanced skills unlock by equipped style mastery", function()
	local locked, lockedReason = SkillSystemModule.canUseSkill({}, "WaterWheel", {
		Level = 1,
		Stamina = 100,
		EquippedStyle = "WaterBreathing",
		Mastery = {
			WaterBreathing = { Level = 1 },
		},
	})
	expectEqual(locked, false, "WaterWheel locked below mastery requirement")
	expectEqual(lockedReason, "Mastery level too low", "mastery gate reason")

	local unlocked, unlockedReason = SkillSystemModule.canUseSkill({}, "WaterWheel", {
		Level = 1,
		Stamina = 100,
		EquippedStyle = "WaterBreathing",
		Mastery = {
			WaterBreathing = { Level = 2 },
		},
	})
	expectEqual(unlocked, true, "WaterWheel unlocks at mastery 2")
	expectEqual(unlockedReason, nil, "no mastery rejection after unlock")
end)

test("skill icons are style-specific instead of slot-only", function()
	local waterQ = SkillSystemModule.getSkill("WaterSurfaceSlash")
	local demonQ = SkillSystemModule.getSkill("DemonSlash")
	local temariQ = SkillSystemModule.getSkill("TemariThrow")

	expectTruthy(waterQ.Icon ~= nil and waterQ.Icon ~= "", "Water Q icon")
	expectTruthy(demonQ.Icon ~= nil and demonQ.Icon ~= "", "Demon Q icon")
	expectTruthy(temariQ.Icon ~= nil and temariQ.Icon ~= "", "Temari Q icon")
	expectEqual(demonQ.Icon ~= waterQ.Icon, true, "Demon Q icon differs from Water Q icon")
	expectEqual(temariQ.Icon ~= waterQ.Icon, true, "Temari Q icon differs from Water Q icon")
end)

test("every Water Breathing form has a distinct asset-driven VFX profile", function()
	local seenProfiles = {}
	for _, skill in ipairs(SkillSystemModule.getSkillsForStyle("WaterBreathing")) do
		expectTruthy(type(skill.VFXProfile) == "string" and skill.VFXProfile ~= "", skill.Id .. " VFX profile")
		expectTruthy(not seenProfiles[skill.VFXProfile], skill.Id .. " VFX profile is unique")
		expectTruthy(type(skill.VFXAssets) == "table" and #skill.VFXAssets >= 4, skill.Id .. " authored asset coverage")
		seenProfiles[skill.VFXProfile] = true
	end
	expectEqual(SkillSystemModule.getSkill("WaterfallBasin").VFXProfile, "StrikingTide", "fourth form presentation")
	expectEqual(
		SkillSystemModule.getSkill("WaterDragon").VFXAssets[1],
		"Constant flux's dragon",
		"water dragon uses imported dragon model"
	)
end)

test("mastery rebirth retains full ability access", function()
	local canUse, reason = SkillSystemModule.canUseSkill({}, "ConstantFlux", {
		Level = 1,
		Stamina = 100,
		EquippedStyle = "WaterBreathing",
		Mastery = {
			WaterBreathing = { Level = 1, RebirthCount = 1 },
		},
	})
	expectEqual(canUse, true, "tier 2 mastery retains ultimate access")
	expectEqual(reason, nil, "tier 2 access rejection")
end)

test("Flame third form uses a distinct meteor-inspired icon", function()
	local flameSecond = SkillSystemModule.getSkill("FlameSecond")
	local flameThird = SkillSystemModule.getSkill("FlameThird")
	expectTruthy(flameSecond, "FlameSecond registered")
	expectTruthy(flameThird, "FlameThird registered")
	expectTruthy(flameThird.Icon ~= nil and flameThird.Icon ~= "", "FlameThird icon")
	expectEqual(flameThird.Icon ~= flameSecond.Icon, true, "FlameThird icon differs from FlameSecond")
end)

test("all skills expose style identity and ability icons for VFX/SFX", function()
	local styles = { "WaterBreathing", "FlameBreathing", "DemonArts", "TemariDemonArts" }
	for _, styleName in styles do
		local skills = SkillSystemModule.getSkillsForStyle(styleName)
		expectTruthy(#skills >= 1, styleName .. " should expose skills")
		for _, skill in skills do
			expectEqual(skill.Style, styleName, skill.Id .. " style")
			expectTruthy(type(skill.Icon) == "string" and #skill.Icon > 0, skill.Id .. " icon")
			expectTruthy(type(skill.Name) == "string" and #skill.Name > 0, skill.Id .. " name")
		end
	end
end)

test("parry tuning drains attacker stamina and extends stun on break", function()
	expectTruthy(CombatModule.PARRY_STAMINA_DAMAGE > 0, "parry stamina punish")
	expectTruthy(CombatModule.PARRY_BREAK_STUN_DURATION > CombatModule.PARRY_STAGGER_DURATION, "guard break stun duration")
	expectTruthy(CombatModule.PARRY_WINDOW >= 0.2 and CombatModule.PARRY_WINDOW <= 0.35, "parry window should stay readable")
end)

-- ==================== Temari Demon Arts ====================
test("TemariDemonArts has exactly 6 skills covering Q/E/R/F/Y/V slots", function()
	local skills = SkillSystemModule.getSkillsForStyle("TemariDemonArts")
	expectEqual(#skills, 6, "TemariDemonArts skill count")

	local slots = {}
	for _, skill in ipairs(skills) do
		slots[skill.Slot] = true
		expectEqual(skill.Faction, "Demon", skill.Id .. " faction")
		expectEqual(skill.Style, "TemariDemonArts", skill.Id .. " style")
	end
	expectTruthy(slots["Q"], "Q slot filled")
	expectTruthy(slots["E"], "E slot filled")
	expectTruthy(slots["R"], "R slot filled")
	expectTruthy(slots["F"], "F slot filled")
	expectTruthy(slots["Y"], "Y slot filled")
	expectTruthy(slots["V"], "V slot filled")
end)

test("Temari skills have sane damage and stamina values", function()
	local qSkill = SkillSystemModule.getSkill("TemariThrow")
	expectTruthy(qSkill, "TemariThrow registered")
	expectTruthy(qSkill.BaseDamage > 0, "TemariThrow damage > 0")
	expectTruthy(qSkill.StaminaCost > 0, "TemariThrow stamina cost > 0")
	expectTruthy(qSkill.Cooldown > 0, "TemariThrow cooldown > 0")

	local vSkill = SkillSystemModule.getSkill("TemariFullMoon")
	expectTruthy(vSkill, "TemariFullMoon registered")
	expectTruthy(vSkill.BaseDamage > qSkill.BaseDamage, "V ultimate stronger than Q")
	expectTruthy(vSkill.Cooldown > qSkill.Cooldown, "V has longer cooldown than Q")
end)

test("TemariDemonFruit item exists and maps to TemariDemonArts", function()
	local fruit = ItemsModule.getScroll("TemariDemonFruit")
	expectTruthy(fruit, "TemariDemonFruit registered")
	expectEqual(fruit.Style, "TemariDemonArts", "TemariDemonFruit style")
	expectEqual(fruit.Faction, "Demon", "TemariDemonFruit faction")
	expectTruthy(fruit.Icon ~= nil and fruit.Icon ~= "", "TemariDemonFruit icon set")
	expectEqual(fruit.Rarity, "Rare", "TemariDemonFruit rarity")
	expectTruthy(fruit.Color ~= nil, "TemariDemonFruit color set")

	expectEqual(ItemsModule.getScrollByStyle("TemariDemonArts").Id, "TemariDemonFruit", "style→item lookup")
end)

test("Temari skill usable when TemariDemonArts equipped", function()
	local skill = SkillSystemModule.getSkillForSlot("TemariDemonArts", "Q")
	expectTruthy(skill, "TemariDemonArts Q slot has a skill")
	expectEqual(skill.Id, "TemariThrow", "TemariDemonArts Q is TemariThrow")

	local canUse, reason = SkillSystemModule.canUseSkill({}, "TemariThrow", {
		Level = 1,
		Stamina = 100,
		EquippedStyle = "TemariDemonArts",
		Mastery = {
			TemariDemonArts = { Level = 1 },
		},
	})
	expectEqual(canUse, true, "Temari skill usable with correct style equipped")
	expectEqual(reason, nil, "no rejection reason")
end)

test("Temari skill gated out when wrong style equipped", function()
	local canUse, reason = SkillSystemModule.canUseSkill({}, "TemariThrow", {
		Level = 1,
		Stamina = 100,
		EquippedStyle = "DemonArts",
	})
	expectEqual(canUse, false, "Temari rejected with DemonArts equipped")
	expectEqual(reason, "Style not equipped", "rejection reason")
end)

-- ==================== QuestDataModule ====================
test("quest routing keeps dummies on Urokodaki and demons on Corps Officer", function()
	local urokodakiQuests = QuestDataModule.getQuestsForNPC("QuestNPC_Elder")
	local officerQuests = QuestDataModule.getQuestsForNPC("QuestNPC_Officer")
	local merchantQuests = QuestDataModule.getQuestsForNPC("QuestNPC_Scout")

	expectTruthy(#urokodakiQuests >= 1, "Urokodaki has training quests")
	expectTruthy(#officerQuests >= 1, "Corps Officer has demon quests")
	expectEqual(#merchantQuests, 0, "Merchant Aoi has no quests")

	for _, quest in ipairs(urokodakiQuests) do
		expectEqual(quest.objectives[1].enemyType, "TrainingDummy", quest.id .. " is a dummy quest")
	end
	for _, quest in ipairs(officerQuests) do
		local enemyType = quest.objectives[1].enemyType
		expectTruthy(
			enemyType == "ForestDemon"
				or enemyType == "DemonBoss"
				or enemyType == "SnowDemon"
				or enemyType == "SnowDemonBoss",
			quest.id .. " is a demon quest"
		)
	end
	for index = 2, #officerQuests do
		expectTruthy(
			officerQuests[index - 1].xpReward <= officerQuests[index].xpReward,
			"officer quests ordered by XP reward"
		)
	end
end)

test("Demon Boss quest is routed to the Corps Officer", function()
	local quest = QuestDataModule.getQuest("demon_boss_01")
	expectTruthy(quest, "Demon Boss quest exists")
	expectEqual(quest.npcId, "QuestNPC_Officer", "Demon Boss quest NPC")
	expectEqual(quest.objectives[1].enemyType, "DemonBoss", "Demon Boss objective type")
	expectEqual(quest.repeatable, true, "Demon Boss quest repeatable")
end)

test("Frost Demon quests are routed to the Corps Officer", function()
	local regularQuest = QuestDataModule.getQuest("frost_demon_01")
	local bossQuest = QuestDataModule.getQuest("frost_boss_01")
	expectTruthy(regularQuest, "Frost Demon quest exists")
	expectTruthy(bossQuest, "Frost Demon Boss quest exists")
	expectEqual(regularQuest.npcId, "QuestNPC_Officer", "Frost Demon quest NPC")
	expectEqual(regularQuest.objectives[1].enemyType, "SnowDemon", "Frost Demon objective type")
	expectEqual(bossQuest.npcId, "QuestNPC_Officer", "Frost Demon Boss quest NPC")
	expectEqual(bossQuest.objectives[1].enemyType, "SnowDemonBoss", "Frost Demon Boss objective type")
end)

test("every quest awards normal, mastery, and title XP", function()
	for _, quest in ipairs(QuestDataModule.Quests) do
		local rewards = QuestDataModule.getProgressionRewards(quest)
		expectTruthy(rewards.XP > 0, quest.id .. " normal XP")
		expectTruthy(rewards.MasteryXP > 0, quest.id .. " mastery XP")
		expectTruthy(rewards.TitleXP > 0, quest.id .. " title XP")
	end
end)

-- ==================== BountyModule ====================
test("PvP bounty transfer grants killer bounty and clamps defeated bounty", function()
	local transfer = BountyModule.calculatePvpTransfer(100, 80)
	expectEqual(transfer.KillerGain, 35, "killer gain includes base plus steal")
	expectEqual(transfer.VictimLoss, 10, "victim loses at least minimum bounty")
	expectEqual(transfer.KillerBounty, 135, "killer bounty updated")
	expectEqual(transfer.VictimBounty, 70, "victim bounty updated")
end)

test("PvP bounty damage multiplier is capped and only above 1", function()
	expectNear(BountyModule.getPvPDamageMultiplier(0), 1, 0.000001, "zero bounty multiplier")
	expectTruthy(BountyModule.getPvPDamageMultiplier(1000) > 1, "positive bounty multiplier")
	expectNear(BountyModule.getPvPDamageMultiplier(999999), 1.25, 0.000001, "bounty multiplier cap")
end)

-- ==================== TeamModule ====================
test("team module enforces max team size", function()
	expectEqual(TeamModule.canAddMember(4), true, "team can add fifth member")
	expectEqual(TeamModule.canAddMember(5), false, "team rejects sixth member")
	expectEqual(TeamModule.MAX_MEMBERS, 5, "team max members")
end)

test("team module share radius helper gates shared rewards", function()
	expectEqual(TeamModule.isInShareRange(TeamModule.SHARE_RADIUS, TeamModule.SHARE_RADIUS), true, "edge of share radius included")
	expectEqual(TeamModule.isInShareRange(TeamModule.SHARE_RADIUS + 1, TeamModule.SHARE_RADIUS), false, "outside share radius excluded")
end)

test("team policy blocks friendly fire and allows non-team PvP", function()
	expectEqual(TeamModule.canDamagePlayer(true), false, "teammate damage blocked")
	expectEqual(TeamModule.canDamagePlayer(false), true, "non-team damage allowed")
	expectEqual(TeamModule.canRemoveMember(true, false, true), true, "leader can remove teammate")
	expectEqual(TeamModule.canRemoveMember(false, false, true), false, "member cannot remove teammate")
	expectEqual(TeamModule.canRemoveMember(true, true, true), false, "leader cannot remove self")
	expectEqual(TeamModule.canRemoveMember(true, false, false), false, "leader cannot remove outsider")
end)

test("quest level requirements lock acceptance until the player reaches the requirement", function()
	local bossQuest = QuestDataModule.getQuest("frost_boss_01")
	local lowEnough, requiredLevel, currentLevel = QuestDataModule.meetsLevelRequirement(bossQuest, 7)
	expectEqual(lowEnough, false, "under-level player locked")
	expectEqual(requiredLevel, 8, "quest required level")
	expectEqual(currentLevel, 7, "reported player level")
	local highEnough = QuestDataModule.meetsLevelRequirement(bossQuest, 8)
	expectEqual(highEnough, true, "required level unlocks quest")
end)

test("clan levels advance from prestige and cap at level eight", function()
	expectEqual(ClanModule.getLevel(0), 1, "new clan level")
	expectEqual(ClanModule.getLevel(4999), 1, "level two remains a meaningful clan goal")
	expectEqual(ClanModule.getLevel(5000), 2, "second clan level")
	expectEqual(ClanModule.getLevel(650000), 8, "maximum clan level")
	expectEqual(ClanModule.getLevel(999999), 8, "clan level cap")
	expectEqual(ClanModule.getNextLevelPrestige(650000), nil, "max level has no next threshold")
end)

test("nearby clan bonuses stack predictably and respect caps", function()
	local solo = ClanModule.getProximityBonuses(0)
	local pair = ClanModule.getProximityBonuses(1)
	local crowded = ClanModule.getProximityBonuses(100)
	expectNear(solo.XPMultiplier, 1, 0.000001, "solo clan XP")
	expectNear(pair.XPMultiplier, 1.05, 0.000001, "one nearby clanmate XP")
	expectNear(pair.DamageMultiplier, 1.04, 0.000001, "one nearby clanmate damage")
	expectNear(crowded.XPMultiplier, 1.20, 0.000001, "clan XP cap")
	expectNear(crowded.DamageMultiplier, 1.16, 0.000001, "clan damage cap")
end)

test("clan creation rules reject unsafe names", function()
	local valid, normalized = ClanModule.isValidName("  Water Hashira  ")
	expectEqual(valid, true, "valid clan name")
	expectEqual(normalized, "Water Hashira", "trimmed clan name")
	local invalidSymbols = ClanModule.isValidName("Bad<script>")
	expectEqual(invalidSymbols, false, "symbol-heavy clan name rejected")
	local tooShort = ClanModule.isValidName("AB")
	expectEqual(tooShort, false, "short clan name rejected")
end)

test("clan achievements reward the clan and every member", function()
	for _, achievement in ipairs(ClanModule.ACHIEVEMENTS) do
		expectTruthy(achievement.Goal > 0, achievement.Id .. " goal")
		expectTruthy(achievement.PrestigeReward > 0, achievement.Id .. " clan prestige reward")
		expectTruthy(
			achievement.MemberReputationReward > 0,
			achievement.Id .. " member reputation reward"
		)
	end
end)

test("combat target policy consults live team membership", function()
	local attacker = { Name = "Attacker" }
	local teammate = { Name = "Teammate" }
	local clanmate = { Name = "Clanmate" }
	local opponent = { Name = "Opponent" }
	local teammateModel = {}
	local clanmateModel = {}
	local opponentModel = {}
	local playersService = game:GetService("Players")
	playersService.GetPlayerFromCharacter = function(_self, model)
		if model == teammateModel then return teammate end
		if model == clanmateModel then return clanmate end
		return opponent
	end
	shared = { -- selene: allow(incorrect_standard_library_use, global_usage)
		TeamService = {
			areTeammates = function(a, b)
				return a == attacker and b == teammate
			end,
		},
		ClanService = {
			areClanmates = function(a, b)
				return a == attacker and b == clanmate
			end,
		},
	}

	expectEqual(CombatModule.canPlayerDamageTarget(attacker, teammateModel), false, "teammate target rejected")
	expectEqual(CombatModule.canPlayerDamageTarget(attacker, clanmateModel), false, "clanmate target rejected")
	expectEqual(CombatModule.canPlayerDamageTarget(attacker, opponentModel), true, "opponent target accepted")
end)

test("damage attribution records the killer before lethal damage is applied", function()
	local attributes = {}
	local target = {
		SetAttribute = function(_self, name, value)
			attributes[name] = value
		end,
	}
	local attacker = { UserId = 24680 }
	CombatModule.recordPlayerDamage(target, attacker, 50)
	expectEqual(attributes.LastAttacker, attacker.UserId, "lethal-hit killer attribution")
end)

test("kill progression dispatches to both active-state services", function()
	local previousShared = shared
	local totalFocusEvent = nil
	local selflessEvent = nil
	shared = {
		TotalFocusServer = {
			grantEventXP = function(_player, eventName)
				totalFocusEvent = eventName
			end,
		},
		SelflessStateServer = {
			grantEventXP = function(_player, eventName)
				selflessEvent = eventName
			end,
		},
	}

	CombatModule.grantStateProgressionEvent({ Name = "Tester" }, "Kill")
	shared = previousShared

	expectEqual(totalFocusEvent, "Kill", "Total Focus kill dispatch")
	expectEqual(selflessEvent, "Kill", "Selfless State kill dispatch")
end)

test("one progression service cannot interrupt the other or combat flow", function()
	local previousShared = shared
	local selflessEvent = nil
	shared = {
		TotalFocusServer = {
			grantEventXP = function()
				error("intentional progression failure")
			end,
		},
		SelflessStateServer = {
			grantEventXP = function(_player, eventName)
				selflessEvent = eventName
			end,
		},
	}

	local ok = pcall(CombatModule.grantStateProgressionEvent, { Name = "Tester" }, "Kill")
	shared = previousShared

	expectEqual(ok, true, "progression failure remains isolated")
	expectEqual(selflessEvent, "Kill", "later progression service still runs")
end)

test("kill rewards use last hitter plus nearby team, not unrelated contributors", function()
	local killer = { Name = "Killer", Parent = true }
	local teammate = { Name = "Teammate", Parent = true }
	local contributor = { Name = "Contributor", Parent = true }
	local target = {}
	shared.TeamService.getNearbyTeamMembers = function(player) -- selene: allow(global_usage)
		return player == killer and { teammate } or {}
	end
	CombatModule.recordDamageContribution(target, contributor, 999)
	local rewards = CombatModule.getRewardPlayers(target, killer, 160)
	expectEqual(#rewards, 2, "reward recipient count")
	expectEqual(rewards[1], killer, "last hitter receives credit")
	expectEqual(rewards[2], teammate, "nearby teammate receives shared credit")
	CombatModule.clearDamageContributors(target)
end)

-- ==================== StatConfig ====================
test("one Damage stat scales every combat style", function()
	expectEqual(#StatConfig.STAT_KEYS, 5, "consolidated stat count")
	expectEqual(StatConfig.STAT_KEYS[1], "Damage", "first stat is Damage")
	expectEqual(StatConfig.VALID_STATS.Damage, true, "Damage allocation is valid")
	expectNear(StatConfig.getDamageMultiplier(10), 1.3, 0.000001, "Damage multiplier")
end)

test("legacy breath and demon damage points migrate into Damage", function()
	expectEqual(StatConfig.LEGACY_KEY_MAP.BreathDamage, "Damage", "breath damage migration")
	expectEqual(StatConfig.LEGACY_KEY_MAP.DemonArtDamage, "Damage", "demon art damage migration")
end)

-- ==================== MasteryModule ====================
test("mastery tiers grow longer and tier floors exceed prior ceilings", function()
	expectEqual(MasteryModule.getMaxLevel(0), 50, "tier 1 mastery cap")
	expectEqual(MasteryModule.getMaxLevel(1), 75, "tier 2 mastery cap")
	local tierOneRoof = MasteryModule.computeDamageMultiplier(MasteryModule.getMaxLevel(0), 0)
	local tierTwoFloor = MasteryModule.computeDamageMultiplier(1, 1)
	expectTruthy(tierTwoFloor > tierOneRoof, "tier 2 floor exceeds tier 1 roof")
	expectEqual(MasteryModule.getEffectiveUnlockLevel(1, 1), 15, "rebirth keeps forms unlocked")
end)

-- ==================== RaceModule ====================
test("race rolls honor configured probability boundaries", function()
	expectEqual(RaceModule.roll(0).Id, "Human", "common roll")
	expectEqual(RaceModule.roll(0.75).Id, "DemonKing", "mythic boundary")
	expectEqual(RaceModule.roll(0.95).Id, "Sun", "divine boundary")
end)

test("race buffs scale all derived stats", function()
	local base = {
		maxHP = 150,
		maxStamina = 100,
		staminaRegen = 12,
		walkSpeed = 24,
		damageMultiplier = 1.2,
		defenseMultiplier = 0.1,
	}
	local sun = RaceModule.applyToStats(base, "Sun")
	expectNear(sun.maxHP, 300, 0.000001, "Sun health")
	expectNear(sun.maxStamina, 200, 0.000001, "Sun stamina")
	expectNear(sun.staminaRegen, 24, 0.000001, "Sun stamina regeneration")
	expectNear(sun.walkSpeed, 48, 0.000001, "Sun speed")
	expectNear(sun.damageMultiplier, 2.4, 0.000001, "Sun damage")
	local demonKing = RaceModule.getRace("DemonKing")
	expectNear(demonKing.HealthRegenPercent, 0.20, 0.000001, "Demon King regeneration")
end)

test("stamina upgrades increase both capacity and regeneration", function()
	expectNear(StatConfig.getMaxStamina(0), 100, 0.000001, "base stamina capacity")
	expectNear(StatConfig.getMaxStamina(10), 150, 0.000001, "upgraded stamina capacity")
	expectNear(StatConfig.getStaminaRegen(0), 12, 0.000001, "base stamina regeneration")
	expectNear(StatConfig.getStaminaRegen(10), 20, 0.000001, "upgraded stamina regeneration")
	expectTruthy(
		StatConfig.getStaminaRegen(10) > StatConfig.getStaminaRegen(1),
		"stamina regeneration grows with invested points"
	)
end)

test("development race spins are explicitly unlimited in public data", function()
	local publicData = RaceModule.getPublicData("Human", 0)
	expectEqual(RaceModule.UNLIMITED_SPINS, true, "temporary unlimited-spin configuration")
	expectEqual(publicData.UnlimitedSpins, true, "client receives unlimited-spin state")
	expectEqual(publicData.Spins, 0, "stored spin balance remains unchanged")
end)

-- ==================== Focus progression ====================
test("Total Focus and Selfless State use distinct combat XP parameters", function()
	expectEqual(TotalFocusModule.getXPForEvent("DamageDealt"), 2, "Total Focus damage XP")
	expectEqual(TotalFocusModule.getXPForEvent("Kill"), 15, "Total Focus kill XP")
	expectEqual(SelflessStateModule.getXPForEvent("DamageTaken"), 3, "Selfless incoming-hit XP")
	expectEqual(SelflessStateModule.getXPForEvent("Kill"), 10, "Selfless kill XP")
	expectEqual(
		SelflessStateModule.REQUIRES_DODGE_POINTS_FOR_XP,
		false,
		"Selfless progression is not silently gated by an unrelated resource"
	)
	expectEqual(TotalFocusModule.getXPForEvent("Unknown"), 0, "unknown Total Focus event")
	expectEqual(SelflessStateModule.getXPForEvent("Unknown"), 0, "unknown Selfless event")
end)

test("Total Focus stamina drain increases at every progression tier", function()
	local previousDrain = 0
	for _, tier in ipairs(TotalFocusModule.TIERS) do
		local drain = TotalFocusModule.getStaminaDrainPerSecond(tier.xp)
		expectTruthy(drain > previousDrain, tier.name .. " stamina drain increases")
		previousDrain = drain
	end
	expectEqual(TotalFocusModule.getStaminaDrainPerSecond(0), 6, "V1 stamina drain per second")
	expectEqual(TotalFocusModule.getStaminaDrainPerSecond(50000), 10, "V5 stamina drain per second")
end)

test("Selfless State exposes timed regen cooldown and defense buffs", function()
	expectEqual(SelflessStateModule.ACTIVE_DURATION, 20, "Selfless active window")
	expectEqual(SelflessStateModule.COOLDOWN_DURATION, 20, "Selfless reuse cooldown")
	expectNear(SelflessStateModule.getStaminaRegenMultiplier(1), 1.10, 0.000001, "V1 stamina regen")
	expectNear(SelflessStateModule.getCooldownMultiplier(1), 0.90, 0.000001, "V1 cooldown multiplier")
	expectNear(SelflessStateModule.getDefenseBonusForTier(1), 0.10, 0.000001, "V1 defense bonus")
	expectNear(SelflessStateModule.getStaminaRegenMultiplier(10), 1.55, 0.000001, "V10 stamina regen")
	expectNear(SelflessStateModule.getCooldownMultiplier(10), 0.45, 0.000001, "V10 cooldown multiplier cap")
	expectNear(SelflessStateModule.getDefenseBonusForTier(10), 0.55, 0.000001, "V10 defense bonus")
	expectEqual(SelflessStateModule.MAX_DEFENSE_MULTIPLIER, 0.85, "Selfless defense cap")
end)

test("stronger enemies grant progressively larger mastery and active-state rewards", function()
	expectTruthy(
		EnemyProgressionModule.getMasteryXP(8, false) > EnemyProgressionModule.getMasteryXP(1, false),
		"higher level mastery reward"
	)
	expectTruthy(
		EnemyProgressionModule.getMasteryXP(12, true) > EnemyProgressionModule.getMasteryXP(12, false),
		"boss mastery bonus"
	)
	expectTruthy(
		EnemyProgressionModule.scaleStateXP(10, 8, false) > EnemyProgressionModule.scaleStateXP(10, 1, false),
		"higher level Focus/Selfless reward"
	)
	expectTruthy(
		EnemyProgressionModule.scaleStateXP(10, 12, true) > EnemyProgressionModule.scaleStateXP(10, 12, false),
		"boss Focus/Selfless bonus"
	)
end)

test("enemy levels scale health damage rewards and mitigation", function()
	local levelOne = EnemyProgressionModule.getCombatStats(1, false)
	local levelFive = EnemyProgressionModule.getCombatStats(5, false)
	local levelTen = EnemyProgressionModule.getCombatStats(10, false)
	expectTruthy(levelFive.hp > levelOne.hp, "level five health")
	expectTruthy(levelTen.hp > levelFive.hp, "level ten health")
	expectTruthy(levelFive.damage > levelOne.damage, "level five damage")
	expectTruthy(levelTen.xp > levelFive.xp, "level ten reward")
	expectTruthy(levelTen.damageReduction > levelFive.damageReduction, "level ten mitigation")
	expectEqual(levelTen.hp, 476, "level ten health tuning")
	expectEqual(levelTen.damage, 30, "level ten damage tuning")
end)

test("frost variants and bosses are stronger at the same enemy level", function()
	local normal = EnemyProgressionModule.getCombatStats(8, false, 1)
	local frost = EnemyProgressionModule.getCombatStats(8, false, 1.12)
	local boss = EnemyProgressionModule.getCombatStats(8, true, 1)
	expectTruthy(frost.hp > normal.hp, "frost health modifier")
	expectTruthy(frost.damage > normal.damage, "frost damage modifier")
	expectTruthy(boss.hp > normal.hp, "boss health modifier")
	expectTruthy(boss.damageReduction > normal.damageReduction, "boss mitigation modifier")
	expectNear(
		EnemyProgressionModule.applyDamageReduction(100, normal.damageReduction),
		100 * (1 - normal.damageReduction),
		0.000001,
		"enemy mitigation application"
	)
end)

-- ==================== Movement physics ====================
test("repeat jumps match configured or observed ground launch velocity", function()
	expectEqual(
		MovementPhysicsModule.getRepeatJumpVelocity(true, 50, 7.2, 196.2, 0),
		50,
		"JumpPower launch velocity"
	)
	local heightVelocity = MovementPhysicsModule.getConfiguredJumpVelocity(false, 0, 7.2, 196.2)
	expectNear(heightVelocity, math.sqrt(2 * 196.2 * 7.2), 0.000001, "JumpHeight launch velocity")
	expectEqual(
		MovementPhysicsModule.getRepeatJumpVelocity(true, 50, 7.2, 196.2, 57),
		57,
		"observed ground launch velocity"
	)
end)

test("repeat jumps gain height with each follow-up jump", function()
	local firstJump = MovementPhysicsModule.getRepeatJumpVelocity(true, 50, 7.2, 196.2, 0, 1)
	local secondJump = MovementPhysicsModule.getRepeatJumpVelocity(true, 50, 7.2, 196.2, 0, 2)
	local fourthJump = MovementPhysicsModule.getRepeatJumpVelocity(true, 50, 7.2, 196.2, 0, 4)
	local cappedJump = MovementPhysicsModule.getRepeatJumpVelocity(true, 50, 7.2, 196.2, 0, 20)

	expectTruthy(firstJump > 50, "first repeat jump rises above ground jump")
	expectTruthy(secondJump > firstJump, "second repeat jump rises higher than first")
	expectTruthy(fourthJump > secondJump, "fourth repeat jump rises higher than second")
	expectEqual(cappedJump, 50 * 1.48, "repeat jump boost caps safely")
end)

-- ==================== Quest compass ====================
test("quest compass selects the first unfinished kill objective", function()
	local objectives = {
		{ type = "KillCount", enemyType = "TrainingDummy", required = 2 },
		{ type = "KillCount", enemyType = "ForestDemon", required = 3 },
	}
	expectEqual(
		QuestTargetModule.getIncompleteEnemyType(objectives, { 2, 1 }),
		"ForestDemon",
		"unfinished target type"
	)
	expectEqual(QuestTargetModule.getIncompleteEnemyType(objectives, { 2, 3 }), nil, "completed quest target")
end)

-- ==================== World spawn layout ====================
test("forest demons are grouped by named region and isolated from training dummies", function()
	local demons = WorldSpawnConfigModule.getDemonSpawns()
	local dummies = WorldSpawnConfigModule.getTrainingDummySpawns()
	expectEqual(#demons, 35, "regular demons plus boss count")
	expectEqual(#dummies, 12, "two six-dummy training grids")

	local grouped = {}
	for _, demon in ipairs(demons) do
		if not demon.boss then
			grouped[demon.zone] = grouped[demon.zone] or {}
			table.insert(grouped[demon.zone], demon)
			expectEqual(
				WorldSpawnConfigModule.getDemonExclusionZone(demon.x, demon.z),
				nil,
				("demon spawn %s outside protected training yard"):format(demon.zone)
			)
			for _, dummy in ipairs(dummies) do
				expectTruthy(
					WorldSpawnConfigModule.distanceBetween(demon, dummy) >= 70,
					("zone %s demon separated from dummy yard"):format(demon.zone)
				)
			end
		end
	end

	for zone, group in pairs(grouped) do
		for _, left in ipairs(group) do
			for _, right in ipairs(group) do
				expectTruthy(
					WorldSpawnConfigModule.distanceBetween(left, right) <= 30,
					("zone %s cluster remains compact"):format(zone)
				)
			end
		end
	end
end)

test("safe-zone spawn config is centered inside the safe zone", function()
	local center = WorldSpawnConfigModule.getSafeZoneCenter()
	local size = WorldSpawnConfigModule.getSafeZoneSize()
	expectNear(center.X, 264.982, 0.001, "safe-zone center X")
	expectNear(center.Y, 46.078, 0.001, "safe-zone center Y")
	expectNear(center.Z, -140.58, 0.001, "safe-zone center Z")
	expectTruthy(size.X >= 120 and size.Z >= 120, "safe-zone covers wider starter house area")
	expectEqual(
		WorldSpawnConfigModule.SAFE_ZONE.bubbleCenterGroundOffset,
		0,
		"safe-zone sphere center sits at ground height to render as a dome"
	)
end)

test("captured forest and frost expansion regions are configured", function()
	local expectedRegions = {
		ForestHollowWest = { x = -82.509, z = 121.252, count = 3 },
		ForestHollowEast = { x = 84.97, z = 257.62, count = 3 },
		ForestHollowNorth = { x = -142.973, z = 188.376, count = 3 },
		DeepSnowfield = { x = -343.46, z = 575.479, count = 4 },
	}

	local configuredRegions = {}
	for _, group in ipairs(WorldSpawnConfigModule.DEMON_GROUPS) do
		configuredRegions[group.zone] = group
	end
	for _, group in ipairs(WorldSpawnConfigModule.FROST_DEMON_GROUPS) do
		configuredRegions[group.zone] = group
	end

	for zone, expected in pairs(expectedRegions) do
		local configured = configuredRegions[zone]
		expectTruthy(configured, zone .. " exists")
		expectNear(configured.centerX, expected.x, 0.001, zone .. " captured X")
		expectNear(configured.centerZ, expected.z, 0.001, zone .. " captured Z")
		expectEqual(configured.count, expected.count, zone .. " enemy count")
	end
end)

test("starter NPCs stay safe while training dummies remain outside the safe zone", function()
	local center = WorldSpawnConfigModule.getSafeZoneCenter()
	local size = WorldSpawnConfigModule.getSafeZoneSize()
	local halfX = size.X * 0.5
	local halfZ = size.Z * 0.5

	for _, npcId in ipairs({ "QuestNPC_Elder", "QuestNPC_Officer", "QuestNPC_Scout" }) do
		local spawn = WorldSpawnConfigModule.getNPCSpawn(npcId)
		expectTruthy(spawn, npcId .. " spawn config exists")
		expectTruthy(math.abs(spawn.position.X - center.X) <= halfX, npcId .. " inside safe-zone X")
		expectTruthy(math.abs(spawn.position.Z - center.Z) <= halfZ, npcId .. " inside safe-zone Z")
	end

	for _, dummy in ipairs(WorldSpawnConfigModule.getTrainingDummySpawns()) do
		local insideX = math.abs(dummy.x - center.X) <= halfX
		local insideZ = math.abs(dummy.z - center.Z) <= halfZ
		expectEqual(insideX and insideZ, false, "training dummy outside safe zone")
	end
end)

test("starter placement coordinates match captured house setup", function()
	local urokodaki = WorldSpawnConfigModule.getNPCSpawn("QuestNPC_Elder")
	local officer = WorldSpawnConfigModule.getNPCSpawn("QuestNPC_Officer")
	local aoi = WorldSpawnConfigModule.getNPCSpawn("QuestNPC_Scout")
	local dummies = WorldSpawnConfigModule.getTrainingDummySpawns()
	local areas = WorldSpawnConfigModule.TRAINING_DUMMY_AREAS

	expectNear(urokodaki.position.X, 291.339, 0.001, "Urokodaki X")
	expectNear(urokodaki.position.Z, -120.274, 0.001, "Urokodaki Z")
	expectNear(officer.position.X, 275.072, 0.001, "Corps Officer X")
	expectNear(officer.position.Z, -122.065, 0.001, "Corps Officer Z")
	expectNear(aoi.position.X, 280.745, 0.001, "Merchant Aoi X")
	expectNear(aoi.position.Z, -111.636, 0.001, "Merchant Aoi Z")
	expectEqual(#areas, 2, "two training areas")
	expectNear(areas[1].centerX, 291.286, 0.001, "north training grid center X")
	expectNear(areas[1].centerZ, -25.608, 0.001, "north training grid center Z")
	expectNear(areas[2].centerX, 368.224, 0.001, "east training grid center X")
	expectNear(areas[2].centerZ, -139.176, 0.001, "east training grid center Z")
	for _, area in ipairs(areas) do
		expectEqual(area.columns * area.rows, 6, area.name .. " dummy count")
	end
	expectEqual(WorldSpawnConfigModule.DUMMY_GRID.useMarkerOverride, false, "captured coordinates override old marker")
	expectTruthy(
		WorldSpawnConfigModule.getDemonExclusionZone(278.982, -126.58) ~= nil,
		"captured training-yard center rejects demon spawns"
	)
	local areaCounts = {}
	for _, dummy in ipairs(dummies) do
		areaCounts[dummy.area] = (areaCounts[dummy.area] or 0) + 1
		expectTruthy(
			WorldSpawnConfigModule.getDemonExclusionZone(dummy.x, dummy.z) ~= nil,
			"each explicit training dummy rejects nearby demon spawns"
		)
	end
	expectEqual(areaCounts.NorthTrainingGround, 6, "north training grid spawn count")
	expectEqual(areaCounts.EastTrainingGround, 6, "east training grid spawn count")
end)

test("all combat styles have owned cast and impact VFX profiles", function()
	local expectedStyles = {
		"Basic",
		"WaterBreathing",
		"FlameBreathing",
		"DemonArts",
		"TemariDemonArts",
	}
	for _, styleName in ipairs(expectedStyles) do
		local profile = CombatVFXConfigModule.getStyleProfile(styleName)
		expectTruthy(profile.Primary, styleName .. " primary color")
		expectTruthy(profile.Secondary, styleName .. " secondary color")
		expectTruthy(#profile.CastTemplates >= 2, styleName .. " layered cast VFX")
		expectTruthy(#profile.ImpactTemplates >= 2, styleName .. " layered impact VFX")
	end

	for _, skill in pairs(SkillSystemModule.getRegisteredSkills()) do
		local profile = CombatVFXConfigModule.getStyleProfile(skill.Style)
		expectTruthy(profile.CastTemplates[1], skill.Id .. " resolves cast VFX")
		expectTruthy(profile.ImpactTemplates[1], skill.Id .. " resolves impact VFX")
	end

	expectEqual(CombatVFXConfigModule.getComboProfile(4).Finisher, true, "fourth basic hit is a VFX finisher")
	expectTruthy(CombatVFXConfigModule.RENDER_DISTANCE > 128, "VFX range covers maximum camera zoom")
end)

test("Demon Boss has a dedicated travel destination", function()
	local demons = WorldSpawnConfigModule.getDemonSpawns()
	local boss = demons[#demons]
	expectEqual(boss.boss, true, "last spawn is boss")
	expectEqual(boss.zone, "DemonBossArena", "boss zone")
	expectNear(boss.x, -393.923, 0.001, "forest boss captured X")
	expectNear(boss.z, -337.774, 0.001, "forest boss captured Z")
	for index = 1, #demons - 1 do
		expectTruthy(
			WorldSpawnConfigModule.distanceBetween(boss, demons[index]) >= 120,
			"boss arena separated from regular demon groups"
		)
	end
end)

test("Frost demons have distinct spawns and a separated boss arena", function()
	local forestDemons = WorldSpawnConfigModule.getDemonSpawns()
	local frostDemons = WorldSpawnConfigModule.getFrostDemonSpawns()
	expectEqual(#frostDemons, 22, "regular frost demons plus boss count")

	local frostBoss = frostDemons[#frostDemons]
	expectEqual(frostBoss.boss, true, "last frost spawn is boss")
	expectEqual(frostBoss.zone, "FrostDemonBossArena", "frost boss zone")
	expectNear(frostBoss.x, -848.917, 0.001, "frost boss captured X")
	expectNear(frostBoss.z, 51.089, 0.001, "frost boss captured Z")

	for frostIndex, frost in ipairs(frostDemons) do
		for forestIndex, forest in ipairs(forestDemons) do
			if not frost.boss and not forest.boss then
				expectTruthy(
					WorldSpawnConfigModule.distanceBetween(frost, forest) >= 80,
					("frost spawn %d separated from forest spawn %d"):format(frostIndex, forestIndex)
				)
			end
		end
		if not frost.boss then
			expectTruthy(
				WorldSpawnConfigModule.distanceBetween(frostBoss, frost) >= 120,
				"frost boss arena separated from regular frost groups"
			)
		end
	end
end)

-- ==================== CompanionModule ====================
local deterministicRandom = {}
function deterministicRandom:NextInteger(minimum, _maximum)
	return minimum
end
function deterministicRandom:NextNumber()
	return 0.5
end

test("new companions roll two unique buffs plus one fixed species stat", function()
	local crow = CompanionModule.createCompanion("KasugaiCrow", "crow-a", deterministicRandom)
	expectTruthy(crow, "crow created")
	expectEqual(crow.Tier, 1, "starting tier")
	expectEqual(#crow.Buffs, 2, "starting random buff count")
	expectTruthy(crow.Buffs[1].Key ~= crow.Buffs[2].Key, "starting buffs are unique")

	local bonuses = CompanionModule.getBonuses(crow)
	expectTruthy((bonuses.MasteryXP or 0) >= 0.05, "crow fixed mastery stat applies")
end)

test("companion fusion requires matching species and tiers", function()
	local primary = CompanionModule.createCompanion("KasugaiCrow", "crow-primary", deterministicRandom)
	local matching = CompanionModule.createCompanion("KasugaiCrow", "crow-material", deterministicRandom)
	local different = CompanionModule.createCompanion("PaperShikigami", "paper-material", deterministicRandom)

	local mismatchAllowed = CompanionModule.canFuse(primary, different)
	expectEqual(mismatchAllowed, false, "different species cannot fuse")

	local fused, result = CompanionModule.fuse(primary, matching, deterministicRandom)
	expectEqual(fused, true, "matching companions fuse")
	expectEqual(result.Tier, 2, "fusion raises tier")
	expectEqual(#result.Buffs, 3, "tier two unlocks a third buff")
end)

test("companion fusion progression caps at five randomized buffs", function()
	local primary = CompanionModule.createCompanion("KasugaiCrow", "crow-1", deterministicRandom)
	for tier = 1, CompanionModule.MAX_TIER - 1 do
		local material = CompanionModule.createCompanion("KasugaiCrow", "material-" .. tostring(tier), deterministicRandom)
		material.Tier = primary.Tier
		local fused = CompanionModule.fuse(primary, material, deterministicRandom)
		expectEqual(fused, true, "tier " .. tostring(tier) .. " fusion succeeds")
	end
	expectEqual(primary.Tier, CompanionModule.MAX_TIER, "maximum tier reached")
	expectEqual(#primary.Buffs, 5, "maximum random buff count")

	local maxMaterial = CompanionModule.createCompanion("KasugaiCrow", "max-material", deterministicRandom)
	maxMaterial.Tier = CompanionModule.MAX_TIER
	local fusedAtMax = CompanionModule.fuse(primary, maxMaterial, deterministicRandom)
	expectEqual(fusedAtMax, false, "maximum-tier companion cannot fuse again")
end)

test("companion buff pool exposes every requested bonus category", function()
	local expected = {
		HealthPercent = true,
		DamagePercent = true,
		MovementSpeed = true,
		StaminaRegen = true,
		PVPDamage = true,
		StaminaPercent = true,
		DefensePercent = true,
		MasteryXP = true,
		LevelXP = true,
		DropRate = true,
	}
	for _, buff in CompanionModule.BUFF_POOL do
		expected[buff.Key] = nil
	end
	expectEqual(next(expected), nil, "all requested companion buffs are configured")
end)

-- ==================== MusicModule ====================
test("MusicModule exposes well-formed track definitions", function()
	local tracks = MusicModule.getAllTracks()
	expectTruthy(#tracks >= 4, "multiple tracks defined")

	local ambient = MusicModule.getDefaultAmbient()
	expectTruthy(ambient, "default ambient track exists")
	expectEqual(MusicModule.isValidTrack(ambient), true, "ambient track has valid shape")
	expectTruthy(ambient.Volume > 0 and ambient.Volume <= 1, "ambient volume in range")
	expectEqual(ambient.Looped, true, "ambient track should loop")
	expectEqual(ambient.Context, "ambient", "ambient track has ambient context")
end)

test("MusicModule exposes quiet ambient and combat playlists", function()
	local ambientTracks = MusicModule.getTracksForContext("ambient")
	local combatTracks = MusicModule.getTracksForContext("combat")
	expectTruthy(#ambientTracks >= 4, "ambient playlist has options")
	expectTruthy(#combatTracks >= 2, "combat playlist has options")
	local ambientAssetIds = {}
	local assetIds = {}
	for _, track in ipairs(ambientTracks) do
		expectTruthy(not ambientAssetIds[track.AssetId], track.Id .. " does not duplicate another ambient asset")
		ambientAssetIds[track.AssetId] = true
	end
	for _, track in ipairs(MusicModule.getAllTracks()) do
		expectTruthy(track.Volume > 0 and track.Volume <= 1, track.Id .. " volume in range")
		expectEqual(track.Looped, true, track.Id .. " loops")
		expectTruthy(track.AssetId:match("^rbxassetid://%d+$") ~= nil, track.Id .. " asset id shape")
		assetIds[track.AssetId] = true
	end
	for _, assetId in ipairs({
		"rbxassetid://113249797851109",
		"rbxassetid://110015946983764",
		"rbxassetid://92987384618845",
		"rbxassetid://88564010620423",
		"rbxassetid://96055187526468",
	}) do
		expectTruthy(assetIds[assetId], "playlist includes " .. assetId)
	end
end)

test("MusicModule getDefaultAmbient returns a valid track", function()
	local ambient = MusicModule.getDefaultAmbient()
	expectTruthy(ambient, "default ambient track exists")
	expectEqual(MusicModule.isValidTrack(ambient), true, "default ambient is valid")
end)

test("MusicModule returns nil for unknown track", function()
	local missing = MusicModule.getTrack("NonExistent")
	expectEqual(missing, nil, "unknown track returns nil")
end)

test("all registered tracks pass isValidTrack", function()
	for _, track in ipairs(MusicModule.getAllTracks()) do
		expectEqual(MusicModule.isValidTrack(track), true, track.Id .. " track shape valid")
		expectTruthy(track.Id ~= nil and track.Id ~= "", track.Id .. " has non-empty Id")
		expectTruthy(track.Name ~= nil and track.Name ~= "", track.Id .. " has non-empty Name")
	end
end)

for _, spec in ipairs(tests) do
	local ok, err = pcall(spec.Callback)
	if ok then
		passed += 1
		print("[PASS] " .. spec.Name)
	else
		failed += 1
		warn("[FAIL] " .. spec.Name .. "\n" .. tostring(err))
	end
end

print(("[UnitTests] %d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("Unit tests failed", 0)
end
