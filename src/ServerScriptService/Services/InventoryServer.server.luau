local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipScrollRemote = Remotes:WaitForChild("EquipScroll")
local StyleChangedRemote = Remotes:WaitForChild("StyleChanged")
local InventoryChangedRemote = Remotes:WaitForChild("InventoryChanged")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local ItemsModule = require(Modules:WaitForChild("ItemsModule"))

-- Send full inventory to a client (called on load and when inventory changes)
local function syncInventory(player)
	local data = PlayerDataModule.getData(player)
	if not data then return end
	InventoryChangedRemote:FireClient(player, data.Inventory, data.EquippedStyle)
end

-- When player joins (after data is loaded), the main GameServer/DataLoader fires this.
-- We hook PlayerAdded to send initial sync after a short delay for data to be ready.
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

	-- Verify player owns this item
	if not ItemsModule.hasItem(data.Inventory, scrollId) then
		warn("[InventoryServer] " .. player.Name .. " tried to equip scroll they don't own: " .. scrollId)
		return
	end

	-- Equip the scroll — replaces any currently equipped style
	local newStyle = scroll.Style
	data.EquippedStyle = newStyle

	StyleChangedRemote:FireClient(player, newStyle, scrollId)
	syncInventory(player)

	print("[InventoryServer] " .. player.Name .. " equipped scroll: " .. scrollId .. " (style: " .. newStyle .. ")")
end)

print("[InventoryServer] Loaded")
