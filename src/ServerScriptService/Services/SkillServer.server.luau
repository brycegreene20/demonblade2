local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UseSkillRemote = Remotes:WaitForChild("UseSkill")
local SkillActivatedRemote = Remotes:WaitForChild("SkillActivated")
local DamageDealt = Remotes:WaitForChild("DamageDealt")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local SkillSystemModule = require(Modules:WaitForChild("SkillSystemModule"))
local CombatModule = require(Modules:WaitForChild("CombatModule"))

local SKILL_RATE_LIMIT = 0.3
local REJECTION_LOG_COOLDOWN = 5
local lastSkillUse = {}
local lastRejectionLog = {}

Players.PlayerAdded:Connect(function(player)
	SkillSystemModule.initPlayer(player)
	lastSkillUse[player] = 0
	lastRejectionLog[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	SkillSystemModule.cleanupPlayer(player)
	lastSkillUse[player] = nil
	lastRejectionLog[player] = nil
end)

local function logRejectedSkillUse(player, skillId, equippedStyle, reason)
	local playerLogs = lastRejectionLog[player]
	if not playerLogs then
		playerLogs = {}
		lastRejectionLog[player] = playerLogs
	end

	local key = skillId .. ":" .. tostring(reason)
	local now = os.clock()
	if now - (playerLogs[key] or 0) < REJECTION_LOG_COOLDOWN then
		return
	end
	playerLogs[key] = now

	warn(
		"[SkillServer] Rejected skill use for "
		.. player.Name
		.. ": skill="
		.. skillId
		.. ", equippedStyle="
		.. tostring(equippedStyle)
		.. ", reason="
		.. tostring(reason)
	)
end

local function applySkillDamage(player, skill, hitIndex)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local parts = SkillSystemModule.createSkillHitbox(
		hrp.CFrame,
		skill.HitboxSize,
		skill.HitboxOffset,
		{character}
	)
	local hitCharacters = SkillSystemModule.getHitCharacters(parts, character)

	local damageMultiplier = PlayerDataModule.getDamageMultiplier(player)
	local masteryMultiplier = PlayerDataModule.getMasteryDamageMultiplier(player, skill.Style)
	local damage = skill.BaseDamage * damageMultiplier * masteryMultiplier
	local appliedHitCount = 0

	for _, target in hitCharacters do
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			if CombatModule.isModelInSafeZone(target) or CombatModule.isModelInSafeZone(character) then
				continue
			end
			if not CombatModule.canPlayerDamageTarget(player, target) then
				continue
			end
			local finalDmg = damage
			local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(target)
			if targetPlayer then
				local defenseMult = PlayerDataModule.getDefenseMultiplier(targetPlayer)
				finalDmg = damage * (1 - defenseMult)
				if targetPlayer ~= player then
					finalDmg *= PlayerDataModule.getPvPDamageMultiplier(player)
				end
			end

			-- Record attribution first so a lethal ability hit cannot outrun the death handler.
			CombatModule.recordPlayerDamage(target, player, finalDmg)

			humanoid:TakeDamage(finalDmg)
			appliedHitCount += 1
			CombatModule.grantStateProgressionEvent(player, "DamageDealt")
			if targetPlayer then
				CombatModule.grantStateProgressionEvent(targetPlayer, "DamageTaken")
			end

			local targetHRP = target:FindFirstChild("HumanoidRootPart")
			local hitPos = targetHRP and targetHRP.Position or Vector3.zero
			DamageDealt:FireAllClients(target, finalDmg, hitPos, hitIndex == 1, skill.Style or skill.Faction or "", skill.Id)
		end
	end

	-- Award title XP for each enemy hit
	if appliedHitCount > 0 then
		local data = PlayerDataModule.getData(player)
		local equippedTitle = data and (data.EquippedTitle or "")
		if data and data.EquippedStyle and data.EquippedStyle ~= "" then
			PlayerDataModule.addMasteryXP(player, data.EquippedStyle, math.max(1, math.floor(skill.BaseDamage / 20)))
		end
		if equippedTitle ~= "" then
			local xpPerHit = math.floor(10 + skill.BaseDamage * 0.1)
			PlayerDataModule.addTitleXP(player, equippedTitle, xpPerHit * appliedHitCount)
		end
	end

	return appliedHitCount, damage
end

UseSkillRemote.OnServerEvent:Connect(function(player, skillId)
	if typeof(skillId) ~= "string" then return end

	local now = os.clock()
	local last = lastSkillUse[player] or 0
	if now - last < SKILL_RATE_LIMIT then return end
	lastSkillUse[player] = now

	local data = PlayerDataModule.getData(player)
	if not data then return end

	local canUse, reason = SkillSystemModule.canUseSkill(player, skillId, data)
	if not canUse then
		logRejectedSkillUse(player, skillId, data.EquippedStyle, reason)
		return
	end

	local skill = SkillSystemModule.getSkill(skillId)
	if not skill then return end

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	PlayerDataModule.consumeStamina(player, skill.StaminaCost)
	local cooldown = skill.Cooldown * PlayerDataModule.getAbilityCooldownMultiplier(player)
	SkillSystemModule.setCooldown(player, skillId, cooldown)

	SkillActivatedRemote:FireClient(player, skillId, cooldown)
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			SkillActivatedRemote:FireClient(otherPlayer, player, skillId)
		end
	end

	if not skill.IsUtility then
		if skill.MultiHit > 1 then
			task.spawn(function()
				for i = 1, skill.MultiHit do
					if not player.Character then break end
					local hum = player.Character:FindFirstChildOfClass("Humanoid")
					if not hum or hum.Health <= 0 then break end
					applySkillDamage(player, skill, i)
					if i < skill.MultiHit then
						task.wait(skill.MultiHitDelay)
					end
				end
			end)
		else
			applySkillDamage(player, skill, 1)
		end
	end
end)

print("[SkillServer] Loaded")
