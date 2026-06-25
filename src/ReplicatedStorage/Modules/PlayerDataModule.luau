local _Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HPChanged = Remotes:WaitForChild("HPChanged")
local StaminaChanged = Remotes:WaitForChild("StaminaChanged")
local PlayerDeath = Remotes:WaitForChild("PlayerDeath")
local PlayerRespawn = Remotes:WaitForChild("PlayerRespawn")
local MasteryChanged = Remotes:FindFirstChild("MasteryChanged")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local StatConfig = require(Modules:WaitForChild("StatConfig"))

local PlayerDataModule = {}

PlayerDataModule.DEFAULTS = {
	MaxHP = StatConfig.BASE.MaxHP,
	HP = StatConfig.BASE.MaxHP,
	MaxStamina = StatConfig.BASE.MaxStamina,
	Stamina = StatConfig.BASE.MaxStamina,
	StaminaRegen = 10,
	StaminaRegenPause = 0.5,
	WalkSpeed = StatConfig.BASE.WalkSpeed,
	JumpPower = 50,
	DodgeCooldown = 0.8,
	DodgeIFrameDuration = 0.3,
	RespawnTime = 5,
	Level = 1,
	XP = 0,
	TotalXP = 0,
	BreathDamage = 0,
	DemonArtDamage = 0,
	Health = 0,
	Defense = 0,
	StaminaStat = 0,
	MovementSpeed = 0,
	StatPoints = 0,
	Faction = "",
	Inventory = {},
	RebirthCount = 0,
	SkillsUnlocked = {},
	Mastery = {},
	Bounty = 0,
	StatPointsMigrated = false,
	lastRespecTime = 0,
}

local STAT_POINTS_PER_LEVEL = StatConfig.STAT_POINTS_PER_LEVEL

local SAVE_FIELDS = {
	"Level", "XP", "TotalXP",
	"BreathDamage", "DemonArtDamage", "Health", "Defense", "StaminaStat", "MovementSpeed",
	"StatPoints", "Faction", "Inventory", "RebirthCount", "SkillsUnlocked",
	"Mastery", "Bounty", "StatPointsMigrated", "lastRespecTime",
}

local playerData = {}
local staminaRegenTimers = {}

local StatsChanged = Remotes:FindFirstChild("StatsChanged")
local LevelUpRemote = Remotes:FindFirstChild("LevelUp")
local StatPointsChanged = Remotes:FindFirstChild("StatPointsChanged")

function PlayerDataModule.xpForLevel(level)
	return math.floor(100 * (level ^ 1.4))
end

function PlayerDataModule.computeStats(data)
	local maxHP = StatConfig.BASE.MaxHP + (data.Health * 15)
	local maxStamina = StatConfig.BASE.MaxStamina + (data.StaminaStat * 5)
	local walkSpeed = math.min(StatConfig.BASE.WalkSpeed + (data.MovementSpeed * 0.5), 40)
	local defenseMultiplier = math.min(data.Defense * 0.008, 0.64)

	local damageMultiplier = 1.0
	if data.Faction == "Slayer" then
		damageMultiplier = 1.0 + (data.BreathDamage * 0.03)
	elseif data.Faction == "Demon" then
		damageMultiplier = 1.0 + (data.DemonArtDamage * 0.03)
	end

	return {
		maxHP = maxHP,
		maxStamina = maxStamina,
		walkSpeed = walkSpeed,
		damageMultiplier = damageMultiplier,
		defenseMultiplier = defenseMultiplier,
	}
end

function PlayerDataModule.getDamageMultiplier(player)
	local data = playerData[player]
	if not data then return 1 end
	local stats = PlayerDataModule.computeStats(data)
	return stats.damageMultiplier
end

function PlayerDataModule.getDefenseMultiplier(player)
	local data = playerData[player]
	if not data then return 0 end
	local stats = PlayerDataModule.computeStats(data)
	return stats.defenseMultiplier
end

function PlayerDataModule.getEffectiveWalkSpeed(player)
	local data = playerData[player]
	if not data then return StatConfig.BASE.WalkSpeed end
	local stats = PlayerDataModule.computeStats(data)
	return stats.walkSpeed
end

function PlayerDataModule.getEffectiveMaxStamina(player)
	local data = playerData[player]
	if not data then return StatConfig.BASE.MaxStamina end
	local stats = PlayerDataModule.computeStats(data)
	return stats.maxStamina
end

function PlayerDataModule.getEffectiveMaxHP(player)
	local data = playerData[player]
	if not data then return StatConfig.BASE.MaxHP end
	local stats = PlayerDataModule.computeStats(data)
	return stats.maxHP
end

function PlayerDataModule.applyStatEffects(player)
	local data = playerData[player]
	if not data then return end
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local stats = PlayerDataModule.computeStats(data)
	local oldMaxHP = data.MaxHP

	data.MaxHP = stats.maxHP
	data.MaxStamina = stats.maxStamina
	data.WalkSpeed = stats.walkSpeed

	humanoid.WalkSpeed = stats.walkSpeed

	if data.MaxHP ~= oldMaxHP then
		data._syncingHealth = true
		humanoid.MaxHealth = data.MaxHP
		local newHP = math.clamp(data.HP, 0, data.MaxHP)
		if data.HP < data.MaxHP and oldMaxHP < data.MaxHP then
			newHP = math.min(data.HP + (data.MaxHP - oldMaxHP), data.MaxHP)
		end
		data.HP = newHP
		humanoid.Health = data.HP
		data._syncingHealth = false
		HPChanged:FireClient(player, data.HP, data.MaxHP)
	end

	local effMax = stats.maxStamina
	if data.Stamina > effMax then
		data.Stamina = effMax
	end
	StaminaChanged:FireClient(player, data.Stamina, effMax)
end

function PlayerDataModule.sendStatPointsUpdate(player)
	local data = playerData[player]
	if not data then return end
	if not StatPointsChanged then return end
	local stats = PlayerDataModule.computeStats(data)
	local payload = {
		StatPoints = data.StatPoints,
		Faction = data.Faction,
		DerivedMaxHP = stats.maxHP,
		DerivedMaxStamina = stats.maxStamina,
		DerivedWalkSpeed = stats.walkSpeed,
		DerivedDamageMultiplier = stats.damageMultiplier,
		DerivedDefenseMultiplier = stats.defenseMultiplier,
		lastRespecTime = data.lastRespecTime or 0,
	}
	for _, key in ipairs(StatConfig.STAT_KEYS) do
		payload[key] = data[key] or 0
	end
	StatPointsChanged:FireClient(player, payload)
end

function PlayerDataModule.addXP(player, amount)
	local data = playerData[player]
	if not data then return end

	data.XP = data.XP + amount
	data.TotalXP = data.TotalXP + amount

	local levelsGained = 0
	local needed = PlayerDataModule.xpForLevel(data.Level)
	while data.XP >= needed do
		data.XP = data.XP - needed
		data.Level = data.Level + 1
		levelsGained = levelsGained + 1
		data.StatPoints = data.StatPoints + STAT_POINTS_PER_LEVEL
		needed = PlayerDataModule.xpForLevel(data.Level)
	end

	if levelsGained > 0 then
		local stats = PlayerDataModule.computeStats(data)
		data.MaxHP = stats.maxHP
		data.MaxStamina = stats.maxStamina
		data.HP = data.MaxHP
		data.Stamina = data.MaxStamina

		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				data._syncingHealth = true
				humanoid.MaxHealth = data.MaxHP
				humanoid.Health = data.HP
				data._syncingHealth = false
			end
		end

		HPChanged:FireClient(player, data.HP, data.MaxHP)
		StaminaChanged:FireClient(player, data.Stamina, data.MaxStamina)

		if LevelUpRemote then
			LevelUpRemote:FireClient(player, data.Level)
		end
		PlayerDataModule.sendStatPointsUpdate(player)
		PlayerDataModule.applyStatEffects(player)
		print("[PlayerDataModule] " .. player.Name .. " leveled up to " .. data.Level .. " (+" .. levelsGained * STAT_POINTS_PER_LEVEL .. " stat points)")
	end

	if StatsChanged then
		StatsChanged:FireClient(player, data.Level, data.XP, PlayerDataModule.xpForLevel(data.Level), data.TotalXP)
	end

	return levelsGained
end

function PlayerDataModule.allocateStat(player, statName)
	local data = playerData[player]
	if not data then return false, "No data" end
	if data.StatPoints <= 0 then return false, "No stat points" end
	if not StatConfig.VALID_STATS[statName] then return false, "Invalid stat" end

	local requiredFaction = StatConfig.FACTION_LOCK[statName]
	if requiredFaction and data.Faction ~= requiredFaction then
		return false, "Wrong faction for this stat"
	end

	data[statName] = (data[statName] or 0) + 1
	data.StatPoints = data.StatPoints - 1

	PlayerDataModule.applyStatEffects(player)
	PlayerDataModule.sendStatPointsUpdate(player)

	return true
end

local RESPEC_COOLDOWN = 86400

function PlayerDataModule.respecStats(player)
	local data = playerData[player]
	if not data then return false, "No data", 0 end

	local now = os.time()
	local lastRespec = data.lastRespecTime or 0
	if lastRespec > 0 and (now - lastRespec) < RESPEC_COOLDOWN then
		local cooldownEnd = lastRespec + RESPEC_COOLDOWN
		return false, "On cooldown", cooldownEnd
	end

	for _, key in ipairs(StatConfig.STAT_KEYS) do
		data[key] = 0
	end

	data.StatPoints = math.max(0, (data.Level - 1) * STAT_POINTS_PER_LEVEL)
	data.lastRespecTime = now

	PlayerDataModule.applyStatEffects(player)
	PlayerDataModule.sendStatPointsUpdate(player)

	local cooldownEnd = now + RESPEC_COOLDOWN
	print("[PlayerDataModule] " .. player.Name .. " respecced all stats, refunded " .. data.StatPoints .. " points")
	return true, "Success", cooldownEnd
end

function PlayerDataModule.setFaction(player, faction)
	local data = playerData[player]
	if not data then return false, "No data" end
	if data.Faction ~= "" then return false, "Faction already chosen" end
	if faction ~= "Slayer" and faction ~= "Demon" then return false, "Invalid faction" end
	data.Faction = faction
	PlayerDataModule.applyStatEffects(player)
	PlayerDataModule.sendStatPointsUpdate(player)
	print("[PlayerDataModule] " .. player.Name .. " chose faction: " .. faction)
	return true
end

function PlayerDataModule.resetFaction(player)
	local data = playerData[player]
	if not data then return false, "No data" end
	if data.Faction == "" then return false, "No faction set" end

	local refunded = 0
	for statKey, _requiredFaction in pairs(StatConfig.FACTION_LOCK) do
		local pts = data[statKey] or 0
		if pts > 0 then
			refunded = refunded + pts
			data[statKey] = 0
		end
	end
	data.StatPoints = data.StatPoints + refunded

	local oldFaction = data.Faction
	data.Faction = ""

	PlayerDataModule.applyStatEffects(player)
	PlayerDataModule.sendStatPointsUpdate(player)
	print("[PlayerDataModule] " .. player.Name .. " reset faction (was " .. oldFaction .. "), refunded " .. refunded .. " faction-locked stat points")
	return true
end

function PlayerDataModule.unlockSkill(player, skillId)
	local data = playerData[player]
	if not data then return false end
	for _, id in data.SkillsUnlocked do
		if id == skillId then return false end
	end
	table.insert(data.SkillsUnlocked, skillId)
	return true
end

function PlayerDataModule.hasSkill(player, skillId)
	local data = playerData[player]
	if not data then return false end
	for _, id in data.SkillsUnlocked do
		if id == skillId then return true end
	end
	return false
end

function PlayerDataModule.addInventoryItem(player, itemId)
	local data = playerData[player]
	if not data then return false end
	table.insert(data.Inventory, itemId)
	return true
end

function PlayerDataModule.removeInventoryItem(player, itemId)
	local data = playerData[player]
	if not data then return false end
	for i, id in data.Inventory do
		if id == itemId then
			table.remove(data.Inventory, i)
			return true
		end
	end
	return false
end

function PlayerDataModule.getSavePayload(player)
	local data = playerData[player]
	if not data then return nil end
	local payload = {}
	for _, key in SAVE_FIELDS do
		payload[key] = data[key]
	end
	return payload
end

function PlayerDataModule.loadSavePayload(player, payload)
	local data = playerData[player]
	if not data or not payload then return end

	local legacyPoints = 0
	for oldKey, newKey in pairs(StatConfig.LEGACY_KEY_MAP) do
		if payload[oldKey] ~= nil then
			local val = payload[oldKey]
			if newKey then
				payload[newKey] = (payload[newKey] or 0) + val
				print("[PlayerDataModule] Migrated legacy stat " .. oldKey .. " -> " .. newKey .. " (" .. val .. " pts) for " .. player.Name)
			else
				legacyPoints = legacyPoints + val
				print("[PlayerDataModule] Stripped unknown legacy stat " .. oldKey .. " (" .. val .. " pts) for " .. player.Name)
			end
			payload[oldKey] = nil
		end
	end

	if legacyPoints > 0 then
		payload.StatPoints = (payload.StatPoints or 0) + legacyPoints
		print("[PlayerDataModule] Refunded " .. legacyPoints .. " legacy points as UnspentPoints for " .. player.Name)
	end

	for _, key in SAVE_FIELDS do
		if payload[key] ~= nil then
			data[key] = payload[key]
		end
	end

	if not data.StatPointsMigrated and data.Level > 1 then
		local pointsSpent = 0
		for _, key in ipairs(StatConfig.STAT_KEYS) do
			pointsSpent = pointsSpent + (data[key] or 0)
		end
		local expectedTotal = (data.Level - 1) * STAT_POINTS_PER_LEVEL
		local actualTotal = pointsSpent + data.StatPoints
		local correction = expectedTotal - actualTotal
		if correction > 0 then
			data.StatPoints = data.StatPoints + correction
			print("[PlayerDataModule] Stat points migration for " .. player.Name .. ": +" .. correction .. " points (had " .. actualTotal .. ", expected " .. expectedTotal .. ")")
		end
		data.StatPointsMigrated = true
	end

	local stats = PlayerDataModule.computeStats(data)
	data.MaxHP = stats.maxHP
	data.MaxStamina = stats.maxStamina
	data.WalkSpeed = stats.walkSpeed
	data.HP = data.MaxHP
	data.Stamina = data.MaxStamina
end

local function connectHealthSync(player, humanoid, data)
	data._syncingHealth = false
	humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		if data._syncingHealth then return end
		local newHP = humanoid.Health
		local maxHP = humanoid.MaxHealth
		data.HP = math.clamp(newHP, 0, maxHP)
		data.MaxHP = maxHP
		HPChanged:FireClient(player, data.HP, data.MaxHP)
		if data.HP <= 0 then
			PlayerDataModule.onPlayerDeath(player)
		end
	end)
end

function PlayerDataModule.initPlayer(player)
	local data = {}
	for key, value in pairs(PlayerDataModule.DEFAULTS) do
		if typeof(value) == "table" then
			data[key] = table.clone(value)
		else
			data[key] = value
		end
	end
	playerData[player] = data

	local stats = PlayerDataModule.computeStats(data)
	data.MaxHP = stats.maxHP
	data.MaxStamina = stats.maxStamina
	data.WalkSpeed = stats.walkSpeed
	data.HP = data.MaxHP
	data.Stamina = data.MaxStamina

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	data._syncingHealth = true
	humanoid.MaxHealth = data.MaxHP
	humanoid.Health = data.HP
	data._syncingHealth = false

	humanoid.WalkSpeed = stats.walkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = data.JumpPower

	connectHealthSync(player, humanoid, data)

	HPChanged:FireClient(player, data.HP, data.MaxHP)
	StaminaChanged:FireClient(player, data.Stamina, stats.maxStamina)
	if StatsChanged then
		StatsChanged:FireClient(player, data.Level, data.XP, PlayerDataModule.xpForLevel(data.Level), data.TotalXP)
	end
	PlayerDataModule.sendStatPointsUpdate(player)

	PlayerDataModule.startStaminaRegen(player)
end

function PlayerDataModule.cleanupPlayer(player)
	playerData[player] = nil
	if staminaRegenTimers[player] then
		staminaRegenTimers[player] = nil
	end
end

function PlayerDataModule.getData(player)
	return playerData[player]
end

function PlayerDataModule.setHP(player, value)
	local data = playerData[player]
	if not data then return end
	data.HP = math.clamp(value, 0, data.MaxHP)
	HPChanged:FireClient(player, data.HP, data.MaxHP)
	if data.HP <= 0 then
		PlayerDataModule.onPlayerDeath(player)
	end
end

function PlayerDataModule.getHP(player)
	local data = playerData[player]
	return data and data.HP or 0
end

function PlayerDataModule.setStamina(player, value)
	local data = playerData[player]
	if not data then return end
	local effMax = PlayerDataModule.getEffectiveMaxStamina(player)
	data.Stamina = math.clamp(value, 0, effMax)
	StaminaChanged:FireClient(player, data.Stamina, effMax)
end

function PlayerDataModule.consumeStamina(player, amount)
	local data = playerData[player]
	if not data then return false end
	if data.Stamina < amount then return false end
	local effMax = PlayerDataModule.getEffectiveMaxStamina(player)
	data.Stamina = math.clamp(data.Stamina - amount, 0, effMax)
	StaminaChanged:FireClient(player, data.Stamina, effMax)
	staminaRegenTimers[player] = os.clock() + data.StaminaRegenPause
	return true
end

function PlayerDataModule.startStaminaRegen(player)
	task.spawn(function()
		while playerData[player] do
			task.wait(0.1)
			local data = playerData[player]
			if not data then break end
			local now = os.clock()
			local pauseUntil = staminaRegenTimers[player] or 0
			local effMax = PlayerDataModule.getEffectiveMaxStamina(player)
			if now >= pauseUntil and data.Stamina < effMax then
				data.Stamina = math.min(data.Stamina + data.StaminaRegen * 0.1, effMax)
				StaminaChanged:FireClient(player, data.Stamina, effMax)
			end
		end
	end)
end

function PlayerDataModule.onPlayerDeath(player)
	local data = playerData[player]
	if not data then return end
	if data.isDead then return end
	data.isDead = true
	PlayerDeath:FireClient(player, data.RespawnTime)
	task.delay(data.RespawnTime, function()
		if not playerData[player] then return end
		player:LoadCharacter()
	end)
end

function PlayerDataModule.onCharacterAdded(player)
	local data = playerData[player]
	if not data then
		PlayerDataModule.initPlayer(player)
		return
	end

	local stats = PlayerDataModule.computeStats(data)
	data.MaxHP = stats.maxHP
	data.MaxStamina = stats.maxStamina
	data.WalkSpeed = stats.walkSpeed
	data.HP = data.MaxHP
	data.Stamina = data.MaxStamina
	data.isDead = false

	local character = player.Character
	local humanoid = character:WaitForChild("Humanoid")
	data._syncingHealth = true
	humanoid.MaxHealth = data.MaxHP
	humanoid.Health = data.HP
	data._syncingHealth = false

	humanoid.WalkSpeed = stats.walkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = data.JumpPower

	connectHealthSync(player, humanoid, data)

	HPChanged:FireClient(player, data.HP, data.MaxHP)
	StaminaChanged:FireClient(player, data.Stamina, stats.maxStamina)
	PlayerRespawn:FireClient(player)
	if StatsChanged then
		StatsChanged:FireClient(player, data.Level, data.XP, PlayerDataModule.xpForLevel(data.Level), data.TotalXP)
	end
	PlayerDataModule.sendStatPointsUpdate(player)

	PlayerDataModule.startStaminaRegen(player)
end

-- ==================== MASTERY SYSTEM ====================
local MASTERY_STYLES = {
	"WaterSurfaceSlash",
	"WaterWheel",
	"FlowingDance",
	"DemonSlash",
	"BloodBurst",
	"ShadowStep",
}

local MASTERY_XP_PER_LEVEL = 100
local MASTERY_LEVEL_EXPONENT = 1.3
local MASTERY_MAX_LEVEL = 50

function PlayerDataModule.masteryXPForLevel(level)
	return math.floor(MASTERY_XP_PER_LEVEL * (level ^ MASTERY_LEVEL_EXPONENT))
end

function PlayerDataModule.getMasteryData(player, styleId)
	local data = playerData[player]
	if not data then return nil end
	if not data.Mastery[styleId] then
		data.Mastery[styleId] = { XP = 0, Level = 1, TotalXP = 0 }
	end
	return data.Mastery[styleId]
end

function PlayerDataModule.getMasteryLevel(player, styleId)
	local mastery = PlayerDataModule.getMasteryData(player, styleId)
	if not mastery then return 1 end
	return mastery.Level
end

function PlayerDataModule.getAllMastery(player)
	local data = playerData[player]
	if not data then return {} end
	return data.Mastery
end

function PlayerDataModule.addMasteryXP(player, styleId, amount)
	local data = playerData[player]
	if not data then return 0 end

	if not data.Mastery[styleId] then
		data.Mastery[styleId] = { XP = 0, Level = 1, TotalXP = 0 }
	end

	local mastery = data.Mastery[styleId]
	mastery.XP = mastery.XP + amount
	mastery.TotalXP = mastery.TotalXP + amount

	local levelsGained = 0
	if mastery.Level < MASTERY_MAX_LEVEL then
		local needed = PlayerDataModule.masteryXPForLevel(mastery.Level)
		while mastery.XP >= needed and mastery.Level < MASTERY_MAX_LEVEL do
			mastery.XP = mastery.XP - needed
			mastery.Level = mastery.Level + 1
			levelsGained = levelsGained + 1
			needed = PlayerDataModule.masteryXPForLevel(mastery.Level)
		end
	end

	if not MasteryChanged then
		MasteryChanged = Remotes:FindFirstChild("MasteryChanged")
	end
	if MasteryChanged then
		MasteryChanged:FireClient(player, styleId, mastery.Level, mastery.XP, PlayerDataModule.masteryXPForLevel(mastery.Level), mastery.TotalXP, levelsGained)
	end

	if levelsGained > 0 then
		print("[PlayerDataModule] " .. player.Name .. " mastery " .. styleId .. " reached level " .. mastery.Level)
	end

	return levelsGained
end

PlayerDataModule.MASTERY_STYLES = MASTERY_STYLES
PlayerDataModule.MASTERY_MAX_LEVEL = MASTERY_MAX_LEVEL

-- ==================== BOUNTY SYSTEM ====================
local BountyChanged = Remotes:FindFirstChild("BountyChanged")

function PlayerDataModule.getBounty(player)
	local data = playerData[player]
	if not data then return 0 end
	return data.Bounty or 0
end

function PlayerDataModule.addBounty(player, amount)
	local data = playerData[player]
	if not data then return end
	data.Bounty = (data.Bounty or 0) + amount
	if not BountyChanged then
		BountyChanged = Remotes:FindFirstChild("BountyChanged")
	end
	if BountyChanged then
		BountyChanged:FireAllClients(player, data.Bounty)
	end
end

function PlayerDataModule.setBounty(player, value)
	local data = playerData[player]
	if not data then return end
	data.Bounty = math.max(0, value)
	if not BountyChanged then
		BountyChanged = Remotes:FindFirstChild("BountyChanged")
	end
	if BountyChanged then
		BountyChanged:FireAllClients(player, data.Bounty)
	end
end

return PlayerDataModule