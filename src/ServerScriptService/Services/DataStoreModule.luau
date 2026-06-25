local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreModule = {}

local STORE_NAME = "PlayerSaveData_v1"
local AUTO_SAVE_INTERVAL = 60
local MAX_RETRIES = 3
local BASE_RETRY_DELAY = 1
local MIN_WRITE_INTERVAL = 6

local dataStore = DataStoreService:GetDataStore(STORE_NAME)
local sessionCache = {}
local dataLoaded = {}
local lastWriteTime = {}
local writeQueue = {}
local processingQueue = false

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getKey(player)
	return "Player_" .. player.UserId
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
		local _player = entry.player
		local key = entry.key
		local data = entry.data
		local playerName = entry.playerName

		local now = os.clock()
		local lastWrite = lastWriteTime[key] or 0
		local elapsed = now - lastWrite
		if elapsed < MIN_WRITE_INTERVAL then
			task.wait(MIN_WRITE_INTERVAL - elapsed)
		end

		local success = retryWithBackoff(function()
			dataStore:SetAsync(key, data)
		end, playerName)

		lastWriteTime[key] = os.clock()

		if success then
			print("[DataStoreModule] Saved data for " .. playerName)
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
		dataLoaded[player] = true
		warn("[DataStoreModule] PERMANENT load failure for " .. player.Name .. ", using defaults")

		local DataLoadError = Remotes:FindFirstChild("DataLoadError")
		if DataLoadError then
			DataLoadError:FireClient(player)
		end

		return {}, false
	end
end

function DataStoreModule.queueSave(player)
	if not dataLoaded[player] then return false end
	local data = sessionCache[player]
	if not data then return false end

	local key = getKey(player)

	for i, entry in writeQueue do
		if entry.key == key then
			writeQueue[i].data = data
			return true
		end
	end

	table.insert(writeQueue, {
		player = player,
		key = key,
		data = data,
		playerName = player.Name,
	})

	task.spawn(processWriteQueue)
	return true
end

function DataStoreModule.saveNow(player)
	if not dataLoaded[player] then return false end
	local data = sessionCache[player]
	if not data then return false end

	local key = getKey(player)
	local playerName = player.Name

	local now = os.clock()
	local lastWrite = lastWriteTime[key] or 0
	local elapsed = now - lastWrite
	if elapsed < MIN_WRITE_INTERVAL then
		task.wait(MIN_WRITE_INTERVAL - elapsed)
	end

	local success = retryWithBackoff(function()
		dataStore:SetAsync(key, data)
	end, playerName)

	lastWriteTime[key] = os.clock()

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
	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			if dataLoaded[player] then
				DataStoreModule.queueSave(player)
			end
		end
		print("[DataStoreModule] Auto-save cycle queued")
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

print("[DataStoreModule] Initialized (store: " .. STORE_NAME .. ", auto-save: " .. AUTO_SAVE_INTERVAL .. "s, queue throttle: " .. MIN_WRITE_INTERVAL .. "s)")

return DataStoreModule