local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local DemonTemplate = Assets:WaitForChild("ForestDemon")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local CombatModule = require(Modules:WaitForChild("CombatModule"))

local MASTERY_KILL_REWARDS = {
	[1] = 3, [2] = 5, [3] = 8, [4] = 12, [5] = 12,
	[6] = 20, [7] = 20, [8] = 20, [9] = 20, [10] = 20,
}

local AGGRO_RADIUS = 55
local ATTACK_RADIUS = 8
local ATTACK_COOLDOWN = 1.5
local ATTACK_WINDUP = CombatModule.NPC_ATTACK_WINDUP
local BOSS_SPECIAL_COOLDOWN = 7
local BOSS_SPECIAL_RADIUS = 20
local RESPAWN_TIME = 15
local AI_TICK = 0.5
local MOVE_SPEED = 14
local LEASH_DISTANCE = 90
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

local DEMON_STATS = {
	{ level = 1,  hp = 80,   damage = 5,   xp = 30  },
	{ level = 2,  hp = 100,  damage = 7,   xp = 40  },
	{ level = 3,  hp = 130,  damage = 9,   xp = 55  },
	{ level = 4,  hp = 160,  damage = 11,  xp = 70  },
	{ level = 5,  hp = 200,  damage = 14,  xp = 90  },
	{ level = 6,  hp = 250,  damage = 17,  xp = 110 },
	{ level = 7,  hp = 310,  damage = 20,  xp = 135 },
	{ level = 8,  hp = 380,  damage = 24,  xp = 165 },
	{ level = 9,  hp = 460,  damage = 28,  xp = 200 },
	{ level = 10, hp = 550,  damage = 33,  xp = 240 },
}

local BOSS_STATS = {
	level = 12,
	hp = 1600,
	damage = 45,
	xp = 600,
}

local RAW_SPAWNS = {
	{ x = 42,  z = 36,  level = 1 },
	{ x = 52,  z = 36,  level = 1 },
	{ x = 62,  z = 36,  level = 1 },
	{ x = 72,  z = 36,  level = 1 },
	{ x = 60,  z = -60,  level = 2 },
	{ x = -50, z = -80,  level = 2 },
	{ x = 80,  z = -100, level = 3 },
	{ x = -70, z = -30,  level = 3 },
	{ x = 100, z = -40,  level = 4 },
	{ x = -90, z = -110, level = 5 },
	{ x = 50,  z = -130, level = 6 },
	{ x = -40, z = -150, level = 7 },
	{ x = 128, z = 78,  level = BOSS_STATS.level, boss = true },
}

local SPAWN_POSITIONS = {}
for _, raw in RAW_SPAWNS do
	table.insert(SPAWN_POSITIONS, {
		pos = CFrame.new(raw.x, FALLBACK_Y + DEMON_HALF_HEIGHT, raw.z),
		level = raw.level,
		boss = raw.boss == true,
	})
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

local function getStatsForLevel(level)
	level = math.clamp(level, 1, 10)
	return DEMON_STATS[level]
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
	billboard.MaxDistance = 60
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
	nameLabel.Text = name .. " [Lv." .. level .. "]"
	nameLabel.ZIndex = 4
	nameLabel.Parent = bg

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
	for _, partName in {"Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg"} do
		local part = demon:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			poseRig.Parts[partName] = part
			poseRig.Offsets[partName] = root.CFrame:ToObjectSpace(part.CFrame)
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
	local target = demonState.hrp.CFrame * baseOffset * CFrame.new(moveOffset) * CFrame.Angles(angles.X, angles.Y, angles.Z)
	TweenService:Create(part, TweenInfo.new(math.max(0.08, AI_TICK * 0.6), Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = target,
	}):Play()
end

local function animateDemonPose(demonState, pose)
	if not demonState.poseRig then return end
	demonState.walkPhase = (demonState.walkPhase or 0) + (pose == "walk" and 1.25 or 0.45)

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
	local spawnCFrame = spawnData.pos
	local level = spawnData.level
	local isBoss = spawnData.boss == true
	local stats = isBoss and BOSS_STATS or getStatsForLevel(level)
	local enemyType = isBoss and "DemonBoss" or "ForestDemon"
	local displayName = isBoss and "Demon Boss" or "Forest Demon"

	local demon = DemonTemplate:Clone()
	demon.Name = isBoss and "DemonBoss" or ("ForestDemon_Lv" .. level)

	local torso = demon:FindFirstChild("Torso")
	if not torso then
		warn("[DemonSpawner] Demon template missing Torso")
		demon:Destroy()
		return
	end

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
	hrp.Anchored = true
	hrp.CFrame = spawnCFrame

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
	demon:SetAttribute("EnemyType", enemyType)
	demon:SetAttribute("XPReward", stats.xp)
	demon:SetAttribute("IsBoss", isBoss)

	demon.PrimaryPart = torso
	demon.Parent = demonsFolder

	if isBoss then
		local ok, scaleErr = pcall(function()
			demon:ScaleTo(1.85)
		end)
		if not ok then
			warn("[DemonSpawner] Could not scale Demon Boss: " .. tostring(scaleErr))
		end
	end

	local pivotOffset = demon:GetPivot()
	local delta = spawnCFrame * pivotOffset:Inverse()
	for _, part in demon:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CFrame = delta * part.CFrame
		end
	end
	hrp.CFrame = spawnCFrame
	streamAnchor.CFrame = spawnCFrame

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
		if lastAttackerId then
			local attacker = Players:GetPlayerByUserId(lastAttackerId)
			if attacker then
				local rewardPlayers = CombatModule.getRewardPlayers(demon, attacker, 160)
				for _, rewardedPlayer in rewardPlayers do
					PlayerDataModule.addXP(rewardedPlayer, stats.xp)
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
						local rewardXP = isBoss and 35 or (MASTERY_KILL_REWARDS[level] or 3)
						PlayerDataModule.addMasteryXP(rewardedPlayer, data.EquippedStyle, rewardXP)
						debugRewardLog("Awarded " .. rewardXP .. " mastery XP to " .. rewardedPlayer.Name .. " for style " .. data.EquippedStyle)
					end
				end
			end
		end
		CombatModule.clearDamageContributors(demon)

		for _, part in demon:GetDescendants() do
			if part:IsA("BasePart") and part ~= hrp and part ~= streamAnchor then
				TweenService:Create(part, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
				}):Play()
			end
		end

		task.delay(0.65, function()
			if demon and demon.Parent then
				demon:Destroy()
			end
		end)

		task.delay(RESPAWN_TIME, function()
			for i, ds in activeDemons do
				if ds == demonState then
					table.remove(activeDemons, i)
					break
				end
			end
			spawnDemon(spawnData)
		end)
	end)

	table.insert(activeDemons, demonState)
	debugSpawnLog("Spawned " .. displayName .. " Lv." .. level .. " at " .. tostring(spawnCFrame.Position))
	return demonState
end

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
						local nextPos = currentPos
						if dist > ATTACK_RADIUS then
							nextPos = currentPos + flatDir.Unit * math.min(MOVE_SPEED * AI_TICK, dist - ATTACK_RADIUS)
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

						local lookCFrame = CFrame.lookAt(nextPos, nextPos + flatDir.Unit)
						demon:PivotTo(lookCFrame)
						if (nextPos - currentPos).Magnitude > 0.05 then
							poseThisTick = "walk"
						end
					end
				end

				demonState.aiState = "attacking"
				if dist <= ATTACK_RADIUS then
					poseThisTick = "idle"
				end

				local now = tick()
				if dist <= ATTACK_RADIUS and now - demonState.lastAttack >= ATTACK_COOLDOWN and not demonState.isAttacking then
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
						animateDemonPose(demonState, "attack")
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
						animateDemonPose(demonState, "attack")
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
				animateDemonPose(demonState, poseThisTick)
			else
				local homeDir = spawnPos - currentPos
				if homeDir.Magnitude > 1 then
					demonState.aiState = "returning"
					local flatHome = Vector3.new(homeDir.X, 0, homeDir.Z)
					if flatHome.Magnitude > 0.1 then
						local nextPos = currentPos + flatHome.Unit * math.min(MOVE_SPEED * AI_TICK, homeDir.Magnitude)
						demon:PivotTo(CFrame.lookAt(nextPos, nextPos + flatHome.Unit))
						poseThisTick = "walk"
					end
				else
					demonState.aiState = "idle"
					demon:PivotTo(demonState.spawnCFrame)
					poseThisTick = "idle"
				end
				animateDemonPose(demonState, poseThisTick)
			end
		end
	end
end)

print("[DemonSpawner] Loaded - " .. #SPAWN_POSITIONS .. " sentinel demon spawn points active")
