local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LightAttackRemote = Remotes:WaitForChild("LightAttack")
local BlockRemote = Remotes:WaitForChild("Block")
local ParryAttemptRemote = Remotes:WaitForChild("ParryAttempt")
local BlockParryVFXRemote = Remotes:WaitForChild("BlockParryVFX")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CombatModule = require(Modules:WaitForChild("CombatModule"))
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local SkillSystemModule = require(Modules:WaitForChild("SkillSystemModule"))

local COMBO_RESET_TIME = CombatModule.COMBO_RESET_TIME
local MAX_COMBO = CombatModule.MAX_COMBO
local _STAMINA_COST = CombatModule.STAMINA_COST_LIGHT
local ATTACK_RATE_LIMIT = 0.25

local BLOCK_STAMINA_DRAIN = CombatModule.BLOCK_STAMINA_DRAIN
local _GUARD_BREAK_STAGGER = CombatModule.GUARD_BREAK_STAGGER
local GUARD_BREAK_REBLOCK_CD = CombatModule.GUARD_BREAK_REBLOCK_COOLDOWN
local PARRY_WHIFF_STAMINA = CombatModule.PARRY_WHIFF_STAMINA
local PARRY_STAGGER_DURATION = CombatModule.PARRY_STAGGER_DURATION

local playerCombos = {}
local playerAttacking = {}
local playerBlocking = {}
local blockDrainThreads = {}
local guardBreakCooldowns = {}

local function getComboState(player)
	if not playerCombos[player] then
		playerCombos[player] = {
			index = 0,
			lastAttackTime = 0,
		}
	end
	return playerCombos[player]
end

local function stopBlocking(player, guardBroken)
	if not playerBlocking[player] then return end
	playerBlocking[player] = nil

	local character = player.Character
	if character then
		CombatModule.setBlocking(character, false)
	end

	if blockDrainThreads[player] then
		task.cancel(blockDrainThreads[player])
		blockDrainThreads[player] = nil
	end

	if guardBroken then
		guardBreakCooldowns[player] = os.clock() + GUARD_BREAK_REBLOCK_CD
		if character then
			CombatModule.applyGuardBreak(character)
		end
		BlockParryVFXRemote:FireAllClients("guardBreak", player, character)
		print("[CombatServer] Guard broken for " .. player.Name)
	end
end

local function startBlockDrain(player)
	if blockDrainThreads[player] then
		task.cancel(blockDrainThreads[player])
	end

	blockDrainThreads[player] = task.spawn(function()
		while playerBlocking[player] do
			task.wait(0.25)
			if not playerBlocking[player] then break end
			local drained = PlayerDataModule.consumeStamina(player, BLOCK_STAMINA_DRAIN * 0.25)
			if not drained then
				stopBlocking(player, true)
				break
			end
		end
	end)
end

BlockRemote.OnServerEvent:Connect(function(player, blocking)
	local character = player.Character
	if blocking then
		if playerBlocking[player] then return end
		if playerAttacking[player] then return end

		local gbExpiry = guardBreakCooldowns[player]
		if gbExpiry and os.clock() < gbExpiry then return end

		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		if CombatModule.isGuardBroken(character) then return end

		playerBlocking[player] = true
		CombatModule.setBlocking(character, true)
		startBlockDrain(player)
		BlockParryVFXRemote:FireAllClients("blockStart", player, character)
	else
		if playerBlocking[player] then
			stopBlocking(player, false)
			BlockParryVFXRemote:FireAllClients("blockEnd", player, character)
		end
	end
end)

ParryAttemptRemote.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local success, attackerModel = CombatModule.tryParry(character)

	if success then
		if humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = math.min(humanoid.Health + 0, humanoid.MaxHealth)
		end

		if attackerModel then
			CombatModule.applyParryStagger(attackerModel)

			local attackerHumanoid = attackerModel:FindFirstChildOfClass("Humanoid")
			if attackerHumanoid then
				attackerHumanoid.WalkSpeed = 0
				task.delay(PARRY_STAGGER_DURATION, function()
					if attackerHumanoid and attackerHumanoid.Parent then
						local attackerPlayer = Players:GetPlayerFromCharacter(attackerModel)
						if attackerPlayer then
							local data = PlayerDataModule.getData(attackerPlayer)
							attackerHumanoid.WalkSpeed = data and data.WalkSpeed or 24
						else
							attackerHumanoid.WalkSpeed = 24
						end
					end
				end)
			end
		end

		BlockParryVFXRemote:FireAllClients("parrySuccess", player, character, attackerModel)
		print("[CombatServer] Perfect parry by " .. player.Name)
	else
		PlayerDataModule.consumeStamina(player, PARRY_WHIFF_STAMINA)
		BlockParryVFXRemote:FireAllClients("parryWhiff", player, character)
	end
end)

LightAttackRemote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	local combo = getComboState(player)

	if now - combo.lastAttackTime < ATTACK_RATE_LIMIT then return end
	if playerBlocking[player] then return end

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	if CombatModule.isParryStaggered(character) then return end
	if CombatModule.isGuardBroken(character) then return end

	if now - combo.lastAttackTime > COMBO_RESET_TIME then
		combo.index = 0
	end

	combo.index = combo.index + 1
	if combo.index > MAX_COMBO then
		combo.index = 1
	end
	combo.lastAttackTime = now

	local hitCharacters = CombatModule.processLightAttack(player, combo.index)

	LightAttackRemote:FireClient(player, combo.index, #hitCharacters > 0)

	for _, other in Players:GetPlayers() do
		if other ~= player then
			LightAttackRemote:FireClient(other, combo.index, #hitCharacters > 0, player)
		end
	end
end)

local MASTERY_XP_PVP_KILL = 10

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		local lastAttackerId = character:GetAttribute("LastAttacker")
		if not lastAttackerId then return end
		local killer = Players:GetPlayerByUserId(lastAttackerId)
		if not killer or killer == player then return end

		local data = PlayerDataModule.getData(killer)
		if not data or data.Faction == "" then return end

		local factionSkills = SkillSystemModule.getSkillsForFaction(data.Faction)
		for _, skill in factionSkills do
			PlayerDataModule.addMasteryXP(killer, skill.Id, MASTERY_XP_PVP_KILL)
		end
		print("[CombatServer] Awarded " .. MASTERY_XP_PVP_KILL .. " mastery XP per equipped style to " .. killer.Name .. " for PvP kill")
	end)
end

Players.PlayerAdded:Connect(function(player)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	stopBlocking(player, false)
	playerCombos[player] = nil
	playerAttacking[player] = nil
	guardBreakCooldowns[player] = nil
	if player.Character then
		CombatModule.cleanupModel(player.Character)
	end
end)

print("[CombatServer] Loaded")