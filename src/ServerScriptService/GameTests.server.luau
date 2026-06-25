-- Lightweight test runner — prints PASS/FAIL per assertion, no external deps.
-- Runs once at server startup. Check Output window for results.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local PASS = 0
local FAIL = 0

local function assert_eq(label, got, expected)
	if got == expected then
		print("[TEST PASS] " .. label)
		PASS += 1
	else
		warn("[TEST FAIL] " .. label .. " — expected: " .. tostring(expected) .. "  got: " .. tostring(got))
		FAIL += 1
	end
end

local function assert_truthy(label, value)
	if value then
		print("[TEST PASS] " .. label)
		PASS += 1
	else
		warn("[TEST FAIL] " .. label .. " — expected truthy, got: " .. tostring(value))
		FAIL += 1
	end
end

local function assert_falsy(label, value)
	if not value then
		print("[TEST PASS] " .. label)
		PASS += 1
	else
		warn("[TEST FAIL] " .. label .. " — expected falsy, got: " .. tostring(value))
		FAIL += 1
	end
end

-- ==================== ItemsModule ====================
do
	local ok, ItemsModule = pcall(require, Modules:WaitForChild("ItemsModule"))
	assert_truthy("ItemsModule loads", ok)
	if not ok then
		warn("[SKIP] ItemsModule suite skipped")
	else
		assert_truthy("WaterBreathingScroll exists", ItemsModule.getScroll("WaterBreathingScroll"))
		assert_truthy("FlameBreathingScroll exists", ItemsModule.getScroll("FlameBreathingScroll"))
		assert_truthy("DemonArtFruit exists",        ItemsModule.getScroll("DemonArtFruit"))
		assert_truthy("TemariDemonFruit exists",      ItemsModule.getScroll("TemariDemonFruit"))

		local ws = ItemsModule.getScroll("WaterBreathingScroll")
		assert_eq("WaterScroll style",    ws and ws.Style,  "WaterBreathing")
		assert_eq("WaterScroll faction",  ws and ws.Faction, "Slayer")
		assert_eq("WaterScroll icon",     ws and ws.Icon,   "📜")

		local td = ItemsModule.getScroll("TemariDemonFruit")
		assert_eq("TemariFruit style",    td and td.Style,  "TemariDemonArts")
		assert_eq("TemariFruit faction",  td and td.Faction, "Demon")
		assert_eq("TemariFruit icon",     td and td.Icon,   "🍊")

		assert_truthy("getScrollByStyle WaterBreathing", ItemsModule.getScrollByStyle("WaterBreathing"))
		assert_truthy("getScrollByStyle TemariDemonArts", ItemsModule.getScrollByStyle("TemariDemonArts"))
		assert_falsy("getScrollByStyle unknown returns nil", ItemsModule.getScrollByStyle("NonExistent"))

		local inv = {"WaterBreathingScroll", "DemonArtFruit"}
		assert_truthy("hasItem found",     ItemsModule.hasItem(inv, "WaterBreathingScroll"))
		assert_falsy("hasItem not found",  ItemsModule.hasItem(inv, "FlameBreathingScroll"))

		local slayerScrolls = ItemsModule.getScrollsForFaction("Slayer")
		assert_truthy("Slayer scrolls >=2", #slayerScrolls >= 2)
	end
end

-- ==================== SkillSystemModule ====================
do
	local ok, SSM = pcall(require, Modules:WaitForChild("SkillSystemModule"))
	assert_truthy("SkillSystemModule loads", ok)
	if not ok then
		warn("[SKIP] SkillSystemModule suite skipped")
	else
		-- Water Breathing
		assert_truthy("WaterSurfaceSlash registered",  SSM.getSkill("WaterSurfaceSlash"))
		assert_truthy("ConstantFlux registered",       SSM.getSkill("ConstantFlux"))
		assert_truthy("WaterDragon registered",        SSM.getSkill("WaterDragon"))

		-- Flame Breathing
		assert_truthy("FlameFirst registered",         SSM.getSkill("FlameFirst"))
		assert_truthy("FlameEsoteric registered",      SSM.getSkill("FlameEsoteric"))
		assert_truthy("FlameFifth registered",         SSM.getSkill("FlameFifth"))

		-- Existing Demon Arts
		assert_truthy("DemonSlash registered",         SSM.getSkill("DemonSlash"))
		assert_truthy("DemonAwakening registered",     SSM.getSkill("DemonAwakening"))

		-- Temari Demon Arts
		assert_truthy("TemariThrow registered",        SSM.getSkill("TemariThrow"))
		assert_truthy("DoubleTemari registered",       SSM.getSkill("DoubleTemari"))
		assert_truthy("TemariBarrage registered",      SSM.getSkill("TemariBarrage"))
		assert_truthy("MoonClaw registered",           SSM.getSkill("MoonClaw"))
		assert_truthy("BloodTemari registered",        SSM.getSkill("BloodTemari"))
		assert_truthy("TemariFullMoon registered",     SSM.getSkill("TemariFullMoon"))

		-- Style field checks
		local temariThrow = SSM.getSkill("TemariThrow")
		assert_eq("TemariThrow style",   temariThrow and temariThrow.Style,   "TemariDemonArts")
		assert_eq("TemariThrow faction", temariThrow and temariThrow.Faction, "Demon")
		assert_eq("TemariThrow slot",    temariThrow and temariThrow.Slot,    "Q")

		local fullMoon = SSM.getSkill("TemariFullMoon")
		assert_eq("FullMoon slot",       fullMoon and fullMoon.Slot, "V")
		assert_truthy("FullMoon damage > 80", fullMoon and fullMoon.BaseDamage > 80)

		-- getSkillsForStyle
		local waterSkills = SSM.getSkillsForStyle("WaterBreathing")
		assert_truthy("WaterBreathing has skills", #waterSkills > 0)
		local temariSkills = SSM.getSkillsForStyle("TemariDemonArts")
		assert_eq("TemariDemonArts has 6 skills", #temariSkills, 6)

		-- getSkillsForFaction
		local demonSkills = SSM.getSkillsForFaction("Demon")
		assert_truthy("Demon faction has skills", #demonSkills >= 6)
		local slayerSkills = SSM.getSkillsForFaction("Slayer")
		assert_truthy("Slayer faction has skills", #slayerSkills >= 6)
	end
end

-- ==================== TitleModule ====================
do
	local ok, TitleModule = pcall(require, Modules:WaitForChild("TitleModule"))
	assert_truthy("TitleModule loads", ok)
	if not ok then
		warn("[SKIP] TitleModule suite skipped")
	else
		assert_truthy("DemonSlayer title exists", TitleModule.getTitle("DemonSlayer"))
		assert_truthy("Demon title exists",       TitleModule.getTitle("Demon"))

		local ds = TitleModule.getTitle("DemonSlayer")
		assert_truthy("DemonSlayer has XP formula", ds and typeof(TitleModule.xpForLevel) == "function")

		local xpLv1  = TitleModule.xpForLevel("DemonSlayer", 1)
		local xpLv10 = TitleModule.xpForLevel("DemonSlayer", 10)
		assert_truthy("XP level 1 > 0",    xpLv1 > 0)
		assert_truthy("XP level 10 > lv1", xpLv10 > xpLv1)
	end
end

-- ==================== Summary ====================
print(string.format("[TEST SUMMARY] %d passed, %d failed", PASS, FAIL))
if FAIL > 0 then
	warn("[TEST SUMMARY] Some tests FAILED — check output above.")
else
	print("[TEST SUMMARY] All tests passed!")
end
