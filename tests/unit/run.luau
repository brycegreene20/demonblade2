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
		expectTruthy(enemyType == "ForestDemon" or enemyType == "DemonBoss", quest.id .. " is a demon quest")
	end
end)

test("Demon Boss quest is routed to the Corps Officer", function()
	local quest = QuestDataModule.getQuest("demon_boss_01")
	expectTruthy(quest, "Demon Boss quest exists")
	expectEqual(quest.npcId, "QuestNPC_Officer", "Demon Boss quest NPC")
	expectEqual(quest.objectives[1].enemyType, "DemonBoss", "Demon Boss objective type")
	expectEqual(quest.repeatable, true, "Demon Boss quest repeatable")
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
end)

test("combat target policy consults live team membership", function()
	local attacker = { Name = "Attacker" }
	local teammate = { Name = "Teammate" }
	local opponent = { Name = "Opponent" }
	local teammateModel = {}
	local opponentModel = {}
	local playersService = game:GetService("Players")
	playersService.GetPlayerFromCharacter = function(_self, model)
		return model == teammateModel and teammate or opponent
	end
	shared = { -- selene: allow(incorrect_standard_library_use, global_usage)
		TeamService = {
			areTeammates = function(a, b)
				return a == attacker and b == teammate
			end,
		},
	}

	expectEqual(CombatModule.canPlayerDamageTarget(attacker, teammateModel), false, "teammate target rejected")
	expectEqual(CombatModule.canPlayerDamageTarget(attacker, opponentModel), true, "opponent target accepted")
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
		walkSpeed = 24,
		damageMultiplier = 1.2,
		defenseMultiplier = 0.1,
	}
	local sun = RaceModule.applyToStats(base, "Sun")
	expectNear(sun.maxHP, 300, 0.000001, "Sun health")
	expectNear(sun.maxStamina, 200, 0.000001, "Sun stamina")
	expectNear(sun.walkSpeed, 48, 0.000001, "Sun speed")
	expectNear(sun.damageMultiplier, 2.4, 0.000001, "Sun damage")
	local demonKing = RaceModule.getRace("DemonKing")
	expectNear(demonKing.HealthRegenPercent, 0.20, 0.000001, "Demon King regeneration")
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
