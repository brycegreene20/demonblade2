local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AcceptQuestRemote = Remotes:WaitForChild("AcceptQuest")
local QuestUpdatedRemote = Remotes:WaitForChild("QuestUpdated")
local QuestCompletedRemote = Remotes:WaitForChild("QuestCompleted")
local GetAvailableQuestsRemote = Remotes:WaitForChild("GetAvailableQuests")
local QuestCompletedToastRemote = Remotes:WaitForChild("QuestCompletedToast")
local QuestTargetModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("QuestTargetModule"))

local TWEEN_FAST = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_BOUNCE = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local PANEL_BG = Color3.fromRGB(12, 14, 22)
local QUEST_AVAILABLE = Color3.fromRGB(255, 200, 50)
local QUEST_ACTIVE = Color3.fromRGB(80, 180, 255)
local QUEST_COMPLETED = Color3.fromRGB(80, 220, 100)
local QUEST_LOCKED = Color3.fromRGB(100, 100, 110)
local TEXT_COLOR = Color3.fromRGB(240, 240, 245)
local TEXT_DIM = Color3.fromRGB(160, 160, 175)
local SHADOW = Color3.fromRGB(0, 0, 0)
local TRACKER_BG = Color3.fromRGB(10, 12, 18)

local acceptSound = Instance.new("Sound")
acceptSound.SoundId = "rbxassetid://9125402735"
acceptSound.Volume = 0.5
acceptSound.Parent = SoundService

local completeSound = Instance.new("Sound")
completeSound.SoundId = "rbxassetid://9125402735"
completeSound.Volume = 0.7
completeSound.PlaybackSpeed = 1.3
completeSound.Parent = SoundService

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuestUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 8
screenGui.Parent = PlayerGui

-- ==================== QUEST DIALOG PANEL ====================
local dialogOverlay = Instance.new("Frame")
dialogOverlay.Name = "DialogOverlay"
dialogOverlay.Size = UDim2.fromScale(1, 1)
dialogOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dialogOverlay.BackgroundTransparency = 1
dialogOverlay.BorderSizePixel = 0
dialogOverlay.Visible = false
dialogOverlay.ZIndex = 20
dialogOverlay.Parent = screenGui

local dialogPanel = Instance.new("Frame")
dialogPanel.Name = "DialogPanel"
dialogPanel.Size = UDim2.fromOffset(420, 0)
dialogPanel.Position = UDim2.fromScale(0.5, 0.5)
dialogPanel.AnchorPoint = Vector2.new(0.5, 0.5)
dialogPanel.BackgroundColor3 = PANEL_BG
dialogPanel.BackgroundTransparency = 0.05
dialogPanel.BorderSizePixel = 0
dialogPanel.ZIndex = 21
dialogPanel.Parent = dialogOverlay

local dialogCorner = Instance.new("UICorner")
dialogCorner.CornerRadius = UDim.new(0, 12)
dialogCorner.Parent = dialogPanel

local dialogStroke = Instance.new("UIStroke")
dialogStroke.Color = Color3.fromRGB(60, 65, 80)
dialogStroke.Thickness = 1.5
dialogStroke.Parent = dialogPanel

local npcNameLabel = Instance.new("TextLabel")
npcNameLabel.Name = "NPCName"
npcNameLabel.Size = UDim2.new(1, -60, 0, 32)
npcNameLabel.Position = UDim2.fromOffset(16, 12)
npcNameLabel.BackgroundTransparency = 1
npcNameLabel.Font = Enum.Font.GothamBold
npcNameLabel.TextSize = 18
npcNameLabel.TextColor3 = QUEST_AVAILABLE
npcNameLabel.TextStrokeColor3 = SHADOW
npcNameLabel.TextStrokeTransparency = 0.5
npcNameLabel.TextXAlignment = Enum.TextXAlignment.Left
npcNameLabel.Text = ""
npcNameLabel.ZIndex = 22
npcNameLabel.Parent = dialogPanel

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.fromOffset(32, 32)
closeBtn.Position = UDim2.new(1, -44, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.fromRGB(220, 100, 100)
closeBtn.Text = "X"
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 22
closeBtn.Parent = dialogPanel

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 6)
closeBtnCorner.Parent = closeBtn

local questListFrame = Instance.new("ScrollingFrame")
questListFrame.Name = "QuestList"
questListFrame.Size = UDim2.new(1, -24, 1, -54)
questListFrame.Position = UDim2.fromOffset(12, 48)
questListFrame.BackgroundTransparency = 1
questListFrame.BorderSizePixel = 0
questListFrame.ScrollBarThickness = 4
questListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
questListFrame.CanvasSize = UDim2.fromOffset(0, 0)
questListFrame.ZIndex = 22
questListFrame.Parent = dialogPanel

local questListLayout = Instance.new("UIListLayout")
questListLayout.Padding = UDim.new(0, 8)
questListLayout.SortOrder = Enum.SortOrder.LayoutOrder
questListLayout.Parent = questListFrame

local dialogOpen = false
local __currentNpcId = nil

local function createQuestCard(questInfo, layoutOrder)
	local statusColor = QUEST_LOCKED
	local statusText = "Locked"
	if questInfo.status == "available" then
		statusColor = QUEST_AVAILABLE
		statusText = "Available"
	elseif questInfo.status == "active" then
		statusColor = QUEST_ACTIVE
		statusText = "In Progress"
	elseif questInfo.status == "completed" then
		statusColor = QUEST_COMPLETED
		local tc = questInfo.timesCompleted or 0
		statusText = tc > 1 and ("Completed x" .. tc) or "Completed"
		if questInfo.repeatable and questInfo.cooldownText then
			statusColor = Color3.fromRGB(140, 140, 160)
			statusText = questInfo.cooldownText
		end
	end

	local card = Instance.new("Frame")
	card.Name = "Quest_" .. questInfo.id
	card.Size = UDim2.new(1, 0, 0, 100)
	card.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	card.BackgroundTransparency = 0.2
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.ZIndex = 23
	card.Parent = questListFrame

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = statusColor
	cardStroke.Thickness = 1.5
	cardStroke.Transparency = 0.5
	cardStroke.Parent = card

	local statusBadge = Instance.new("Frame")
	statusBadge.Size = UDim2.new(0, 4, 1, -8)
	statusBadge.Position = UDim2.fromOffset(4, 4)
	statusBadge.BackgroundColor3 = statusColor
	statusBadge.BorderSizePixel = 0
	statusBadge.ZIndex = 24
	statusBadge.Parent = card

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 2)
	badgeCorner.Parent = statusBadge

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -100, 0, 22)
	titleLabel.Position = UDim2.fromOffset(16, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = TEXT_COLOR
	titleLabel.TextStrokeColor3 = SHADOW
	titleLabel.TextStrokeTransparency = 0.6
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = questInfo.title
	titleLabel.ZIndex = 24
	titleLabel.Parent = card

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.fromOffset(80, 18)
	statusLabel.Position = UDim2.new(1, -88, 0, 8)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 11
	statusLabel.TextColor3 = statusColor
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.Text = statusText
	statusLabel.ZIndex = 24
	statusLabel.Parent = card

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -24, 0, 30)
	descLabel.Position = UDim2.fromOffset(16, 28)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 11
	descLabel.TextColor3 = TEXT_DIM
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Text = questInfo.description
	descLabel.ZIndex = 24
	descLabel.Parent = card

	local xpLabel = Instance.new("TextLabel")
	xpLabel.Size = UDim2.fromOffset(80, 16)
	xpLabel.Position = UDim2.new(0, 16, 1, -24)
	xpLabel.BackgroundTransparency = 1
	xpLabel.Font = Enum.Font.GothamBold
	xpLabel.TextSize = 11
	xpLabel.TextColor3 = Color3.fromRGB(120, 80, 255)
	xpLabel.TextXAlignment = Enum.TextXAlignment.Left
	xpLabel.Text = "+" .. questInfo.xpReward .. " XP"
	xpLabel.ZIndex = 24
	xpLabel.Parent = card

	if questInfo.status == "available" then
		local acceptBtn = Instance.new("TextButton")
		acceptBtn.Size = UDim2.fromOffset(80, 28)
		acceptBtn.Position = UDim2.new(1, -92, 1, -36)
		acceptBtn.BackgroundColor3 = QUEST_AVAILABLE
		acceptBtn.BorderSizePixel = 0
		acceptBtn.Font = Enum.Font.GothamBold
		acceptBtn.TextSize = 12
		acceptBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
		acceptBtn.Text = "Accept"
		acceptBtn.AutoButtonColor = false
		acceptBtn.ZIndex = 24
		acceptBtn.Parent = card

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = acceptBtn

		acceptBtn.MouseEnter:Connect(function()
			TweenService:Create(acceptBtn, TWEEN_FAST, {BackgroundColor3 = Color3.fromRGB(255, 220, 80)}):Play()
		end)
		acceptBtn.MouseLeave:Connect(function()
			TweenService:Create(acceptBtn, TWEEN_FAST, {BackgroundColor3 = QUEST_AVAILABLE}):Play()
		end)

		acceptBtn.MouseButton1Click:Connect(function()
			acceptBtn.Text = "..."
			AcceptQuestRemote:FireServer(questInfo.id)
			acceptSound:Play()
			task.delay(0.5, function()
				closeDialog()
			end)
		end)
	elseif questInfo.status == "locked" then
		local lockLabel = Instance.new("TextLabel")
		lockLabel.Size = UDim2.fromOffset(120, 16)
		lockLabel.Position = UDim2.new(1, -132, 1, -24)
		lockLabel.BackgroundTransparency = 1
		lockLabel.Font = Enum.Font.Gotham
		lockLabel.TextSize = 10
		lockLabel.TextColor3 = Color3.fromRGB(120, 100, 100)
		lockLabel.TextXAlignment = Enum.TextXAlignment.Right
		lockLabel.Text = questInfo.lockReason or "Locked"
		lockLabel.ZIndex = 24
		lockLabel.Parent = card
	end

	return card
end

local function openDialog(npcId, npcName)
	if dialogOpen then return end
	dialogOpen = true
	_currentNpcId = npcId

	npcNameLabel.Text = npcName

	for _, child in questListFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local quests = GetAvailableQuestsRemote:InvokeServer(npcId)
	if not quests or #quests == 0 then
		dialogOpen = false
		return
	end

	local totalHeight = 0
	for i, questInfo in quests do
		createQuestCard(questInfo, i)
		totalHeight = totalHeight + 108
	end

	questListFrame.CanvasSize = UDim2.fromOffset(0, totalHeight)

	local panelHeight = math.min(54 + totalHeight + 12, 400)

	dialogOverlay.Visible = true
	dialogOverlay.BackgroundTransparency = 1
	dialogPanel.Size = UDim2.fromOffset(420, 0)
	dialogPanel.BackgroundTransparency = 1

	TweenService:Create(dialogOverlay, TWEEN_FAST, {BackgroundTransparency = 0.4}):Play()
	TweenService:Create(dialogPanel, TWEEN_BOUNCE, {
		Size = UDim2.fromOffset(420, panelHeight),
		BackgroundTransparency = 0.05,
	}):Play()
end

function closeDialog()
	if not dialogOpen then return end
	dialogOpen = false
	_currentNpcId = nil

	TweenService:Create(dialogPanel, TWEEN_FAST, {
		Size = UDim2.fromOffset(420, 0),
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(dialogOverlay, TWEEN_FAST, {BackgroundTransparency = 1}):Play()
	task.delay(0.25, function()
		if not dialogOpen then
			dialogOverlay.Visible = false
		end
	end)
end

closeBtn.MouseButton1Click:Connect(closeDialog)

closeBtn.MouseEnter:Connect(function()
	TweenService:Create(closeBtn, TWEEN_FAST, {BackgroundColor3 = Color3.fromRGB(100, 40, 40)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
	TweenService:Create(closeBtn, TWEEN_FAST, {BackgroundColor3 = Color3.fromRGB(60, 30, 30)}):Play()
end)

-- ==================== QUEST TRACKER HUD ====================
local trackerFrame = Instance.new("Frame")
trackerFrame.Name = "QuestTracker"
trackerFrame.Size = UDim2.fromOffset(260, 70)
trackerFrame.Position = UDim2.new(1, -20, 0, 100)
trackerFrame.AnchorPoint = Vector2.new(1, 0)
trackerFrame.BackgroundColor3 = TRACKER_BG
trackerFrame.BackgroundTransparency = 0.3
trackerFrame.BorderSizePixel = 0
trackerFrame.Visible = false
trackerFrame.ZIndex = 6
trackerFrame.Parent = screenGui

local trackerCorner = Instance.new("UICorner")
trackerCorner.CornerRadius = UDim.new(0, 8)
trackerCorner.Parent = trackerFrame

local trackerStroke = Instance.new("UIStroke")
trackerStroke.Color = Color3.fromRGB(40, 45, 55)
trackerStroke.Thickness = 1
trackerStroke.Transparency = 0.4
trackerStroke.Parent = trackerFrame

local trackerTitle = Instance.new("TextLabel")
trackerTitle.Name = "Title"
trackerTitle.Size = UDim2.new(1, -16, 0, 22)
trackerTitle.Position = UDim2.fromOffset(10, 6)
trackerTitle.BackgroundTransparency = 1
trackerTitle.Font = Enum.Font.GothamBold
trackerTitle.TextSize = 13
trackerTitle.TextColor3 = QUEST_AVAILABLE
trackerTitle.TextStrokeColor3 = SHADOW
trackerTitle.TextStrokeTransparency = 0.5
trackerTitle.TextXAlignment = Enum.TextXAlignment.Left
trackerTitle.Text = ""
trackerTitle.ZIndex = 7
trackerTitle.Parent = trackerFrame

local trackerObjective = Instance.new("TextLabel")
trackerObjective.Name = "Objective"
trackerObjective.Size = UDim2.new(1, -16, 0, 16)
trackerObjective.Position = UDim2.fromOffset(10, 30)
trackerObjective.BackgroundTransparency = 1
trackerObjective.Font = Enum.Font.Gotham
trackerObjective.TextSize = 12
trackerObjective.TextColor3 = TEXT_COLOR
trackerObjective.TextStrokeColor3 = SHADOW
trackerObjective.TextStrokeTransparency = 0.6
trackerObjective.TextXAlignment = Enum.TextXAlignment.Left
trackerObjective.Text = ""
trackerObjective.ZIndex = 7
trackerObjective.Parent = trackerFrame

local trackerProgress = Instance.new("TextLabel")
trackerProgress.Name = "Progress"
trackerProgress.Size = UDim2.new(1, -16, 0, 14)
trackerProgress.Position = UDim2.fromOffset(10, 48)
trackerProgress.BackgroundTransparency = 1
trackerProgress.Font = Enum.Font.GothamBold
trackerProgress.TextSize = 11
trackerProgress.TextColor3 = QUEST_ACTIVE
trackerProgress.TextStrokeColor3 = SHADOW
trackerProgress.TextStrokeTransparency = 0.6
trackerProgress.TextXAlignment = Enum.TextXAlignment.Left
trackerProgress.Text = ""
trackerProgress.ZIndex = 7
trackerProgress.Parent = trackerFrame

local compassFrame = Instance.new("Frame")
compassFrame.Name = "QuestCompass"
compassFrame.Size = UDim2.fromOffset(176, 50)
compassFrame.Position = UDim2.fromScale(0.5, 0.5)
compassFrame.AnchorPoint = Vector2.new(0.5, 1)
compassFrame.BackgroundColor3 = TRACKER_BG
compassFrame.BackgroundTransparency = 0.25
compassFrame.BorderSizePixel = 0
compassFrame.Visible = false
compassFrame.ZIndex = 6
compassFrame.Parent = screenGui

local compassCorner = Instance.new("UICorner")
compassCorner.CornerRadius = UDim.new(0, 8)
compassCorner.Parent = compassFrame

local compassStroke = Instance.new("UIStroke")
compassStroke.Color = QUEST_ACTIVE
compassStroke.Thickness = 1
compassStroke.Transparency = 0.35
compassStroke.Parent = compassFrame

local compassArrow = Instance.new("TextLabel")
compassArrow.Name = "Arrow"
compassArrow.Size = UDim2.fromOffset(40, 40)
compassArrow.Position = UDim2.fromOffset(7, 5)
compassArrow.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
compassArrow.BackgroundTransparency = 0.15
compassArrow.Font = Enum.Font.GothamBold
compassArrow.TextSize = 32
compassArrow.TextColor3 = QUEST_AVAILABLE
compassArrow.TextStrokeColor3 = SHADOW
compassArrow.TextStrokeTransparency = 0.35
compassArrow.Text = "↑"
compassArrow.ZIndex = 7
compassArrow.Parent = compassFrame

local compassArrowCorner = Instance.new("UICorner")
compassArrowCorner.CornerRadius = UDim.new(1, 0)
compassArrowCorner.Parent = compassArrow

local compassTargetLabel = Instance.new("TextLabel")
compassTargetLabel.Name = "Target"
compassTargetLabel.Size = UDim2.new(1, -56, 0, 21)
compassTargetLabel.Position = UDim2.fromOffset(52, 5)
compassTargetLabel.BackgroundTransparency = 1
compassTargetLabel.Font = Enum.Font.GothamBold
compassTargetLabel.TextSize = 12
compassTargetLabel.TextColor3 = TEXT_COLOR
compassTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
compassTargetLabel.Text = "QUEST TARGET"
compassTargetLabel.ZIndex = 7
compassTargetLabel.Parent = compassFrame

local compassDistanceLabel = Instance.new("TextLabel")
compassDistanceLabel.Name = "Distance"
compassDistanceLabel.Size = UDim2.new(1, -56, 0, 18)
compassDistanceLabel.Position = UDim2.fromOffset(52, 27)
compassDistanceLabel.BackgroundTransparency = 1
compassDistanceLabel.Font = Enum.Font.GothamMedium
compassDistanceLabel.TextSize = 11
compassDistanceLabel.TextColor3 = TEXT_DIM
compassDistanceLabel.TextXAlignment = Enum.TextXAlignment.Left
compassDistanceLabel.Text = ""
compassDistanceLabel.ZIndex = 7
compassDistanceLabel.Parent = compassFrame

local activeQuestTargetType = nil
local compassTargetModel = nil

local function getEnemyFolder(enemyType)
	if enemyType == "TrainingDummy" then
		return workspace:FindFirstChild("TrainingDummies")
	end
	if enemyType == "ForestDemon" or enemyType == "DemonBoss" then
		return workspace:FindFirstChild("ForestDemons")
	end
	return nil
end

local function findNearestQuestTarget(enemyType)
	local folder = getEnemyFolder(enemyType)
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not folder or not root then return nil end

	local nearest = nil
	local nearestDistance = math.huge
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("EnemyType") == enemyType then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if humanoid and humanoid.Health > 0 and targetRoot then
				local distance = (targetRoot.Position - root.Position).Magnitude
				if distance < nearestDistance then
					nearest = model
					nearestDistance = distance
				end
			end
		end
	end
	return nearest
end

local function refreshQuestCompass()
	if not activeQuestTargetType then
		compassTargetModel = nil
		compassFrame.Visible = false
		return
	end

	compassTargetModel = findNearestQuestTarget(activeQuestTargetType)
	compassFrame.Visible = true
	compassArrow.Visible = compassTargetModel ~= nil
	compassTargetLabel.Text = activeQuestTargetType == "TrainingDummy" and "TRAINING DUMMY"
		or (activeQuestTargetType == "DemonBoss" and "DEMON BOSS" or "FOREST DEMON")
	if not compassTargetModel then
		compassDistanceLabel.Text = "Target respawning..."
	end
end

local function updateTracker(data)
	if not data then
		trackerFrame.Visible = false
		activeQuestTargetType = nil
		refreshQuestCompass()
		return
	end

	trackerTitle.Text = data.title
	trackerFrame.Visible = true
	activeQuestTargetType = QuestTargetModule.getIncompleteEnemyType(data.objectives, data.progress)
	refreshQuestCompass()

	local objectiveTexts = {}
	local progressTexts = {}
	for i, obj in data.objectives do
		local current = data.progress[i] or 0
		local required = obj.required
		table.insert(objectiveTexts, obj.label)
		table.insert(progressTexts, current .. " / " .. required)
	end

	trackerObjective.Text = table.concat(objectiveTexts, " | ")
	trackerProgress.Text = table.concat(progressTexts, " | ")

	local allDone = true
	for i, obj in data.objectives do
		if (data.progress[i] or 0) < obj.required then
			allDone = false
			break
		end
	end

	if allDone then
		trackerProgress.TextColor3 = QUEST_COMPLETED
	else
		trackerProgress.TextColor3 = QUEST_ACTIVE
	end
end

local compassSearchElapsed = 0
RunService.RenderStepped:Connect(function(dt)
	compassSearchElapsed += dt
	if compassSearchElapsed >= 0.5 then
		compassSearchElapsed = 0
		if activeQuestTargetType then
			local humanoid = compassTargetModel and compassTargetModel:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				refreshQuestCompass()
			end
		end
	end

	if not activeQuestTargetType then
		compassFrame.Visible = false
		return
	end

	local character = LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not head or not root or not camera then
		compassFrame.Visible = false
		return
	end

	local viewportPoint, onScreen = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 2.8, 0))
	compassFrame.Visible = onScreen
	if not onScreen then return end
	compassFrame.Position = UDim2.fromOffset(viewportPoint.X, viewportPoint.Y - 8)

	if not compassTargetModel then return end
	local targetRoot = compassTargetModel:FindFirstChild("HumanoidRootPart") or compassTargetModel.PrimaryPart
	if not targetRoot then return end

	local offset = targetRoot.Position - root.Position
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	if flatOffset.Magnitude < 0.01 then return end
	local direction = flatOffset.Unit
	local cameraLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local cameraRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	if cameraLook.Magnitude < 0.01 or cameraRight.Magnitude < 0.01 then return end

	local angle = math.atan2(cameraRight.Unit:Dot(direction), cameraLook.Unit:Dot(direction))
	compassArrow.Rotation = math.deg(angle)
	compassDistanceLabel.Text = tostring(math.floor(offset.Magnitude + 0.5)) .. " studs"
end)

-- ==================== QUEST COMPLETE NOTIFICATION ====================
local completeFrame = Instance.new("Frame")
completeFrame.Name = "QuestComplete"
completeFrame.Size = UDim2.fromOffset(320, 70)
completeFrame.Position = UDim2.fromScale(0.5, 0.18)
completeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
completeFrame.BackgroundColor3 = Color3.fromRGB(15, 25, 15)
completeFrame.BackgroundTransparency = 0.1
completeFrame.BorderSizePixel = 0
completeFrame.Visible = false
completeFrame.ZIndex = 18
completeFrame.Parent = screenGui

local completeCorner = Instance.new("UICorner")
completeCorner.CornerRadius = UDim.new(0, 10)
completeCorner.Parent = completeFrame

local completeStroke = Instance.new("UIStroke")
completeStroke.Color = QUEST_COMPLETED
completeStroke.Thickness = 2
completeStroke.Transparency = 0.3
completeStroke.Parent = completeFrame

local completeTitle = Instance.new("TextLabel")
completeTitle.Size = UDim2.new(1, 0, 0, 30)
completeTitle.Position = UDim2.fromOffset(0, 8)
completeTitle.BackgroundTransparency = 1
completeTitle.Font = Enum.Font.GothamBold
completeTitle.TextSize = 20
completeTitle.TextColor3 = QUEST_COMPLETED
completeTitle.TextStrokeColor3 = SHADOW
completeTitle.TextStrokeTransparency = 0.3
completeTitle.Text = "QUEST COMPLETE!"
completeTitle.ZIndex = 19
completeTitle.Parent = completeFrame

local completeSub = Instance.new("TextLabel")
completeSub.Size = UDim2.new(1, 0, 0, 20)
completeSub.Position = UDim2.fromOffset(0, 38)
completeSub.BackgroundTransparency = 1
completeSub.Font = Enum.Font.GothamMedium
completeSub.TextSize = 14
completeSub.TextColor3 = Color3.fromRGB(200, 200, 220)
completeSub.TextStrokeColor3 = SHADOW
completeSub.TextStrokeTransparency = 0.5
completeSub.Text = ""
completeSub.ZIndex = 19
completeSub.Parent = completeFrame

local function showQuestComplete(data)
	completeSub.Text = data.title
		.. "  +"
		.. data.xpReward
		.. " XP  +"
		.. (data.masteryXPReward or 0)
		.. " Mastery  +"
		.. (data.titleXPReward or 0)
		.. " Title"
	completeFrame.Visible = true
	completeFrame.Position = UDim2.fromScale(0.5, 0.14)
	completeFrame.BackgroundTransparency = 1
	completeTitle.TextTransparency = 1
	completeSub.TextTransparency = 1

	TweenService:Create(completeFrame, TWEEN_BOUNCE, {
		Position = UDim2.fromScale(0.5, 0.18),
		BackgroundTransparency = 0.1,
	}):Play()
	TweenService:Create(completeTitle, TweenInfo.new(0.25), {TextTransparency = 0}):Play()
	TweenService:Create(completeSub, TweenInfo.new(0.25), {TextTransparency = 0}):Play()

	completeSound:Play()

	task.delay(3.5, function()
		TweenService:Create(completeFrame, TWEEN_FAST, {
			Position = UDim2.fromScale(0.5, 0.14),
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(completeTitle, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(completeSub, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		task.delay(0.3, function()
			completeFrame.Visible = false
		end)
	end)
end

-- ==================== QUEST COMPLETED TOAST (Repeat Quest) ====================
local TOAST_COLOR = Color3.fromRGB(18, 22, 30)
local TOAST_ACCENT = Color3.fromRGB(255, 200, 50)
local TWEEN_SLIDE = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local toastFrame = Instance.new("Frame")
toastFrame.Name = "QuestToast"
toastFrame.Size = UDim2.fromOffset(300, 90)
toastFrame.Position = UDim2.new(1, 320, 0, 100)
toastFrame.AnchorPoint = Vector2.new(1, 0)
toastFrame.BackgroundColor3 = TOAST_COLOR
toastFrame.BackgroundTransparency = 0.05
toastFrame.BorderSizePixel = 0
toastFrame.Visible = false
toastFrame.ZIndex = 30
toastFrame.Parent = screenGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = toastFrame

local toastStroke = Instance.new("UIStroke")
toastStroke.Color = TOAST_ACCENT
toastStroke.Thickness = 1.5
toastStroke.Transparency = 0.3
toastStroke.Parent = toastFrame

local toastAccentBar = Instance.new("Frame")
toastAccentBar.Size = UDim2.new(0, 4, 1, -8)
toastAccentBar.Position = UDim2.fromOffset(4, 4)
toastAccentBar.BackgroundColor3 = TOAST_ACCENT
toastAccentBar.BorderSizePixel = 0
toastAccentBar.ZIndex = 31
toastAccentBar.Parent = toastFrame

local toastAccentCorner = Instance.new("UICorner")
toastAccentCorner.CornerRadius = UDim.new(0, 2)
toastAccentCorner.Parent = toastAccentBar

local toastTitle = Instance.new("TextLabel")
toastTitle.Name = "Title"
toastTitle.Size = UDim2.new(1, -24, 0, 20)
toastTitle.Position = UDim2.fromOffset(16, 8)
toastTitle.BackgroundTransparency = 1
toastTitle.Font = Enum.Font.GothamBold
toastTitle.TextSize = 13
toastTitle.TextColor3 = TOAST_ACCENT
toastTitle.TextStrokeColor3 = SHADOW
toastTitle.TextStrokeTransparency = 0.5
toastTitle.TextXAlignment = Enum.TextXAlignment.Left
toastTitle.Text = ""
toastTitle.ZIndex = 31
toastTitle.Parent = toastFrame

local toastXP = Instance.new("TextLabel")
toastXP.Name = "XP"
toastXP.Size = UDim2.new(1, -24, 0, 16)
toastXP.Position = UDim2.fromOffset(16, 30)
toastXP.BackgroundTransparency = 1
toastXP.Font = Enum.Font.GothamMedium
toastXP.TextSize = 11
toastXP.TextColor3 = Color3.fromRGB(120, 80, 255)
toastXP.TextStrokeColor3 = SHADOW
toastXP.TextStrokeTransparency = 0.6
toastXP.TextXAlignment = Enum.TextXAlignment.Left
toastXP.Text = ""
toastXP.ZIndex = 31
toastXP.Parent = toastFrame

local toastRepeatBtn = Instance.new("TextButton")
toastRepeatBtn.Name = "RepeatBtn"
toastRepeatBtn.Size = UDim2.fromOffset(120, 28)
toastRepeatBtn.Position = UDim2.new(0, 16, 1, -36)
toastRepeatBtn.BackgroundColor3 = TOAST_ACCENT
toastRepeatBtn.BorderSizePixel = 0
toastRepeatBtn.Font = Enum.Font.GothamBold
toastRepeatBtn.TextSize = 12
toastRepeatBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
toastRepeatBtn.Text = "↺ Repeat Quest"
toastRepeatBtn.AutoButtonColor = false
toastRepeatBtn.ZIndex = 31
toastRepeatBtn.Parent = toastFrame

local toastRepeatCorner = Instance.new("UICorner")
toastRepeatCorner.CornerRadius = UDim.new(0, 6)
toastRepeatCorner.Parent = toastRepeatBtn

local toastDismissBtn = Instance.new("TextButton")
toastDismissBtn.Name = "DismissBtn"
toastDismissBtn.Size = UDim2.fromOffset(24, 24)
toastDismissBtn.Position = UDim2.new(1, -32, 0, 6)
toastDismissBtn.BackgroundTransparency = 1
toastDismissBtn.Font = Enum.Font.GothamBold
toastDismissBtn.TextSize = 14
toastDismissBtn.TextColor3 = Color3.fromRGB(160, 160, 175)
toastDismissBtn.Text = "✕"
toastDismissBtn.ZIndex = 31
toastDismissBtn.Parent = toastFrame

local toastQuestId = nil
local toastDismissThread = nil
local TOAST_AUTO_DISMISS_SECONDS = 6.5

local function dismissToast()
	if toastDismissThread then
		task.cancel(toastDismissThread)
		toastDismissThread = nil
	end
	TweenService:Create(toastFrame, TWEEN_SLIDE, {
		Position = UDim2.new(1, 320, 0, 100),
	}):Play()
	task.delay(0.35, function()
		toastFrame.Visible = false
		toastQuestId = nil
	end)
end

local function showToast(data)
	if toastDismissThread then
		task.cancel(toastDismissThread)
		toastDismissThread = nil
	end

	toastQuestId = data.questId
	toastTitle.Text = data.title
	toastXP.Text = "+"
		.. data.xpReward
		.. " XP  |  +"
		.. (data.masteryXPReward or 0)
		.. " Mastery  |  +"
		.. (data.titleXPReward or 0)
		.. " Title"

	toastFrame.Visible = true
	toastFrame.Position = UDim2.new(1, 320, 0, 100)

	TweenService:Create(toastFrame, TWEEN_SLIDE, {
		Position = UDim2.new(1, -20, 0, 100),
	}):Play()

	toastDismissThread = task.delay(TOAST_AUTO_DISMISS_SECONDS, function()
		toastDismissThread = nil
		dismissToast()
	end)
end

toastRepeatBtn.MouseEnter:Connect(function()
	TweenService:Create(toastRepeatBtn, TWEEN_FAST, {BackgroundColor3 = Color3.fromRGB(255, 220, 80)}):Play()
end)
toastRepeatBtn.MouseLeave:Connect(function()
	TweenService:Create(toastRepeatBtn, TWEEN_FAST, {BackgroundColor3 = TOAST_ACCENT}):Play()
end)

toastRepeatBtn.MouseButton1Click:Connect(function()
	if not toastQuestId then return end
	local qId = toastQuestId
	toastRepeatBtn.Text = "..."
	AcceptQuestRemote:FireServer(qId)
	acceptSound:Play()
	task.delay(0.3, function()
		toastRepeatBtn.Text = "↺ Repeat Quest"
		dismissToast()
	end)
end)

toastDismissBtn.MouseButton1Click:Connect(dismissToast)

-- ==================== EVENT CONNECTIONS ====================
QuestUpdatedRemote.OnClientEvent:Connect(function(data)
	updateTracker(data)
end)

QuestCompletedRemote.OnClientEvent:Connect(function(data)
	showQuestComplete(data)
	updateTracker(nil)
end)

QuestCompletedToastRemote.OnClientEvent:Connect(function(data)
	if data.isRepeatable then
		showToast(data)
	end
end)

-- ==================== NPC PROXIMITY PROMPT ====================
local NPC_NAMES = {
	QuestNPC_Elder = "Trainer Urokodaki",
	QuestNPC_Scout = "Merchant Aoi",
	QuestNPC_Officer = "Corps Officer",
}

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if player ~= LocalPlayer then return end
	if prompt.Name ~= "TalkPrompt" then return end

	local npcModel = prompt.Parent and prompt.Parent.Parent
	if not npcModel then return end

	local npcId = npcModel.Name
	local npcName = NPC_NAMES[npcId] or npcId

	if not npcId:match("^QuestNPC_") then return end

	openDialog(npcId, npcName)
end)

print("[QuestController] Loaded")
