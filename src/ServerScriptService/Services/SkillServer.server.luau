local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UseSkillRemote = Remotes:WaitForChild("UseSkill")
local SkillActivatedRemote = Remotes:WaitForChild("SkillActivated")
local DamageDealt = Remotes:WaitForChild("DamageDealt")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local SkillSystemModule = require(Modules:WaitForChild("SkillSystemModule"))

local SKILL_RATE_LIMIT = 0.3
local lastSkillUse = {}

Players.PlayerAdded:Connect(function(player)
	SkillSystemModule.initPlayer(player)
	lastSkillUse[player] = 0
end)

Players.PlayerRemoving:Connect(function(player)
	SkillSystemModule.cleanupPlayer(player)
	lastSkillUse[player] = nil
end)

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
	local damage = skill.BaseDamage * damageMultiplier

	for _, target in hitCharacters do
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local finalDmg = damage
			local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(target)
			if targetPlayer then
				local defenseMult = PlayerDataModule.getDefenseMultiplier(targetPlayer)
				finalDmg = damage * (1 - defenseMult)
			end

			humanoid:TakeDamage(finalDmg)

			target:SetAttribute("LastAttacker", player.UserId)

			local targetHRP = target:FindFirstChild("HumanoidRootPart")
			local hitPos = targetHRP and targetHRP.Position or Vector3.zero
			DamageDealt:FireAllClients(target, finalDmg, hitPos, hitIndex == 1)
		end
	end

	-- Award title XP for each enemy hit
	if #hitCharacters > 0 then
		local data = PlayerDataModule.getData(player)
		local equippedTitle = data and (data.EquippedTitle or "")
		if equippedTitle ~= "" then
			local xpPerHit = math.floor(10 + skill.BaseDamage * 0.1)
			PlayerDataModule.addTitleXP(player, equippedTitle, xpPerHit * #hitCharacters)
		end
	end

	return #hitCharacters, damage
end

UseSkillRemote.OnServerEvent:Connect(function(player, skillId)
	if typeof(skillId) ~= "string" then return end

	local now = os.clock()
	local last = lastSkillUse[player] or 0
	if now - last < SKILL_RATE_LIMIT then return end
	lastSkillUse[player] = now

	local data = PlayerDataModule.getData(player)
	if not data then return end

	local canUse, _reason = SkillSystemModule.canUseSkill(player, skillId, data)
	if not canUse then return end

	local skill = SkillSystemModule.getSkill(skillId)
	if not skill then return end

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	PlayerDataModule.consumeStamina(player, skill.StaminaCost)
	SkillSystemModule.setCooldown(player, skillId, skill.Cooldown)

	SkillActivatedRemote:FireClient(player, skillId, skill.Cooldown)
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			SkillActivatedRemote:FireClient(otherPlayer, player, skillId)
		end
	end

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
end)

print("[SkillServer] Loaded")