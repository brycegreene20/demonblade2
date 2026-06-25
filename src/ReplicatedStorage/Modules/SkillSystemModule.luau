local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _Remotes = ReplicatedStorage:WaitForChild("Remotes")
local _Modules = ReplicatedStorage:WaitForChild("Modules")

local SkillSystemModule = {}

local registeredSkills = {}
local playerCooldowns = {}

function SkillSystemModule.registerSkill(skillId, config)
	registeredSkills[skillId] = {
		Id = skillId,
		Name = config.Name or skillId,
		Faction = config.Faction or "Any",
		Slot = config.Slot or "Q",
		BaseDamage = config.BaseDamage or 0,
		StaminaCost = config.StaminaCost or 0,
		Cooldown = config.Cooldown or 5,
		HitboxSize = config.HitboxSize or Vector3.new(8, 6, 10),
		HitboxOffset = config.HitboxOffset or 5,
		MultiHit = config.MultiHit or 1,
		MultiHitDelay = config.MultiHitDelay or 0.15,
		Description = config.Description or "",
		LevelRequired = config.LevelRequired or 1,
	}
end

SkillSystemModule.registerSkill("WaterSurfaceSlash", {
	Name = "First Form: Water Surface Slash",
	Faction = "Slayer",
	Slot = "Q",
	BaseDamage = 28,
	StaminaCost = 18,
	Cooldown = 5,
	HitboxSize = Vector3.new(9, 6, 12),
	HitboxOffset = 6,
	MultiHit = 2,
	MultiHitDelay = 0.1,
	Description = "A single concentrated slash of water that cuts through enemies.",
	LevelRequired = 1,
})

SkillSystemModule.registerSkill("WaterWheel", {
	Name = "Second Form: Water Wheel",
	Faction = "Slayer",
	Slot = "E",
	BaseDamage = 22,
	StaminaCost = 28,
	Cooldown = 8,
	HitboxSize = Vector3.new(12, 8, 12),
	HitboxOffset = 4,
	MultiHit = 3,
	MultiHitDelay = 0.12,
	Description = "Spin your body in a vertical circle, creating a wheel of water that slashes all around.",
	LevelRequired = 1,
})

SkillSystemModule.registerSkill("FlowingDance", {
	Name = "Third Form: Flowing Dance",
	Faction = "Slayer",
	Slot = "R",
	BaseDamage = 16,
	StaminaCost = 38,
	Cooldown = 14,
	HitboxSize = Vector3.new(10, 8, 14),
	HitboxOffset = 5,
	MultiHit = 5,
	MultiHitDelay = 0.15,
	Description = "Swift flowing sword strikes that move like water, hitting enemies repeatedly.",
	LevelRequired = 1,
})

SkillSystemModule.registerSkill("WaterfallBasin", {
	Name = "Fourth Form: Striking Tide",
	Faction = "Slayer",
	Slot = "F",
	BaseDamage = 50,
	StaminaCost = 45,
	Cooldown = 18,
	HitboxSize = Vector3.new(14, 10, 16),
	HitboxOffset = 5,
	MultiHit = 3,
	MultiHitDelay = 0.2,
	Description = "A powerful downward slash that crashes like a waterfall, dealing massive damage.",
	LevelRequired = 1,
})

SkillSystemModule.registerSkill("ConstantFlux", {
	Name = "Eleventh Form: Dead Calm",
	Faction = "Slayer",
	Slot = "V",
	BaseDamage = 80,
	StaminaCost = 65,
	Cooldown = 45,
	HitboxSize = Vector3.new(18, 12, 20),
	HitboxOffset = 6,
	MultiHit = 6,
	MultiHitDelay = 0.12,
	Description = "The ultimate water breathing technique — a flurry of devastating slashes that obliterate all in their path.",
	LevelRequired = 1,
})

SkillSystemModule.registerSkill("WaterDragon", {
	Name = "Tenth Form: Water Dragon",
	Faction = "Slayer",
	Slot = "Y",
	BaseDamage = 65,
	StaminaCost = 55,
	Cooldown = 30,
	HitboxSize = Vector3.new(16, 10, 50),
	HitboxOffset = 25,
	MultiHit = 4,
	MultiHitDelay = 0.15,
	Description = "A spiraling water dragon charges forward, obliterating everything in its path.",
	LevelRequired = 1,
})

SkillSystemModule.registerSkill("DemonSlash", {
	Name = "Demon Slash",
	Faction = "Demon",
	Slot = "Q",
	BaseDamage = 30,
	StaminaCost = 18,
	Cooldown = 5,
	HitboxSize = Vector3.new(9, 7, 10),
	HitboxOffset = 5,
	MultiHit = 2,
	MultiHitDelay = 0.15,
	Description = "Claw forward with dark energy, striking twice.",
	LevelRequired = 1,
})

SkillSystemModule.registerSkill("BloodBurst", {
	Name = "Blood Burst",
	Faction = "Demon",
	Slot = "E",
	BaseDamage = 45,
	StaminaCost = 35,
	Cooldown = 12,
	HitboxSize = Vector3.new(14, 10, 14),
	HitboxOffset = 0,
	MultiHit = 1,
	MultiHitDelay = 0,
	Description = "Explode blood energy around you, damaging all nearby.",
	LevelRequired = 1,
})

SkillSystemModule.registerSkill("ShadowStep", {
	Name = "Shadow Step",
	Faction = "Demon",
	Slot = "R",
	BaseDamage = 20,
	StaminaCost = 40,
	Cooldown = 16,
	HitboxSize = Vector3.new(10, 8, 12),
	HitboxOffset = 6,
	MultiHit = 4,
	MultiHitDelay = 0.1,
	Description = "Teleport behind the closest enemy and strike rapidly.",
	LevelRequired = 1,
})

SkillSystemModule.registerSkill("CrimsonClaw", {
	Name = "Crimson Claw",
	Faction = "Demon",
	Slot = "F",
	BaseDamage = 55,
	StaminaCost = 45,
	Cooldown = 18,
	HitboxSize = Vector3.new(14, 10, 14),
	HitboxOffset = 5,
	MultiHit = 3,
	MultiHitDelay = 0.15,
	Description = "Rend the air with blood-soaked claws, tearing through multiple enemies.",
	LevelRequired = 1,
})

SkillSystemModule.registerSkill("DemonAwakening", {
	Name = "Demon Awakening",
	Faction = "Demon",
	Slot = "V",
	BaseDamage = 85,
	StaminaCost = 65,
	Cooldown = 45,
	HitboxSize = Vector3.new(20, 14, 20),
	HitboxOffset = 0,
	MultiHit = 5,
	MultiHitDelay = 0.15,
	Description = "Unleash your full demonic power in a devastating explosion of dark energy.",
	LevelRequired = 1,
})

SkillSystemModule.registerSkill("BloodMoon", {
	Name = "Blood Moon",
	Faction = "Demon",
	Slot = "Y",
	BaseDamage = 70,
	StaminaCost = 55,
	Cooldown = 30,
	HitboxSize = Vector3.new(18, 12, 18),
	HitboxOffset = 0,
	MultiHit = 4,
	MultiHitDelay = 0.15,
	Description = "Unleash a blood-red moon that engulfs the area in dark energy.",
	LevelRequired = 1,
})

function SkillSystemModule.getSkill(skillId)
	return registeredSkills[skillId]
end

function SkillSystemModule.getRegisteredSkills()
	return registeredSkills
end

function SkillSystemModule.getSkillsForFaction(faction)
	local skills = {}
	for _id, skill in registeredSkills do
		if skill.Faction == faction or skill.Faction == "Any" then
			table.insert(skills, skill)
		end
	end
	return skills
end

function SkillSystemModule.getSkillForSlot(faction, slot)
	if faction and faction ~= "" then
		for _id, skill in registeredSkills do
			if (skill.Faction == faction or skill.Faction == "Any") and skill.Slot == slot then
				return skill
			end
		end
	else
		for _id, skill in registeredSkills do
			if skill.Slot == slot then
				return skill
			end
		end
	end
	return nil
end

function SkillSystemModule.initPlayer(player)
	playerCooldowns[player] = {}
end

function SkillSystemModule.cleanupPlayer(player)
	playerCooldowns[player] = nil
end

function SkillSystemModule.setCooldown(player, skillId, duration)
	if not playerCooldowns[player] then
		playerCooldowns[player] = {}
	end
	playerCooldowns[player][skillId] = os.clock() + duration
end

function SkillSystemModule.getCooldownRemaining(player, skillId)
	if not playerCooldowns[player] then return 0 end
	local expiry = playerCooldowns[player][skillId]
	if not expiry then return 0 end
	local remaining = expiry - os.clock()
	return remaining > 0 and remaining or 0
end

function SkillSystemModule.isOnCooldown(player, skillId)
	return SkillSystemModule.getCooldownRemaining(player, skillId) > 0
end

function SkillSystemModule.canUseSkill(player, skillId, playerData)
	local skill = registeredSkills[skillId]
	if not skill then return false, "Unknown skill" end
	if not playerData then return false, "No data" end

	if playerData.Level < skill.LevelRequired then
		return false, "Level too low"
	end

	if SkillSystemModule.isOnCooldown(player, skillId) then
		return false, "On cooldown"
	end

	if playerData.Stamina < skill.StaminaCost then
		return false, "Not enough stamina"
	end

	return true
end

function SkillSystemModule.createSkillHitbox(originCFrame, size, offset, ignoreList)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = ignoreList or {}
	local hitboxCenter = originCFrame + originCFrame.LookVector * offset
	local parts = workspace:GetPartBoundsInBox(hitboxCenter, size, overlapParams)
	return parts
end

function SkillSystemModule.getHitCharacters(parts, attackerCharacter)
	local hitCharacters = {}
	local seen = {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model ~= attackerCharacter and not seen[model] then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				seen[model] = true
				table.insert(hitCharacters, model)
			end
		end
	end
	return hitCharacters
end

return SkillSystemModule