local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NPCModels = ReplicatedStorage:WaitForChild("NPCModels")
local DummyTemplate = NPCModels:WaitForChild("TrainingDummy")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerDataModule = require(Modules:WaitForChild("PlayerDataModule"))
local SkillSystemModule = require(Modules:WaitForChild("SkillSystemModule"))

local DUMMY_HP = 500
local DUMMY_XP_REWARD = 25
local RESPAWN_TIME = 3
local FADE_TIME = 1

local GRID_ORIGIN_X = 10
local GRID_ORIGIN_Z = 8
local GRID_COLS = 4
local GRID_ROWS = 3
local GRID_SPACING = 8
local FALLBACK_Y = 0.5
local MODEL_HALF_HEIGHT = 3

local SPAWN_POSITIONS = {}
for row = 0, GRID_ROWS - 1 do
	for col = 0, GRID_COLS - 1 do
		local x = GRID_ORIGIN_X + col * GRID_SPACING
		local z = GRID_ORIGIN_Z + row * GRID_SPACING
		table.insert(SPAWN_POSITIONS, CFrame.new(x, FALLBACK_Y + MODEL_HALF_HEIGHT, z))
	end
end

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
	nameLabel.Text = "Training Dummy"
	nameLabel.ZIndex = 4
	nameLabel.Parent = bg

	return billboard, fill, damageFill, label
end

local function spawnDummy(spawnCFrame)
	local dummy = DummyTemplate:Clone()
	dummy.Name = "TrainingDummy"

	local hrp = dummy:FindFirstChild("HumanoidRootPart")
	if not hrp then
		warn("[TrainingDummyServer] Template missing HumanoidRootPart")
		dummy:Destroy()
		return
	end
	hrp.Anchored = true

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

	dummy.PrimaryPart = streamAnchor

	for _, part in dummy:GetDescendants() do
		if part:IsA("BasePart") and part ~= streamAnchor then
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
	dummy:SetAttribute("XPReward", DUMMY_XP_REWARD)

	dummy:PivotTo(spawnCFrame)
	dummy.Parent = dummiesFolder

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
				PlayerDataModule.addXP(attacker, DUMMY_XP_REWARD)
				print("[TrainingDummyServer] Awarded " .. DUMMY_XP_REWARD .. " XP to " .. attacker.Name)

				-- selene: allow(global_usage)
				if shared.QuestServer and shared.QuestServer.onEnemyKilled then
					-- selene: allow(global_usage)
					shared.QuestServer.onEnemyKilled(attacker, "TrainingDummy")
				end

				-- selene: allow(global_usage)
				if shared.BountyServer and shared.BountyServer.onEnemyKilled then
					-- selene: allow(global_usage)
					shared.BountyServer.onEnemyKilled(attacker, "TrainingDummy")
				end

				local data = PlayerDataModule.getData(attacker)
				if data and data.Faction ~= "" then
					local factionSkills = SkillSystemModule.getSkillsForFaction(data.Faction)
					for _, skill in factionSkills do
						PlayerDataModule.addMasteryXP(attacker, skill.Id, 1)
					end
					print("[TrainingDummyServer] Awarded 1 mastery XP per equipped style to " .. attacker.Name)
				end
			end
		end

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

	print("[TrainingDummyServer] Spawned dummy at " .. tostring(spawnCFrame.Position))
	return dummy
end

for _, cframe in SPAWN_POSITIONS do
	spawnDummy(cframe)
end

print("[TrainingDummyServer] Loaded - " .. #SPAWN_POSITIONS .. " dummy(s) spawned")