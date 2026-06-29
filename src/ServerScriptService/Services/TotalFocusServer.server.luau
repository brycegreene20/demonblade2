--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TotalFocusModule = require(Modules:WaitForChild("TotalFocusModule"))
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))

local TotalFocusToggle  = Remotes:WaitForChild("TotalFocusToggle")
local TotalFocusChanged = Remotes:WaitForChild("TotalFocusChanged")
local TotalFocusRebirth = Remotes:WaitForChild("TotalFocusRebirth")

local STAMINA_DRAIN_INTERVAL = 0.5
local SPEED_BONUS = 15

-- Runtime active state (not persisted)
local activePlayers: { [Player]: boolean } = {}
local drainTimers:   { [Player]: number  } = {}

local function getData(player: Player)
	return PlayerDataModule.getData(player)
end

local function fireUpdate(player: Player)
	local data = getData(player)
	if not data then return end
	local xp = data.TotalFocusXP or 0
	local rebirths = data.TotalFocusRebirths or 0
	local active = activePlayers[player] == true
	local tier = TotalFocusModule.getTier(xp)
	TotalFocusChanged:FireClient(player, {
		xp = xp,
		tierName = tier.name,
		tierIndex = TotalFocusModule.getTierIndex(xp),
		rebirths = rebirths,
		active = active,
		label = rebirths > 0 and TotalFocusModule.getConstantLabel(rebirths) or tier.name,
		haloColor = tier.haloColor,
		damageBonus = tier.damageBonus,
		damageReduction = tier.damageReduction,
	})
end

-- Called by CombatServer when the player kills or is hit while Focus is active
local function grantXP(player: Player, amount: number)
	if not activePlayers[player] then return end
	local data = getData(player)
	if not data then return end
	local xp = (data.TotalFocusXP or 0) + amount
	PlayerDataModule.setField(player, "TotalFocusXP", xp)
	fireUpdate(player)
end

-- selene: allow(global_usage)
shared.TotalFocusServer = { grantXP = grantXP }

local function deactivate(player: Player)
	if not activePlayers[player] then return end
	activePlayers[player] = false
	drainTimers[player] = nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = math.max(0, humanoid.WalkSpeed - SPEED_BONUS)
	end
	fireUpdate(player)
end

TotalFocusToggle.OnServerEvent:Connect(function(player: Player)
	local data = getData(player)
	if not data then return end
	local wasActive = activePlayers[player] == true

	if wasActive then
		deactivate(player)
	else
		local stamina = data.Stamina or 0
		if stamina <= 0 then return end
		activePlayers[player] = true
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed += SPEED_BONUS
		end
		drainTimers[player] = 0
		fireUpdate(player)
	end
end)

TotalFocusRebirth.OnServerEvent:Connect(function(player: Player)
	local data = getData(player)
	if not data then return end
	local xp = data.TotalFocusXP or 0
	local rebirths = data.TotalFocusRebirths or 0
	if not TotalFocusModule.canRebirth(xp, rebirths) then return end
	PlayerDataModule.setField(player, "TotalFocusXP", 0)
	PlayerDataModule.setField(player, "TotalFocusRebirths", rebirths + 1)
	fireUpdate(player)
	print("[TotalFocusServer]", player.Name, "rebirths into", TotalFocusModule.getConstantLabel(rebirths + 1))
end)

-- Stamina drain loop for V1 speed bonus (V2+ no drain); deactivates on empty stamina
RunService.Heartbeat:Connect(function(dt: number)
	for player, _ in activePlayers do
		if not activePlayers[player] then continue end
		local data = getData(player)
		if not data then continue end

		if (data.Stamina or 0) <= 0 then
			deactivate(player)
			continue
		end

		local xp = data.TotalFocusXP or 0
		local tierIdx = TotalFocusModule.getTierIndex(xp)
		local tier = TotalFocusModule.TIERS[tierIdx]
		if tier.staminaDrainPerHalfSec <= 0 then continue end

		drainTimers[player] = (drainTimers[player] or 0) + dt
		if drainTimers[player] >= STAMINA_DRAIN_INTERVAL then
			drainTimers[player] -= STAMINA_DRAIN_INTERVAL
			PlayerDataModule.drainStamina(player, tier.staminaDrainPerHalfSec)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	activePlayers[player] = nil
	drainTimers[player] = nil
end)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function()
		activePlayers[player] = false
		fireUpdate(player)
	end)
end)

print("[TotalFocusServer] Loaded")
