local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpinRaceRemote = Remotes:WaitForChild("SpinRace")
local RaceChangedRemote = Remotes:WaitForChild("RaceChanged")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local RaceModule = require(Modules:WaitForChild("RaceModule"))

local Services = ServerScriptService:WaitForChild("Services")
local DataStoreModule = require(Services:WaitForChild("DataStoreModule"))

local random = Random.new()
local regenLoops = {}

local function syncCacheFromData(player)
	local payload = PlayerDataModule.getSavePayload(player)
	if not payload then return end
	for key, value in pairs(payload) do
		DataStoreModule.setCache(player, key, value)
	end
end

local function startRegenerationLoop(player)
	if regenLoops[player] then return end
	regenLoops[player] = true
	task.spawn(function()
		while player.Parent do
			task.wait(RaceModule.REGEN_INTERVAL_SECONDS)
			local data = PlayerDataModule.getData(player)
			if not data then continue end
			local race = RaceModule.getRace(data.Race)
			if (race.HealthRegenPercent or 0) <= 0 or data.isDead then continue end

			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
				local heal = humanoid.MaxHealth * race.HealthRegenPercent
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
			end
		end
		regenLoops[player] = nil
	end)
end

SpinRaceRemote.OnServerInvoke = function(player)
	local data = PlayerDataModule.getData(player)
	if not data then
		return { Success = false, Message = "Player data is not ready" }
	end
	local consumedSpin = false
	if not RaceModule.UNLIMITED_SPINS then
		consumedSpin = PlayerDataModule.consumeRaceSpin(player)
	end
	if not RaceModule.UNLIMITED_SPINS and not consumedSpin then
		return {
			Success = false,
			Message = "No race spins remaining",
			Race = PlayerDataModule.getRaceData(player),
		}
	end

	local race = RaceModule.roll(random:NextNumber())
	if not PlayerDataModule.setRace(player, race.Id) then
		if consumedSpin then
			data.RaceSpins += 1
		end
		return { Success = false, Message = "Race roll could not be applied" }
	end

	local publicData = PlayerDataModule.getRaceData(player)
	syncCacheFromData(player)
	RaceChangedRemote:FireClient(player, publicData)
	print(
		"[RaceServer] "
			.. player.Name
			.. " rolled "
			.. race.Name
			.. " ("
			.. (publicData.UnlimitedSpins and "unlimited spins" or (tostring(publicData.Spins) .. " spins remaining"))
			.. ")"
	)
	return {
		Success = true,
		Message = "Rolled " .. race.Name,
		Race = publicData,
	}
end

Players.PlayerAdded:Connect(startRegenerationLoop)
Players.PlayerRemoving:Connect(function(player)
	regenLoops[player] = nil
end)
for _, player in Players:GetPlayers() do
	startRegenerationLoop(player)
end

print("[RaceServer] Loaded")
