local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local DemonTemplate = Assets:WaitForChild("ForestDemon")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local CombatModule = require(Modules:WaitForChild("CombatModule"))
local WorldSpawnConfigModule = require(Modules:WaitForChild("WorldSpawnConfigModule"))
local EnemyProgressionModule = require(Modules:WaitForChild("EnemyProgressionModule"))

local AGGRO_RADIUS = 85
local ATTACK_RADIUS = 8
local ATTACK_MOVE_STOP_RADIUS = 4.5
local ATTACK_ENGAGE_RADIUS = 6.5
local ATTACK_COOLDOWN = 1.5
local ATTACK_WINDUP = CombatModule.NPC_ATTACK_WINDUP
local BOSS_SPECIAL_COOLDOWN = 7
local BOSS_SPECIAL_RADIUS = 20
local RESPAWN_TIME = 15
local AI_TICK = 0.5
local MOVE_SPEED = 14
local LEASH_DISTANCE = 90
local MIN_DEMON_SEPARATION = 4.5
local DEMON_HALF_HEIGHT = 3
local FALLBACK_Y = 0.5
local DEBUG_DEMON_SPAWNS = false
local DEBUG_DEMON_REWARDS = false

local function debugSpawnLog(message)
	if DEBUG_DEMON_SPAWNS then
		print("[DemonSpawner] " .. message)
	end
end

local function debugRewardLog(message)
	if DEBUG_DEMON_REWARDS then
		print("[DemonSpawner] " .. message)
	end
end

local RAW_SPAWNS = WorldSpawnConfigModule.getDemonSpawns()

local SPAWN_POSITIONS = {}
for _, raw in RAW_SPAWNS do
	local exclusionZone = WorldSpawnConfigModule.getDemonExclusionZone(raw.x, raw.z)
	if exclusionZone then
		warn(("[DemonSpawner] Skipped configured spawn in protected zone '%s'"):format(exclusionZone.name))
	else
		table.insert(SPAWN_POSITIONS, {
			pos = CFrame.new(raw.x, FALLBACK_Y + DEMON_HALF_HEIGHT, raw.z),
			level = raw.level,
			boss = raw.boss == true,
			x = raw.x,
			z = raw.z,
			zone = raw.zone,
		})
	end
end

local BAR_WIDTH = 4
local BAR_HEIGHT = 0.4
local HP_COLOR_FULL = Color3.fromRGB(200, 50, 50)
local HP_COLOR_MID = Color3.fromRGB(240, 120, 40)
local HP_COLOR_LOW = Color3.fromRGB(180, 30, 30)
local HP_BG_COLOR = Color3.fromRGB(40, 40, 40)

local demonsFolder = Instance.new("Folder")
demonsFolder.Name = "ForestDemons"
demonsFolder.Parent = workspace

local activeDemons = {}

local SPAWN_SEARCH_OFFSETS = {
	Vector2.new(0, 0),
	Vector2.new(8, 0),
	Vector2.new(-8, 0),
	Vector2.new(0, 8),
	Vector2.new(0, -8),
	Vector2.new(10, 10),
	Vector2.new(-10, 10),
	Vector2.new(10, -10),
	Vector2.new(-10, -10),
}

local function getGroundResult(x, z)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { demonsFolder }
	local dummiesFolder = workspace:FindFirstChild("TrainingDummies")
	local markersFolder = workspace:FindFirstChild("DemonBlade2Markers")
	if dummiesFolder then
		table.insert(excluded, dummiesFolder)
	end
	if markersFolder then
		table.insert(excluded, markersFolder)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	raycastParams.FilterDescendantsInstances = excluded
	raycastParams.IgnoreWater = true
	raycastParams.RespectCanCollide = true
	return workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), raycastParams)
end

local function hasSpawnClearance(cframe)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { demonsFolder }
	local dummiesFolder = workspace:FindFirstChild("TrainingDummies")
	local markersFolder = workspace:FindFirstChild("DemonBlade2Markers")
	if dummiesFolder then
		table.insert(excluded, dummiesFolder)
	end
	if markersFolder then
		table.insert(excluded, markersFolder)
	end
	overlapParams.FilterDescendantsInstances = excluded

	local parts = workspace:GetPartBoundsInBox(
		cframe * CFrame.new(0, 0.5, 0),
		Vector3.new(6, 5, 6),
		overlapParams
	)
	for _, part in parts do
		if part.CanCollide then
			return false
		end
	end
	return true
end

local function resolveSpawnCFrame(spawnData)
	local firstGroundCFrame = nil
	for _, offset in SPAWN_SEARCH_OFFSETS do
		local x = spawnData.x + offset.X
		local z = spawnData.z + offset.Y
		local result = getGroundResult(x, z)
		if result and result.Normal.Y >= 0.65 then
			local cframe = CFrame.new(result.Position + Vector3.new(0, DEMON_HALF_HEIGHT, 0))
			firstGroundCFrame = firstGroundCFrame or cframe
			if hasSpawnClearance(cframe) then
				return cframe
			end
		end
	end

	if firstGroundCFrame then
		warn(("[DemonSpawner] Ground found for %s but clearance was blocked; using grounded fallback"):format(
			spawnData.zone or "unknown zone"
		))
		return firstGroundCFrame
	end

	warn(("[DemonSpawner] No clear ground found for %s; using configured fallback"):format(
		spawnData.zone or "unknown zone"
	))
	return spawnData.pos
end

local function getMovementRaycastParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { demonsFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	params.FilterDescendantsInstances = excluded
	params.IgnoreWater = true
	params.RespectCanCollide = true
	return params
end

local function getGroundedMovementPosition(position)
	local result = workspace:Raycast(
		position + Vector3.new(0, 18, 0),
		Vector3.new(0, -45, 0),
		getMovementRaycastParams()
	)
	if not result or result.Normal.Y < 0.65 then
		return nil
	end
	return Vector3.new(position.X, result.Position.Y + DEMON_HALF_HEIGHT, position.Z)
end

local function isMovementPathClear(currentPosition, desiredPosition)
	local offset = desiredPosition - currentPosition
	if offset.Magnitude < 0.05 then return true end
	return workspace:Raycast(currentPosition, offset, getMovementRaycastParams()) == nil
end

local function _getNavigablePosition(currentPosition, desiredPosition)
	local flatOffset = Vector3.new(
		desiredPosition.X - currentPosition.X,
		0,
		desiredPosition.Z - currentPosition.Z
	)
	if flatOffset.Magnitude < 0.05 then
		return currentPosition
	end

	local stepDistance = flatOffset.Magnitude
	local forward = flatOffset.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local candidates = {
		currentPosition + forward * stepDistance,
		currentPosition + (forward + right).Unit * stepDistance,
		currentPosition + (forward - right).Unit * stepDistance,
	}

	for _, candidate in candidates do
		local grounded = getGroundedMovementPosition(candidate)
		if grounded and isMovementPathClear(currentPosition, grounded) then
			return grounded
		end
	end
	return currentPosition
end

local function getStatsForLevel(level, isBoss)
	return EnemyProgressionModule.getCombatStats(level, isBoss, 1)
end

local function getHPColor(ratio)
	if ratio > 0.5 then
		return HP_COLOR_MID:Lerp(HP_COLOR_FULL, (ratio - 0.5) / 0.5)
	else
		return HP_COLOR_LOW:Lerp(HP_COLOR_MID, ratio / 0.5)
	end
end

local function createHPBar(parent, name, level)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HPBarGui"
	billboard.Size = UDim2.fromScale(BAR_WIDTH, BAR_HEIGHT)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 300
	billboard.LightInfluence = 0
	billboard.Parent = parent

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = HP_BG_COLOR
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0.3, 0)
	bgCorner.Parent = bg

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(20, 20, 20)
	bgStroke.Thickness = 1.5
	bgStroke.Transparency = 0.3
	bgStroke.Parent = bg

	local damageFill = Instance.new("Frame")
	damageFill.Name = "DamageFill"
	damageFill.Size = UDim2.fromScale(1, 1)
	damageFill.BackgroundColor3 = Color3.fromRGB(255, 160, 60)
	damageFill.BorderSizePixel = 0
	damageFill.ZIndex = 2
	damageFill.Parent = bg

	local damageFillCorner = Instance.new("UICorner")
	damageFillCorner.CornerRadius = UDim.new(0.3, 0)
	damageFillCorner.Parent = damageFill

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = HP_COLOR_FULL
	fill.BorderSizePixel = 0
	fill.ZIndex = 3
	fill.Parent = bg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.3, 0)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Name = "HPText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.4
	label.ZIndex = 4
	label.Parent = bg

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 0.8)
	nameLabel.Position = UDim2.fromScale(0, -1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = name
	nameLabel.ZIndex = 4
	nameLabel.Parent = bg

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.fromScale(0.7, 0.7)
	levelLabel.Position = UDim2.fromScale(0.15, -1.75)
	levelLabel.BackgroundColor3 = Color3.fromRGB(72, 22, 22)
	levelLabel.BackgroundTransparency = 0.12
	levelLabel.BorderSizePixel = 0
	levelLabel.Font = Enum.Font.GothamBlack
	levelLabel.TextScaled = true
	levelLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	levelLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	levelLabel.TextStrokeTransparency = 0.35
	levelLabel.Text = "LEVEL " .. level
	levelLabel.ZIndex = 5
	levelLabel.Parent = bg
	local levelCorner = Instance.new("UICorner")
	levelCorner.CornerRadius = UDim.new(0, 5)
	levelCorner.Parent = levelLabel

	return billboard, fill, damageFill, label
end

local playEnemySFX

local function spawnDemonAttackVFX(demon)
	local root = demon:FindFirstChild("HumanoidRootPart") or demon.PrimaryPart
	if not root then return end
	playEnemySFX(root, "rbxasset://sounds/action_get_up.mp3", 0.34, 0.58)

	local slash = Instance.new("Part")
	slash.Name = "DemonAttackSlash"
	slash.Size = Vector3.new(0.15, 5, 5)
	slash.CFrame = root.CFrame * CFrame.new(0, 0, -3) * CFrame.Angles(0, 0, math.rad(35))
	slash.Anchored = true
	slash.CanCollide = false
	slash.CanQuery = false
	slash.CanTouch = false
	slash.CastShadow = false
	slash.Material = Enum.Material.Neon
	slash.Color = Color3.fromRGB(190, 20, 45)
	slash.Transparency = 0.15
	slash.Parent = workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = slash
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "DemonClawSparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 35, 65), Color3.fromRGB(90, 0, 120))
	sparks.LightEmission = 0.9
	sparks.Lifetime = NumberRange.new(0.18, 0.35)
	sparks.Rate = 0
	sparks.Speed = NumberRange.new(12, 28)
	sparks.SpreadAngle = Vector2.new(120, 120)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Parent = attachment
	sparks:Emit(28)

	TweenService:Create(slash, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, 8, 8),
		Transparency = 1,
		CFrame = root.CFrame * CFrame.new(0, 0, -4) * CFrame.Angles(0, 0, math.rad(-35)),
	}):Play()

	task.delay(0.35, function()
		if slash and slash.Parent then
			slash:Destroy()
		end
	end)
end

local function spawnBossDemonArtVFX(demon)
	local root = demon:FindFirstChild("HumanoidRootPart") or demon.PrimaryPart
	if not root then return end
	playEnemySFX(root, "rbxasset://sounds/impact_explosion_03.mp3", 0.42, 0.72)

	local orb = Instance.new("Part")
	orb.Name = "DemonBossBloodArt"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(4, 4, 4)
	orb.CFrame = root.CFrame
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.CastShadow = false
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(170, 0, 45)
	orb.Transparency = 0.25
	orb.Parent = workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = orb
	local pulse = Instance.new("ParticleEmitter")
	pulse.Name = "BossBloodArtPulse"
	pulse.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pulse.Color = ColorSequence.new(Color3.fromRGB(255, 30, 70), Color3.fromRGB(100, 0, 150))
	pulse.LightEmission = 0.9
	pulse.Lifetime = NumberRange.new(0.35, 0.7)
	pulse.Rate = 0
	pulse.Speed = NumberRange.new(18, 34)
	pulse.SpreadAngle = Vector2.new(180, 180)
	pulse.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	pulse.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	pulse.Parent = attachment
	pulse:Emit(70)

	TweenService:Create(orb, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(BOSS_SPECIAL_RADIUS * 2, BOSS_SPECIAL_RADIUS * 2, BOSS_SPECIAL_RADIUS * 2),
		Transparency = 1,
	}):Play()

	task.delay(0.85, function()
		if orb and orb.Parent then
			orb:Destroy()
		end
	end)
end

function playEnemySFX(root, soundId, volume, playbackSpeed)
	if not root then return end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed or 1
	sound.RollOffMaxDistance = 90
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 2)
end

local function buildPoseRig(demon, root)
	local poseRig = {
		Parts = {},
		Offsets = {},
	}
	local partCandidates = {
		{ logical = "Head",      candidates = { "Head" } },
		{ logical = "Left Arm",  candidates = { "Left Arm",  "LeftUpperArm" } },
		{ logical = "Right Arm", candidates = { "Right Arm", "RightUpperArm" } },
		{ logical = "Left Leg",  candidates = { "Left Leg",  "LeftUpperLeg" } },
		{ logical = "Right Leg", candidates = { "Right Leg", "RightUpperLeg" } },
	}
	for _, entry in partCandidates do
		for _, name in entry.candidates do
			local part = demon:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				poseRig.Parts[entry.logical] = part
				poseRig.Offsets[entry.logical] = root.CFrame:ToObjectSpace(part.CFrame)
				break
			end
		end
	end
	return poseRig
end

local function tweenPosePart(demonState, partName, angles, offset)
	local poseRig = demonState.poseRig
	if not poseRig then return end
	local part = poseRig.Parts[partName]
	local baseOffset = poseRig.Offsets[partName]
	if not part or not baseOffset then return end

	local moveOffset = offset or Vector3.zero
	-- Direct CFrame set every Heartbeat frame instead of TweenService; TweenService tweens
	-- fight with PivotTo (which also moves parts every frame), causing limbs to lag behind torso.
	part.CFrame = demonState.hrp.CFrame * baseOffset * CFrame.new(moveOffset) * CFrame.Angles(angles.X, angles.Y, angles.Z)
end

local function animateDemonPose(demonState, pose, dt)
	if not demonState.poseRig then return end
	-- When called from Heartbeat with dt, accumulate by time so rate is fps-independent.
	local speed = pose == "walk" and 2.5 or 0.9
	demonState.walkPhase = (demonState.walkPhase or 0) + speed * (dt or AI_TICK)

	local phase = demonState.walkPhase
	local swing = math.sin(phase) * (pose == "walk" and 0.55 or 0.08)
	local legSwing = math.sin(phase) * (pose == "walk" and 0.38 or 0.04)
	local headYaw = math.sin(phase * 0.6) * (pose == "idle" and 0.12 or 0.04)
	local attack = pose == "attack"

	if attack then
		tweenPosePart(demonState, "Right Arm", Vector3.new(math.rad(-82), math.rad(12), math.rad(28)), Vector3.new(0, 0.1, -0.15))
		tweenPosePart(demonState, "Left Arm", Vector3.new(math.rad(-45), math.rad(-10), math.rad(-24)), Vector3.new(0, 0.05, -0.05))
		tweenPosePart(demonState, "Head", Vector3.new(math.rad(-8), 0, 0), Vector3.new(0, 0, -0.08))
		tweenPosePart(demonState, "Right Leg", Vector3.new(math.rad(12), 0, 0), Vector3.zero)
		tweenPosePart(demonState, "Left Leg", Vector3.new(math.rad(-10), 0, 0), Vector3.zero)
		return
	end

	tweenPosePart(demonState, "Right Arm", Vector3.new(swing, 0, math.rad(8)), Vector3.zero)
	tweenPosePart(demonState, "Left Arm", Vector3.new(-swing, 0, math.rad(-8)), Vector3.zero)
	tweenPosePart(demonState, "Right Leg", Vector3.new(-legSwing, 0, 0), Vector3.zero)
	tweenPosePart(demonState, "Left Leg", Vector3.new(legSwing, 0, 0), Vector3.zero)
	tweenPosePart(demonState, "Head", Vector3.new(0, headYaw, 0), Vector3.zero)
end

local function isSafePosition(position)
	-- selene: allow(global_usage)
	local zoneServer = shared and shared.ZoneServer
	return zoneServer and zoneServer.isSafePosition and zoneServer.isSafePosition(position) == true
end

local function separateNextPos(pos, selfState)
	local selfHRP = selfState.hrp
	-- Check both folders so Forest and Snow demons push each other apart too.
	for _, folderName in {"ForestDemons", "SnowDemons"} do
		local folder = workspace:FindFirstChild(folderName)
		if not folder then continue end
		for _, model in folder:GetChildren() do
			if not model:IsA("Model") then continue end
			local otherHRP = model:FindFirstChild("HumanoidRootPart")
			if not otherHRP or otherHRP == selfHRP then continue end
			local diff = Vector3.new(pos.X - otherHRP.Position.X, 0, pos.Z - otherHRP.Position.Z)
			local d = diff.Magnitude
			if d < MIN_DEMON_SEPARATION then
				-- When d ≈ 0 (exactly stacked), fall back to the demon's stored escape angle
				-- so every demon pushes in a unique direction instead of NaN.
				local pushDir = d > 0.05 and diff.Unit
					or Vector3.new(math.cos(selfState.sepAngle), 0, math.sin(selfState.sepAngle))
				pos = pos + pushDir * (MIN_DEMON_SEPARATION - d) * 0.5
			end
		end
	end
	return pos
end

local function findPlayerInRadius(position, radius)
	local closest = nil
	local closestDist = radius

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end
		if isSafePosition(hrp.Position) then continue end

		local dist = (hrp.Position - position).Magnitude
		if dist < closestDist then
			closest = player
			closestDist = dist
		end
	end

	return closest, closestDist
end

local function spawnDemon(spawnData)
	local spawnCFrame = resolveSpawnCFrame(spawnData)
	local level = spawnData.level
	local isBoss = spawnData.boss == true
	local stats = getStatsForLevel(level, isBoss)
	local enemyType = isBoss and "DemonBoss" or "ForestDemon"
	local displayName = isBoss and "Demon Boss" or "Forest Demon"

	local demon = DemonTemplate:Clone()
	demon.Name = isBoss and "DemonBoss" or ("ForestDemon_Lv" .. level)
	demon.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local torso = demon:FindFirstChild("Torso") or demon:FindFirstChild("UpperTorso")
	if not torso then
		warn("[DemonSpawner] Demon template missing Torso/UpperTorso")
		demon:Destroy()
		return
	end

	-- HRP is used as the model pivot: the R15 importer always creates it
	-- axis-aligned, whereas mesh parts (UpperTorso etc.) can carry FBX orientation
	-- bakes. Using a rotated mesh part as the pivot causes the delta-inverse to
	-- rotate every part flat against the ground.
	local hrp = demon:FindFirstChild("HumanoidRootPart")
	if not hrp then
		hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 2, 1)
		hrp.Transparency = 1
		hrp.CanCollide = false
		hrp.CanQuery = true
		hrp.Parent = demon
	end

	demon.PrimaryPart = hrp
	local targetHeight = isBoss and 11.5 or 6.29
	local rawExtents = demon:GetExtentsSize()
	if rawExtents.Y > 0 then
		local ok, scaleErr = pcall(function()
			demon:ScaleTo(targetHeight / rawExtents.Y)
		end)
		if not ok then
			warn("[DemonSpawner] Could not scale demon: " .. tostring(scaleErr))
		end
	end

	local streamAnchor = demon:FindFirstChild("StreamAnchor")
	if not streamAnchor then
		streamAnchor = Instance.new("Part")
		streamAnchor.Name = "StreamAnchor"
		streamAnchor.Size = Vector3.new(1, 1, 1)
		streamAnchor.Transparency = 1
		streamAnchor.CanCollide = false
		streamAnchor.CanQuery = false
		streamAnchor.CanTouch = false
		streamAnchor.Anchored = true
		streamAnchor.CFrame = spawnCFrame
		streamAnchor.Parent = demon
	end

	local humanoid = demon:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = demon
	end
	humanoid.MaxHealth = stats.hp
	humanoid.Health = stats.hp
	humanoid.WalkSpeed = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false

	demon:SetAttribute("Level", level)
	demon:SetAttribute("Damage", stats.damage)
	demon:SetAttribute("DamageReduction", stats.damageReduction)
	demon:SetAttribute("EnemyType", enemyType)
	demon:SetAttribute("SpawnZone", spawnData.zone or "Snowfield")
	demon:SetAttribute("XPReward", stats.xp)
	demon:SetAttribute("IsBoss", isBoss)

	-- Capture HRP's world position now, before anything moves.
	-- Only the position (not the rotation) is used for the delta so the result is
	-- a pure translation — no rotation is inverted onto the parts, which is what
	-- was causing the character to lie flat when the FBX pivot had a baked rotation.
	local templateHRPPos = hrp.Position
	hrp.Anchored = true

	demon.Parent = demonsFolder

	-- Translate every part so HRP's template position aligns with spawnCFrame.
	local delta = spawnCFrame * CFrame.new(templateHRPPos):Inverse()
	for _, part in demon:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CFrame = delta * part.CFrame
		end
	end
	-- Force HRP and the stream anchor to exact spawn position regardless of delta offset.
	hrp.CFrame = spawnCFrame
	streamAnchor.CFrame = spawnCFrame

	-- Ground-snap: shift the whole model so the lowest visible part's bottom edge
	-- sits on the terrain found by resolveSpawnCFrame. This must use the resolved
	-- ground height, not world Y=0.5, otherwise raised snow maps bury the rig.
	local lowestY = math.huge
	for _, part in demon:GetDescendants() do
		if part:IsA("BasePart")
			and part.Name ~= "HumanoidRootPart"
			and part.Name ~= "StreamAnchor"
			and part.Name ~= "DebugRadius" then
			local bottom = part.Position.Y - part.Size.Y * 0.5
			if bottom < lowestY then
				lowestY = bottom
			end
		end
	end
	if lowestY ~= math.huge then
		local targetGroundY = spawnCFrame.Position.Y - DEMON_HALF_HEIGHT
		local lift = Vector3.new(0, targetGroundY - lowestY, 0)
		for _, part in demon:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = part.CFrame + lift
			end
		end
	end

	debugSpawnLog("Parts repositioned for Lv." .. level .. " at " .. tostring(spawnCFrame.Position))
	for _, part in demon:GetDescendants() do
		if part:IsA("BasePart") then
			debugSpawnLog("  " .. part.Name .. " at " .. tostring(part.Position))
		end
	end

	CollectionService:AddTag(demon, "Demon")

	local head = demon:FindFirstChild("Head")
	local barParent = head or hrp
	local _billboard, fill, damageFill, hpLabel = createHPBar(barParent, displayName, level)
	hpLabel.Text = stats.hp .. " / " .. stats.hp

	local showDebug = demon:FindFirstChild("ShowDebug")
	if not showDebug then
		showDebug = Instance.new("BoolValue")
		showDebug.Name = "ShowDebug"
		showDebug.Value = false
		showDebug.Parent = demon
	end

	local debugCylinder = nil
	local function updateDebugVis()
		if showDebug.Value then
			if not debugCylinder then
				debugCylinder = Instance.new("Part")
				debugCylinder.Name = "DebugRadius"
				debugCylinder.Shape = Enum.PartType.Cylinder
				debugCylinder.Size = Vector3.new(0.5, ATTACK_RADIUS * 2, ATTACK_RADIUS * 2)
				debugCylinder.CFrame = spawnCFrame * CFrame.Angles(0, 0, math.rad(90))
				debugCylinder.Anchored = true
				debugCylinder.CanCollide = false
				debugCylinder.CanQuery = false
				debugCylinder.CanTouch = false
				debugCylinder.Color = Color3.fromRGB(200, 40, 40)
				debugCylinder.Transparency = 0.85
				debugCylinder.Material = Enum.Material.ForceField
				debugCylinder.Parent = demon
			end
		else
			if debugCylinder then
				debugCylinder:Destroy()
				debugCylinder = nil
			end
		end
	end
	updateDebugVis()
	showDebug.Changed:Connect(updateDebugVis)

	local demonState = {
		model = demon,
		humanoid = humanoid,
		hrp = hrp,
		spawnCFrame = spawnCFrame,
		level = level,
		stats = stats,
		alive = true,
		lastAttack = 0,
		fill = fill,
		damageFill = damageFill,
		hpLabel = hpLabel,
		aiState = "idle",
		isAttacking = false,
		isBoss = isBoss,
		lastSpecial = 0,
		poseRig = buildPoseRig(demon, hrp),
		walkPhase = 0,
		attackPoseUntil = 0,
		moveCFrame = nil,
		currentPose = "idle",
		sepAngle = math.random() * 2 * math.pi,
	}

	local function updateBar()
		local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		local color = getHPColor(ratio)

		TweenService:Create(fill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(ratio, 1),
			BackgroundColor3 = color,
		}):Play()

		task.delay(0.3, function()
			if damageFill and damageFill.Parent then
				TweenService:Create(damageFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.fromScale(ratio, 1),
				}):Play()
			end
		end)

		hpLabel.Text = math.floor(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)
	end

	humanoid.HealthChanged:Connect(function(newHealth)
		updateBar()
		if newHealth <= 0 then
			demonState.alive = false
		end
	end)

	humanoid.Died:Connect(function()
		demonState.alive = false
		demonState.isAttacking = false
		CollectionService:RemoveTag(demon, "Demon")

		for _, descendant in demon:GetDescendants() do
			if descendant:IsA("BillboardGui") or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
				descendant.Enabled = false
			end
			local part = descendant
			if part:IsA("BasePart") then
				part.CanQuery = false
				part.CanTouch = false
				part.CanCollide = false
			end
		end

		local lastAttackerId = demon:GetAttribute("LastAttacker")
		for i, state in activeDemons do
			if state == demonState then
				table.remove(activeDemons, i)
				break
			end
		end
		-- Cleanup and respawn scheduling happen before optional reward systems.
		-- A progression/quest failure must never strand a defeated rig in Workspace.
		demon:Destroy()
		task.delay(RESPAWN_TIME, function()
			spawnDemon(spawnData)
		end)

		if lastAttackerId then
			local attacker = Players:GetPlayerByUserId(lastAttackerId)
			if attacker then
				-- selene: allow(global_usage)
				if shared.ClanService and shared.ClanService.grantActivity then
					-- selene: allow(global_usage)
					shared.ClanService.grantActivity(
						attacker,
						isBoss and "BossKill" or "EnemyKill",
						level * (isBoss and 10 or 3),
						level * (isBoss and 5 or 2)
					)
				end
				local rewardPlayers = CombatModule.getRewardPlayers(demon, attacker, 160)
				local stateMultiplier = EnemyProgressionModule.getKillMultiplier(level, isBoss)
				local masteryReward = EnemyProgressionModule.getMasteryXP(level, isBoss)
				for _, rewardedPlayer in rewardPlayers do
					PlayerDataModule.addXP(rewardedPlayer, stats.xp)
					CombatModule.grantStateProgressionEvent(rewardedPlayer, "Kill", stateMultiplier)
					debugRewardLog("Awarded " .. stats.xp .. " XP to " .. rewardedPlayer.Name)

					-- selene: allow(global_usage)
					if shared.QuestServer and shared.QuestServer.onEnemyKilled then
						-- selene: allow(global_usage)
						shared.QuestServer.onEnemyKilled(rewardedPlayer, enemyType)
					end

					-- selene: allow(global_usage)
					if shared.BountyServer and shared.BountyServer.onEnemyKilled then
						-- selene: allow(global_usage)
						shared.BountyServer.onEnemyKilled(rewardedPlayer, enemyType, level)
					end

					local data = PlayerDataModule.getData(rewardedPlayer)
					if data and data.EquippedStyle and data.EquippedStyle ~= "" then
						PlayerDataModule.addMasteryXP(rewardedPlayer, data.EquippedStyle, masteryReward)
						debugRewardLog("Awarded " .. masteryReward .. " mastery XP to " .. rewardedPlayer.Name .. " for style " .. data.EquippedStyle)
					end
				end
			end
		end
		CombatModule.clearDamageContributors(demon)
	end)

	table.insert(activeDemons, demonState)
	debugSpawnLog("Spawned " .. displayName .. " Lv." .. level .. " at " .. tostring(spawnCFrame.Position))
	return demonState
end

local function replaceAuthoredDemonModels()
	local candidates = {}
	local removedFromProtectedZones = 0
	for _, model in workspace:GetDescendants() do
		if not model:IsA("Model") or model:IsDescendantOf(demonsFolder) then
			continue
		end
		if Players:GetPlayerFromCharacter(model) then
			continue
		end
		-- Other enemy services mark their runtime models with EnemyType.
		-- Those models are already managed and must not be converted here.
		if model:GetAttribute("EnemyType") ~= nil then
			continue
		end

		local lowerName = string.lower(model.Name)
		if not string.find(lowerName, "demon", 1, true) then
			continue
		end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local hasRigParts = model:FindFirstChild("Head") and model:FindFirstChild("Torso")
		local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart
		if (humanoid or hasRigParts) and root then
			local exclusionZone = WorldSpawnConfigModule.getDemonExclusionZone(root.Position.X, root.Position.Z)
			if exclusionZone then
				removedFromProtectedZones += 1
				model:Destroy()
			else
				table.insert(candidates, model)
			end
		end
	end

	for _, model in candidates do
		if not model.Parent then continue end
		local pivot = model:GetPivot()
		local lowerName = string.lower(model.Name)
		local isBoss = model:GetAttribute("IsBoss") == true
			or string.find(lowerName, "boss", 1, true) ~= nil
		local parsedLevel = tonumber(string.match(model.Name, "[Ll][Vv]%.?%s*(%d+)"))
		local level = tonumber(model:GetAttribute("Level")) or parsedLevel or (isBoss and 12 or 1)

		model:Destroy()
		spawnDemon({
			pos = pivot,
			x = pivot.Position.X,
			z = pivot.Position.Z,
			level = level,
			boss = isBoss,
			zone = "AuthoredSnowfield",
		})
	end

	if #candidates > 0 then
		print(("[DemonSpawner] Replaced %d authored demon rig(s) with combat-enabled AI"):format(#candidates))
	end
	if removedFromProtectedZones > 0 then
		print(("[DemonSpawner] Removed %d authored demon rig(s) from protected training areas"):format(
			removedFromProtectedZones
		))
	end
end

replaceAuthoredDemonModels()

for _, spawnData in SPAWN_POSITIONS do
	spawnDemon(spawnData)
end

task.spawn(function()
	while true do
		task.wait(AI_TICK)

		for _, demonState in activeDemons do
			if not demonState.alive then continue end
			local demon = demonState.model
			local hrp = demonState.hrp
			if not demon.Parent or not hrp.Parent then
				demonState.alive = false
				continue
			end
			if demonState.humanoid.Health <= 0 then
				demonState.alive = false
				continue
			end

			local spawnPos = demonState.spawnCFrame.Position
			local currentPos = hrp.Position
			local closestPlayer, dist = findPlayerInRadius(currentPos, AGGRO_RADIUS)
			local poseThisTick = "idle"

			if closestPlayer then
				local targetHRP = closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart")
				if targetHRP then
					local targetPos = targetHRP.Position
					local direction = targetPos - currentPos
					local flatDir = Vector3.new(direction.X, 0, direction.Z)
					if flatDir.Magnitude > 0.1 then
						local nextPos
						if dist > ATTACK_MOVE_STOP_RADIUS then
							nextPos = currentPos + flatDir.Unit * math.min(MOVE_SPEED * AI_TICK, dist - ATTACK_MOVE_STOP_RADIUS)
						else
							local spread = ATTACK_MOVE_STOP_RADIUS * 0.75
							local idealPos = Vector3.new(
								targetPos.X + math.cos(demonState.sepAngle) * spread,
								currentPos.Y,
								targetPos.Z + math.sin(demonState.sepAngle) * spread
							)
							local toIdeal = Vector3.new(idealPos.X - currentPos.X, 0, idealPos.Z - currentPos.Z)
							nextPos = toIdeal.Magnitude > 0.3
								and currentPos + toIdeal.Unit * math.min(MOVE_SPEED * AI_TICK, toIdeal.Magnitude)
								or currentPos
						end

						if (nextPos - spawnPos).Magnitude > LEASH_DISTANCE or isSafePosition(nextPos) then
							demonState.aiState = "returning"
							local homeDir = spawnPos - currentPos
							if homeDir.Magnitude > 0.5 then
								local flatHome = Vector3.new(homeDir.X, 0, homeDir.Z).Unit
								nextPos = currentPos + flatHome * math.min(MOVE_SPEED * AI_TICK, homeDir.Magnitude)
							else
								nextPos = spawnPos
							end
						end

						nextPos = separateNextPos(nextPos, demonState)
						local lookCFrame = CFrame.lookAt(nextPos, nextPos + flatDir.Unit)
						demonState.moveCFrame = lookCFrame
						if (nextPos - currentPos).Magnitude > 0.05 then
							poseThisTick = "walk"
						end
					end
				end

				demonState.aiState = "attacking"
				if dist <= ATTACK_ENGAGE_RADIUS then
					poseThisTick = "idle"
				end

				local now = tick()
				if dist <= ATTACK_ENGAGE_RADIUS and now - demonState.lastAttack >= ATTACK_COOLDOWN and not demonState.isAttacking then
					demonState.lastAttack = now
					demonState.isAttacking = true
					demonState.attackPoseUntil = now + ATTACK_WINDUP + 0.35
					poseThisTick = "attack"

					local debugMode = false
					local debugVal = demon:FindFirstChild("DebugHitbox")
					if debugVal and debugVal:IsA("BoolValue") then
						debugMode = debugVal.Value
					end

					if demonState.isBoss and now - demonState.lastSpecial >= BOSS_SPECIAL_COOLDOWN then
						demonState.lastSpecial = now
						spawnBossDemonArtVFX(demon)

						task.delay(ATTACK_WINDUP + 0.2, function()
							if not demonState.alive or not demon.Parent or demonState.humanoid.Health <= 0 then
								demonState.isAttacking = false
								return
							end

							local bossPos = hrp.Position
							for _, player in Players:GetPlayers() do
								local character = player.Character
								local playerHRP = character and character:FindFirstChild("HumanoidRootPart")
								local humanoid = character and character:FindFirstChildOfClass("Humanoid")
								if playerHRP and humanoid and humanoid.Health > 0 then
									local distance = (playerHRP.Position - bossPos).Magnitude
									if distance <= BOSS_SPECIAL_RADIUS and not isSafePosition(playerHRP.Position) then
										CombatModule.applyDamageFromNPC(character, demonState.stats.damage * 1.4, demon)
									end
								end
							end

							demonState.isAttacking = false
						end)
					else
						spawnDemonAttackVFX(demon)

						task.delay(ATTACK_WINDUP, function()
							if not demonState.alive or not demon.Parent or demonState.humanoid.Health <= 0 then
								demonState.isAttacking = false
								return
							end
							CombatModule.processNPCAttack(demon, demonState.stats.damage, debugMode)
							demonState.isAttacking = false
						end)
					end
				end
				if tick() < (demonState.attackPoseUntil or 0) then
					poseThisTick = "attack"
				end
				demonState.currentPose = poseThisTick
			else
				local homeDir = spawnPos - currentPos
				if homeDir.Magnitude > 1 then
					demonState.aiState = "returning"
					local flatHome = Vector3.new(homeDir.X, 0, homeDir.Z)
					if flatHome.Magnitude > 0.1 then
						local nextPos = separateNextPos(currentPos + flatHome.Unit * math.min(MOVE_SPEED * AI_TICK, homeDir.Magnitude), demonState)
						demonState.moveCFrame = CFrame.lookAt(nextPos, nextPos + flatHome.Unit)
						poseThisTick = "walk"
					end
				else
					demonState.aiState = "idle"
					demonState.moveCFrame = demonState.spawnCFrame
					poseThisTick = "idle"
				end
				demonState.currentPose = poseThisTick
			end
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for _, demonState in activeDemons do
		if not demonState.alive then continue end
		local demon = demonState.model
		local hrp = demonState.hrp
		if not demon.Parent or not hrp.Parent then continue end

		if demonState.moveCFrame then
			local target = demonState.moveCFrame
			local dist = (target.Position - hrp.Position).Magnitude
			if dist >= 0.01 then
				local step = math.min(MOVE_SPEED * dt, dist)
				demon:PivotTo(hrp.CFrame:Lerp(target, step / dist))
			end
		end

		-- Animate limbs directly every frame after PivotTo so they track HRP without TweenService conflicts.
		local pose = demonState.currentPose or "idle"
		if demonState.attackPoseUntil and tick() < demonState.attackPoseUntil then
			pose = "attack"
		end
		animateDemonPose(demonState, pose, dt)
	end
end)

print("[DemonSpawner] Loaded - " .. #SPAWN_POSITIONS .. " sentinel demon spawn points active")
