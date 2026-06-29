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

local function getData(player: Player)
	return PlayerDataModule.getData(player)
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
	})
end

-- Called by CombatServer when player kills or is attacked while Selfless is active
local function grantXP(player: Player, amount: number)
	if not activePlayers[player] then return false, nil end
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
	if granted and xp and eventName == "Kill" then
		print(("[SelflessStateServer] %s gained %d kill XP (%d total)"):format(player.Name, amount, xp))
	end
end

-- selene: allow(global_usage)
shared.SelflessStateServer = {
	grantXP = grantXP,
	grantEventXP = grantEventXP,
}

local function deactivate(player: Player)
	if not activePlayers[player] then return end
	activePlayers[player] = false
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

Players.PlayerRemoving:Connect(function(player: Player)
	activePlayers[player] = nil
end)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function()
		activePlayers[player] = false
		fireUpdate(player)
	end)
end)

print("[SelflessStateServer] Loaded")
