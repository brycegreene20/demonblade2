local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipScrollRemote = Remotes:WaitForChild("EquipScroll")
local StyleChangedRemote = Remotes:WaitForChild("StyleChanged")
local InventoryChangedRemote = Remotes:WaitForChild("InventoryChanged")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local ItemsModule = require(Modules:WaitForChild("ItemsModule"))

local function syncInventory(player)
	local data = PlayerDataModule.getData(player)
	if not data then return end
	InventoryChangedRemote:FireClient(player, data.Inventory, data.EquippedStyle)
end

Players.PlayerAdded:Connect(function(player)
	task.delay(3, function()
		if player and player.Parent then
			syncInventory(player)
		end
	end)
end)

EquipScrollRemote.OnServerEvent:Connect(function(player, scrollId)
	if typeof(scrollId) ~= "string" then return end

	local data = PlayerDataModule.getData(player)
	if not data then return end

	local scroll = ItemsModule.getScroll(scrollId)
	if not scroll then return end

	if not ItemsModule.hasItem(data.Inventory, scrollId) then
		warn("[InventoryServer] " .. player.Name .. " tried to equip an item they do not own: " .. scrollId)
		return
	end

	local newStyle = scroll.Style
	PlayerDataModule.equipStyle(player, newStyle)

	StyleChangedRemote:FireClient(player, newStyle, scrollId)
	syncInventory(player)

	print(
		"[InventoryServer] "
		.. player.Name
		.. " equipped style item: "
		.. scrollId
		.. " (style="
		.. newStyle
		.. ", titleFaction="
		.. tostring(data.Faction)
		.. ")"
	)
end)

print("[InventoryServer] Loaded")
