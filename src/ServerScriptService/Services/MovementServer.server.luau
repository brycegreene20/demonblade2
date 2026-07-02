local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LungeRemote = Remotes:WaitForChild("Lunge")

local JumpStaminaRemote = Remotes:FindFirstChild("JumpStamina")
if not JumpStaminaRemote then
	JumpStaminaRemote = Instance.new("RemoteEvent")
	JumpStaminaRemote.Name = "JumpStamina"
	JumpStaminaRemote.Parent = Remotes
end

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local MovementPhysicsModule = require(Modules:WaitForChild("MovementPhysicsModule"))

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
local GROUND_JUMP_STAMINA_COST = 10
local AIR_JUMP_STAMINA_COST = 15
local JUMP_STAMINA_RATE_LIMIT = 0.2
local LUNGE_POWER = 110
local AERIAL_POWER_MULT = 1.1
local LUNGE_FORCE_DURATION = 0.18
local IFRAME_DURATION = 0.2
local LUNGE_RATE_LIMIT = 0.85
local LUNGE_MAX_FORCE = 22000
local LUNGE_COLLISION_BUFFER = 4
local LUNGE_WALL_STOP_OFFSET = 3
local LUNGE_SWEEP_SIDE_OFFSET = 1.25
local LUNGE_SWEEP_UP_OFFSET = 1.4
local LUNGE_SWEEP_DOWN_OFFSET = 1.2

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
	-- Register CharacterAdded BEFORE blocking on loadAsync so we never miss the event
	local savedData = nil
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
					humanoid.WalkSpeed = PlayerDataModule.getEffectiveWalkSpeed(player)
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

	-- Load data after handlers are connected so CharacterAdded is never missed
	local loadedSuccessfully
	savedData, loadedSuccessfully = DataStoreModule.loadAsync(player)
	player:SetAttribute("DataPersistenceAvailable", loadedSuccessfully == true)

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
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid.AutoRotate = true
		if not enabled and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			task.defer(function()
				if humanoid and humanoid.Parent and humanoid.Health > 0 then
					humanoid:ChangeState(Enum.HumanoidStateType.Running)
				end
			end)
		end
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

local function getLungeSweepOffsets(direction, hrp)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local right = flat.Magnitude > 0.01 and flat.Unit:Cross(Vector3.yAxis).Unit or hrp.CFrame.RightVector
	return {
		Vector3.zero,
		Vector3.new(0, LUNGE_SWEEP_UP_OFFSET, 0),
		Vector3.new(0, -LUNGE_SWEEP_DOWN_OFFSET, 0),
		right * LUNGE_SWEEP_SIDE_OFFSET,
		-right * LUNGE_SWEEP_SIDE_OFFSET,
	}
end

local function getBlockingLungeHit(previousPosition, direction, power, deltaTime, hrp, raycastParams)
	local frameTravel = math.max((hrp.Position - previousPosition).Magnitude, power * deltaTime)
	local castVector = direction * math.max(2, frameTravel + LUNGE_COLLISION_BUFFER)
	for _, offset in getLungeSweepOffsets(direction, hrp) do
		local result = workspace:Raycast(previousPosition + offset, castVector, raycastParams)
		if result then
			return result
		end
	end
	return nil
end

local function moveRootPreservingFacing(hrp, position)
	local look = hrp.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then
		flatLook = Vector3.new(0, 0, -1)
	end
	hrp.CFrame = CFrame.lookAt(position, position + flatLook.Unit)
end

local function sanitizeLungeDirection(moveDirection, isAerial, hrp)
	local fallback = hrp.CFrame.LookVector
	if typeof(moveDirection) ~= "Vector3" or moveDirection.Magnitude <= 0.01 then
		moveDirection = fallback
	end

	local x = moveDirection.X
	local y = if isAerial == true then math.clamp(moveDirection.Y, -0.15, 0.25) else 0
	local z = moveDirection.Z
	local sanitized = Vector3.new(x, y, z)

	if sanitized.Magnitude <= 0.01 then
		sanitized = Vector3.new(fallback.X, 0, fallback.Z)
	end

	if sanitized.Magnitude <= 0.01 then
		warn("[MovementServer] Invalid lunge direction; falling back to world forward")
		return Vector3.new(0, 0, -1)
	end

	return sanitized.Unit
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

	local dir = sanitizeLungeDirection(moveDirection, isAerial, hrp)

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
	linearVelocity.MaxForce = LUNGE_MAX_FORCE
	linearVelocity.VectorVelocity = dir * power
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Parent = hrp

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true
	raycastParams.RespectCanCollide = true

	local previousPosition = hrp.Position
	local cleanedUp = false
	local sweepConnection
	local function stopLunge(blockingHit)
		if cleanedUp then return end
		cleanedUp = true
		if sweepConnection then
			sweepConnection:Disconnect()
			sweepConnection = nil
		end
		if linearVelocity.Parent then
			linearVelocity:Destroy()
		end
		if blockingHit and hrp.Parent then
			local safeDistance = MovementPhysicsModule.getDashStopDistance(
				blockingHit.Distance,
				LUNGE_WALL_STOP_OFFSET
			)
			local stopPosition = previousPosition + dir * safeDistance
			moveRootPreservingFacing(hrp, stopPosition)
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			print("[MovementServer] Blocked dash into " .. blockingHit.Instance:GetFullName() .. " for " .. player.Name)
		end
	end

	sweepConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not hrp.Parent then
			stopLunge(nil)
			return
		end
		local blockingHit = getBlockingLungeHit(previousPosition, dir, power, deltaTime, hrp, raycastParams)
		if blockingHit then
			stopLunge(blockingHit)
			return
		end
		hrp.AssemblyAngularVelocity = Vector3.zero
		previousPosition = hrp.Position
	end)

	task.delay(LUNGE_FORCE_DURATION, function()
		stopLunge(nil)
	end)

	task.delay(IFRAME_DURATION, function()
		if character and character.Parent then
			setIFrames(character, false)
		end
		iframeActive[player] = false
	end)

	task.delay(IFRAME_DURATION + 0.45, function()
		if not character or not character.Parent then return end
		local recoveryHumanoid = character:FindFirstChildOfClass("Humanoid")
		if not recoveryHumanoid or recoveryHumanoid.Health <= 0 then return end
		if recoveryHumanoid.PlatformStand or recoveryHumanoid.Sit then
			warn("[MovementServer] Recovered stuck humanoid after lunge for " .. player.Name)
			recoveryHumanoid.PlatformStand = false
			recoveryHumanoid.Sit = false
			recoveryHumanoid.AutoRotate = true
			recoveryHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end)

AllocateStatRemote.OnServerEvent:Connect(function(player, statName, requestedAmount)
	if typeof(statName) ~= "string" then return end
	local success, _err, allocatedAmount = PlayerDataModule.allocateStat(player, statName, requestedAmount)
	if success then
		syncCacheFromData(player)
		print(
			("[MovementServer] %s allocated %d points to %s"):format(
				player.Name,
				allocatedAmount,
				statName
			)
		)
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
		TechniqueFaction = PlayerDataModule.getTechniqueFactionFromData(data),
		StatPoints = data.StatPoints,
		EquippedStyle = data.EquippedStyle or "",
		EquippedTitle = data.EquippedTitle or "",
		NeedsTitleSelection = needsTitleSelection,
		Titles = data.Titles or {},
		Inventory = data.Inventory or {},
		Mastery = data.Mastery or {},
		Race = data.Race or "Human",
		RaceSpins = data.RaceSpins or 0,
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

local jumpStaminaTimers = {}

JumpStaminaRemote.OnServerEvent:Connect(function(player, isAirJump)
	local now = os.clock()
	local last = jumpStaminaTimers[player] or 0
	if now - last < JUMP_STAMINA_RATE_LIMIT then return end
	jumpStaminaTimers[player] = now

	local cost = if isAirJump == true then AIR_JUMP_STAMINA_COST else GROUND_JUMP_STAMINA_COST
	PlayerDataModule.consumeStamina(player, cost)
end)

Players.PlayerRemoving:Connect(function(player)
	jumpStaminaTimers[player] = nil
end)

print("[MovementServer] Loaded - Lunge System")
