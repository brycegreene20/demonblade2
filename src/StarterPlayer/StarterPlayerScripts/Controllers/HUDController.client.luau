local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HPChanged = Remotes:WaitForChild("HPChanged")
local StaminaChanged = Remotes:WaitForChild("StaminaChanged")
local PlayerDeath = Remotes:WaitForChild("PlayerDeath")
local PlayerRespawn = Remotes:WaitForChild("PlayerRespawn")
local StatsChanged = Remotes:WaitForChild("StatsChanged")
local LevelUpRemote = Remotes:WaitForChild("LevelUp")
local StatPointsChanged = Remotes:WaitForChild("StatPointsChanged")
local AllocateStatRemote = Remotes:WaitForChild("AllocateStat")
local ChooseFactionRemote = Remotes:WaitForChild("ChooseFaction")
local FactionChosenRemote = Remotes:WaitForChild("FactionChosen")
local ShowFactionSelectRemote = Remotes:WaitForChild("ShowFactionSelect")
local RespecStatsRemote = Remotes:WaitForChild("RespecStats")
local RespecResultRemote = Remotes:WaitForChild("RespecResult")
local ResetFactionRemote = Remotes:WaitForChild("ResetFaction")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SkillSystemModule = require(Modules:WaitForChild("SkillSystemModule"))

local BAR_WIDTH = 260
local BAR_HEIGHT = 22
local STAMINA_BAR_HEIGHT = 14
local XP_BAR_HEIGHT = 10
local MASTERY_BAR_HEIGHT = 8
local CORNER_RADIUS = 6
local PADDING = 12
local BOTTOM_OFFSET = 40

local HP_COLOR = Color3.fromRGB(220, 50, 50)
local HP_BG = Color3.fromRGB(60, 15, 15)
local HP_DAMAGE_COLOR = Color3.fromRGB(255, 160, 60)
local STAMINA_COLOR = Color3.fromRGB(60, 180, 220)
local STAMINA_BG = Color3.fromRGB(15, 45, 60)
local XP_COLOR = Color3.fromRGB(120, 80, 255)
local XP_BG = Color3.fromRGB(30, 20, 60)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local SHADOW_COLOR = Color3.fromRGB(0, 0, 0)
local DEATH_OVERLAY_COLOR = Color3.fromRGB(0, 0, 0)

local STAT_PANEL_BG = Color3.fromRGB(15, 18, 25)
local STAT_BTN_COLOR = Color3.fromRGB(45, 50, 65)
local STAT_BTN_HOVER = Color3.fromRGB(65, 70, 90)
local STAT_BTN_DISABLED = Color3.fromRGB(30, 32, 40)
local _STRENGTH_COLOR = Color3.fromRGB(255, 80, 80)
local _SPEED_COLOR = Color3.fromRGB(80, 200, 255)
local _BREATH_COLOR = Color3.fromRGB(80, 255, 120)
local GOLD_COLOR = Color3.fromRGB(255, 220, 50)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 5
screenGui.Parent = PlayerGui

local container = Instance.new("Frame")
container.Name = "BarContainer"
container.Size = UDim2.fromOffset(BAR_WIDTH + PADDING * 2, BAR_HEIGHT + STAMINA_BAR_HEIGHT + MASTERY_BAR_HEIGHT + XP_BAR_HEIGHT + PADDING * 3 + 68)
container.Position = UDim2.new(0, 20, 1, -BOTTOM_OFFSET)
container.AnchorPoint = Vector2.new(0, 1)
container.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
container.BackgroundTransparency = 0.3
container.BorderSizePixel = 0
container.Parent = screenGui

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 10)
containerCorner.Parent = container

local containerStroke = Instance.new("UIStroke")
containerStroke.Color = Color3.fromRGB(40, 45, 55)
containerStroke.Thickness = 1.5
containerStroke.Transparency = 0.4
containerStroke.Parent = container

local function createBar(name, parent, yOffset, barHeight, fillColor, bgColor, showText)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(BAR_WIDTH, barHeight)
	frame.Position = UDim2.fromOffset(PADDING, yOffset)
	frame.BackgroundColor3 = bgColor
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CORNER_RADIUS)
	corner.Parent = frame

	local damageFill
	if name == "HPBar" then
		damageFill = Instance.new("Frame")
		damageFill.Name = "DamageFill"
		damageFill.Size = UDim2.fromScale(1, 1)
		damageFill.BackgroundColor3 = HP_DAMAGE_COLOR
		damageFill.BorderSizePixel = 0
		damageFill.ZIndex = 1
		damageFill.Parent = frame

		local damageFillCorner = Instance.new("UICorner")
		damageFillCorner.CornerRadius = UDim.new(0, CORNER_RADIUS)
		damageFillCorner.Parent = damageFill
	end

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = frame

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, CORNER_RADIUS)
	fillCorner.Parent = fill

	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0.7, 0.7, 0.7)),
	})
	fillGradient.Rotation = 90
	fillGradient.Parent = fill

	local label
	if showText then
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = TEXT_COLOR
		label.TextStrokeColor3 = SHADOW_COLOR
		label.TextStrokeTransparency = 0.5
		label.Text = ""
		label.ZIndex = 3
		label.Parent = frame
	end

	return {
		Frame = frame,
		Fill = fill,
		DamageFill = damageFill,
		Label = label,
	}
end

local hpLabel = Instance.new("TextLabel")
hpLabel.Name = "HPLabel"
hpLabel.Size = UDim2.fromOffset(BAR_WIDTH, 16)
hpLabel.Position = UDim2.fromOffset(PADDING, PADDING - 2)
hpLabel.BackgroundTransparency = 1
hpLabel.Font = Enum.Font.GothamBold
hpLabel.TextSize = 12
hpLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
hpLabel.TextStrokeColor3 = SHADOW_COLOR
hpLabel.TextStrokeTransparency = 0.6
hpLabel.TextXAlignment = Enum.TextXAlignment.Left
hpLabel.Text = "HP"
hpLabel.Parent = container

local hpBar = createBar("HPBar", container, PADDING + 14, BAR_HEIGHT, HP_COLOR, HP_BG, true)
local staminaBar = createBar("StaminaBar", container, PADDING + 14 + BAR_HEIGHT + 8, STAMINA_BAR_HEIGHT, STAMINA_COLOR, STAMINA_BG, false)

local masterySectionY = PADDING + 14 + BAR_HEIGHT + 8 + STAMINA_BAR_HEIGHT + 10

local MASTERY_BREATH_COLOR1 = Color3.fromRGB(60, 180, 220)
local MASTERY_BREATH_COLOR2 = Color3.fromRGB(40, 120, 180)
local MASTERY_DEMON_COLOR1 = Color3.fromRGB(180, 40, 40)
local MASTERY_DEMON_COLOR2 = Color3.fromRGB(120, 20, 50)
local MASTERY_GOLD_COLOR = Color3.fromRGB(255, 210, 50)
local MASTERY_BG = Color3.fromRGB(20, 25, 35)

local _MASTERY_MILESTONES = {10, 25, 50, 75, 100}
local MASTERY_MAX = 100

local masteryBarContainer = Instance.new("CanvasGroup")
masteryBarContainer.Name = "MasteryBarContainer"
masteryBarContainer.Size = UDim2.fromOffset(BAR_WIDTH, MASTERY_BAR_HEIGHT + 14)
masteryBarContainer.Position = UDim2.fromOffset(PADDING, masterySectionY)
masteryBarContainer.BackgroundTransparency = 1
masteryBarContainer.GroupTransparency = 0
masteryBarContainer.Parent = container

local masteryStyleLabel = Instance.new("TextLabel")
masteryStyleLabel.Name = "StyleLabel"
masteryStyleLabel.Size = UDim2.new(1, -50, 0, 12)
masteryStyleLabel.Position = UDim2.fromOffset(0, 0)
masteryStyleLabel.BackgroundTransparency = 1
masteryStyleLabel.Font = Enum.Font.GothamBold
masteryStyleLabel.TextSize = 11
masteryStyleLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
masteryStyleLabel.TextStrokeColor3 = SHADOW_COLOR
masteryStyleLabel.TextStrokeTransparency = 0.5
masteryStyleLabel.TextXAlignment = Enum.TextXAlignment.Left
masteryStyleLabel.Text = "No style equipped"
masteryStyleLabel.Parent = masteryBarContainer

local masteryLvLabel = Instance.new("TextLabel")
masteryLvLabel.Name = "LvLabel"
masteryLvLabel.Size = UDim2.fromOffset(50, 12)
masteryLvLabel.Position = UDim2.new(1, -50, 0, 0)
masteryLvLabel.BackgroundTransparency = 1
masteryLvLabel.Font = Enum.Font.GothamBold
masteryLvLabel.TextSize = 11
masteryLvLabel.TextColor3 = TEXT_COLOR
masteryLvLabel.TextStrokeColor3 = SHADOW_COLOR
masteryLvLabel.TextStrokeTransparency = 0.4
masteryLvLabel.TextXAlignment = Enum.TextXAlignment.Right
masteryLvLabel.Text = ""
masteryLvLabel.Parent = masteryBarContainer

local masteryBarBg = Instance.new("Frame")
masteryBarBg.Name = "MasteryBarBg"
masteryBarBg.Size = UDim2.new(1, 0, 0, MASTERY_BAR_HEIGHT)
masteryBarBg.Position = UDim2.fromOffset(0, 14)
masteryBarBg.BackgroundColor3 = MASTERY_BG
masteryBarBg.BorderSizePixel = 0
masteryBarBg.Parent = masteryBarContainer

local masteryBarBgCorner = Instance.new("UICorner")
masteryBarBgCorner.CornerRadius = UDim.new(0, 4)
masteryBarBgCorner.Parent = masteryBarBg

local masteryFill = Instance.new("Frame")
masteryFill.Name = "Fill"
masteryFill.Size = UDim2.fromScale(0, 1)
masteryFill.BackgroundColor3 = MASTERY_BREATH_COLOR1
masteryFill.BorderSizePixel = 0
masteryFill.ZIndex = 2
masteryFill.Parent = masteryBarBg

local masteryFillCorner = Instance.new("UICorner")
masteryFillCorner.CornerRadius = UDim.new(0, 4)
masteryFillCorner.Parent = masteryFill

local masteryFillGradient = Instance.new("UIGradient")
masteryFillGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.new(0.8, 0.8, 0.8)),
})
masteryFillGradient.Rotation = 90
masteryFillGradient.Parent = masteryFill

local xpSectionY = masterySectionY + MASTERY_BAR_HEIGHT + 14 + 6

local levelBadge = Instance.new("Frame")
levelBadge.Name = "LevelBadge"
levelBadge.Size = UDim2.fromOffset(36, 20)
levelBadge.Position = UDim2.fromOffset(PADDING, xpSectionY)
levelBadge.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
levelBadge.BorderSizePixel = 0
levelBadge.Parent = container

local levelBadgeCorner = Instance.new("UICorner")
levelBadgeCorner.CornerRadius = UDim.new(0, 4)
levelBadgeCorner.Parent = levelBadge

local levelText = Instance.new("TextLabel")
levelText.Name = "LevelText"
levelText.Size = UDim2.fromScale(1, 1)
levelText.BackgroundTransparency = 1
levelText.Font = Enum.Font.GothamBold
levelText.TextSize = 12
levelText.TextColor3 = TEXT_COLOR
levelText.TextStrokeColor3 = SHADOW_COLOR
levelText.TextStrokeTransparency = 0.5
levelText.Text = "Lv 1"
levelText.Parent = levelBadge

local xpBarFrame = Instance.new("Frame")
xpBarFrame.Name = "XPBar"
xpBarFrame.Size = UDim2.fromOffset(BAR_WIDTH - 42, XP_BAR_HEIGHT)
xpBarFrame.Position = UDim2.fromOffset(PADDING + 42, xpSectionY + 5)
xpBarFrame.BackgroundColor3 = XP_BG
xpBarFrame.BorderSizePixel = 0
xpBarFrame.Parent = container

local xpBarCorner = Instance.new("UICorner")
xpBarCorner.CornerRadius = UDim.new(0, 4)
xpBarCorner.Parent = xpBarFrame

local xpFill = Instance.new("Frame")
xpFill.Name = "Fill"
xpFill.Size = UDim2.fromScale(0, 1)
xpFill.BackgroundColor3 = XP_COLOR
xpFill.BorderSizePixel = 0
xpFill.ZIndex = 2
xpFill.Parent = xpBarFrame

local xpFillCorner = Instance.new("UICorner")
xpFillCorner.CornerRadius = UDim.new(0, 4)
xpFillCorner.Parent = xpFill

local xpLabel = Instance.new("TextLabel")
xpLabel.Name = "XPLabel"
xpLabel.Size = UDim2.fromScale(1, 1)
xpLabel.BackgroundTransparency = 1
xpLabel.Font = Enum.Font.GothamBold
xpLabel.TextSize = 9
xpLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
xpLabel.TextStrokeColor3 = SHADOW_COLOR
xpLabel.TextStrokeTransparency = 0.5
xpLabel.Text = "0 / 80 XP"
xpLabel.ZIndex = 3
xpLabel.Parent = xpBarFrame

local TWEEN_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_STAMINA = TweenInfo.new(0.1, Enum.EasingStyle.Linear)

local function updateHP(current, max)
	local ratio = math.clamp(current / max, 0, 1)
	TweenService:Create(hpBar.Fill, TWEEN_FAST, {Size = UDim2.fromScale(ratio, 1)}):Play()

	if hpBar.DamageFill then
		task.delay(0.3, function()
			TweenService:Create(hpBar.DamageFill, TWEEN_SLOW, {Size = UDim2.fromScale(ratio, 1)}):Play()
		end)
	end

	if hpBar.Label then
		hpBar.Label.Text = math.floor(current) .. " / " .. math.floor(max)
	end

	if ratio <= 0.25 then
		hpBar.Fill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	elseif ratio <= 0.5 then
		hpBar.Fill.BackgroundColor3 = Color3.fromRGB(240, 120, 40)
	else
		hpBar.Fill.BackgroundColor3 = HP_COLOR
	end
end

local function updateStamina(current, max)
	local ratio = math.clamp(current / max, 0, 1)
	TweenService:Create(staminaBar.Fill, TWEEN_STAMINA, {Size = UDim2.fromScale(ratio, 1)}):Play()

	if ratio <= 0.2 then
		staminaBar.Fill.BackgroundColor3 = Color3.fromRGB(40, 100, 140)
	else
		staminaBar.Fill.BackgroundColor3 = STAMINA_COLOR
	end
end

local TWEEN_XP = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function updateStats(level, xp, xpNeeded, _totalXP)
	levelText.Text = "Lv " .. level
	local ratio = math.clamp(xp / math.max(xpNeeded, 1), 0, 1)
	TweenService:Create(xpFill, TWEEN_XP, {Size = UDim2.fromScale(ratio, 1)}):Play()
	xpLabel.Text = xp .. " / " .. xpNeeded .. " XP"
end

local function flashLevelUp()
	local originalColor = levelBadge.BackgroundColor3
	levelBadge.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
	TweenService:Create(levelBadge, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = originalColor,
	}):Play()
end

local currentLevel = 1

-- ==================== STAT ALLOCATION PANEL ====================
local cachedStatPoints = 0
local cachedStatData = {}
local cachedFaction = ""
local statPanelOpen = false

local PANEL_HEIGHT = 400
local statPanel = Instance.new("Frame")
statPanel.Name = "StatPanel"
statPanel.Size = UDim2.fromOffset(310, PANEL_HEIGHT)
statPanel.Position = UDim2.fromScale(0.5, 0.5)
statPanel.AnchorPoint = Vector2.new(0.5, 0.5)
statPanel.BackgroundColor3 = STAT_PANEL_BG
statPanel.BackgroundTransparency = 0.05
statPanel.BorderSizePixel = 0
statPanel.Visible = false
statPanel.ZIndex = 15
statPanel.Parent = screenGui

local statPanelCorner = Instance.new("UICorner")
statPanelCorner.CornerRadius = UDim.new(0, 12)
statPanelCorner.Parent = statPanel

local statPanelStroke = Instance.new("UIStroke")
statPanelStroke.Color = Color3.fromRGB(60, 65, 80)
statPanelStroke.Thickness = 1.5
statPanelStroke.Parent = statPanel

local statTitle = Instance.new("TextLabel")
statTitle.Name = "Title"
statTitle.Size = UDim2.new(1, 0, 0, 36)
statTitle.Position = UDim2.fromOffset(0, 0)
statTitle.BackgroundTransparency = 1
statTitle.Font = Enum.Font.GothamBold
statTitle.TextSize = 16
statTitle.TextColor3 = TEXT_COLOR
statTitle.TextStrokeColor3 = SHADOW_COLOR
statTitle.TextStrokeTransparency = 0.5
statTitle.Text = "STAT ALLOCATION"
statTitle.ZIndex = 16
statTitle.Parent = statPanel

local statPointsLabel = Instance.new("TextLabel")
statPointsLabel.Name = "StatPoints"
statPointsLabel.Size = UDim2.new(1, -20, 0, 24)
statPointsLabel.Position = UDim2.fromOffset(10, 36)
statPointsLabel.BackgroundTransparency = 1
statPointsLabel.Font = Enum.Font.GothamBold
statPointsLabel.TextSize = 14
statPointsLabel.TextColor3 = GOLD_COLOR
statPointsLabel.TextStrokeColor3 = SHADOW_COLOR
statPointsLabel.TextStrokeTransparency = 0.5
statPointsLabel.TextXAlignment = Enum.TextXAlignment.Center
statPointsLabel.Text = "0 points available"
statPointsLabel.ZIndex = 16
statPointsLabel.Parent = statPanel

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, 0, 0, 20)
hintLabel.Position = UDim2.new(0, 0, 1, -22)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 11
hintLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
hintLabel.Text = "Press [P] to close"
hintLabel.ZIndex = 16
hintLabel.Parent = statPanel

local statRows = {}

local STAT_DEFS = {
	{key = "BreathDamage", display = "Breath DMG", desc = "+3% ability damage", color = Color3.fromRGB(80, 160, 220), faction = "Slayer"},
	{key = "DemonArtDamage", display = "Demon Art DMG", desc = "+3% ability damage", color = Color3.fromRGB(200, 60, 60), faction = "Demon"},
	{key = "Health", display = "Health", desc = "+15 max HP per point", color = Color3.fromRGB(220, 60, 60)},
	{key = "Defense", display = "Defense", desc = "Reduce damage taken (cap 64%)", color = Color3.fromRGB(180, 160, 60)},
	{key = "StaminaStat", display = "Stamina", desc = "+5 max stamina per point", color = Color3.fromRGB(60, 180, 220)},
	{key = "MovementSpeed", display = "Speed", desc = "+0.5 walk speed per point", color = Color3.fromRGB(80, 220, 140)},
}

local function createStatRow(def, yPos)
	local statName = def.key
	local row = Instance.new("Frame")
	row.Name = statName .. "Row"
	row.Size = UDim2.new(1, -20, 0, 46)
	row.Position = UDim2.fromOffset(10, yPos)
	row.BackgroundColor3 = Color3.fromRGB(22, 25, 35)
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel = 0
	row.ZIndex = 16
	row.Parent = statPanel

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 6)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.fromOffset(90, 20)
	nameLabel.Position = UDim2.fromOffset(10, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = def.color
	nameLabel.TextStrokeColor3 = SHADOW_COLOR
	nameLabel.TextStrokeTransparency = 0.6
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = def.display
	nameLabel.ZIndex = 17
	nameLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Desc"
	descLabel.Size = UDim2.fromOffset(140, 14)
	descLabel.Position = UDim2.fromOffset(10, 26)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 9
	descLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Text = def.desc
	descLabel.ZIndex = 17
	descLabel.Parent = row

	local derivedLabel = Instance.new("TextLabel")
	derivedLabel.Name = "Derived"
	derivedLabel.Size = UDim2.fromOffset(70, 14)
	derivedLabel.Position = UDim2.fromOffset(100, 4)
	derivedLabel.BackgroundTransparency = 1
	derivedLabel.Font = Enum.Font.GothamMedium
	derivedLabel.TextSize = 10
	derivedLabel.TextColor3 = Color3.fromRGB(170, 170, 190)
	derivedLabel.TextStrokeColor3 = SHADOW_COLOR
	derivedLabel.TextStrokeTransparency = 0.6
	derivedLabel.TextXAlignment = Enum.TextXAlignment.Left
	derivedLabel.Text = ""
	derivedLabel.ZIndex = 17
	derivedLabel.Parent = row

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.fromOffset(36, 46)
	valueLabel.Position = UDim2.new(1, -85, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 18
	valueLabel.TextColor3 = TEXT_COLOR
	valueLabel.TextStrokeColor3 = SHADOW_COLOR
	valueLabel.TextStrokeTransparency = 0.5
	valueLabel.Text = "0"
	valueLabel.ZIndex = 17
	valueLabel.Parent = row

	local addBtn = Instance.new("TextButton")
	addBtn.Name = "AddBtn"
	addBtn.Size = UDim2.fromOffset(38, 30)
	addBtn.Position = UDim2.new(1, -43, 0.5, 0)
	addBtn.AnchorPoint = Vector2.new(0, 0.5)
	addBtn.BackgroundColor3 = STAT_BTN_COLOR
	addBtn.BorderSizePixel = 0
	addBtn.Font = Enum.Font.GothamBold
	addBtn.TextSize = 18
	addBtn.TextColor3 = GOLD_COLOR
	addBtn.Text = "+"
	addBtn.ZIndex = 17
	addBtn.AutoButtonColor = false
	addBtn.Parent = row

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = addBtn

	addBtn.MouseEnter:Connect(function()
		if cachedStatPoints > 0 then
			TweenService:Create(addBtn, TweenInfo.new(0.1), {BackgroundColor3 = STAT_BTN_HOVER}):Play()
		end
	end)
	addBtn.MouseLeave:Connect(function()
		if cachedStatPoints > 0 then
			TweenService:Create(addBtn, TweenInfo.new(0.1), {BackgroundColor3 = STAT_BTN_COLOR}):Play()
		end
	end)

	addBtn.MouseButton1Click:Connect(function()
		if cachedStatPoints <= 0 then return end
		AllocateStatRemote:FireServer(statName)
	end)

	return {
		Row = row,
		ValueLabel = valueLabel,
		DerivedLabel = derivedLabel,
		AddBtn = addBtn,
		Def = def,
	}
end

local yPos = 68
for _, def in STAT_DEFS do
	statRows[def.key] = createStatRow(def, yPos)
	yPos = yPos + 52
end

-- ==================== RESPEC BUTTON ====================
local RESPEC_COOLDOWN = 86400
local cachedLastRespecTime = 0
local respecCooldownConn = nil

local respecBtn = Instance.new("TextButton")
respecBtn.Name = "RespecBtn"
respecBtn.Size = UDim2.fromOffset(130, 28)
respecBtn.Position = UDim2.new(0, 10, 1, -52)
respecBtn.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
respecBtn.BackgroundTransparency = 0.6
respecBtn.BorderSizePixel = 0
respecBtn.Font = Enum.Font.GothamMedium
respecBtn.TextSize = 11
respecBtn.TextColor3 = Color3.fromRGB(180, 160, 200)
respecBtn.Text = "Respec Points"
respecBtn.AutoButtonColor = false
respecBtn.ZIndex = 16
respecBtn.Parent = statPanel

local respecBtnCorner = Instance.new("UICorner")
respecBtnCorner.CornerRadius = UDim.new(0, 6)
respecBtnCorner.Parent = respecBtn

local respecBtnStroke = Instance.new("UIStroke")
respecBtnStroke.Color = Color3.fromRGB(100, 85, 140)
respecBtnStroke.Thickness = 1
respecBtnStroke.Transparency = 0.3
respecBtnStroke.Parent = respecBtn

local respecConfirmFrame = Instance.new("Frame")
respecConfirmFrame.Name = "RespecConfirm"
respecConfirmFrame.Size = UDim2.fromOffset(280, 140)
respecConfirmFrame.Position = UDim2.fromScale(0.5, 0.5)
respecConfirmFrame.AnchorPoint = Vector2.new(0.5, 0.5)
respecConfirmFrame.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
respecConfirmFrame.BackgroundTransparency = 0.02
respecConfirmFrame.BorderSizePixel = 0
respecConfirmFrame.Visible = false
respecConfirmFrame.ZIndex = 20
respecConfirmFrame.Parent = statPanel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = respecConfirmFrame
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(200, 80, 80)
	s.Thickness = 1.5
	s.Transparency = 0.2
	s.Parent = respecConfirmFrame
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.Size = UDim2.new(1, -20, 0, 24)
	t.Position = UDim2.fromOffset(10, 10)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextColor3 = Color3.fromRGB(220, 80, 80)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = "Reset Stat Points?"
	t.ZIndex = 21
	t.Parent = respecConfirmFrame
	local m = Instance.new("TextLabel")
	m.Name = "Message"
	m.Size = UDim2.new(1, -20, 0, 46)
	m.Position = UDim2.fromOffset(10, 36)
	m.BackgroundTransparency = 1
	m.Font = Enum.Font.Gotham
	m.TextSize = 11
	m.TextColor3 = Color3.fromRGB(170, 170, 190)
	m.TextWrapped = true
	m.TextXAlignment = Enum.TextXAlignment.Left
	m.TextYAlignment = Enum.TextYAlignment.Top
	m.Text = "Your current allocations will be cleared and all points refunded."
	m.ZIndex = 21
	m.Parent = respecConfirmFrame
	local yes = Instance.new("TextButton")
	yes.Name = "Confirm"
	yes.Size = UDim2.fromOffset(100, 30)
	yes.Position = UDim2.new(0, 20, 1, -42)
	yes.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	yes.BorderSizePixel = 0
	yes.Font = Enum.Font.GothamBold
	yes.TextSize = 12
	yes.TextColor3 = TEXT_COLOR
	yes.Text = "Confirm"
	yes.AutoButtonColor = false
	yes.ZIndex = 21
	yes.Parent = respecConfirmFrame
	local yc = Instance.new("UICorner")
	yc.CornerRadius = UDim.new(0, 6)
	yc.Parent = yes
	local no = Instance.new("TextButton")
	no.Name = "Cancel"
	no.Size = UDim2.fromOffset(100, 30)
	no.Position = UDim2.new(1, -120, 1, -42)
	no.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
	no.BorderSizePixel = 0
	no.Font = Enum.Font.GothamBold
	no.TextSize = 12
	no.TextColor3 = Color3.fromRGB(180, 180, 200)
	no.Text = "Cancel"
	no.AutoButtonColor = false
	no.ZIndex = 21
	no.Parent = respecConfirmFrame
	local nc = Instance.new("UICorner")
	nc.CornerRadius = UDim.new(0, 6)
	nc.Parent = no
	yes.MouseButton1Click:Connect(function()
		respecConfirmFrame.Visible = false
		RespecStatsRemote:FireServer()
	end)
	no.MouseButton1Click:Connect(function()
		respecConfirmFrame.Visible = false
	end)
	yes.MouseEnter:Connect(function()
		TweenService:Create(yes, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(210, 65, 65)}):Play()
	end)
	yes.MouseLeave:Connect(function()
		TweenService:Create(yes, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(180, 50, 50)}):Play()
	end)
	no.MouseEnter:Connect(function()
		TweenService:Create(no, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(70, 75, 95)}):Play()
	end)
	no.MouseLeave:Connect(function()
		TweenService:Create(no, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 55, 70)}):Play()
	end)
end

local function getRespecCooldownRemaining()
	if cachedLastRespecTime == 0 then return 0 end
	local elapsed = os.time() - cachedLastRespecTime
	return math.max(0, RESPEC_COOLDOWN - elapsed)
end

local function formatCooldown(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return string.format("Available in %dh %dm", h, m)
	else
		return string.format("Available in %dm", m)
	end
end

local function updateRespecButton()
	local remaining = getRespecCooldownRemaining()
	if remaining > 0 then
		respecBtn.Text = formatCooldown(remaining)
		respecBtn.TextColor3 = Color3.fromRGB(100, 95, 110)
		respecBtnStroke.Color = Color3.fromRGB(60, 55, 75)
		respecBtnStroke.Transparency = 0.6
	else
		respecBtn.Text = "Respec Points"
		respecBtn.TextColor3 = Color3.fromRGB(180, 160, 200)
		respecBtnStroke.Color = Color3.fromRGB(100, 85, 140)
		respecBtnStroke.Transparency = 0.3
	end
end

local function startRespecCooldownTick()
	if respecCooldownConn then return end
	respecCooldownConn = game:GetService("RunService").Heartbeat:Connect(function()
		if not statPanelOpen then
			if respecCooldownConn then
				respecCooldownConn:Disconnect()
				respecCooldownConn = nil
			end
			return
		end
		updateRespecButton()
	end)
end

respecBtn.MouseEnter:Connect(function()
	if getRespecCooldownRemaining() <= 0 then
		TweenService:Create(respecBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
		TweenService:Create(respecBtnStroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(140, 120, 180), Transparency = 0}):Play()
	end
end)

respecBtn.MouseLeave:Connect(function()
	TweenService:Create(respecBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.6}):Play()
	updateRespecButton()
end)

respecBtn.MouseButton1Click:Connect(function()
	if getRespecCooldownRemaining() > 0 then return end
	respecConfirmFrame.Visible = true
end)

-- ==================== CHANGE FACTION BUTTON ====================
local changeFactionBtn = Instance.new("TextButton")
changeFactionBtn.Name = "ChangeFactionBtn"
changeFactionBtn.Size = UDim2.fromOffset(140, 28)
changeFactionBtn.Position = UDim2.new(0, 150, 1, -52)
changeFactionBtn.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
changeFactionBtn.BackgroundTransparency = 0.6
changeFactionBtn.BorderSizePixel = 0
changeFactionBtn.Font = Enum.Font.GothamMedium
changeFactionBtn.TextSize = 11
changeFactionBtn.TextColor3 = Color3.fromRGB(200, 140, 80)
changeFactionBtn.Text = "Change Faction"
changeFactionBtn.AutoButtonColor = false
changeFactionBtn.ZIndex = 16
changeFactionBtn.Parent = statPanel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = changeFactionBtn
end
local changeFactionStroke = Instance.new("UIStroke")
changeFactionStroke.Color = Color3.fromRGB(160, 110, 50)
changeFactionStroke.Thickness = 1
changeFactionStroke.Transparency = 0.3
changeFactionStroke.Parent = changeFactionBtn

local factionResetConfirm = Instance.new("Frame")
factionResetConfirm.Name = "FactionResetConfirm"
factionResetConfirm.Size = UDim2.fromOffset(280, 155)
factionResetConfirm.Position = UDim2.fromScale(0.5, 0.5)
factionResetConfirm.AnchorPoint = Vector2.new(0.5, 0.5)
factionResetConfirm.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
factionResetConfirm.BackgroundTransparency = 0.02
factionResetConfirm.BorderSizePixel = 0
factionResetConfirm.Visible = false
factionResetConfirm.ZIndex = 22
factionResetConfirm.Parent = statPanel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = factionResetConfirm
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(200, 140, 50)
	s.Thickness = 1.5
	s.Transparency = 0.2
	s.Parent = factionResetConfirm
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -20, 0, 24)
	t.Position = UDim2.fromOffset(10, 10)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextColor3 = Color3.fromRGB(220, 160, 50)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = "Change Faction?"
	t.ZIndex = 23
	t.Parent = factionResetConfirm
	local m = Instance.new("TextLabel")
	m.Size = UDim2.new(1, -20, 0, 56)
	m.Position = UDim2.fromOffset(10, 36)
	m.BackgroundTransparency = 1
	m.Font = Enum.Font.Gotham
	m.TextSize = 11
	m.TextColor3 = Color3.fromRGB(170, 170, 190)
	m.TextWrapped = true
	m.TextXAlignment = Enum.TextXAlignment.Left
	m.TextYAlignment = Enum.TextYAlignment.Top
	m.Text = "Your faction will be reset and you will pick a new one. Faction-locked stat points (Breath DMG / Demon Art DMG) will be refunded."
	m.ZIndex = 23
	m.Parent = factionResetConfirm
	local yes = Instance.new("TextButton")
	yes.Size = UDim2.fromOffset(100, 30)
	yes.Position = UDim2.new(0, 20, 1, -42)
	yes.BackgroundColor3 = Color3.fromRGB(180, 120, 30)
	yes.BorderSizePixel = 0
	yes.Font = Enum.Font.GothamBold
	yes.TextSize = 12
	yes.TextColor3 = TEXT_COLOR
	yes.Text = "Confirm"
	yes.AutoButtonColor = false
	yes.ZIndex = 23
	yes.Parent = factionResetConfirm
	local yc = Instance.new("UICorner")
	yc.CornerRadius = UDim.new(0, 6)
	yc.Parent = yes
	local no = Instance.new("TextButton")
	no.Size = UDim2.fromOffset(100, 30)
	no.Position = UDim2.new(1, -120, 1, -42)
	no.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
	no.BorderSizePixel = 0
	no.Font = Enum.Font.GothamBold
	no.TextSize = 12
	no.TextColor3 = Color3.fromRGB(180, 180, 200)
	no.Text = "Cancel"
	no.AutoButtonColor = false
	no.ZIndex = 23
	no.Parent = factionResetConfirm
	local nc = Instance.new("UICorner")
	nc.CornerRadius = UDim.new(0, 6)
	nc.Parent = no
	yes.MouseButton1Click:Connect(function()
		factionResetConfirm.Visible = false
		ResetFactionRemote:FireServer()
	end)
	no.MouseButton1Click:Connect(function()
		factionResetConfirm.Visible = false
	end)
	yes.MouseEnter:Connect(function()
		TweenService:Create(yes, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(210, 145, 40)}):Play()
	end)
	yes.MouseLeave:Connect(function()
		TweenService:Create(yes, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(180, 120, 30)}):Play()
	end)
	no.MouseEnter:Connect(function()
		TweenService:Create(no, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(70, 75, 95)}):Play()
	end)
	no.MouseLeave:Connect(function()
		TweenService:Create(no, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 55, 70)}):Play()
	end)
end

changeFactionBtn.MouseEnter:Connect(function()
	TweenService:Create(changeFactionBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
	TweenService:Create(changeFactionStroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(200, 150, 70), Transparency = 0}):Play()
end)
changeFactionBtn.MouseLeave:Connect(function()
	TweenService:Create(changeFactionBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.6}):Play()
	TweenService:Create(changeFactionStroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(160, 110, 50), Transparency = 0.3}):Play()
end)
changeFactionBtn.MouseButton1Click:Connect(function()
	factionResetConfirm.Visible = true
end)

local function updateStatPanel()
	statPointsLabel.Text = cachedStatPoints .. " point" .. (cachedStatPoints ~= 1 and "s" or "") .. " available"
	local enabled = cachedStatPoints > 0

	for key, rowData in statRows do
		local def = rowData.Def
		local points = cachedStatData[key] or 0
		rowData.ValueLabel.Text = tostring(points)

		local factionMatch = not def.faction or (def.faction == cachedFaction)
		rowData.Row.Visible = factionMatch

		local canAllocate = enabled and factionMatch
		rowData.AddBtn.BackgroundColor3 = canAllocate and STAT_BTN_COLOR or STAT_BTN_DISABLED
		rowData.AddBtn.TextColor3 = canAllocate and GOLD_COLOR or Color3.fromRGB(80, 80, 90)

		if key == "Health" then
			local maxHP = cachedStatData.DerivedMaxHP or (150 + points * 15)
			rowData.DerivedLabel.Text = "HP: " .. math.floor(maxHP)
		elseif key == "Defense" then
			local defMult = cachedStatData.DerivedDefenseMultiplier or (math.min(points * 0.008, 0.64))
			rowData.DerivedLabel.Text = string.format("-%.0f%%", defMult * 100)
		elseif key == "StaminaStat" then
			local maxStam = cachedStatData.DerivedMaxStamina or (100 + points * 5)
			rowData.DerivedLabel.Text = "Stam: " .. math.floor(maxStam)
		elseif key == "MovementSpeed" then
			local ws = cachedStatData.DerivedWalkSpeed or math.min(24 + points * 0.5, 40)
			rowData.DerivedLabel.Text = string.format("WS: %.1f", ws)
		elseif key == "BreathDamage" or key == "DemonArtDamage" then
			local dmgMult = cachedStatData.DerivedDamageMultiplier or (1.0 + points * 0.03)
			rowData.DerivedLabel.Text = string.format("x%.2f", dmgMult)
		end
	end

	local visibleCount = 0
	local yOff = 68
	for _, def in STAT_DEFS do
		local rowData = statRows[def.key]
		if rowData.Row.Visible then
			rowData.Row.Position = UDim2.fromOffset(10, yOff)
			yOff = yOff + 52
			visibleCount = visibleCount + 1
		end
	end

	local respecY = yOff + 6
	respecBtn.Position = UDim2.fromOffset(10, respecY)
	changeFactionBtn.Position = UDim2.fromOffset(150, respecY)
	updateRespecButton()

	PANEL_HEIGHT = 68 + visibleCount * 52 + 42 + 30
	hintLabel.Position = UDim2.fromOffset(0, 68 + visibleCount * 52 + 42 + 6)

	if getRespecCooldownRemaining() > 0 then
		startRespecCooldownTick()
	end
end

local function toggleStatPanel()
	statPanelOpen = not statPanelOpen
	if statPanelOpen then
		updateStatPanel()
		statPanel.Visible = true
		statPanel.Size = UDim2.fromOffset(310, 0)
		statPanel.BackgroundTransparency = 1
		TweenService:Create(statPanel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(310, PANEL_HEIGHT),
			BackgroundTransparency = 0.05,
		}):Play()
		if getRespecCooldownRemaining() > 0 then
			startRespecCooldownTick()
		end
	else
		respecConfirmFrame.Visible = false
		TweenService:Create(statPanel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromOffset(310, 0),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.2, function()
			if not statPanelOpen then
				statPanel.Visible = false
			end
		end)
	end
end

-- ==================== LEVEL UP NOTIFICATION ====================
local levelUpFrame = Instance.new("Frame")
levelUpFrame.Name = "LevelUpNotif"
levelUpFrame.Size = UDim2.fromOffset(300, 80)
levelUpFrame.Position = UDim2.fromScale(0.5, 0.25)
levelUpFrame.AnchorPoint = Vector2.new(0.5, 0.5)
levelUpFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 40)
levelUpFrame.BackgroundTransparency = 0.15
levelUpFrame.BorderSizePixel = 0
levelUpFrame.Visible = false
levelUpFrame.ZIndex = 18
levelUpFrame.Parent = screenGui

local levelUpCorner = Instance.new("UICorner")
levelUpCorner.CornerRadius = UDim.new(0, 10)
levelUpCorner.Parent = levelUpFrame

local levelUpStroke = Instance.new("UIStroke")
levelUpStroke.Color = GOLD_COLOR
levelUpStroke.Thickness = 2
levelUpStroke.Transparency = 0.3
levelUpStroke.Parent = levelUpFrame

local levelUpTitle = Instance.new("TextLabel")
levelUpTitle.Name = "Title"
levelUpTitle.Size = UDim2.new(1, 0, 0, 36)
levelUpTitle.Position = UDim2.fromOffset(0, 8)
levelUpTitle.BackgroundTransparency = 1
levelUpTitle.Font = Enum.Font.GothamBold
levelUpTitle.TextSize = 24
levelUpTitle.TextColor3 = GOLD_COLOR
levelUpTitle.TextStrokeColor3 = SHADOW_COLOR
levelUpTitle.TextStrokeTransparency = 0.3
levelUpTitle.Text = "LEVEL UP!"
levelUpTitle.ZIndex = 19
levelUpTitle.Parent = levelUpFrame

local levelUpSub = Instance.new("TextLabel")
levelUpSub.Name = "Sub"
levelUpSub.Size = UDim2.new(1, 0, 0, 24)
levelUpSub.Position = UDim2.fromOffset(0, 44)
levelUpSub.BackgroundTransparency = 1
levelUpSub.Font = Enum.Font.GothamMedium
levelUpSub.TextSize = 16
levelUpSub.TextColor3 = Color3.fromRGB(200, 200, 220)
levelUpSub.TextStrokeColor3 = SHADOW_COLOR
levelUpSub.TextStrokeTransparency = 0.5
levelUpSub.Text = "You reached Level 2! (+5 SP)"
levelUpSub.ZIndex = 19
levelUpSub.Parent = levelUpFrame

local levelUpSound = Instance.new("Sound")
levelUpSound.Name = "LevelUpSound"
levelUpSound.SoundId = "rbxassetid://9125402735"
levelUpSound.Volume = 0.6
levelUpSound.Parent = SoundService

local function showLevelUpNotification(newLevel)
	levelUpSub.Text = "You reached Level " .. newLevel .. "! (+5 SP)"
	levelUpFrame.Visible = true
	levelUpFrame.Position = UDim2.fromScale(0.5, 0.2)
	levelUpFrame.BackgroundTransparency = 1
	levelUpTitle.TextTransparency = 1
	levelUpSub.TextTransparency = 1

	TweenService:Create(levelUpFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.25),
		BackgroundTransparency = 0.15,
	}):Play()
	TweenService:Create(levelUpTitle, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()
	TweenService:Create(levelUpSub, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()

	levelUpSound:Play()
	flashLevelUp()

	task.delay(3, function()
		TweenService:Create(levelUpFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 0.2),
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(levelUpTitle, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(levelUpSub, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		task.delay(0.5, function()
			levelUpFrame.Visible = false
		end)
	end)
end

-- ==================== STAT POINTS HINT (on HUD) ====================
local statHint = Instance.new("TextLabel")
statHint.Name = "StatHint"
statHint.Size = UDim2.fromOffset(BAR_WIDTH + PADDING * 2, 18)
statHint.Position = UDim2.new(0, 20, 1, -BOTTOM_OFFSET - container.Size.Y.Offset - 4)
statHint.AnchorPoint = Vector2.new(0, 1)
statHint.BackgroundTransparency = 1
statHint.Font = Enum.Font.GothamBold
statHint.TextSize = 11
statHint.TextColor3 = GOLD_COLOR
statHint.TextStrokeColor3 = SHADOW_COLOR
statHint.TextStrokeTransparency = 0.5
statHint.Text = ""
statHint.Visible = false
statHint.ZIndex = 6
statHint.Parent = screenGui

local function updateStatHint()
	if cachedStatPoints > 0 then
		local mode = ReplicatedStorage:FindFirstChild("InputMode") and ReplicatedStorage.InputMode.Value
		local key = (mode == "Xbox" or mode == "PlayStation") and "DPad Up" or "P"
		statHint.Text = cachedStatPoints .. " stat point" .. (cachedStatPoints > 1 and "s" or "") .. " available [" .. key .. "]"
		statHint.Visible = true
	else
		statHint.Visible = false
	end
end

-- ==================== STAT ICON BUTTON ====================
local STAT_ICON_SIZE = 28
local statIconBtn = Instance.new("ImageButton")
statIconBtn.Name = "StatIconBtn"
statIconBtn.Size = UDim2.fromOffset(STAT_ICON_SIZE, STAT_ICON_SIZE)
statIconBtn.Position = UDim2.new(0, 20 + BAR_WIDTH + PADDING * 2 - STAT_ICON_SIZE, 1, -BOTTOM_OFFSET - container.Size.Y.Offset - 6)
statIconBtn.AnchorPoint = Vector2.new(0, 1)
statIconBtn.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
statIconBtn.BackgroundTransparency = 0.2
statIconBtn.BorderSizePixel = 0
statIconBtn.Image = "rbxassetid://129933134513508"
statIconBtn.ImageColor3 = Color3.fromRGB(200, 180, 255)
statIconBtn.ScaleType = Enum.ScaleType.Fit
statIconBtn.AutoButtonColor = false
statIconBtn.ZIndex = 6
statIconBtn.Parent = screenGui

local statIconCorner = Instance.new("UICorner")
statIconCorner.CornerRadius = UDim.new(0, 6)
statIconCorner.Parent = statIconBtn

local statIconStroke = Instance.new("UIStroke")
statIconStroke.Color = Color3.fromRGB(80, 70, 120)
statIconStroke.Thickness = 1
statIconStroke.Transparency = 0.3
statIconStroke.Parent = statIconBtn

local statIconScale = Instance.new("UIScale")
statIconScale.Scale = 1
statIconScale.Parent = statIconBtn

local statIconTooltip = Instance.new("TextLabel")
statIconTooltip.Name = "Tooltip"
statIconTooltip.Size = UDim2.fromOffset(110, 22)
statIconTooltip.Position = UDim2.new(0.5, 0, 0, -6)
statIconTooltip.AnchorPoint = Vector2.new(0.5, 1)
statIconTooltip.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
statIconTooltip.BackgroundTransparency = 0.15
statIconTooltip.BorderSizePixel = 0
statIconTooltip.Font = Enum.Font.GothamBold
statIconTooltip.TextSize = 11
statIconTooltip.TextColor3 = Color3.fromRGB(200, 200, 220)
statIconTooltip.TextStrokeColor3 = SHADOW_COLOR
statIconTooltip.TextStrokeTransparency = 0.5
statIconTooltip.Text = "Character Stats"
statIconTooltip.Visible = false
statIconTooltip.ZIndex = 7
statIconTooltip.Parent = statIconBtn

local tooltipCorner = Instance.new("UICorner")
tooltipCorner.CornerRadius = UDim.new(0, 4)
tooltipCorner.Parent = statIconTooltip

statIconBtn.MouseEnter:Connect(function()
	statIconTooltip.Visible = true
	TweenService:Create(statIconBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(35, 40, 55),
		ImageColor3 = Color3.fromRGB(230, 210, 255),
	}):Play()
end)

statIconBtn.MouseLeave:Connect(function()
	statIconTooltip.Visible = false
	TweenService:Create(statIconBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(20, 24, 32),
		ImageColor3 = Color3.fromRGB(200, 180, 255),
	}):Play()
end)

statIconBtn.Activated:Connect(function()
	toggleStatPanel()
end)

local pulseRunning = false
local function startPulse()
	if pulseRunning then return end
	pulseRunning = true
	task.spawn(function()
		while pulseRunning do
			TweenService:Create(statIconScale, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Scale = 1.08}):Play()
			TweenService:Create(statIconStroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = GOLD_COLOR, Transparency = 0}):Play()
			task.wait(0.6)
			if not pulseRunning then break end
			TweenService:Create(statIconScale, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Scale = 1.0}):Play()
			TweenService:Create(statIconStroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = Color3.fromRGB(80, 70, 120), Transparency = 0.3}):Play()
			task.wait(0.6)
		end
	end)
end

local function stopPulse()
	pulseRunning = false
	TweenService:Create(statIconScale, TweenInfo.new(0.15), {Scale = 1.0}):Play()
	TweenService:Create(statIconStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(80, 70, 120), Transparency = 0.3}):Play()
end

local function updateStatIconPulse()
	if cachedStatPoints > 0 then
		startPulse()
	else
		stopPulse()
	end
end

-- ==================== INVENTORY ICON BUTTON ====================
local invIconBtn = Instance.new("ImageButton")
do
	local btn = invIconBtn
	btn.Name = "InventoryIconBtn"
	btn.Size = UDim2.fromOffset(STAT_ICON_SIZE, STAT_ICON_SIZE)
	btn.Position = UDim2.new(
		0, 20 + BAR_WIDTH + PADDING * 2 + 8,
		1, -BOTTOM_OFFSET - container.Size.Y.Offset - 6
	)
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	btn.BackgroundTransparency = 0.2
	btn.BorderSizePixel = 0
	btn.Image = "rbxassetid://6034818372"
	btn.ImageColor3 = Color3.fromRGB(180, 200, 255)
	btn.ScaleType = Enum.ScaleType.Fit
	btn.AutoButtonColor = false
	btn.ZIndex = 6
	btn.Parent = screenGui

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn

	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(70, 80, 120)
	s.Thickness = 1
	s.Transparency = 0.3
	s.Parent = btn

	Instance.new("UIScale").Parent = btn

	local tt = Instance.new("TextLabel")
	tt.Name = "Tooltip"
	tt.Size = UDim2.fromOffset(120, 22)
	tt.Position = UDim2.new(0.5, 0, 0, -6)
	tt.AnchorPoint = Vector2.new(0.5, 1)
	tt.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	tt.BackgroundTransparency = 0.15
	tt.BorderSizePixel = 0
	tt.Font = Enum.Font.GothamBold
	tt.TextSize = 11
	tt.TextColor3 = Color3.fromRGB(200, 200, 220)
	tt.TextStrokeColor3 = SHADOW_COLOR
	tt.TextStrokeTransparency = 0.5
	tt.Text = "Abilities & Scrolls"
	tt.Visible = false
	tt.ZIndex = 7
	tt.Parent = btn

	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 4)
	tc.Parent = tt

	btn.MouseEnter:Connect(function()
		tt.Visible = true
		TweenService:Create(btn, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(35, 40, 55),
			ImageColor3 = Color3.fromRGB(210, 225, 255),
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		tt.Visible = false
		TweenService:Create(btn, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(20, 24, 32),
			ImageColor3 = Color3.fromRGB(180, 200, 255),
		}):Play()
	end)

	btn.Activated:Connect(function()
		print("[HUDController] Inventory button clicked — scroll panel not yet implemented")
	end)
end

-- ==================== DEATH SCREEN ====================
local deathScreen = Instance.new("Frame")
deathScreen.Name = "DeathScreen"
deathScreen.Size = UDim2.fromScale(1, 1)
deathScreen.BackgroundColor3 = DEATH_OVERLAY_COLOR
deathScreen.BackgroundTransparency = 1
deathScreen.BorderSizePixel = 0
deathScreen.ZIndex = 10
deathScreen.Visible = false
deathScreen.Parent = screenGui

local deathTitle = Instance.new("TextLabel")
deathTitle.Name = "Title"
deathTitle.Size = UDim2.new(1, 0, 0, 60)
deathTitle.Position = UDim2.fromScale(0, 0.35)
deathTitle.BackgroundTransparency = 1
deathTitle.Font = Enum.Font.GothamBold
deathTitle.TextSize = 42
deathTitle.TextColor3 = Color3.fromRGB(220, 40, 40)
deathTitle.TextStrokeColor3 = SHADOW_COLOR
deathTitle.TextStrokeTransparency = 0.3
deathTitle.Text = "YOU DIED"
deathTitle.ZIndex = 11
deathTitle.Parent = deathScreen

local deathTimer = Instance.new("TextLabel")
deathTimer.Name = "Timer"
deathTimer.Size = UDim2.new(1, 0, 0, 30)
deathTimer.Position = UDim2.new(0, 0, 0.35, 65)
deathTimer.BackgroundTransparency = 1
deathTimer.Font = Enum.Font.GothamMedium
deathTimer.TextSize = 20
deathTimer.TextColor3 = Color3.fromRGB(180, 180, 180)
deathTimer.TextStrokeColor3 = SHADOW_COLOR
deathTimer.TextStrokeTransparency = 0.5
deathTimer.Text = ""
deathTimer.ZIndex = 11
deathTimer.Parent = deathScreen

local function showDeathScreen(respawnTime)
	deathScreen.Visible = true
	deathScreen.BackgroundTransparency = 1
	TweenService:Create(deathScreen, TweenInfo.new(0.5), {BackgroundTransparency = 0.5}):Play()

	deathTitle.TextTransparency = 1
	TweenService:Create(deathTitle, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()

	task.spawn(function()
		for i = respawnTime, 1, -1 do
			deathTimer.Text = "Respawning in " .. i .. "..."
			task.wait(1)
		end
		deathTimer.Text = "Respawning..."
	end)
end

local function hideDeathScreen()
	TweenService:Create(deathScreen, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
	TweenService:Create(deathTitle, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
	TweenService:Create(deathTimer, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
	task.delay(0.35, function()
		deathScreen.Visible = false
		deathTimer.TextTransparency = 0
	end)
end

-- ==================== ERROR BANNER ====================
local DataLoadError = Remotes:WaitForChild("DataLoadError")

local errorBanner = Instance.new("Frame")
errorBanner.Name = "ErrorBanner"
errorBanner.Size = UDim2.fromOffset(400, 50)
errorBanner.Position = UDim2.new(0.5, 0, 0, -60)
errorBanner.AnchorPoint = Vector2.new(0.5, 0)
errorBanner.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
errorBanner.BackgroundTransparency = 0.1
errorBanner.BorderSizePixel = 0
errorBanner.Visible = false
errorBanner.ZIndex = 20
errorBanner.Parent = screenGui

local errorCorner = Instance.new("UICorner")
errorCorner.CornerRadius = UDim.new(0, 8)
errorCorner.Parent = errorBanner

local errorStroke = Instance.new("UIStroke")
errorStroke.Color = Color3.fromRGB(255, 80, 80)
errorStroke.Thickness = 2
errorStroke.Parent = errorBanner

local errorIcon = Instance.new("TextLabel")
errorIcon.Name = "Icon"
errorIcon.Size = UDim2.new(0, 40, 1, 0)
errorIcon.Position = UDim2.fromOffset(0, 0)
errorIcon.BackgroundTransparency = 1
errorIcon.Font = Enum.Font.GothamBold
errorIcon.TextSize = 22
errorIcon.TextColor3 = Color3.fromRGB(255, 220, 60)
errorIcon.Text = "⚠"
errorIcon.ZIndex = 21
errorIcon.Parent = errorBanner

local errorText = Instance.new("TextLabel")
errorText.Name = "ErrorText"
errorText.Size = UDim2.new(1, -45, 1, 0)
errorText.Position = UDim2.fromOffset(40, 0)
errorText.BackgroundTransparency = 1
errorText.Font = Enum.Font.GothamBold
errorText.TextSize = 14
errorText.TextColor3 = Color3.fromRGB(255, 255, 255)
errorText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
errorText.TextStrokeTransparency = 0.5
errorText.TextXAlignment = Enum.TextXAlignment.Left
errorText.TextWrapped = true
errorText.Text = "Save data could not be loaded. Playing with default data."
errorText.ZIndex = 21
errorText.Parent = errorBanner

-- ==================== EVENT CONNECTIONS ====================
HPChanged.OnClientEvent:Connect(function(hp, maxHp)
	updateHP(hp, maxHp)
end)

StaminaChanged.OnClientEvent:Connect(function(stamina, maxStam)
	updateStamina(stamina, maxStam)
end)

PlayerDeath.OnClientEvent:Connect(function(respawnTime)
	showDeathScreen(respawnTime or 5)
end)

PlayerRespawn.OnClientEvent:Connect(function()
	hideDeathScreen()
end)

StatsChanged.OnClientEvent:Connect(function(level, xp, xpNeeded, totalXP)
	if level > currentLevel then
		flashLevelUp()
	end
	currentLevel = level
	updateStats(level, xp, xpNeeded, totalXP)
end)

LevelUpRemote.OnClientEvent:Connect(function(newLevel)
	currentLevel = newLevel
	showLevelUpNotification(newLevel)
end)

StatPointsChanged.OnClientEvent:Connect(function(data)
	if typeof(data) == "table" then
		cachedStatPoints = data.StatPoints or 0
		cachedFaction = data.Faction or ""
		cachedStatData = data
		cachedLastRespecTime = data.lastRespecTime or 0
	end
	updateStatPanel()
	updateStatHint()
	updateStatIconPulse()
end)

RespecResultRemote.OnClientEvent:Connect(function(success, msg, cooldownEnd)
	if success then
		cachedLastRespecTime = os.time()
		updateStatPanel()
		updateRespecButton()
		startRespecCooldownTick()
	else
		if msg == "On cooldown" and cooldownEnd then
			cachedLastRespecTime = cooldownEnd - RESPEC_COOLDOWN
			updateRespecButton()
			startRespecCooldownTick()
		end
	end
end)

DataLoadError.OnClientEvent:Connect(function()
	errorBanner.Visible = true
	errorBanner.Position = UDim2.new(0.5, 0, 0, -60)
	TweenService:Create(errorBanner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 20),
	}):Play()

	task.delay(10, function()
		TweenService:Create(errorBanner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -60),
		}):Play()
		task.delay(0.35, function()
			errorBanner.Visible = false
		end)
	end)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.DPadUp then
		toggleStatPanel()
	end
end)

-- ==================== FACTION SELECTION UI ====================
local SLAYER_COLOR = Color3.fromRGB(50, 120, 220)
local SLAYER_HOVER = Color3.fromRGB(70, 145, 255)
local DEMON_COLOR = Color3.fromRGB(180, 40, 60)
local DEMON_HOVER = Color3.fromRGB(220, 55, 75)

local factionOverlay = Instance.new("Frame")
factionOverlay.Name = "FactionOverlay"
factionOverlay.Size = UDim2.fromScale(1, 1)
factionOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
factionOverlay.BackgroundTransparency = 0.35
factionOverlay.BorderSizePixel = 0
factionOverlay.Visible = false
factionOverlay.ZIndex = 30
factionOverlay.Parent = screenGui

local factionPanel = Instance.new("Frame")
factionPanel.Name = "FactionPanel"
factionPanel.Size = UDim2.fromOffset(520, 340)
factionPanel.Position = UDim2.fromScale(0.5, 0.5)
factionPanel.AnchorPoint = Vector2.new(0.5, 0.5)
factionPanel.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
factionPanel.BackgroundTransparency = 0.05
factionPanel.BorderSizePixel = 0
factionPanel.ZIndex = 31
factionPanel.Parent = factionOverlay

local factionPanelCorner = Instance.new("UICorner")
factionPanelCorner.CornerRadius = UDim.new(0, 14)
factionPanelCorner.Parent = factionPanel

local factionPanelStroke = Instance.new("UIStroke")
factionPanelStroke.Color = Color3.fromRGB(80, 85, 100)
factionPanelStroke.Thickness = 1.5
factionPanelStroke.Parent = factionPanel

local factionTitle = Instance.new("TextLabel")
factionTitle.Name = "Title"
factionTitle.Size = UDim2.new(1, 0, 0, 44)
factionTitle.Position = UDim2.fromOffset(0, 10)
factionTitle.BackgroundTransparency = 1
factionTitle.Font = Enum.Font.GothamBold
factionTitle.TextSize = 22
factionTitle.TextColor3 = TEXT_COLOR
factionTitle.TextStrokeColor3 = SHADOW_COLOR
factionTitle.TextStrokeTransparency = 0.3
factionTitle.Text = "CHOOSE YOUR PATH"
factionTitle.ZIndex = 32
factionTitle.Parent = factionPanel

local factionSubtitle = Instance.new("TextLabel")
factionSubtitle.Name = "Subtitle"
factionSubtitle.Size = UDim2.new(1, 0, 0, 20)
factionSubtitle.Position = UDim2.fromOffset(0, 50)
factionSubtitle.BackgroundTransparency = 1
factionSubtitle.Font = Enum.Font.Gotham
factionSubtitle.TextSize = 13
factionSubtitle.TextColor3 = Color3.fromRGB(160, 160, 180)
factionSubtitle.Text = "This choice is permanent and cannot be changed."
factionSubtitle.ZIndex = 32
factionSubtitle.Parent = factionPanel

local factionChosen = false

local function createFactionCard(name, displayName, description, traits, color, hoverColor, xPos)
	local card = Instance.new("Frame")
	card.Name = name .. "Card"
	card.Size = UDim2.fromOffset(220, 220)
	card.Position = UDim2.fromOffset(xPos, 82)
	card.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	card.BorderSizePixel = 0
	card.ZIndex = 32
	card.Parent = factionPanel

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = color
	cardStroke.Thickness = 2
	cardStroke.Transparency = 0.5
	cardStroke.Parent = card

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(1, 0, 0, 50)
	iconLabel.Position = UDim2.fromOffset(0, 12)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextSize = 36
	iconLabel.TextColor3 = color
	iconLabel.Text = name == "Slayer" and "⚔" or "👹"
	iconLabel.ZIndex = 33
	iconLabel.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.Position = UDim2.fromOffset(0, 60)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 18
	nameLabel.TextColor3 = color
	nameLabel.TextStrokeColor3 = SHADOW_COLOR
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Text = displayName
	nameLabel.ZIndex = 33
	nameLabel.Parent = card

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Desc"
	descLabel.Size = UDim2.new(1, -20, 0, 32)
	descLabel.Position = UDim2.fromOffset(10, 90)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 11
	descLabel.TextColor3 = Color3.fromRGB(180, 180, 195)
	descLabel.TextWrapped = true
	descLabel.Text = description
	descLabel.ZIndex = 33
	descLabel.Parent = card

	local traitsLabel = Instance.new("TextLabel")
	traitsLabel.Name = "Traits"
	traitsLabel.Size = UDim2.new(1, -20, 0, 40)
	traitsLabel.Position = UDim2.fromOffset(10, 124)
	traitsLabel.BackgroundTransparency = 1
	traitsLabel.Font = Enum.Font.GothamMedium
	traitsLabel.TextSize = 10
	traitsLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
	traitsLabel.TextWrapped = true
	traitsLabel.TextYAlignment = Enum.TextYAlignment.Top
	traitsLabel.Text = traits
	traitsLabel.ZIndex = 33
	traitsLabel.Parent = card

	local selectBtn = Instance.new("TextButton")
	selectBtn.Name = "SelectBtn"
	selectBtn.Size = UDim2.new(1, -30, 0, 34)
	selectBtn.Position = UDim2.new(0, 15, 1, -46)
	selectBtn.BackgroundColor3 = color
	selectBtn.BorderSizePixel = 0
	selectBtn.Font = Enum.Font.GothamBold
	selectBtn.TextSize = 14
	selectBtn.TextColor3 = TEXT_COLOR
	selectBtn.Text = "Choose " .. displayName
	selectBtn.AutoButtonColor = false
	selectBtn.ZIndex = 33
	selectBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = selectBtn

	selectBtn.MouseEnter:Connect(function()
		if factionChosen then return end
		TweenService:Create(selectBtn, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
		TweenService:Create(cardStroke, TweenInfo.new(0.15), {Transparency = 0}):Play()
	end)
	selectBtn.MouseLeave:Connect(function()
		if factionChosen then return end
		TweenService:Create(selectBtn, TweenInfo.new(0.15), {BackgroundColor3 = color}):Play()
		TweenService:Create(cardStroke, TweenInfo.new(0.15), {Transparency = 0.5}):Play()
	end)

	selectBtn.MouseButton1Click:Connect(function()
		if factionChosen then return end
		factionChosen = true
		selectBtn.Text = "Choosing..."
		ChooseFactionRemote:FireServer(name)
	end)

	return {Card = card, SelectBtn = selectBtn, Stroke = cardStroke}
end

local _slayerCard = createFactionCard(
	"Slayer", "SLAYER",
	"Protectors of humanity. Master breathing techniques to slay demons.",
	"• Breathing Style skills\n• Balanced stats\n• Katana combat",
	SLAYER_COLOR, SLAYER_HOVER, 30
)

local _demonCard = createFactionCard(
	"Demon", "DEMON",
	"Embrace the darkness. Gain demonic blood arts and supernatural power.",
	"• Blood Demon Arts\n• Higher base power\n• Regeneration abilities",
	DEMON_COLOR, DEMON_HOVER, 270
)

local factionPromptShowing = false

local NORMAL_DISPLAY_ORDER = 5
local MODAL_DISPLAY_ORDER = 100

local function showFactionSelect()
	if factionChosen then return end
	if factionPromptShowing then return end
	factionPromptShowing = true
	screenGui.DisplayOrder = MODAL_DISPLAY_ORDER
	factionOverlay.Visible = true
	factionPanel.Size = UDim2.fromOffset(520, 0)
	factionPanel.BackgroundTransparency = 1
	TweenService:Create(factionPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(520, 340),
		BackgroundTransparency = 0.05,
	}):Play()
	TweenService:Create(factionOverlay, TweenInfo.new(0.3), {BackgroundTransparency = 0.35}):Play()
end

local function hideFactionSelect(chosenFaction)
	local flashColor = chosenFaction == "Slayer" and SLAYER_COLOR or DEMON_COLOR
	factionPanel.BackgroundColor3 = flashColor
	TweenService:Create(factionPanel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(520, 0),
	}):Play()
	TweenService:Create(factionOverlay, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
	task.delay(0.55, function()
		factionOverlay.Visible = false
		factionPromptShowing = false
		screenGui.DisplayOrder = NORMAL_DISPLAY_ORDER
	end)
end

local factionConfirmSound = Instance.new("Sound")
factionConfirmSound.Name = "FactionConfirmSound"
factionConfirmSound.SoundId = "rbxassetid://9125402735"
factionConfirmSound.Volume = 0.7
factionConfirmSound.Parent = SoundService

ShowFactionSelectRemote.OnClientEvent:Connect(function()
	factionChosen = false
	showFactionSelect()
end)

FactionChosenRemote.OnClientEvent:Connect(function(faction)
	factionConfirmSound:Play()
	hideFactionSelect(faction)
end)

-- ==================== LUNGE COOLDOWN INDICATOR ====================
local lungeFrame = Instance.new("Frame")
lungeFrame.Name = "LungeCooldown"
lungeFrame.Size = UDim2.fromOffset(44, 44)
lungeFrame.Position = UDim2.new(0, 20 + BAR_WIDTH + PADDING * 2 + 10, 1, -BOTTOM_OFFSET - 10)
lungeFrame.AnchorPoint = Vector2.new(0, 1)
lungeFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
lungeFrame.BackgroundTransparency = 0.2
lungeFrame.BorderSizePixel = 0
lungeFrame.Parent = screenGui

local lungeCorner = Instance.new("UICorner")
lungeCorner.CornerRadius = UDim.new(0, 8)
lungeCorner.Parent = lungeFrame

local lungeStroke = Instance.new("UIStroke")
lungeStroke.Color = Color3.fromRGB(180, 200, 255)
lungeStroke.Thickness = 1.5
lungeStroke.Transparency = 0.3
lungeStroke.Parent = lungeFrame

local lungeIcon = Instance.new("TextLabel")
lungeIcon.Name = "Icon"
lungeIcon.Size = UDim2.new(1, 0, 0, 24)
lungeIcon.Position = UDim2.fromOffset(0, 4)
lungeIcon.BackgroundTransparency = 1
lungeIcon.Font = Enum.Font.GothamBold
lungeIcon.TextSize = 18
lungeIcon.TextColor3 = Color3.fromRGB(180, 200, 255)
lungeIcon.Text = "⟐"
lungeIcon.ZIndex = 3
lungeIcon.Parent = lungeFrame

local lungeKeyLabel = Instance.new("TextLabel")
lungeKeyLabel.Name = "Key"
lungeKeyLabel.Size = UDim2.new(1, 0, 0, 12)
lungeKeyLabel.Position = UDim2.new(0, 0, 1, -14)
lungeKeyLabel.BackgroundTransparency = 1
lungeKeyLabel.Font = Enum.Font.GothamBold
lungeKeyLabel.TextSize = 9
lungeKeyLabel.TextColor3 = Color3.fromRGB(150, 160, 180)
lungeKeyLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
lungeKeyLabel.TextStrokeTransparency = 0.5
lungeKeyLabel.Text = "SHIFT"
lungeKeyLabel.ZIndex = 3
lungeKeyLabel.Parent = lungeFrame

local lungeCdOverlay = Instance.new("Frame")
lungeCdOverlay.Name = "CdOverlay"
lungeCdOverlay.Size = UDim2.fromScale(1, 0)
lungeCdOverlay.Position = UDim2.fromScale(0, 1)
lungeCdOverlay.AnchorPoint = Vector2.new(0, 1)
lungeCdOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
lungeCdOverlay.BackgroundTransparency = 0.4
lungeCdOverlay.BorderSizePixel = 0
lungeCdOverlay.ZIndex = 2
lungeCdOverlay.Parent = lungeFrame

local lungeCdCorner = Instance.new("UICorner")
lungeCdCorner.CornerRadius = UDim.new(0, 8)
lungeCdCorner.Parent = lungeCdOverlay

task.spawn(function()
	while true do
		task.wait(0.05)
		-- selene: allow(global_usage)
		local mc = _G.MovementController
		if mc then
			local remaining = mc.getCooldownRemaining()
			local total = mc.getCooldownTotal()
			if remaining > 0 then
				local ratio = math.clamp(remaining / total, 0, 1)
				lungeCdOverlay.Size = UDim2.fromScale(1, ratio)
				lungeIcon.TextColor3 = Color3.fromRGB(80, 80, 100)
				lungeStroke.Color = Color3.fromRGB(80, 80, 100)
			else
				lungeCdOverlay.Size = UDim2.fromScale(1, 0)
				lungeIcon.TextColor3 = Color3.fromRGB(180, 200, 255)
				lungeStroke.Color = Color3.fromRGB(180, 200, 255)
			end
		end
	end
end)

local InputModeValue = ReplicatedStorage:WaitForChild("InputMode")

local function updateHUDPrompts()
	local mode = InputModeValue.Value
	local isGamepad = (mode == "Xbox" or mode == "PlayStation")
	hintLabel.Text = isGamepad and "Press [DPad Up] to close" or "Press [P] to close"
	lungeKeyLabel.Text = isGamepad and "L3" or "SHIFT"

	if cachedStatPoints > 0 then
		local key = isGamepad and "DPad Up" or "P"
		statHint.Text = cachedStatPoints .. " stat point" .. (cachedStatPoints > 1 and "s" or "") .. " available [" .. key .. "]"
	end
end

InputModeValue.Changed:Connect(function()
	updateHUDPrompts()
end)

updateHP(100, 100)
updateStamina(100, 100)
updateStats(1, 0, 100, 0)
updateHUDPrompts()
updateStatIconPulse()

-- ==================== MASTERY BAR SYSTEM ====================
do
	local currentMasteryFaction = ""
	local currentMasteryStyleId = ""
	local currentMasteryLevel = 0
	local currentMasteryXP = 0
	local currentMasteryXPNeeded = 100
	local masteryEquipped = false
	local MASTERY_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local MASTERY_FLASH_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local function getActiveStyleFromSkills(faction)
		for _, slot in {"Q", "E", "R", "F", "V"} do
			local skill = SkillSystemModule.getSkillForSlot(faction, slot)
			if skill then
				return skill.Id
			end
		end
		return ""
	end

	local function updateMasteryBarUI()
		if not masteryEquipped or currentMasteryStyleId == "" then
			masteryBarContainer.GroupTransparency = 0.7
			masteryStyleLabel.Text = "No style equipped"
			masteryLvLabel.Text = ""
			masteryFill.Size = UDim2.fromScale(0, 1)
			return
		end

		masteryBarContainer.GroupTransparency = 0

		if currentMasteryLevel >= MASTERY_MAX then
			masteryStyleLabel.Text = "MASTERED"
			masteryLvLabel.Text = "Lv " .. currentMasteryLevel
			masteryFill.BackgroundColor3 = MASTERY_GOLD_COLOR
			TweenService:Create(masteryFill, MASTERY_TWEEN, {Size = UDim2.fromScale(1, 1)}):Play()
			return
		end

		local skill = SkillSystemModule.getSkill(currentMasteryStyleId)
		local displayName = currentMasteryStyleId
		if skill then
			if skill.Faction == "Slayer" then
				displayName = "Water Breath"
				masteryFill.BackgroundColor3 = MASTERY_BREATH_COLOR1
				masteryFillGradient.Color = ColorSequence.new(MASTERY_BREATH_COLOR1, MASTERY_BREATH_COLOR2)
			elseif skill.Faction == "Demon" then
				displayName = "Blood Demon Art"
				masteryFill.BackgroundColor3 = MASTERY_DEMON_COLOR1
				masteryFillGradient.Color = ColorSequence.new(MASTERY_DEMON_COLOR1, MASTERY_DEMON_COLOR2)
			end
			currentMasteryFaction = skill.Faction
		end

		masteryStyleLabel.Text = displayName
		masteryLvLabel.Text = "Lv " .. currentMasteryLevel

		local ratio = 0
		if currentMasteryXPNeeded > 0 then
			ratio = math.clamp(currentMasteryXP / currentMasteryXPNeeded, 0, 1)
		end
		TweenService:Create(masteryFill, MASTERY_TWEEN, {Size = UDim2.fromScale(ratio, 1)}):Play()
	end

	local function flashMasteryWhite()
		local origColor = masteryFill.BackgroundColor3
		masteryFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		TweenService:Create(masteryFill, MASTERY_FLASH_TWEEN, {BackgroundColor3 = origColor}):Play()
	end

	local MasteryChangedRemote = Remotes:FindFirstChild("MasteryChanged")
	if not MasteryChangedRemote then
		MasteryChangedRemote = Remotes:WaitForChild("MasteryChanged", 5)
	end

	if MasteryChangedRemote then
		MasteryChangedRemote.OnClientEvent:Connect(function(styleId, level, xp, xpNeeded, _totalXP, levelsGained)
			local activeStyle = getActiveStyleFromSkills(currentMasteryFaction)
			if styleId == activeStyle or styleId == currentMasteryStyleId then
				currentMasteryLevel = level
				currentMasteryXP = xp
				currentMasteryXPNeeded = xpNeeded
				currentMasteryStyleId = styleId
				masteryEquipped = true
				updateMasteryBarUI()
				if levelsGained > 0 then
					flashMasteryWhite()
				end
			end
		end)
	end

	FactionChosenRemote.OnClientEvent:Connect(function(faction)
		currentMasteryFaction = faction
		local activeStyle = getActiveStyleFromSkills(faction)
		if activeStyle ~= "" then
			currentMasteryStyleId = activeStyle
			masteryEquipped = true
			currentMasteryLevel = 0
			currentMasteryXP = 0
			currentMasteryXPNeeded = 100
		else
			masteryEquipped = false
			currentMasteryStyleId = ""
		end
		updateMasteryBarUI()
	end)

	task.spawn(function()
		local GetPlayerData = Remotes:FindFirstChild("GetPlayerData")
		if GetPlayerData then
			local ok, result = pcall(function()
				return GetPlayerData:InvokeServer()
			end)
			if ok and result and typeof(result) == "table" then
				if result.Faction and result.Faction ~= "" then
					currentMasteryFaction = result.Faction
					local activeStyle = getActiveStyleFromSkills(result.Faction)
					if activeStyle ~= "" then
						currentMasteryStyleId = activeStyle
						masteryEquipped = true
						if result.Mastery and result.Mastery[activeStyle] then
							local m = result.Mastery[activeStyle]
							currentMasteryLevel = m.Level or 1
							currentMasteryXP = m.XP or 0
							currentMasteryXPNeeded = math.floor(100 * ((m.Level or 1) ^ 1.3))
						end
					end
				elseif result.Level then
					print("[HUDController] No faction set — showing faction select from client-side check")
					factionChosen = false
					factionPromptShowing = false
					showFactionSelect()
				end
				updateMasteryBarUI()
			end
		end
	end)

	updateMasteryBarUI()
end

print("[HUDController] Loaded")