local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataStoreModule = {}

local STORE_NAME = "PlayerSaveData_v1"
local AUTO_SAVE_ENABLED = true

local dataStore = DataStoreService:GetDataStore(STORE_NAME)
local sessionCache = {}
local dataLoaded = {}
local lastWriteTime = {}
local writeQueue = {}
local processingQueue = false
local writeLocks = {}
local writeRevisions = {}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local DataPersistencePolicyModule = require(Modules:WaitForChild("DataPersistencePolicyModule"))
local AUTO_SAVE_INTERVAL = DataPersistencePolicyModule.AUTO_SAVE_INTERVAL
local MAX_RETRIES = DataPersistencePolicyModule.MAX_RETRIES
local BASE_RETRY_DELAY = DataPersistencePolicyModule.BASE_RETRY_DELAY
local MIN_WRITE_INTERVAL = DataPersistencePolicyModule.MIN_WRITE_INTERVAL

local function getLatestSnapshot(player)
	local payload = PlayerDataModule.getSavePayload(player)
	if payload then
		sessionCache[player] = DataPersistencePolicyModule.copySnapshot(payload)
	end
	return sessionCache[player] and DataPersistencePolicyModule.copySnapshot(sessionCache[player]) or nil
end

local function getKey(player)
	return "Player_" .. player.UserId
end

local function nextWriteRevision(key)
	local revision = (writeRevisions[key] or 0) + 1
	writeRevisions[key] = revision
	return revision
end

local function acquireWriteLock(key)
	while writeLocks[key] do
		task.wait(0.05)
	end
	writeLocks[key] = true
end

local function releaseWriteLock(key)
	writeLocks[key] = nil
end

local function removeQueuedWrites(key)
	for index = #writeQueue, 1, -1 do
		if writeQueue[index].key == key then
			table.remove(writeQueue, index)
		end
	end
end

local function retryWithBackoff(func, playerName)
	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(func)
		if success then
			return true, result
		end
		local delay = BASE_RETRY_DELAY * (2 ^ (attempt - 1))
		warn("[DataStoreModule] Attempt " .. attempt .. "/" .. MAX_RETRIES .. " failed for " .. playerName .. ": " .. tostring(result) .. " (retry in " .. delay .. "s)")
		if attempt < MAX_RETRIES then
			task.wait(delay)
		end
	end
	return false, nil
end

local function processWriteQueue()
	if processingQueue then return end
	processingQueue = true

	while #writeQueue > 0 do
		local entry = table.remove(writeQueue, 1)
		local key = entry.key
		local data = entry.data
		local playerName = entry.playerName

		acquireWriteLock(key)
		if entry.revision ~= writeRevisions[key] then
			releaseWriteLock(key)
			continue
		end

		local now = os.clock()
		local lastWrite = lastWriteTime[key] or 0
		local elapsed = now - lastWrite
		if elapsed < MIN_WRITE_INTERVAL then
			task.wait(MIN_WRITE_INTERVAL - elapsed)
		end

		local attemptedWrite = false
		local success = false
		if entry.revision == writeRevisions[key] then
			attemptedWrite = true
			success = retryWithBackoff(function()
				dataStore:UpdateAsync(key, function()
					return data
				end)
			end, playerName)
		end

		if attemptedWrite then
			lastWriteTime[key] = os.clock()
		end
		releaseWriteLock(key)

		if success then
			print("[DataStoreModule] Saved data for " .. playerName)
		elseif entry.revision ~= writeRevisions[key] then
			print("[DataStoreModule] Skipped stale queued save for " .. playerName)
		else
			warn("[DataStoreModule] FAILED to save data for " .. playerName .. " after " .. MAX_RETRIES .. " attempts")
		end
	end

	processingQueue = false
end

function DataStoreModule.loadAsync(player)
	local key = getKey(player)

	local success, data = retryWithBackoff(function()
		return dataStore:GetAsync(key)
	end, player.Name)

	if success and data and typeof(data) == "table" then
		sessionCache[player] = data
		dataLoaded[player] = true
		print("[DataStoreModule] Loaded data for " .. player.Name)
		return data, true
	elseif success then
		sessionCache[player] = {}
		dataLoaded[player] = true
		print("[DataStoreModule] No saved data for " .. player.Name .. ", using defaults")
		return {}, true
	else
		sessionCache[player] = {}
		dataLoaded[player] = false
		warn("[DataStoreModule] PERMANENT load failure for " .. player.Name .. ", using defaults")

		local DataLoadError = Remotes:FindFirstChild("DataLoadError")
		if DataLoadError then
			DataLoadError:FireClient(player)
		end

		return {}, false
	end
end

function DataStoreModule.queueSave(player)
	if not DataPersistencePolicyModule.canWrite(dataLoaded[player]) then return false end
	local data = getLatestSnapshot(player)
	if not data then return false end

	local key = getKey(player)

	for i, entry in writeQueue do
		if entry.key == key then
			writeQueue[i].data = data
			writeQueue[i].revision = nextWriteRevision(key)
			return true
		end
	end

	table.insert(writeQueue, {
		key = key,
		data = data,
		playerName = player.Name,
		revision = nextWriteRevision(key),
	})

	task.spawn(processWriteQueue)
	return true
end

function DataStoreModule.saveNow(player)
	if not DataPersistencePolicyModule.canWrite(dataLoaded[player]) then return false end
	local data = getLatestSnapshot(player)
	if not data then return false end

	local key = getKey(player)
	local playerName = player.Name
	nextWriteRevision(key)
	removeQueuedWrites(key)
	acquireWriteLock(key)

	local now = os.clock()
	local lastWrite = lastWriteTime[key] or 0
	local elapsed = now - lastWrite
	if elapsed < MIN_WRITE_INTERVAL then
		task.wait(MIN_WRITE_INTERVAL - elapsed)
	end

	local success = retryWithBackoff(function()
		dataStore:UpdateAsync(key, function()
			return data
		end)
	end, playerName)

	lastWriteTime[key] = os.clock()
	releaseWriteLock(key)

	if success then
		print("[DataStoreModule] Saved data for " .. playerName)
	else
		warn("[DataStoreModule] FAILED to save data for " .. playerName)
	end

	return success
end

function DataStoreModule.getCache(player)
	return sessionCache[player]
end

function DataStoreModule.setCache(player, key, value)
	if not sessionCache[player] then
		sessionCache[player] = {}
	end
	sessionCache[player][key] = value
end

function DataStoreModule.isLoaded(player)
	return dataLoaded[player] == true
end

function DataStoreModule.cleanup(player)
	sessionCache[player] = nil
	dataLoaded[player] = nil
end

task.spawn(function()
	while AUTO_SAVE_ENABLED do
		task.wait(AUTO_SAVE_INTERVAL)
		local queued = 0
		for _, player in Players:GetPlayers() do
			if dataLoaded[player] and DataStoreModule.queueSave(player) then
				queued += 1
			end
		end
		if queued > 0 then
			print("[DataStoreModule] Auto-save queued fresh snapshots for " .. queued .. " player(s)")
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		if dataLoaded[player] then
			task.spawn(function()
				DataStoreModule.saveNow(player)
			end)
		end
	end
	task.wait(MIN_WRITE_INTERVAL + 2)
end)

print(
	("[DataStoreModule] Initialized (store: %s, auto-save: %ds, queue throttle: %ds, Studio: %s)"):format(
		STORE_NAME,
		AUTO_SAVE_INTERVAL,
		MIN_WRITE_INTERVAL,
		tostring(RunService:IsStudio())
	)
)
if RunService:IsStudio() then
	print("[DataStoreModule] Studio saves require Game Settings > Security > Enable Studio Access to API Services")
end

return DataStoreModule
