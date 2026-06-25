local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LungeRemote = Remotes:WaitForChild("Lunge")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))

local Services = ServerScriptService:WaitForChild("Services")
local DataStoreModule = require(Services:WaitForChild("DataStoreModule"))

local AllocateStatRemote = Remotes:WaitForChild("AllocateStat")
local ChooseFactionRemote = Remotes:WaitForChild("ChooseFaction")
local FactionChosenRemote = Remotes:WaitForChild("FactionChosen")
local GetPlayerDataRemote = Remotes:WaitForChild("GetPlayerData")
local ShowFactionSelectRemote = Remotes:WaitForChild("ShowFactionSelect")
local RespecStatsRemote = Remotes:WaitForChild("RespecStats")
local RespecResultRemote = Remotes:WaitForChild("RespecResult")
local ResetFactionRemote = Remotes:WaitForChild("ResetFaction")

local LUNGE_STAMINA_COST = 15
local LUNGE_POWER = 110
local AERIAL_POWER_MULT = 1.1
local LUNGE_FORCE_DURATION = 0.18
local IFRAME_DURATION = 0.2
local LUNGE_RATE_LIMIT = 0.85

local lungeCooldowns = {}
local iframeActive = {}

local function syncCacheFromData(player)
	local payload = PlayerDataModule.getSavePayload(player)
	if not payload then return end
	for key, value in pairs(payload) do
		DataStoreModule.setCache(player, key, value)
	end
end

Players.PlayerAdded:Connect(function(player)
	local savedData, _loadSuccess = DataStoreModule.loadAsync(player)
	local dataApplied = false

	local function applyLoadedData(_p)
		if dataApplied then return end
		if not savedData or not next(savedData) then return end
		dataApplied = true

		PlayerDataModule.loadSavePayload(player, savedData)
		savedData = nil

		local data = PlayerDataModule.getData(player)
		if data then
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					data._syncingHealth = true
					humanoid.MaxHealth = data.MaxHP
					humanoid.Health = data.MaxHP
					data._syncingHealth = false
					humanoid.WalkSpeed = data.WalkSpeed
				end
			end

			local StatsChanged = Remotes:FindFirstChild("StatsChanged")
			if StatsChanged then
				StatsChanged:FireClient(player, data.Level, data.XP, PlayerDataModule.xpForLevel(data.Level), data.TotalXP)
			end

			local HPChanged = Remotes:FindFirstChild("HPChanged")
			if HPChanged then
				HPChanged:FireClient(player, data.HP, data.MaxHP)
			end
			local StaminaChanged = Remotes:FindFirstChild("StaminaChanged")
			if StaminaChanged then
				StaminaChanged:FireClient(player, data.Stamina, data.MaxStamina)
			end

			PlayerDataModule.sendStatPointsUpdate(player)
		end
	end

	player.CharacterAdded:Connect(function()
		PlayerDataModule.onCharacterAdded(player)
		applyLoadedData(player)
		lungeCooldowns[player] = 0
		iframeActive[player] = false
	end)

	if player.Character then
		PlayerDataModule.onCharacterAdded(player)
	end

	applyLoadedData(player)

	local data = PlayerDataModule.getData(player)
	if data and PlayerDataModule.needsTitleSelection(player) then
		task.spawn(function()
			if not player.Parent then return end
			local char = player.Character or player.CharacterAdded:Wait()
			if not player.Parent then return end
			local hum = char:WaitForChild("Humanoid", 10)
			if not hum then return end

			hum.WalkSpeed = 0
			hum.JumpPower = 0
			print("[MovementServer] Faction not set for " .. player.Name .. " — character frozen, showing faction prompt")
			task.wait(2)
			if not player.Parent then return end
			if PlayerDataModule.needsTitleSelection(player) then
				ShowFactionSelectRemote:FireClient(player)
				print("[MovementServer] Sent ShowFactionSelect to " .. player.Name)
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	syncCacheFromData(player)
	DataStoreModule.saveNow(player)
	DataStoreModule.cleanup(player)
	PlayerDataModule.cleanupPlayer(player)
	lungeCooldowns[player] = nil
	iframeActive[player] = nil
end)

local function setIFrames(character, enabled)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = not enabled
		end
	end
	-- PlatformStand prevents the Humanoid's auto-balance physics from tripping
	-- the character when passing through enemy bodies at high speed.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = enabled
	end
	local forceField = character:FindFirstChildOfClass("ForceField")
	if enabled and not forceField then
		local ff = Instance.new("ForceField")
		ff.Visible = false
		ff.Name = "LungeIFrame"
		ff.Parent = character
	elseif not enabled and forceField and forceField.Name == "LungeIFrame" then
		forceField:Destroy()
	end
end

LungeRemote.OnServerEvent:Connect(function(player, moveDirection, isAerial)
	local now = os.clock()
	local lastLunge = lungeCooldowns[player] or 0
	if now - lastLunge < LUNGE_RATE_LIMIT then return end

	local data = PlayerDataModule.getData(player)
	if not data then return end

	if not PlayerDataModule.consumeStamina(player, LUNGE_STAMINA_COST) then return end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	lungeCooldowns[player] = now
	iframeActive[player] = true

	local dir
	if typeof(moveDirection) == "Vector3" and moveDirection.Magnitude > 0 then
		dir = moveDirection.Unit
	else
		dir = hrp.CFrame.LookVector
	end

	local power = LUNGE_POWER
	if isAerial == true then
		power = LUNGE_POWER * AERIAL_POWER_MULT
	end

	setIFrames(character, true)

	local attachment = hrp:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = hrp
	end

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.MaxForce = math.huge
	linearVelocity.VectorVelocity = dir * power
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Parent = hrp

	task.delay(LUNGE_FORCE_DURATION, function()
		if linearVelocity and linearVelocity.Parent then
			linearVelocity:Destroy()
		end
	end)

	task.delay(IFRAME_DURATION, function()
		if character and character.Parent then
			setIFrames(character, false)
		end
		iframeActive[player] = false
	end)
end)

AllocateStatRemote.OnServerEvent:Connect(function(player, statName)
	if typeof(statName) ~= "string" then return end
	local success, _err = PlayerDataModule.allocateStat(player, statName)
	if success then
		syncCacheFromData(player)
		print("[MovementServer] " .. player.Name .. " allocated point to " .. statName)
	end
end)

ChooseFactionRemote.OnServerEvent:Connect(function(player, faction)
	if typeof(faction) ~= "string" then return end
	local success, err = PlayerDataModule.setFaction(player, faction)
	if success then
		syncCacheFromData(player)
		FactionChosenRemote:FireClient(player, faction)

		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = PlayerDataModule.getEffectiveWalkSpeed(player)
				hum.JumpPower = 50
				print("[MovementServer] " .. player.Name .. " chose " .. faction .. " — character unfrozen")
			end
		end
	else
		warn("[MovementServer] Faction selection failed for " .. player.Name .. ": " .. (err or "unknown"))
	end
end)

GetPlayerDataRemote.OnServerInvoke = function(player)
	local data = PlayerDataModule.getData(player)
	if not data then return {} end
	local needsTitleSelection = PlayerDataModule.needsTitleSelection(player)
	local StatConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("StatConfig"))
	local result = {
		Level = data.Level,
		XP = data.XP,
		Faction = data.Faction,
		StatPoints = data.StatPoints,
		EquippedStyle = data.EquippedStyle or "",
		EquippedTitle = data.EquippedTitle or "",
		NeedsTitleSelection = needsTitleSelection,
		Titles = data.Titles or {},
		Inventory = data.Inventory or {},
		Mastery = data.Mastery or {},
	}
	for _, key in ipairs(StatConfig.STAT_KEYS) do
		result[key] = data[key] or 0
	end
	print(
		"[MovementServer:GetPlayerData] "
			.. player.Name
			.. " title=" .. tostring(result.EquippedTitle)
			.. " faction=" .. tostring(result.Faction)
			.. " style=" .. tostring(result.EquippedStyle)
			.. " needsTitleSelection=" .. tostring(result.NeedsTitleSelection)
			.. " inventoryCount=" .. tostring(#result.Inventory)
	)
	return result
end

RespecStatsRemote.OnServerEvent:Connect(function(player)
	local success, msg, cooldownEnd = PlayerDataModule.respecStats(player)
	if success then
		syncCacheFromData(player)
		print("[MovementServer] " .. player.Name .. " respecced stats")
	end
	RespecResultRemote:FireClient(player, success, msg, cooldownEnd)
end)

ResetFactionRemote.OnServerEvent:Connect(function(player)
	local success, err = PlayerDataModule.resetFaction(player)
	if not success then
		warn("[MovementServer] Faction reset failed for " .. player.Name .. ": " .. (err or "unknown"))
		return
	end

	syncCacheFromData(player)

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		end
	end

	ShowFactionSelectRemote:FireClient(player)
	print("[MovementServer] " .. player.Name .. " faction reset — showing faction prompt")
end)

print("[MovementServer] Loaded - Lunge System")
