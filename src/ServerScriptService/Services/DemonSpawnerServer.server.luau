local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local DemonTemplate = Assets:WaitForChild("ForestDemon")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local CombatModule = require(Modules:WaitForChild("CombatModule"))
local SkillSystemModule = require(Modules:WaitForChild("SkillSystemModule"))

local MASTERY_KILL_REWARDS = {
	[1] = 3, [2] = 5, [3] = 8, [4] = 12, [5] = 12,
	[6] = 20, [7] = 20, [8] = 20, [9] = 20, [10] = 20,
}

local ATTACK_RADIUS = 12
local ATTACK_COOLDOWN = 1.5
local ATTACK_WINDUP = CombatModule.NPC_ATTACK_WINDUP
local RESPAWN_TIME = 15
local AI_TICK = 0.5
local DEMON_HALF_HEIGHT = 3
local FALLBACK_Y = 0.5

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

local RAW_SPAWNS = {
	{ x = 10,  z = 26,  level = 1 },
	{ x = 18,  z = 26,  level = 1 },
	{ x = 26,  z = 26,  level = 1 },
	{ x = 34,  z = 26,  level = 1 },
	{ x = 60,  z = -60,  level = 2 },
	{ x = -50, z = -80,  level = 2 },
	{ x = 80,  z = -100, level = 3 },
	{ x = -70, z = -30,  level = 3 },
	{ x = 100, z = -40,  level = 4 },
	{ x = -90, z = -110, level = 5 },
	{ x = 50,  z = -130, level = 6 },
	{ x = -40, z = -150, level = 7 },
}

local SPAWN_POSITIONS = {}
for _, raw in RAW_SPAWNS do
	table.insert(SPAWN_POSITIONS, {
		pos = CFrame.new(raw.x, FALLBACK_Y + DEMON_HALF_HEIGHT, raw.z),
		level = raw.level,
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
	local stats = getStatsForLevel(level)

	local demon = DemonTemplate:Clone()
	demon.Name = "ForestDemon_Lv" .. level

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
	demon:SetAttribute("EnemyType", "ForestDemon")
	demon:SetAttribute("XPReward", stats.xp)

	demon.PrimaryPart = torso
	demon.Parent = demonsFolder

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

	print("[DemonSpawner] Parts repositioned for Lv." .. level .. " at " .. tostring(spawnCFrame.Position))
	for _, part in demon:GetDescendants() do
		if part:IsA("BasePart") then
			print("[DemonSpawner]   " .. part.Name .. " at " .. tostring(part.Position))
		end
	end

	CollectionService:AddTag(demon, "Demon")

	local head = demon:FindFirstChild("Head")
	local barParent = head or hrp
	local _billboard, fill, damageFill, hpLabel = createHPBar(barParent, "Forest Demon", level)
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

		for _, part in demon:GetDescendants() do
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
				PlayerDataModule.addXP(attacker, stats.xp)
				print("[DemonSpawner] Awarded " .. stats.xp .. " XP to " .. attacker.Name)

				-- selene: allow(global_usage)
				if shared.QuestServer and shared.QuestServer.onEnemyKilled then
					-- selene: allow(global_usage)
					shared.QuestServer.onEnemyKilled(attacker, "ForestDemon")
				end

				-- selene: allow(global_usage)
				if shared.BountyServer and shared.BountyServer.onEnemyKilled then
					-- selene: allow(global_usage)
					shared.BountyServer.onEnemyKilled(attacker, "ForestDemon", level)
				end

				local data = PlayerDataModule.getData(attacker)
				if data and data.Faction ~= "" then
					local rewardXP = MASTERY_KILL_REWARDS[level] or 3
					local factionSkills = SkillSystemModule.getSkillsForFaction(data.Faction)
					for _, skill in factionSkills do
						PlayerDataModule.addMasteryXP(attacker, skill.Id, rewardXP)
					end
					print("[DemonSpawner] Awarded " .. rewardXP .. " mastery XP per equipped style to " .. attacker.Name)
				end
			end
		end

		hpLabel.Text = "DEFEATED"
		fill.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		TweenService:Create(fill, TweenInfo.new(0.2), {
			Size = UDim2.fromScale(0, 1),
		}):Play()
		TweenService:Create(damageFill, TweenInfo.new(0.3), {
			Size = UDim2.fromScale(0, 1),
		}):Play()

		for _, part in demon:GetDescendants() do
			if part:IsA("BasePart") and part ~= hrp and part ~= streamAnchor then
				TweenService:Create(part, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
				}):Play()
			end
		end

		task.delay(RESPAWN_TIME, function()
			if demon and demon.Parent then
				demon:Destroy()
			end
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
	print("[DemonSpawner] Spawned Lv." .. level .. " sentinel demon at " .. tostring(spawnCFrame.Position))
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
			local closestPlayer, _dist = findPlayerInRadius(spawnPos, ATTACK_RADIUS)

			if closestPlayer then
				local targetHRP = closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart")
				if targetHRP then
					local direction = targetHRP.Position - spawnPos
					local flatDir = Vector3.new(direction.X, 0, direction.Z)
					if flatDir.Magnitude > 0.1 then
						local lookCFrame = CFrame.lookAt(spawnPos, spawnPos + flatDir.Unit)
						demon:PivotTo(lookCFrame)
					end
				end

				demonState.aiState = "attacking"

				local now = tick()
				if now - demonState.lastAttack >= ATTACK_COOLDOWN and not demonState.isAttacking then
					demonState.lastAttack = now
					demonState.isAttacking = true

					local debugMode = false
					local debugVal = demon:FindFirstChild("DebugHitbox")
					if debugVal and debugVal:IsA("BoolValue") then
						debugMode = debugVal.Value
					end

					task.delay(ATTACK_WINDUP, function()
						if not demonState.alive or not demon.Parent or demonState.humanoid.Health <= 0 then
							demonState.isAttacking = false
							return
						end
						CombatModule.processNPCAttack(demon, demonState.stats.damage, debugMode)
						demonState.isAttacking = false
					end)
				end
			else
				if demonState.aiState ~= "idle" then
					demonState.aiState = "idle"
					demon:PivotTo(demonState.spawnCFrame)
				end
			end
		end
	end
end)

print("[DemonSpawner] Loaded - " .. #SPAWN_POSITIONS .. " sentinel demon spawn points active")