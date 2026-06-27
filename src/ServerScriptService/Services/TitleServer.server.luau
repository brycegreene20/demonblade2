local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipTitleRemote = Remotes:WaitForChild("EquipTitle")
local TitleRebirthRemote = Remotes:WaitForChild("TitleRebirth")
local MasteryRebirthRemote = Remotes:WaitForChild("MasteryRebirth")
local FactionChosenRemote = Remotes:WaitForChild("FactionChosen")
local StyleChangedRemote = Remotes:WaitForChild("StyleChanged")
local InventoryChangedRemote = Remotes:WaitForChild("InventoryChanged")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local TitleModule = require(Modules:WaitForChild("TitleModule"))

local Services = ServerScriptService:WaitForChild("Services")
local DataStoreModule = require(Services:WaitForChild("DataStoreModule"))

local function syncCacheFromData(player)
	local payload = PlayerDataModule.getSavePayload(player)
	if not payload then return end
	for key, value in pairs(payload) do
		DataStoreModule.setCache(player, key, value)
	end
end

-- Equip or unequip a title
EquipTitleRemote.OnServerEvent:Connect(function(player, titleId, unequip)
	print("[TitleServer] EquipTitle request from " .. player.Name .. ": title=" .. tostring(titleId) .. ", unequip=" .. tostring(unequip))
	if unequip then
		PlayerDataModule.unequipTitle(player)
		FactionChosenRemote:FireClient(player, "")
		syncCacheFromData(player)
		print("[TitleServer] " .. player.Name .. " unequipped title")
		return
	end

	if typeof(titleId) ~= "string" then return end
	if not TitleModule.getTitle(titleId) then
		warn("[TitleServer] Unknown title request from " .. player.Name .. ": " .. titleId)
		return
	end

	local success = PlayerDataModule.equipTitle(player, titleId)
	if not success then
		warn("[TitleServer] equipTitle failed for " .. player.Name .. ": " .. titleId)
		return
	end

	local data = PlayerDataModule.getData(player)
	if not data then return end

	-- Unfreeze character (mirrors what old faction selection did)
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = PlayerDataModule.getEffectiveWalkSpeed(player)
			hum.JumpPower = 50
		end
	end

	FactionChosenRemote:FireClient(player, data.Faction)
	StyleChangedRemote:FireClient(player, data.EquippedStyle, nil)
	InventoryChangedRemote:FireClient(player, data.Inventory, data.EquippedStyle)

	syncCacheFromData(player)
	print("[TitleServer] " .. player.Name .. " equipped title=" .. titleId .. ", faction=" .. tostring(data.Faction) .. ", style=" .. tostring(data.EquippedStyle))
end)

-- Rebirth a title (must be at MaxLevel)
TitleRebirthRemote.OnServerEvent:Connect(function(player, titleId)
	if typeof(titleId) ~= "string" then return end

	local success, msg = PlayerDataModule.rebirthTitle(player, titleId)
	if not success then
		warn("[TitleServer] Rebirth failed for " .. player.Name .. " (" .. titleId .. "): " .. (msg or "?"))
		return
	end

	syncCacheFromData(player)
	print("[TitleServer] " .. player.Name .. " rebirthd title: " .. titleId)
end)

MasteryRebirthRemote.OnServerEvent:Connect(function(player, styleId)
	if typeof(styleId) ~= "string" then return end
	local success, msg = PlayerDataModule.rebirthMastery(player, styleId)
	if not success then
		warn("[TitleServer] Mastery rebirth failed for " .. player.Name .. " (" .. styleId .. "): " .. (msg or "?"))
		return
	end
	syncCacheFromData(player)
	print("[TitleServer] " .. player.Name .. " advanced mastery tier for " .. styleId)
end)

Players.PlayerRemoving:Connect(function(_player)
	-- cleanup handled in MovementServer
end)

print("[TitleServer] Loaded")
