local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local DemonTemplate = Assets:WaitForChild("SnowDemon")

local attackAnimRemote = Instance.new("RemoteEvent")
attackAnimRemote.Name = "SnowDemonAttackAnim"
attackAnimRemote.Parent = ReplicatedStorage

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local CombatModule = require(Modules:WaitForChild("CombatModule"))
local WorldSpawnConfigModule = require(Modules:WaitForChild("WorldSpawnConfigModule"))
local EnemyProgressionModule = require(Modules:WaitForChild("EnemyProgressionModule"))

local AGGRO_RADIUS = 55
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
local WANDER_RADIUS = 20
local WANDER_SPEED_MULT = 0.35
local FALLBACK_Y = 0.5
local GROUND_OFFSET = 3 -- studs above terrain to place HRP; boss scales this by BOSS_SCALE
local BOSS_SCALE = 2.75
local DEBUG_DEMON_SPAWNS = false
local DEBUG_DEMON_REWARDS = false

local function debugSpawnLog(message)
	if DEBUG_DEMON_SPAWNS then
		print("[SnowDemonSpawner] " .. message)
	end
end

local function debugRewardLog(message)
	if DEBUG_DEMON_REWARDS then
		print("[SnowDemonSpawner] " .. message)
	end
end

local RAW_SPAWNS = WorldSpawnConfigModule.getFrostDemonSpawns()

local SPAWN_POSITIONS = {}
for _, raw in RAW_SPAWNS do
	local exclusionZone = WorldSpawnConfigModule.getDemonExclusionZone(raw.x, raw.z)
	if exclusionZone then
		warn(("[SnowDemonSpawner] Skipped configured spawn in protected zone '%s'"):format(exclusionZone.name))
	else
		table.insert(SPAWN_POSITIONS, {
			pos = CFrame.new(raw.x, FALLBACK_Y, raw.z),
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
demonsFolder.Name = "SnowDemons"
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
	local forestDemonsFolder = workspace:FindFirstChild("ForestDemons")
	local dummiesFolder = workspace:FindFirstChild("TrainingDummies")
	local markersFolder = workspace:FindFirstChild("DemonBlade2Markers")
	if forestDemonsFolder then
		table.insert(excluded, forestDemonsFolder)
	end
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
	return workspace:Raycast(Vector3.new(x, 350, z), Vector3.new(0, -800, 0), raycastParams)
end

local function hasSpawnClearance(cframe, isBoss)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { demonsFolder }
	local forestDemonsFolder = workspace:FindFirstChild("ForestDemons")
	local dummiesFolder = workspace:FindFirstChild("TrainingDummies")
	local markersFolder = workspace:FindFirstChild("DemonBlade2Markers")
	if forestDemonsFolder then
		table.insert(excluded, forestDemonsFolder)
	end
	if dummiesFolder then
		table.insert(excluded, dummiesFolder)
	end
	if markersFolder then
		table.insert(excluded, markersFolder)
	end
	overlapParams.FilterDescendantsInstances = excluded

	local boxSize = isBoss and Vector3.new(14, 16, 14) or Vector3.new(6, 5, 6)
	local parts = workspace:GetPartBoundsInBox(cframe * CFrame.new(0, 0.5, 0), boxSize, overlapParams)
	for _, part in parts do
		if part.CanCollide then
			return false
		end
	end
	return true
end

local function resolveSpawnCFrame(spawnData, isBoss)
	local groundOffset = isBoss and GROUND_OFFSET * BOSS_SCALE or GROUND_OFFSET
	local firstGroundCFrame = nil
	for _, offset in SPAWN_SEARCH_OFFSETS do
		local x = spawnData.x + offset.X
		local z = spawnData.z + offset.Y
		local result = getGroundResult(x, z)
		if result and result.Normal.Y >= 0.65 then
			local cframe = CFrame.new(result.Position + Vector3.new(0, groundOffset, 0))
			firstGroundCFrame = firstGroundCFrame or cframe
			if hasSpawnClearance(cframe, isBoss) then
				return cframe
			end
		end
	end

	if firstGroundCFrame then
		warn(("[SnowDemonSpawner] Ground found for %s but clearance was blocked; using grounded fallback"):format(
			spawnData.zone or "unknown zone"
		))
		return firstGroundCFrame
	end

	warn(("[SnowDemonSpawner] No clear ground found for %s; using configured fallback"):format(
		spawnData.zone or "unknown zone"
	))
	return CFrame.new(spawnData.x, FALLBACK_Y + groundOffset, spawnData.z)
end

local function getStatsForLevel(level, isBoss)
	return EnemyProgressionModule.getCombatStats(level, isBoss, 1.12)
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
	damageFill.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
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
	nameLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = name
	nameLabel.ZIndex = 4
	nameLabel.Parent = bg

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.fromScale(0.7, 0.7)
	levelLabel.Position = UDim2.fromScale(0.15, -1.75)
	levelLabel.BackgroundColor3 = Color3.fromRGB(22, 48, 72)
	levelLabel.BackgroundTransparency = 0.12
	levelLabel.BorderSizePixel = 0
	levelLabel.Font = Enum.Font.GothamBlack
	levelLabel.TextScaled = true
	levelLabel.TextColor3 = Color3.fromRGB(185, 235, 255)
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

local function spawnBossDemonArtVFX(demon)
	local root = demon:FindFirstChild("HumanoidRootPart") or demon.PrimaryPart
	if not root then return end
	playEnemySFX(root, "rbxasset://sounds/impact_explosion_03.mp3", 0.42, 0.72)

	local orb = Instance.new("Part")
	orb.Name = "SnowDemonBossBlizzardArt"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(4, 4, 4)
	orb.CFrame = root.CFrame
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.CastShadow = false
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(60, 160, 255)
	orb.Transparency = 0.25
	orb.Parent = workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = orb
	local pulse = Instance.new("ParticleEmitter")
	pulse.Name = "BossBlizzardArtPulse"
	pulse.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pulse.Color = ColorSequence.new(Color3.fromRGB(180, 230, 255), Color3.fromRGB(40, 100, 200))
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

local function isSafePosition(position)
	-- selene: allow(global_usage)
	local zoneServer = shared and shared.ZoneServer
	return zoneServer and zoneServer.isSafePosition and zoneServer.isSafePosition(position) == true
end

local function separateNextPos(pos, selfState)
	local selfHRP = selfState.hrp
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
	local level = spawnData.level
	local isBoss = spawnData.boss == true
	local spawnCFrame = resolveSpawnCFrame(spawnData, isBoss)
	local stats = getStatsForLevel(level, isBoss)
	local enemyType = isBoss and "SnowDemonBoss" or "SnowDemon"
	local displayName = isBoss and "Snow Demon Boss" or "Snow Demon"

	local demon = DemonTemplate:Clone()
	demon.Name = isBoss and "SnowDemonBoss" or ("SnowDemon_Lv" .. level)
	demon.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for _, descendant in demon:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end

	-- Support both R6 (Torso) and R15 (UpperTorso/LowerTorso) rigs
	local torso = demon:FindFirstChild("Torso")
		or demon:FindFirstChild("UpperTorso")
		or demon:FindFirstChild("LowerTorso")
	if not torso then
		warn("[SnowDemonSpawner] SnowDemon template missing Torso — check model structure")
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
	demon:SetAttribute("SpawnZone", spawnData.zone or "FrostSnowfield")
	demon:SetAttribute("XPReward", stats.xp)
	demon:SetAttribute("IsBoss", isBoss)

	-- HRP is always world-aligned in a properly set-up rig; using it as PrimaryPart
	-- ensures PivotTo keeps the model upright regardless of the torso's internal rotation.
	demon.PrimaryPart = hrp
	demon.Parent = demonsFolder

	if isBoss then
		local ok, scaleErr = pcall(function()
			demon:ScaleTo(BOSS_SCALE)
		end)
		if not ok then
			warn("[SnowDemonSpawner] Could not scale Snow Demon Boss: " .. tostring(scaleErr))
		end
	end

	-- Only anchor HRP and StreamAnchor. Limbs must stay unanchored so Motor6D
	-- joints can apply animation transforms. The joint chain holds them in place.
	for _, part in demon:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			local isRoot = part == hrp or part.Name == "StreamAnchor"
			part.Anchored = isRoot
		end
	end
	hrp.Anchored = true

	demon:PivotTo(spawnCFrame)
	hrp.CFrame = spawnCFrame
	streamAnchor.CFrame = spawnCFrame

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
				debugCylinder.Color = Color3.fromRGB(80, 160, 255)
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
		moveCFrame = nil,
		sepAngle = math.random() * 2 * math.pi,
		wanderTarget = nil,
		wanderTimer = 0,
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
		-- Remove the rig and schedule its replacement before optional rewards.
		-- Reward failures must never leave a defeated Snow Demon in Workspace.
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
			if closestPlayer then
				local targetHRP = closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart")
				local attackTargetPosition = targetHRP and targetHRP.Position
				if targetHRP then
					local targetPos = targetHRP.Position
					local direction = targetPos - currentPos
					local flatDir = Vector3.new(direction.X, 0, direction.Z)
					if flatDir.Magnitude > 0.1 then
						local nextPos
						if dist > ATTACK_MOVE_STOP_RADIUS then
							nextPos = currentPos + flatDir.Unit * math.min(MOVE_SPEED * AI_TICK, dist - ATTACK_MOVE_STOP_RADIUS)
						else
							-- Each demon targets its own angular slot around the player so they ring out
							-- instead of all converging to the same point.
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
						local lookCFrame = CFrame.lookAt(nextPos, nextPos + flatDir.Unit) * CFrame.Angles(0, math.pi, 0)
						demonState.moveCFrame = lookCFrame
					end
				end

				demonState.aiState = "attacking"

				local now = tick()
				if dist <= ATTACK_ENGAGE_RADIUS and now - demonState.lastAttack >= ATTACK_COOLDOWN and not demonState.isAttacking then
					demonState.lastAttack = now
					demonState.isAttacking = true

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
						local vfxTarget = attackTargetPosition or (hrp.Position + hrp.CFrame.LookVector * 4)
						attackAnimRemote:FireAllClients(demon, vfxTarget)

						task.delay(ATTACK_WINDUP, function()
							if not demonState.alive or not demon.Parent or demonState.humanoid.Health <= 0 then
								demonState.isAttacking = false
								return
							end
							-- processNPCAttack places its hitbox at hrp.CFrame * CFrame.new(0,0,-3).
							-- The Snow Demon's HRP is rotated 180° so its -Z faces away from the player,
							-- putting the hitbox behind the demon. Use a direct radius check instead.
							local attackPos = hrp.Position
							for _, player in Players:GetPlayers() do
								local character = player.Character
								local playerHRP = character and character:FindFirstChild("HumanoidRootPart")
								local humanoid = character and character:FindFirstChildOfClass("Humanoid")
								if playerHRP and humanoid and humanoid.Health > 0 then
									if (playerHRP.Position - attackPos).Magnitude <= ATTACK_ENGAGE_RADIUS and not isSafePosition(playerHRP.Position) then
										CombatModule.applyDamageFromNPC(character, demonState.stats.damage, demon)
									end
								end
							end
							demonState.isAttacking = false
						end)
					end
				end
			else
				local homeDir = spawnPos - currentPos
				if homeDir.Magnitude > WANDER_RADIUS + 3 then
					-- Too far from spawn (leashed away during chase) — head back
					demonState.aiState = "returning"
					local flatHome = Vector3.new(homeDir.X, 0, homeDir.Z)
					if flatHome.Magnitude > 0.1 then
						local nextPos = separateNextPos(currentPos + flatHome.Unit * math.min(MOVE_SPEED * AI_TICK, homeDir.Magnitude), demonState)
						demonState.moveCFrame = CFrame.lookAt(nextPos, nextPos + flatHome.Unit) * CFrame.Angles(0, math.pi, 0)
					end
				else
					-- Wander randomly within WANDER_RADIUS of spawn
					demonState.aiState = "idle"
					local now = tick()
					local flatPos = Vector3.new(currentPos.X, 0, currentPos.Z)
					local wanderFlat = demonState.wanderTarget and Vector3.new(demonState.wanderTarget.X, 0, demonState.wanderTarget.Z)
					local needNew = not demonState.wanderTarget
						or (wanderFlat - flatPos).Magnitude < 1.5
						or now > demonState.wanderTimer
					if needNew then
						local angle = math.random() * 2 * math.pi
						local radius = WANDER_RADIUS * (0.3 + math.random() * 0.7)
						demonState.wanderTarget = Vector3.new(
							spawnPos.X + math.cos(angle) * radius,
							currentPos.Y,
							spawnPos.Z + math.sin(angle) * radius
						)
						demonState.wanderTimer = now + math.random(3, 9)
					end
					local wt = demonState.wanderTarget
					local wanderDir = Vector3.new(wt.X - currentPos.X, 0, wt.Z - currentPos.Z)
					if wanderDir.Magnitude > 1.5 then
						-- Point at the FULL target, not a step ahead. The Heartbeat drives
						-- the actual movement speed via aiState, so the demon walks
						-- continuously at patrol speed with no stop-start between ticks.
						local wtAdj = separateNextPos(Vector3.new(wt.X, currentPos.Y, wt.Z), demonState)
						demonState.moveCFrame = CFrame.lookAt(wtAdj, wtAdj + wanderDir.Unit) * CFrame.Angles(0, math.pi, 0)
					else
						demonState.moveCFrame = nil
					end
				end
			end
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for _, demonState in activeDemons do
		if not demonState.alive or not demonState.moveCFrame then continue end
		local demon = demonState.model
		local hrp = demonState.hrp
		if not demon.Parent or not hrp.Parent then continue end

		local target = demonState.moveCFrame
		local dist = (target.Position - hrp.Position).Magnitude
		if dist < 0.01 then continue end

		local speed = demonState.aiState == "idle" and MOVE_SPEED * WANDER_SPEED_MULT or MOVE_SPEED
		local step = math.min(speed * dt, dist)
		-- Only move HRP — Motor6D holds the limbs relative to it.
		-- Using PivotTo would set all limb CFrames on the server each frame,
		-- which overrides the client-side Motor6D animation and causes limbs to freeze.
		hrp.CFrame = hrp.CFrame:Lerp(target, step / dist)
	end
end)

print("[SnowDemonSpawner] Loaded - " .. #SPAWN_POSITIONS .. " Snow Demon spawn points active")
