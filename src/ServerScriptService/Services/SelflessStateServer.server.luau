--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SelflessStateModule = require(Modules:WaitForChild("SelflessStateModule"))
local PlayerDataModule    = require(Modules:WaitForChild("PlayerDataModule"))

local SelflessStateToggle  = Remotes:WaitForChild("SelflessStateToggle")
local SelflessStateChanged = Remotes:WaitForChild("SelflessStateChanged")

local activePlayers:  { [Player]: boolean } = {}
local activeExpiresAt: { [Player]: number } = {}
local cooldownUntil: { [Player]: number } = {}
local DEBUG_KILL_XP = false

local function getData(player: Player)
	return PlayerDataModule.getData(player)
end

local function isCurrentlyActive(player: Player): boolean
	local expiry = activeExpiresAt[player]
	if not activePlayers[player] or not expiry then
		return false
	end
	return os.clock() < expiry
end

local function getTierForPlayer(player: Player): number
	local data = getData(player)
	if not data then return 1 end
	return SelflessStateModule.getTier(data.SelflessStateXP or 0)
end

local function fireUpdate(player: Player)
	local data = getData(player)
	if not data then return end
	local xp = data.SelflessStateXP or 0
	local tier = SelflessStateModule.getTier(xp)
	local bonus = SelflessStateModule.getBonusForTier(tier)
	local now = os.clock()
	local activeRemaining = activePlayers[player] and math.max(0, (activeExpiresAt[player] or now) - now) or 0
	local cooldownRemaining = math.max(0, (cooldownUntil[player] or now) - now)
	SelflessStateChanged:FireClient(player, {
		xp = xp,
		tier = tier,
		bonus = bonus,
		active = isCurrentlyActive(player),
		activeRemaining = activeRemaining,
		activeDuration = SelflessStateModule.ACTIVE_DURATION,
		cooldownRemaining = cooldownRemaining,
		cooldownDuration = SelflessStateModule.COOLDOWN_DURATION,
	})
end

-- Called by CombatServer when player kills or is attacked while Selfless is active
local function grantXP(player: Player, amount: number)
	if not isCurrentlyActive(player) then return false, nil end
	local data = getData(player)
	if not data then return false, nil end
	if not SelflessStateModule.canGainXP(data.SelflessStateXP or 0) then return false, nil end
	amount = math.max(0, amount)
	if amount <= 0 then return false, nil end

	local oldXP = data.SelflessStateXP or 0
	local oldTier = SelflessStateModule.getTier(oldXP)
	local newXP = oldXP + amount
	if not PlayerDataModule.setProgressionField(player, "SelflessStateXP", newXP) then
		warn("[SelflessStateServer] Could not persist XP for " .. player.Name)
		return false, nil
	end
	fireUpdate(player)
	local newTier = SelflessStateModule.getTier(newXP)
	if newTier > oldTier then
		print(("[SelflessStateServer] %s advanced to V%d at %d XP"):format(player.Name, newTier, newXP))
	end
	return true, newXP
end

local function grantEventXP(player: Player, eventName: string)
	local amount = SelflessStateModule.getXPForEvent(eventName)
	local granted, xp = grantXP(player, amount)
	if DEBUG_KILL_XP and granted and xp and eventName == "Kill" then
		print(("[SelflessStateServer] %s gained %d kill XP (%d total)"):format(player.Name, amount, xp))
	end
end

-- selene: allow(global_usage)
shared.SelflessStateServer = {
	grantXP = grantXP,
	grantEventXP = grantEventXP,
	isActive = isCurrentlyActive,
	getDefenseBonus = function(player: Player): number
		if not isCurrentlyActive(player) then return 0 end
		return SelflessStateModule.getDefenseBonusForTier(getTierForPlayer(player))
	end,
	getMaxDefenseMultiplier = function(_player: Player): number
		return SelflessStateModule.MAX_DEFENSE_MULTIPLIER
	end,
	getStaminaRegenMultiplier = function(player: Player): number
		if not isCurrentlyActive(player) then return 1 end
		return SelflessStateModule.getStaminaRegenMultiplier(getTierForPlayer(player))
	end,
	getAbilityCooldownMultiplier = function(player: Player): number
		if not isCurrentlyActive(player) then return 1 end
		return SelflessStateModule.getCooldownMultiplier(getTierForPlayer(player))
	end,
}

local function deactivate(player: Player, startCooldown: boolean?)
	if not activePlayers[player] then return end
	activePlayers[player] = false
	activeExpiresAt[player] = nil
	if startCooldown then
		cooldownUntil[player] = os.clock() + SelflessStateModule.COOLDOWN_DURATION
	end
	fireUpdate(player)
end

SelflessStateToggle.OnServerEvent:Connect(function(player: Player)
	local data = getData(player)
	if not data then return end
	if isCurrentlyActive(player) then
		deactivate(player, true)
	else
		if activePlayers[player] then
			deactivate(player, true)
			return
		end
		local now = os.clock()
		if now < (cooldownUntil[player] or 0) then
			fireUpdate(player)
			return
		end
		if (data.Stamina or 0) <= 0 then return end
		activePlayers[player] = true
		local expiry = now + SelflessStateModule.ACTIVE_DURATION
		activeExpiresAt[player] = expiry
		fireUpdate(player)
		task.delay(SelflessStateModule.ACTIVE_DURATION, function()
			if activePlayers[player] and activeExpiresAt[player] == expiry then
				deactivate(player, true)
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	activePlayers[player] = nil
	activeExpiresAt[player] = nil
	cooldownUntil[player] = nil
end)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function()
		activePlayers[player] = false
		activeExpiresAt[player] = nil
		fireUpdate(player)
	end)
end)

print("[SelflessStateServer] Loaded")
