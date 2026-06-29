--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SelflessStateModule = require(Modules:WaitForChild("SelflessStateModule"))
local PlayerDataModule    = require(Modules:WaitForChild("PlayerDataModule"))

local SelflessStateToggle  = Remotes:WaitForChild("SelflessStateToggle")
local SelflessStateChanged = Remotes:WaitForChild("SelflessStateChanged")
local DodgePointsChanged   = Remotes:WaitForChild("DodgePointsChanged")

local DODGE_REGEN_INTERVAL = 1

local activePlayers:  { [Player]: boolean } = {}
local regenTimers:    { [Player]: number  } = {}

local function getData(player: Player)
	return PlayerDataModule.getData(player)
end

local function fireDodgeUpdate(player: Player)
	local data = getData(player)
	if not data then return end
	DodgePointsChanged:FireClient(player, data.SelflessDodgePoints or 100)
end

local function fireUpdate(player: Player)
	local data = getData(player)
	if not data then return end
	local xp = data.SelflessStateXP or 0
	local tier = SelflessStateModule.getTier(xp)
	local bonus = SelflessStateModule.getBonusForTier(tier)
	SelflessStateChanged:FireClient(player, {
		xp = xp,
		tier = tier,
		bonus = bonus,
		active = activePlayers[player] == true,
		dodgePoints = data.SelflessDodgePoints or 100,
	})
end

-- Called by CombatServer when player kills or is attacked while Selfless is active
local function grantXP(player: Player, amount: number)
	if not activePlayers[player] then return end
	local data = getData(player)
	if not data then return end
	if not SelflessStateModule.canGainXP(data.SelflessStateXP or 0) then return end

	local dodgePoints = data.SelflessDodgePoints or 0
	if dodgePoints < SelflessStateModule.XP_DODGE_COST then return end

	PlayerDataModule.setField(player, "SelflessStateXP", (data.SelflessStateXP or 0) + amount)
	PlayerDataModule.setField(player, "SelflessDodgePoints", dodgePoints - SelflessStateModule.XP_DODGE_COST)
	fireUpdate(player)
	fireDodgeUpdate(player)
end

-- selene: allow(global_usage)
shared.SelflessStateServer = { grantXP = grantXP }

local function deactivate(player: Player)
	if not activePlayers[player] then return end
	activePlayers[player] = false
	regenTimers[player] = nil
	fireUpdate(player)
end

SelflessStateToggle.OnServerEvent:Connect(function(player: Player)
	local data = getData(player)
	if not data then return end
	if activePlayers[player] then
		deactivate(player)
	else
		if (data.Stamina or 0) <= 0 then return end
		activePlayers[player] = true
		fireUpdate(player)
	end
end)

-- Dodge point regen loop; deactivates on empty stamina
RunService.Heartbeat:Connect(function(dt: number)
	for player, _ in activePlayers do
		local data = getData(player)
		if not data then continue end

		if (data.Stamina or 0) <= 0 then
			deactivate(player)
			continue
		end
		local pts = data.SelflessDodgePoints or 0
		if pts >= SelflessStateModule.MAX_DODGE_POINTS then continue end

		regenTimers[player] = (regenTimers[player] or 0) + dt
		if regenTimers[player] >= DODGE_REGEN_INTERVAL then
			regenTimers[player] -= DODGE_REGEN_INTERVAL
			local newPts = math.min(pts + SelflessStateModule.DODGE_REGEN_RATE, SelflessStateModule.MAX_DODGE_POINTS)
			PlayerDataModule.setField(player, "SelflessDodgePoints", newPts)
			fireDodgeUpdate(player)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	activePlayers[player] = nil
	regenTimers[player] = nil
end)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function()
		activePlayers[player] = false
		fireUpdate(player)
	end)
end)

print("[SelflessStateServer] Loaded")
