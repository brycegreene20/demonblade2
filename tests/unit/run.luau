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
local SkillSystemModule = loadModule("src/ReplicatedStorage/Modules/SkillSystemModule.luau")
local QuestDataModule = loadModule("src/ReplicatedStorage/Modules/QuestDataModule.luau")
local MusicModule = loadModule("src/ReplicatedStorage/Modules/MusicModule.luau")

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
		expectEqual(quest.objectives[1].enemyType, "ForestDemon", quest.id .. " is a demon quest")
	end
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
