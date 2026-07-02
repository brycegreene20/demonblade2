local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CompanionAction = Remotes:WaitForChild("CompanionAction")
local CompanionUpdate = Remotes:WaitForChild("CompanionUpdate")
local GetCompanionData = Remotes:WaitForChild("GetCompanionData")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CompanionModule = require(Modules:WaitForChild("CompanionModule"))
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local DataStoreModule = require(ServerScriptService:WaitForChild("Services"):WaitForChild("DataStoreModule"))

local random = Random.new()
local lastActionAt = {}
local ACTION_COOLDOWN = 0.2

local function syncCache(player)
	local payload = PlayerDataModule.getSavePayload(player)
	if not payload then return end
	DataStoreModule.setCache(player, "Companions", payload.Companions)
	DataStoreModule.setCache(player, "EquippedCompanionId", payload.EquippedCompanionId)
end

local function updateEquippedAttributes(player)
	local data = PlayerDataModule.getData(player)
	local equipped = data and CompanionModule.getEquippedCompanion(data)
	player:SetAttribute("EquippedCompanionId", equipped and equipped.Id or "")
	player:SetAttribute("EquippedCompanionSpecies", equipped and equipped.SpeciesId or "")
	player:SetAttribute("EquippedCompanionTier", equipped and equipped.Tier or 0)
end

local function getPublicData(player)
	local data = PlayerDataModule.getData(player)
	if not data then
		return {
			Companions = {},
			EquippedCompanionId = "",
			CanGrantPrototype = RunService:IsStudio(),
			Catalog = CompanionModule.CATALOG,
		}
	end
	PlayerDataModule.getCompanions(player)
	return CompanionModule.getPublicData(data, RunService:IsStudio())
end

local function publish(player, message)
	updateEquippedAttributes(player)
	syncCache(player)
	local publicData = getPublicData(player)
	CompanionUpdate:FireClient(player, publicData, message)
	return publicData
end

local function result(player, success, message)
	return {
		Success = success,
		Message = message,
		Data = getPublicData(player),
	}
end

local function actionAllowed(player)
	local now = os.clock()
	if now - (lastActionAt[player] or 0) < ACTION_COOLDOWN then
		return false
	end
	lastActionAt[player] = now
	return true
end

GetCompanionData.OnServerInvoke = function(player)
	return getPublicData(player)
end

CompanionAction.OnServerInvoke = function(player, payload)
	if not actionAllowed(player) then
		return result(player, false, "Please wait a moment")
	end
	if typeof(payload) ~= "table" or typeof(payload.Action) ~= "string" then
		return result(player, false, "Invalid companion action")
	end

	local action = payload.Action
	if action == "Equip" then
		local companionId = payload.CompanionId
		if typeof(companionId) ~= "string" then
			return result(player, false, "Invalid companion")
		end
		local success, reason = PlayerDataModule.equipCompanion(player, companionId)
		if not success then return result(player, false, reason) end
		local data = publish(player, companionId == "" and "Companion unequipped" or "Companion equipped")
		print("[CompanionService] " .. player.Name .. " equipped companion " .. companionId)
		return { Success = true, Message = "Companion equipped", Data = data }
	elseif action == "Fuse" then
		if typeof(payload.PrimaryId) ~= "string" or typeof(payload.MaterialId) ~= "string" then
			return result(player, false, "Choose two companions to fuse")
		end
		local success, fusedOrReason = PlayerDataModule.fuseCompanions(
			player,
			payload.PrimaryId,
			payload.MaterialId,
			random
		)
		if not success then return result(player, false, fusedOrReason) end
		local data = publish(player, "Fusion complete: tier " .. tostring(fusedOrReason.Tier))
		print(
			("[CompanionService] %s fused %s with %s to tier %d"):format(
				player.Name,
				payload.PrimaryId,
				payload.MaterialId,
				fusedOrReason.Tier
			)
		)
		return { Success = true, Message = "Fusion complete", Data = data }
	elseif action == "DevGrant" then
		if not RunService:IsStudio() then
			warn("[CompanionService] Rejected prototype grant outside Studio from " .. player.Name)
			return result(player, false, "Prototype grants are Studio-only")
		end
		local speciesId = typeof(payload.SpeciesId) == "string" and payload.SpeciesId
			or CompanionModule.STARTING_SPECIES
		local companion = CompanionModule.createCompanion(speciesId, HttpService:GenerateGUID(false), random)
		if not companion or not PlayerDataModule.addCompanion(player, companion) then
			return result(player, false, "Companion could not be granted")
		end
		local data = publish(player, "Prototype companion added")
		print("[CompanionService] Granted Studio prototype " .. speciesId .. " to " .. player.Name)
		return { Success = true, Message = "Prototype companion added", Data = data }
	end

	return result(player, false, "Unknown companion action")
end

local function initializePlayer(player)
	task.spawn(function()
		for _ = 1, 30 do
			if not player.Parent then return end
			if PlayerDataModule.getData(player) then
				PlayerDataModule.getCompanions(player)
				publish(player, nil)
				return
			end
			task.wait(0.25)
		end
		warn("[CompanionService] Player data was not ready for " .. player.Name)
	end)
end

Players.PlayerAdded:Connect(initializePlayer)
Players.PlayerRemoving:Connect(function(player)
	lastActionAt[player] = nil
end)
for _, player in Players:GetPlayers() do
	initializePlayer(player)
end

print("[CompanionService] Loaded")
