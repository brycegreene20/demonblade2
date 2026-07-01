local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NPCModels = ReplicatedStorage:WaitForChild("NPCModels")
local DummyTemplate = NPCModels:WaitForChild("TrainingDummy")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local CombatModule = require(Modules:WaitForChild("CombatModule"))
local WorldSpawnConfigModule = require(Modules:WaitForChild("WorldSpawnConfigModule"))

local DUMMY_HP = 500
local DUMMY_XP_REWARD = 25
local DUMMY_LEVEL = 1
local RESPAWN_TIME = 3
local FADE_TIME = 1
local DEBUG_DUMMY_SPAWNS = false
local DEBUG_DUMMY_REWARDS = false

local function debugSpawnLog(message)
	if DEBUG_DUMMY_SPAWNS then
		print("[TrainingDummyServer] " .. message)
	end
end

local function debugRewardLog(message)
	if DEBUG_DUMMY_REWARDS then
		print("[TrainingDummyServer] " .. message)
	end
end

local MODEL_HALF_HEIGHT = 3
local MARKERS_FOLDER_NAME = "DemonBlade2Markers"
local DUMMY_YARD_MARKER_NAME = "TrainingDummyYard"

local BAR_WIDTH = 4
local BAR_HEIGHT = 0.4
local BAR_STUDS_OFFSET = Vector3.new(0, 3, 0)
local HP_COLOR_FULL = Color3.fromRGB(50, 220, 80)
local HP_COLOR_MID = Color3.fromRGB(240, 200, 40)
local HP_COLOR_LOW = Color3.fromRGB(220, 50, 50)
local HP_BG_COLOR = Color3.fromRGB(40, 40, 40)

local dummiesFolder = Instance.new("Folder")
dummiesFolder.Name = "TrainingDummies"
dummiesFolder.Parent = workspace

local function getMarkerPart(markerName)
	local markersFolder = workspace:FindFirstChild(MARKERS_FOLDER_NAME)
	if not markersFolder then
		return nil
	end

	local marker = markersFolder:FindFirstChild(markerName)
	if marker and marker:IsA("BasePart") then
		return marker
	end
	return nil
end

local function getMarkerAttributeNumber(marker, attributeName, fallback)
	local value = marker:GetAttribute(attributeName)
	return type(value) == "number" and value or fallback
end

local function getRawSpawns()
	local marker = getMarkerPart(DUMMY_YARD_MARKER_NAME)
	if marker and WorldSpawnConfigModule.DUMMY_GRID.useMarkerOverride then
		local grid = WorldSpawnConfigModule.DUMMY_GRID
		local columns = math.max(1, math.floor(getMarkerAttributeNumber(marker, "Columns", grid.columns)))
		local rows = math.max(1, math.floor(getMarkerAttributeNumber(marker, "Rows", grid.rows)))
		local spacing = math.max(5, getMarkerAttributeNumber(marker, "Spacing", grid.spacing))
		local startX = marker.Position.X - ((columns - 1) * spacing) * 0.5
		local startZ = marker.Position.Z - ((rows - 1) * spacing) * 0.5
		local spawns = {}

		for row = 0, rows - 1 do
			for column = 0, columns - 1 do
				table.insert(spawns, {
					x = startX + column * spacing,
					z = startZ + row * spacing,
				})
			end
		end
		print(("[TrainingDummyServer] Using %s marker for %d dummy spawn(s)"):format(
			DUMMY_YARD_MARKER_NAME,
			#spawns
		))
		return spawns
	end

	return WorldSpawnConfigModule.getTrainingDummySpawns()
end

local RAW_SPAWNS = getRawSpawns()

local SPAWN_SEARCH_OFFSETS = {
	Vector2.new(0, 0),
	Vector2.new(6, 0),
	Vector2.new(-6, 0),
	Vector2.new(0, 6),
	Vector2.new(0, -6),
	Vector2.new(8, 8),
	Vector2.new(-8, 8),
	Vector2.new(8, -8),
	Vector2.new(-8, -8),
}

local function getGroundResult(x, z)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { dummiesFolder }
	local markersFolder = workspace:FindFirstChild(MARKERS_FOLDER_NAME)
	if markersFolder then
		table.insert(excluded, markersFolder)
	end
	raycastParams.FilterDescendantsInstances = excluded
	raycastParams.IgnoreWater = true
	raycastParams.RespectCanCollide = true

	return workspace:Raycast(Vector3.new(x, 350, z), Vector3.new(0, -800, 0), raycastParams)
end

local function hasSpawnClearance(cframe)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { dummiesFolder }
	local markersFolder = workspace:FindFirstChild(MARKERS_FOLDER_NAME)
	if markersFolder then
		table.insert(excluded, markersFolder)
	end
	overlapParams.FilterDescendantsInstances = excluded

	local parts = workspace:GetPartBoundsInBox(
		cframe * CFrame.new(0, 0.5, 0),
		Vector3.new(5, 5, 5),
		overlapParams
	)
	for _, part in parts do
		if part.CanCollide then
			return false
		end
	end
	return true
end

local function resolveSpawnCFrame(spawn)
	local firstGroundCFrame = nil
	for _, offset in SPAWN_SEARCH_OFFSETS do
		local x = spawn.x + offset.X
		local z = spawn.z + offset.Y
		local result = getGroundResult(x, z)
		if result and result.Normal.Y >= 0.65 then
			local cframe = CFrame.new(result.Position + Vector3.new(0, MODEL_HALF_HEIGHT, 0))
			firstGroundCFrame = firstGroundCFrame or cframe
			if hasSpawnClearance(cframe) then
				return cframe
			end
		end
	end

	if firstGroundCFrame then
		warn(("[TrainingDummyServer] Ground found for dummy at %.1f, %.1f but clearance was blocked; using grounded fallback"):format(
			spawn.x,
			spawn.z
		))
		return firstGroundCFrame
	end

	warn(("[TrainingDummyServer] No clear ground found for dummy at %.1f, %.1f; using configured fallback"):format(
		spawn.x,
		spawn.z
	))
	return CFrame.new(spawn.x, MODEL_HALF_HEIGHT, spawn.z)
end

local function getHPColor(ratio)
	if ratio > 0.5 then
		return HP_COLOR_MID:Lerp(HP_COLOR_FULL, (ratio - 0.5) / 0.5)
	else
		return HP_COLOR_LOW:Lerp(HP_COLOR_MID, ratio / 0.5)
	end
end

local function createHPBar(parent)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HPBarGui"
	billboard.Size = UDim2.fromScale(BAR_WIDTH, BAR_HEIGHT)
	billboard.StudsOffset = BAR_STUDS_OFFSET
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
	label.Text = DUMMY_HP .. " / " .. DUMMY_HP
	label.ZIndex = 4
	label.Parent = bg

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 0.8)
	nameLabel.Position = UDim2.fromScale(0, -1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = "Training Dummy [Lv." .. DUMMY_LEVEL .. "]"
	nameLabel.ZIndex = 4
	nameLabel.Parent = bg

	return billboard, fill, damageFill, label
end

local function spawnDummy(spawnCFrame)
	local dummy = DummyTemplate:Clone()
	dummy.Name = "TrainingDummy"
	dummy.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local hrp = dummy:FindFirstChild("HumanoidRootPart")
	if not hrp then
		warn("[TrainingDummyServer] Template missing HumanoidRootPart")
		dummy:Destroy()
		return
	end
	hrp.Anchored = true

	dummy.PrimaryPart = hrp

	for _, part in dummy:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			if part ~= hrp then
				part.CanCollide = true
			end
		end
	end

	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = dummy
	end
	humanoid.MaxHealth = DUMMY_HP
	humanoid.Health = DUMMY_HP
	humanoid.WalkSpeed = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false

	dummy:SetAttribute("EnemyType", "TrainingDummy")
	dummy:SetAttribute("Level", DUMMY_LEVEL)
	dummy:SetAttribute("XPReward", DUMMY_XP_REWARD)

	dummy:PivotTo(spawnCFrame)

	local streamAnchor = Instance.new("Part")
	streamAnchor.Name = "StreamAnchor"
	streamAnchor.Size = Vector3.new(1, 1, 1)
	streamAnchor.Transparency = 1
	streamAnchor.CanCollide = false
	streamAnchor.CanQuery = false
	streamAnchor.CanTouch = false
	streamAnchor.Anchored = true
	streamAnchor.CFrame = spawnCFrame
	streamAnchor.Parent = dummy

	dummy.Parent = dummiesFolder
	debugSpawnLog("Spawned dummy at " .. tostring(spawnCFrame.Position))

	local head = dummy:FindFirstChild("Head")
	local barParent = head or hrp
	local billboard, fill, damageFill, hpLabel = createHPBar(barParent)

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

	humanoid.HealthChanged:Connect(function()
		updateBar()
	end)

	humanoid.Died:Connect(function()
		for _, part in dummy:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanQuery = false
				part.CanTouch = false
			end
		end

		local lastAttackerId = dummy:GetAttribute("LastAttacker")
		if lastAttackerId then
			local attacker = Players:GetPlayerByUserId(lastAttackerId)
			if attacker then
				CombatModule.grantStateProgressionEvent(attacker, "Kill")
				local rewardPlayers = CombatModule.getRewardPlayers(dummy, attacker, 120)
				for _, rewardedPlayer in rewardPlayers do
					PlayerDataModule.addXP(rewardedPlayer, DUMMY_XP_REWARD)
					debugRewardLog("Awarded " .. DUMMY_XP_REWARD .. " XP to " .. rewardedPlayer.Name)

					-- selene: allow(global_usage)
					if shared.QuestServer and shared.QuestServer.onEnemyKilled then
						-- selene: allow(global_usage)
						shared.QuestServer.onEnemyKilled(rewardedPlayer, "TrainingDummy")
					end

					-- selene: allow(global_usage)
					if shared.BountyServer and shared.BountyServer.onEnemyKilled then
						-- selene: allow(global_usage)
						shared.BountyServer.onEnemyKilled(rewardedPlayer, "TrainingDummy")
					end

					local data = PlayerDataModule.getData(rewardedPlayer)
					if data and data.EquippedStyle and data.EquippedStyle ~= "" then
						PlayerDataModule.addMasteryXP(rewardedPlayer, data.EquippedStyle, 1)
						debugRewardLog("Awarded 1 mastery XP to " .. rewardedPlayer.Name .. " for style " .. data.EquippedStyle)
					end
				end
			end
		end
		CombatModule.clearDamageContributors(dummy)

		hpLabel.Text = "DEFEATED"
		fill.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		TweenService:Create(fill, TweenInfo.new(0.2), {Size = UDim2.fromScale(0, 1)}):Play()
		TweenService:Create(damageFill, TweenInfo.new(0.3), {Size = UDim2.fromScale(0, 1)}):Play()

		for _, part in dummy:GetDescendants() do
			if part:IsA("BasePart") and part ~= streamAnchor then
				TweenService:Create(part, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
				}):Play()
			end
		end

		if billboard then
			TweenService:Create(billboard, TweenInfo.new(FADE_TIME), {}):Play()
			task.delay(FADE_TIME, function()
				billboard.Enabled = false
			end)
		end

		task.delay(RESPAWN_TIME, function()
			if dummy and dummy.Parent then
				dummy:Destroy()
			end
			spawnDummy(spawnCFrame)
		end)
	end)

	return dummy
end

for _, spawn in RAW_SPAWNS do
	spawnDummy(resolveSpawnCFrame(spawn))
end

print("[TrainingDummyServer] Loaded - " .. #RAW_SPAWNS .. " dummy(s) spawned")
