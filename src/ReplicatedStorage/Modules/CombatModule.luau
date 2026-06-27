local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DamageDealt = Remotes:WaitForChild("DamageDealt")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local CombatModule = {}

CombatModule.COMBO_RESET_TIME = 1.2
CombatModule.MAX_COMBO = 4
CombatModule.STAMINA_COST_LIGHT = 5
CombatModule.GUARD_BREAK_DURATION = 1.5

CombatModule.BLOCK_REDUCTION = 0.70
CombatModule.BLOCK_HEAVY_REDUCTION = 0.40
CombatModule.BLOCK_STAMINA_DRAIN = 8
CombatModule.GUARD_BREAK_STAGGER = 1.2
CombatModule.GUARD_BREAK_REBLOCK_COOLDOWN = 2.0
CombatModule.PARRY_WINDOW = 0.25
CombatModule.PARRY_STAGGER_DURATION = 0.8
CombatModule.PARRY_BREAK_STUN_DURATION = 1.6
CombatModule.PARRY_STAMINA_DAMAGE = 35
CombatModule.PARRY_WHIFF_STAMINA = 15

CombatModule.LIGHT_BASE_DAMAGE = {10, 10, 12, 18}
CombatModule.HITBOX_SIZE = Vector3.new(6, 6, 8)
CombatModule.HITBOX_OFFSET = 4

local blockingModels = {}
local incomingHitTimestamps = {}
local parryStaggerTargets = {}
local damageContributors = setmetatable({}, { __mode = "k" })
local friendlyFireLogTimes = setmetatable({}, { __mode = "k" })

local FRIENDLY_FIRE_LOG_COOLDOWN = 10

local function isModelInSafeZone(model)
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	-- selene: allow(global_usage)
	local zoneServer = shared and shared.ZoneServer
	if zoneServer and zoneServer.isSafePosition then
		return zoneServer.isSafePosition(hrp.Position) == true
	end
	return false
end

function CombatModule.isModelInSafeZone(model)
	return isModelInSafeZone(model)
end

function CombatModule.canPlayerDamageTarget(attackerPlayer, targetModel)
	if not attackerPlayer or not targetModel then return true end
	local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(targetModel)
	if not targetPlayer then return true end
	if targetPlayer == attackerPlayer then return false end

	-- selene: allow(global_usage)
	local teamService = shared and shared.TeamService
	if teamService and teamService.areTeammates and teamService.areTeammates(attackerPlayer, targetPlayer) then
		local now = os.clock()
		local attackerLogs = friendlyFireLogTimes[attackerPlayer] or {}
		local lastLog = attackerLogs[targetPlayer]
		if not lastLog or now - lastLog >= FRIENDLY_FIRE_LOG_COOLDOWN then
			attackerLogs[targetPlayer] = now
			friendlyFireLogTimes[attackerPlayer] = attackerLogs
			print("[CombatModule] Blocked team friendly fire: " .. attackerPlayer.Name .. " -> " .. targetPlayer.Name)
		end
		return false
	end
	return true
end

function CombatModule.recordDamageContribution(targetModel, attackerPlayer, amount)
	if not targetModel or not attackerPlayer then return end
	local contributors = damageContributors[targetModel]
	if not contributors then
		contributors = {}
		damageContributors[targetModel] = contributors
	end

	local current = contributors[attackerPlayer] or { damage = 0, lastHit = 0 }
	current.damage += amount or 0
	current.lastHit = os.clock()
	contributors[attackerPlayer] = current
end

function CombatModule.getRewardPlayers(targetModel, primaryPlayer, maxDistance)
	local result = {}
	local seen = {}

	local function addPlayer(player)
		if not player or seen[player] or not player.Parent then return end
		if maxDistance and primaryPlayer and primaryPlayer.Character and player.Character then
			local primaryRoot = primaryPlayer.Character:FindFirstChild("HumanoidRootPart")
			local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
			if primaryRoot and playerRoot and (primaryRoot.Position - playerRoot.Position).Magnitude > maxDistance then
				return
			end
		end
		seen[player] = true
		table.insert(result, player)
	end

	addPlayer(primaryPlayer)

	-- selene: allow(global_usage)
	local teamService = shared and shared.TeamService
	if teamService and teamService.getNearbyTeamMembers then
		for _, teamMember in teamService.getNearbyTeamMembers(primaryPlayer, maxDistance) do
			addPlayer(teamMember)
		end
	end

	return result
end

function CombatModule.clearDamageContributors(targetModel)
	damageContributors[targetModel] = nil
end

function CombatModule.setBlocking(model, isBlocking)
	if isBlocking then
		blockingModels[model] = true
	else
		blockingModels[model] = nil
	end
end

function CombatModule.isBlocking(model)
	return blockingModels[model] == true
end

function CombatModule.recordIncomingHit(targetModel, attackerModel)
	incomingHitTimestamps[targetModel] = {
		time = os.clock(),
		attacker = attackerModel,
	}
end

function CombatModule.tryParry(targetModel)
	local record = incomingHitTimestamps[targetModel]
	if not record then return false, nil end
	local elapsed = os.clock() - record.time
	if elapsed <= CombatModule.PARRY_WINDOW then
		incomingHitTimestamps[targetModel] = nil
		return true, record.attacker
	end
	return false, nil
end

function CombatModule.applyParryStagger(attackerModel, duration)
	parryStaggerTargets[attackerModel] = os.clock() + (duration or CombatModule.PARRY_STAGGER_DURATION)
end

function CombatModule.isParryStaggered(model)
	local expiry = parryStaggerTargets[model]
	if not expiry then return false end
	if os.clock() > expiry then
		parryStaggerTargets[model] = nil
		return false
	end
	return true
end

function CombatModule.createHitbox(originCFrame, size, ignoreList)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = ignoreList or {}

	local hitboxCenter = originCFrame + originCFrame.LookVector * CombatModule.HITBOX_OFFSET
	local parts = workspace:GetPartBoundsInBox(hitboxCenter, size, overlapParams)
	return parts
end

function CombatModule.getHitCharacters(parts, attackerCharacter)
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

function CombatModule.applyDamage(targetModel, amount, attackerPlayer, isHeavyOrSkill)
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	if isModelInSafeZone(targetModel) then return false end
	if attackerPlayer and attackerPlayer.Character and isModelInSafeZone(attackerPlayer.Character) then return false end
	if not CombatModule.canPlayerDamageTarget(attackerPlayer, targetModel) then return false end

	local finalAmount = amount
	if CombatModule.isBlocking(targetModel) then
		local reduction = isHeavyOrSkill and CombatModule.BLOCK_HEAVY_REDUCTION or CombatModule.BLOCK_REDUCTION
		finalAmount = amount * (1 - reduction)
	end

	local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
	local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(targetModel)
	if targetPlayer then
		local defenseMult = PlayerDataModule.getDefenseMultiplier(targetPlayer)
		finalAmount = finalAmount * (1 - defenseMult)
		if attackerPlayer and attackerPlayer ~= targetPlayer then
			finalAmount = finalAmount * PlayerDataModule.getPvPDamageMultiplier(attackerPlayer)
		end
	end

	local attackerCharacter = nil
	if attackerPlayer and attackerPlayer.Character then
		attackerCharacter = attackerPlayer.Character
	end
	CombatModule.recordIncomingHit(targetModel, attackerCharacter)

	humanoid:TakeDamage(finalAmount)

	if attackerPlayer then
		targetModel:SetAttribute("LastAttacker", attackerPlayer.UserId)
		CombatModule.recordDamageContribution(targetModel, attackerPlayer, finalAmount)
	end

	local targetHRP = targetModel:FindFirstChild("HumanoidRootPart")
	local hitPos = targetHRP and targetHRP.Position or Vector3.zero

	DamageDealt:FireAllClients(targetModel, finalAmount, hitPos, false, "Physical", "LightAttack")
	return true
end

CombatModule.NPC_HITBOX_SIZE = Vector3.new(5, 5, 5)
CombatModule.NPC_HITBOX_OFFSET = 3
CombatModule.NPC_HITBOX_LINGER = 0.2
CombatModule.NPC_ATTACK_WINDUP = 0.4

function CombatModule.applyDamageFromNPC(targetModel, amount, attackerModel)
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	if isModelInSafeZone(targetModel) then return false end
	if attackerModel and isModelInSafeZone(attackerModel) then return false end

	local finalAmount = amount
	if CombatModule.isBlocking(targetModel) then
		finalAmount = amount * (1 - CombatModule.BLOCK_REDUCTION)
	end

	local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
	local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(targetModel)
	if targetPlayer then
		local defenseMult = PlayerDataModule.getDefenseMultiplier(targetPlayer)
		finalAmount = finalAmount * (1 - defenseMult)
	end

	CombatModule.recordIncomingHit(targetModel, attackerModel)

	humanoid:TakeDamage(finalAmount)

	local targetHRP = targetModel:FindFirstChild("HumanoidRootPart")
	local hitPos = targetHRP and targetHRP.Position or Vector3.zero

	DamageDealt:FireAllClients(targetModel, finalAmount, hitPos, false, "DemonEnemy", "EnemyClaw")
	return true
end

function CombatModule.processNPCAttack(attackerModel, damage, debugMode)
	local hrp = attackerModel:FindFirstChild("HumanoidRootPart")
	if not hrp then return {} end

	local hitboxCFrame = hrp.CFrame * CFrame.new(0, 0, -CombatModule.NPC_HITBOX_OFFSET)
	local hitboxSize = CombatModule.NPC_HITBOX_SIZE

	local hbPart = Instance.new("Part")
	hbPart.Name = "NPCHitbox"
	hbPart.Size = hitboxSize
	hbPart.CFrame = hitboxCFrame
	hbPart.Anchored = true
	hbPart.CanCollide = false
	hbPart.CanQuery = false
	hbPart.CanTouch = false

	if debugMode then
		hbPart.Transparency = 0.6
		hbPart.Color = Color3.fromRGB(255, 0, 0)
		hbPart.Material = Enum.Material.ForceField
	else
		hbPart.Transparency = 1
	end

	hbPart.Parent = workspace

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {attackerModel, hbPart}

	local parts = workspace:GetPartBoundsInBox(hitboxCFrame, hitboxSize, overlapParams)
	local hitCharacters = CombatModule.getHitCharacters(parts, attackerModel)

	local hitPlayers = {}
	for _, target in hitCharacters do
		local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(target)
		if targetPlayer then
			table.insert(hitPlayers, target)
		end
	end

	for _, target in hitPlayers do
		CombatModule.applyDamageFromNPC(target, damage, attackerModel)
	end

	task.delay(CombatModule.NPC_HITBOX_LINGER, function()
		if hbPart and hbPart.Parent then
			hbPart:Destroy()
		end
	end)

	return hitPlayers
end

function CombatModule.processLightAttack(player, comboIndex)
	local character = player.Character
	if not character then return {} end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return {} end

	if CombatModule.isParryStaggered(character) then return {} end

	local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
	local baseDamage = CombatModule.LIGHT_BASE_DAMAGE[comboIndex] or CombatModule.LIGHT_BASE_DAMAGE[1]
	local damage = baseDamage * PlayerDataModule.getDamageMultiplier(player)

	local parts = CombatModule.createHitbox(hrp.CFrame, CombatModule.HITBOX_SIZE, {character})
	local hitCharacters = CombatModule.getHitCharacters(parts, character)

	for _, target in hitCharacters do
		CombatModule.applyDamage(target, damage, player, false)
	end

	return hitCharacters
end

local guardBrokenTargets = {}

function CombatModule.applyGuardBreak(targetModel)
	guardBrokenTargets[targetModel] = os.clock() + CombatModule.GUARD_BREAK_DURATION
end

function CombatModule.isGuardBroken(targetModel)
	local expiry = guardBrokenTargets[targetModel]
	if not expiry then return false end
	if os.clock() > expiry then
		guardBrokenTargets[targetModel] = nil
		return false
	end
	return true
end

function CombatModule.cleanupModel(model)
	blockingModels[model] = nil
	incomingHitTimestamps[model] = nil
	parryStaggerTargets[model] = nil
	guardBrokenTargets[model] = nil
end

return CombatModule
