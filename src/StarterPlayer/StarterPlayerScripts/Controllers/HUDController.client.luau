local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local DEBUG_HUD = false
local DEBUG_HUD_VERBOSE = false
local function hudLog(message)
	if DEBUG_HUD then
		print("[HUDController] " .. message)
	end
end

local function hudTrace(message)
	if DEBUG_HUD and DEBUG_HUD_VERBOSE then
		print("[HUDController] " .. message)
	end
end

hudLog("Booting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
hudLog("PlayerGui found: " .. PlayerGui:GetFullName())
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HPChanged = Remotes:WaitForChild("HPChanged")
local StaminaChanged = Remotes:WaitForChild("StaminaChanged")
local PlayerDeath = Remotes:WaitForChild("PlayerDeath")
local PlayerRespawn = Remotes:WaitForChild("PlayerRespawn")
local StatsChanged = Remotes:WaitForChild("StatsChanged")
local LevelUpRemote = Remotes:WaitForChild("LevelUp")
local StatPointsChanged = Remotes:WaitForChild("StatPointsChanged")
local AllocateStatRemote = Remotes:WaitForChild("AllocateStat")
local FactionChosenRemote = Remotes:WaitForChild("FactionChosen")
local ShowFactionSelectRemote = Remotes:WaitForChild("ShowFactionSelect")
local RespecStatsRemote = Remotes:WaitForChild("RespecStats")
local RespecResultRemote = Remotes:WaitForChild("RespecResult")
local _ResetFactionRemote = Remotes:FindFirstChild("ResetFaction")
hudLog("Core remotes ready")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SkillSystemModule = require(Modules:WaitForChild("SkillSystemModule"))
hudLog("SkillSystemModule loaded")

local EquipTitleRemote = Remotes:FindFirstChild("EquipTitle")
local TitleRebirthRemote = Remotes:FindFirstChild("TitleRebirth")
local StyleChangedRemote = Remotes:FindFirstChild("StyleChanged")
local InventoryChangedRemote = Remotes:FindFirstChild("InventoryChanged")
local EquipScrollRemote = Remotes:FindFirstChild("EquipScroll")

local okItemsModule, ItemsModule = pcall(require, Modules:WaitForChild("ItemsModule", 5))
if not okItemsModule then
	warn("[HUDController] ItemsModule unavailable; inventory UI will stay empty")
	ItemsModule = nil
end

local okTitleModule, TitleModule = pcall(require, Modules:WaitForChild("TitleModule", 5))
if not okTitleModule then
	warn("[HUDController] TitleModule unavailable; title UI will stay closed")
	TitleModule = nil
end

local cachedInventory = {}
local cachedEquippedStyle = ""
local cachedTitles = {}
local cachedEquippedTitle = ""

local BAR_WIDTH = 200
local BAR_HEIGHT = 16
local STAMINA_BAR_HEIGHT = 10
local XP_BAR_HEIGHT = 8
local MASTERY_BAR_HEIGHT = 6
local CORNER_RADIUS = 5
local PADDING = 8
local BOTTOM_OFFSET = 30

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
screenGui.DisplayOrder = 30
screenGui.Parent = PlayerGui
hudLog("ScreenGui mounted")

local container = Instance.new("Frame")
container.Name = "BarContainer"
container.Size = UDim2.fromOffset(BAR_WIDTH + PADDING * 2, BAR_HEIGHT + STAMINA_BAR_HEIGHT + MASTERY_BAR_HEIGHT + XP_BAR_HEIGHT + PADDING * 3 + 57)
container.Position = UDim2.new(0, 20, 1, -BOTTOM_OFFSET)
container.AnchorPoint = Vector2.new(0, 1)
container.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
container.BackgroundTransparency = 0.3
container.BorderSizePixel = 0
container.Visible = true
container.Parent = screenGui
hudLog("BarContainer mounted")

screenGui.AncestryChanged:Connect(function(_, parent)
	hudLog("ScreenGui ancestry changed; parent=" .. (parent and parent:GetFullName() or "nil"))
end)

container.AncestryChanged:Connect(function(_, parent)
	hudLog("BarContainer ancestry changed; parent=" .. (parent and parent:GetFullName() or "nil"))
end)

container:GetPropertyChangedSignal("Visible"):Connect(function()
	hudLog("BarContainer visibility changed: " .. tostring(container.Visible))
end)

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
local staminaBar = createBar("StaminaBar", container, PADDING + 14 + BAR_HEIGHT + 4, STAMINA_BAR_HEIGHT, STAMINA_COLOR, STAMINA_BG, true)

local masterySectionY = PADDING + 14 + BAR_HEIGHT + 4 + STAMINA_BAR_HEIGHT + 5

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

local xpSectionY = masterySectionY + MASTERY_BAR_HEIGHT + 14 + 4

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
	current = tonumber(current) or 0
	max = math.max(tonumber(max) or 1, 1)
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
	current = tonumber(current) or 0
	max = math.max(tonumber(max) or 1, 1)
	local ratio = math.clamp(current / max, 0, 1)
	TweenService:Create(staminaBar.Fill, TWEEN_STAMINA, {Size = UDim2.fromScale(ratio, 1)}):Play()

	if ratio <= 0.2 then
		staminaBar.Fill.BackgroundColor3 = Color3.fromRGB(40, 100, 140)
	else
		staminaBar.Fill.BackgroundColor3 = STAMINA_COLOR
	end

	if staminaBar.Label then
		staminaBar.Label.Text = math.floor(current) .. " / " .. math.floor(max)
	end
end

local TWEEN_XP = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function updateStats(level, xp, xpNeeded, _totalXP)
	level = tonumber(level) or 1
	xp = tonumber(xp) or 0
	xpNeeded = tonumber(xpNeeded) or 100
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

local function syncFromCharacter(reason)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		hudTrace("Character sync skipped (" .. reason .. "): humanoid not ready")
		return
	end

	hudTrace("Character sync (" .. reason .. "): hp=" .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth))
	updateHP(humanoid.Health, humanoid.MaxHealth)
end

local function reportHudState(reason)
	local parentName = screenGui.Parent and screenGui.Parent:GetFullName() or "nil"
	local absPos = container.AbsolutePosition
	local absSize = container.AbsoluteSize
	hudTrace(
		reason
			.. " state: guiParent=" .. parentName
			.. ", enabled=" .. tostring(screenGui.Enabled)
			.. ", displayOrder=" .. tostring(screenGui.DisplayOrder)
			.. ", containerParent=" .. (container.Parent and container.Parent.Name or "nil")
			.. ", visible=" .. tostring(container.Visible)
			.. ", absPos=" .. tostring(math.floor(absPos.X)) .. "," .. tostring(math.floor(absPos.Y))
			.. ", absSize=" .. tostring(math.floor(absSize.X)) .. "x" .. tostring(math.floor(absSize.Y))
	)
end

local function forceHudVisible(reason)
	local repaired = false
	if screenGui.Parent ~= PlayerGui then
		screenGui.Parent = PlayerGui
		repaired = true
	end
	if not screenGui.Enabled then
		screenGui.Enabled = true
		repaired = true
	end
	if screenGui.DisplayOrder ~= 30 then
		screenGui.DisplayOrder = 30
		repaired = true
	end
	if container.Parent ~= screenGui then
		container.Parent = screenGui
		repaired = true
	end
	if not container.Visible then
		container.Visible = true
		repaired = true
	end
	if container.Position ~= UDim2.new(0, 20, 1, -BOTTOM_OFFSET) then
		container.Position = UDim2.new(0, 20, 1, -BOTTOM_OFFSET)
	end
	if container.AnchorPoint ~= Vector2.new(0, 1) then
		container.AnchorPoint = Vector2.new(0, 1)
	end
	if repaired then
		hudLog("HUD visibility repaired from " .. tostring(reason))
		reportHudState(reason)
	end
end

updateHP(150, 150)
updateStamina(100, 100)
updateStats(1, 0, 100)
forceHudVisible("initial")

task.defer(function()
	syncFromCharacter("deferred")
	forceHudVisible("deferred")
end)

task.delay(3, function()
	syncFromCharacter("3s watchdog")
	forceHudVisible("3s watchdog")
end)

-- ==================== STAT ALLOCATION PANEL ====================
local cachedStatPoints = 0
local cachedStatData: {[string]: any} = {}
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

-- ==================== TITLES BUTTON ====================
local showTitlePanel -- forward declaration; defined in Title Selection UI section below
local hideTitlePanel
local titlePanelShowing = false
local changeFactionBtn = Instance.new("TextButton")
changeFactionBtn.Name = "TitlesBtn"
changeFactionBtn.Size = UDim2.fromOffset(140, 28)
changeFactionBtn.Position = UDim2.new(0, 150, 1, -52)
changeFactionBtn.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
changeFactionBtn.BackgroundTransparency = 0.6
changeFactionBtn.BorderSizePixel = 0
changeFactionBtn.Font = Enum.Font.GothamMedium
changeFactionBtn.TextSize = 11
changeFactionBtn.TextColor3 = Color3.fromRGB(140, 180, 255)
changeFactionBtn.Text = "Titles"
changeFactionBtn.AutoButtonColor = false
changeFactionBtn.ZIndex = 16
changeFactionBtn.Parent = statPanel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = changeFactionBtn
end
local changeFactionStroke = Instance.new("UIStroke")
changeFactionStroke.Color = Color3.fromRGB(80, 110, 180)
changeFactionStroke.Thickness = 1
changeFactionStroke.Transparency = 0.3
changeFactionStroke.Parent = changeFactionBtn

changeFactionBtn.MouseEnter:Connect(function()
	TweenService:Create(changeFactionBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
	TweenService:Create(changeFactionStroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(120, 160, 255), Transparency = 0}):Play()
end)
changeFactionBtn.MouseLeave:Connect(function()
	TweenService:Create(changeFactionBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.6}):Play()
	TweenService:Create(changeFactionStroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(80, 110, 180), Transparency = 0.3}):Play()
end)
changeFactionBtn.MouseButton1Click:Connect(function()
	if showTitlePanel then
		showTitlePanel()
	end
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
local HUD_ACTION_ICON_SIZE = 32
local HUD_ACTION_ICON_GAP = 8
local HUD_ACTION_ICON_BASE_X = 20
local HUD_ACTION_ICON_Y = -BOTTOM_OFFSET - container.Size.Y.Offset - 6
local HUD_ACTION_PANEL_X = HUD_ACTION_ICON_BASE_X + (HUD_ACTION_ICON_SIZE * 3) + (HUD_ACTION_ICON_GAP * 3) + 10

local statHint = Instance.new("TextLabel")
statHint.Name = "StatHint"
statHint.Size = UDim2.fromOffset(math.max(BAR_WIDTH + PADDING * 2 - HUD_ACTION_PANEL_X + 20, 120), 18)
statHint.Position = UDim2.new(0, HUD_ACTION_PANEL_X, 1, -BOTTOM_OFFSET - container.Size.Y.Offset - 10)
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
		local key = (mode == "Xbox" or mode == "PlayStation") and "Stats icon" or "P"
		statHint.Text = cachedStatPoints .. " stat point" .. (cachedStatPoints > 1 and "s" or "") .. " available [" .. key .. "]"
		statHint.Visible = true
	else
		statHint.Visible = false
	end
end

-- ==================== STAT ICON BUTTON ====================
local STAT_ICON_SIZE = HUD_ACTION_ICON_SIZE
local statIconBtn = Instance.new("TextButton")
statIconBtn.Name = "StatIconBtn"
statIconBtn.Size = UDim2.fromOffset(STAT_ICON_SIZE, STAT_ICON_SIZE)
statIconBtn.Position = UDim2.new(0, HUD_ACTION_ICON_BASE_X, 1, HUD_ACTION_ICON_Y)
statIconBtn.AnchorPoint = Vector2.new(0, 1)
statIconBtn.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
statIconBtn.BackgroundTransparency = 0.2
statIconBtn.BorderSizePixel = 0
statIconBtn.Text = "✚"
statIconBtn.TextColor3 = Color3.fromRGB(220, 205, 255)
statIconBtn.TextSize = 18
statIconBtn.Font = Enum.Font.GothamBold
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

local statIconBadge = Instance.new("TextLabel")
statIconBadge.Name = "PointBadge"
statIconBadge.Size = UDim2.fromOffset(18, 18)
statIconBadge.Position = UDim2.new(1, -2, 0, 2)
statIconBadge.AnchorPoint = Vector2.new(1, 0)
statIconBadge.BackgroundColor3 = GOLD_COLOR
statIconBadge.BorderSizePixel = 0
statIconBadge.Font = Enum.Font.GothamBold
statIconBadge.TextSize = 10
statIconBadge.TextColor3 = Color3.fromRGB(20, 18, 12)
statIconBadge.Text = "0"
statIconBadge.Visible = false
statIconBadge.ZIndex = 8
statIconBadge.Parent = statIconBtn
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = statIconBadge
end

statIconBtn.MouseEnter:Connect(function()
	statIconTooltip.Visible = true
	TweenService:Create(statIconBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(35, 40, 55),
		TextColor3 = Color3.fromRGB(245, 235, 255),
	}):Play()
end)

statIconBtn.MouseLeave:Connect(function()
	statIconTooltip.Visible = false
	TweenService:Create(statIconBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(20, 24, 32),
		TextColor3 = Color3.fromRGB(220, 205, 255),
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
		statIconBadge.Text = tostring(math.min(cachedStatPoints, 99))
		statIconBadge.Visible = true
		startPulse()
	else
		statIconBadge.Visible = false
		stopPulse()
	end
end

-- ==================== TITLE ICON BUTTON ====================
local titleIconBtn = Instance.new("TextButton")
do
	local btn = titleIconBtn
	btn.Name = "TitleIconBtn"
	btn.Size = UDim2.fromOffset(STAT_ICON_SIZE, STAT_ICON_SIZE)
	btn.Position = UDim2.new(
		0, HUD_ACTION_ICON_BASE_X + STAT_ICON_SIZE + HUD_ACTION_ICON_GAP,
		1, HUD_ACTION_ICON_Y
	)
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	btn.BackgroundTransparency = 0.2
	btn.BorderSizePixel = 0
	btn.Text = "T"
	btn.TextColor3 = GOLD_COLOR
	btn.TextSize = 16
	btn.Font = Enum.Font.GothamBold
	btn.AutoButtonColor = false
	btn.ZIndex = 6
	btn.Parent = screenGui

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn

	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(120, 95, 40)
	s.Thickness = 1
	s.Transparency = 0.25
	s.Parent = btn

	local tt = Instance.new("TextLabel")
	tt.Name = "Tooltip"
	tt.Size = UDim2.fromOffset(92, 22)
	tt.Position = UDim2.new(0.5, 0, 0, -6)
	tt.AnchorPoint = Vector2.new(0.5, 1)
	tt.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	tt.BackgroundTransparency = 0.15
	tt.BorderSizePixel = 0
	tt.Font = Enum.Font.GothamBold
	tt.TextSize = 11
	tt.TextColor3 = Color3.fromRGB(220, 210, 160)
	tt.TextStrokeColor3 = SHADOW_COLOR
	tt.TextStrokeTransparency = 0.5
	tt.Text = "Titles"
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
			TextColor3 = Color3.fromRGB(255, 235, 120),
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		tt.Visible = false
		TweenService:Create(btn, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(20, 24, 32),
			TextColor3 = GOLD_COLOR,
		}):Play()
	end)

	btn.Activated:Connect(function()
		if showTitlePanel then
			showTitlePanel()
		else
			warn("[HUDController] Title icon pressed before title panel was ready")
		end
	end)
end

-- ==================== INVENTORY ICON BUTTON ====================
local toggleInventoryPanel -- forward declaration; defined after the panel is built
local invIconBadge
local invIconBtn = Instance.new("TextButton")
do
	local btn = invIconBtn
	btn.Name = "InventoryIconBtn"
	btn.Size = UDim2.fromOffset(STAT_ICON_SIZE, STAT_ICON_SIZE)
	btn.Position = UDim2.new(
		0, HUD_ACTION_ICON_BASE_X + (STAT_ICON_SIZE + HUD_ACTION_ICON_GAP) * 2,
		1, HUD_ACTION_ICON_Y
	)
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	btn.BackgroundTransparency = 0.2
	btn.BorderSizePixel = 0
	btn.Text = "🎒"
	btn.TextColor3 = Color3.fromRGB(195, 215, 255)
	btn.TextSize = 18
	btn.Font = Enum.Font.GothamBold
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
	tt.Text = "Inventory"
	tt.Visible = false
	tt.ZIndex = 7
	tt.Parent = btn

	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 4)
	tc.Parent = tt

	invIconBadge = Instance.new("TextLabel")
	invIconBadge.Name = "ItemBadge"
	invIconBadge.Size = UDim2.fromOffset(18, 18)
	invIconBadge.Position = UDim2.new(1, -2, 0, 2)
	invIconBadge.AnchorPoint = Vector2.new(1, 0)
	invIconBadge.BackgroundColor3 = Color3.fromRGB(90, 150, 255)
	invIconBadge.BorderSizePixel = 0
	invIconBadge.Font = Enum.Font.GothamBold
	invIconBadge.TextSize = 10
	invIconBadge.TextColor3 = Color3.fromRGB(245, 248, 255)
	invIconBadge.Text = "0"
	invIconBadge.Visible = false
	invIconBadge.ZIndex = 8
	invIconBadge.Parent = btn
	do
		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(1, 0)
		badgeCorner.Parent = invIconBadge
	end

	btn.MouseEnter:Connect(function()
		tt.Visible = true
		TweenService:Create(btn, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(35, 40, 55),
			TextColor3 = Color3.fromRGB(230, 240, 255),
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		tt.Visible = false
		TweenService:Create(btn, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(20, 24, 32),
			TextColor3 = Color3.fromRGB(195, 215, 255),
		}):Play()
	end)

	btn.Activated:Connect(function()
		toggleInventoryPanel()
	end)
end

local function updateInventoryIconBadge()
	if not invIconBadge then return end
	local count = #cachedInventory
	invIconBadge.Text = tostring(math.min(count, 99))
	invIconBadge.Visible = count > 0
end

-- ==================== INVENTORY PANEL ====================
local invPanelOpen = false

local invPanel = Instance.new("Frame")
invPanel.Name = "InventoryPanel"
invPanel.Size = UDim2.fromOffset(300, 300)
invPanel.Position = UDim2.new(0, HUD_ACTION_PANEL_X, 1, -BOTTOM_OFFSET - 6)
invPanel.AnchorPoint = Vector2.new(0, 1)
invPanel.BackgroundColor3 = STAT_PANEL_BG
invPanel.BackgroundTransparency = 0.05
invPanel.BorderSizePixel = 0
invPanel.Visible = false
invPanel.ZIndex = 15
invPanel.Parent = screenGui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = invPanel
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(60, 65, 80)
	s.Thickness = 1.5
	s.Parent = invPanel
end

local invPanelTitle = Instance.new("TextLabel")
invPanelTitle.Size = UDim2.new(1, 0, 0, 36)
invPanelTitle.Position = UDim2.fromOffset(0, 0)
invPanelTitle.BackgroundTransparency = 1
invPanelTitle.Font = Enum.Font.GothamBold
invPanelTitle.TextSize = 15
invPanelTitle.TextColor3 = TEXT_COLOR
invPanelTitle.Text = "SCROLLS & FRUITS"
invPanelTitle.ZIndex = 16
invPanelTitle.Parent = invPanel

local invPanelHint = Instance.new("TextLabel")
invPanelHint.Size = UDim2.new(1, -16, 0, 16)
invPanelHint.Position = UDim2.fromOffset(8, 34)
invPanelHint.BackgroundTransparency = 1
invPanelHint.Font = Enum.Font.Gotham
invPanelHint.TextSize = 10
invPanelHint.TextColor3 = Color3.fromRGB(120, 120, 140)
invPanelHint.TextXAlignment = Enum.TextXAlignment.Left
invPanelHint.Text = "Equip a scroll or fruit to use its abilities."
invPanelHint.ZIndex = 16
invPanelHint.Parent = invPanel

local invScrollFrame = Instance.new("ScrollingFrame")
invScrollFrame.Name = "ItemList"
invScrollFrame.Size = UDim2.new(1, -16, 1, -60)
invScrollFrame.Position = UDim2.fromOffset(8, 54)
invScrollFrame.BackgroundTransparency = 1
invScrollFrame.BorderSizePixel = 0
invScrollFrame.ScrollBarThickness = 4
invScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 85, 100)
invScrollFrame.CanvasSize = UDim2.fromOffset(0, 0)
invScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
invScrollFrame.ZIndex = 16
invScrollFrame.Parent = invPanel

local invListLayout = Instance.new("UIListLayout")
invListLayout.Padding = UDim.new(0, 6)
invListLayout.SortOrder = Enum.SortOrder.LayoutOrder
invListLayout.Parent = invScrollFrame

local function rebuildInventoryPanel()
	for _, child in invScrollFrame:GetChildren() do
		if child:IsA("Frame") then
				child:Destroy()
			end
	end

	local RARITY_COLORS = {
		Common = Color3.fromRGB(180, 180, 180),
		Rare = Color3.fromRGB(60, 140, 255),
		Legendary = Color3.fromRGB(255, 165, 0),
	}

	if #cachedInventory == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.TextColor3 = Color3.fromRGB(120, 120, 140)
		empty.Text = "No items in inventory."
		empty.ZIndex = 17
		empty.Parent = invScrollFrame
		return
	end

	for i, itemId in cachedInventory do
		local item = ItemsModule and ItemsModule.getScroll(itemId)
		if not item then continue end

		local isEquipped = (item.Style == cachedEquippedStyle)
		local rarityColor = RARITY_COLORS[item.Rarity] or RARITY_COLORS.Common

		local row = Instance.new("Frame")
		row.Name = itemId .. "Row"
		row.Size = UDim2.new(1, 0, 0, 54)
		row.BackgroundColor3 = isEquipped and Color3.fromRGB(30, 38, 55) or Color3.fromRGB(22, 25, 35)
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.ZIndex = 17
		row.Parent = invScrollFrame
		do
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = row
			if isEquipped then
				local s = Instance.new("UIStroke")
				s.Color = rarityColor
				s.Thickness = 1.5
				s.Transparency = 0.2
				s.Parent = row
			end
		end

		local iconBox = Instance.new("Frame")
		iconBox.Size = UDim2.fromOffset(42, 42)
		iconBox.Position = UDim2.fromOffset(6, 6)
		iconBox.BackgroundColor3 = item.Color or Color3.fromRGB(40, 40, 55)
		iconBox.BackgroundTransparency = 0.3
		iconBox.BorderSizePixel = 0
		iconBox.ZIndex = 18
		iconBox.Parent = row
		do
			local ic = Instance.new("UICorner")
			ic.CornerRadius = UDim.new(0, 8)
			ic.Parent = iconBox
			local ig = Instance.new("UIGradient")
			ig.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.6, 0.6, 0.6))
			ig.Rotation = 135
			ig.Parent = iconBox
		end
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.fromScale(1, 1)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.TextSize = 22
		iconLabel.TextColor3 = Color3.new(1, 1, 1)
		iconLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		iconLabel.TextStrokeTransparency = 0.4
		iconLabel.Text = item.Icon or "?"
		iconLabel.ZIndex = 19
		iconLabel.Parent = iconBox

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.fromOffset(162, 18)
		nameLabel.Position = UDim2.fromOffset(54, 6)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextColor3 = rarityColor
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = item.Name
		nameLabel.ZIndex = 18
		nameLabel.Parent = row

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.fromOffset(162, 24)
		descLabel.Position = UDim2.fromOffset(54, 26)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 9
		descLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextWrapped = true
		descLabel.Text = item.Description
		descLabel.ZIndex = 18
		descLabel.Parent = row

		local equipBtn = Instance.new("TextButton")
		equipBtn.Size = UDim2.fromOffset(60, 30)
		equipBtn.Position = UDim2.new(1, -68, 0.5, 0)
		equipBtn.AnchorPoint = Vector2.new(0, 0.5)
		equipBtn.BackgroundColor3 = isEquipped and Color3.fromRGB(40, 90, 60) or STAT_BTN_COLOR
		equipBtn.BorderSizePixel = 0
		equipBtn.Font = Enum.Font.GothamBold
		equipBtn.TextSize = 11
		equipBtn.TextColor3 = isEquipped and Color3.fromRGB(80, 220, 120) or GOLD_COLOR
		equipBtn.Text = isEquipped and "Equipped" or "Equip"
		equipBtn.AutoButtonColor = false
		equipBtn.ZIndex = 18
		equipBtn.Parent = row
		do
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = equipBtn
		end

		if not isEquipped then
			equipBtn.MouseButton1Click:Connect(function()
				if EquipScrollRemote then
					EquipScrollRemote:FireServer(itemId)
					hudLog("EquipScroll requested: item=" .. tostring(itemId) .. ", style=" .. tostring(item.Style))
				else
					warn("[HUDController] EquipScroll remote missing; cannot equip item " .. tostring(itemId))
				end
			end)
			equipBtn.MouseEnter:Connect(function()
				TweenService:Create(equipBtn, TweenInfo.new(0.1), {BackgroundColor3 = STAT_BTN_HOVER}):Play()
			end)
			equipBtn.MouseLeave:Connect(function()
				TweenService:Create(equipBtn, TweenInfo.new(0.1), {BackgroundColor3 = STAT_BTN_COLOR}):Play()
			end)
		end
	end
end

toggleInventoryPanel = function()
	invPanelOpen = not invPanelOpen
	hudLog("Inventory panel " .. (invPanelOpen and "opened" or "closed") .. "; items=" .. tostring(#cachedInventory))
	if invPanelOpen then
		updateInventoryIconBadge()
		rebuildInventoryPanel()
		invPanel.Visible = true
		invPanel.Size = UDim2.fromOffset(300, 0)
		invPanel.BackgroundTransparency = 1
		TweenService:Create(invPanel, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(300, 300),
			BackgroundTransparency = 0.05,
		}):Play()
	else
		TweenService:Create(invPanel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromOffset(300, 0),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.18, function()
			if not invPanelOpen then
					invPanel.Visible = false
				end
		end)
	end
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
local ZoneChangedRemote = Remotes:FindFirstChild("ZoneChanged")

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

local safeZoneBanner = Instance.new("TextLabel")
safeZoneBanner.Name = "SafeZoneBanner"
safeZoneBanner.Size = UDim2.fromOffset(220, 30)
safeZoneBanner.Position = UDim2.new(0.5, 0, 0, 18)
safeZoneBanner.AnchorPoint = Vector2.new(0.5, 0)
safeZoneBanner.BackgroundColor3 = Color3.fromRGB(20, 60, 90)
safeZoneBanner.BackgroundTransparency = 0.18
safeZoneBanner.BorderSizePixel = 0
safeZoneBanner.Font = Enum.Font.GothamBold
safeZoneBanner.TextSize = 14
safeZoneBanner.TextColor3 = Color3.fromRGB(195, 240, 255)
safeZoneBanner.TextStrokeColor3 = SHADOW_COLOR
safeZoneBanner.TextStrokeTransparency = 0.45
safeZoneBanner.Text = "SAFE ZONE"
safeZoneBanner.Visible = false
safeZoneBanner.ZIndex = 18
safeZoneBanner.Parent = screenGui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = safeZoneBanner
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(90, 200, 255)
	s.Thickness = 1
	s.Transparency = 0.25
	s.Parent = safeZoneBanner
end

-- ==================== EVENT CONNECTIONS ====================
HPChanged.OnClientEvent:Connect(function(hp, maxHp)
	hudTrace("HPChanged received: " .. tostring(hp) .. "/" .. tostring(maxHp))
	forceHudVisible("HPChanged")
	updateHP(hp, maxHp)
end)

StaminaChanged.OnClientEvent:Connect(function(stamina, maxStam)
	hudTrace("StaminaChanged received: " .. tostring(stamina) .. "/" .. tostring(maxStam))
	updateStamina(stamina, maxStam)
end)

PlayerDeath.OnClientEvent:Connect(function(respawnTime)
	showDeathScreen(respawnTime or 5)
end)

PlayerRespawn.OnClientEvent:Connect(function()
	hideDeathScreen()
end)

StatsChanged.OnClientEvent:Connect(function(level, xp, xpNeeded, totalXP)
	hudLog("StatsChanged received: level=" .. tostring(level) .. ", xp=" .. tostring(xp) .. "/" .. tostring(xpNeeded))
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
		cachedFaction = data.TechniqueFaction or data.Faction or ""
		cachedEquippedStyle = data.EquippedStyle or cachedEquippedStyle
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

if ZoneChangedRemote then
	ZoneChangedRemote.OnClientEvent:Connect(function(newZone)
		local inSafeZone = newZone == "SafeZone"
		safeZoneBanner.Visible = inSafeZone
		if inSafeZone then
			safeZoneBanner.TextTransparency = 1
			TweenService:Create(safeZoneBanner, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if titlePanelShowing and hideTitlePanel and (
		input.KeyCode == Enum.KeyCode.Escape
			or input.KeyCode == Enum.KeyCode.Backspace
			or input.KeyCode == Enum.KeyCode.ButtonB
	) then
		hudLog("Title panel closed from input: " .. tostring(input.KeyCode))
		hideTitlePanel()
		return
	end
	if input.KeyCode == Enum.KeyCode.P then
		toggleStatPanel()
	end
end)

-- ==================== TITLE SELECTION UI ====================
local function initTitleSelectionUI()
local SLAYER_COLOR = Color3.fromRGB(50, 120, 220)
local DEMON_COLOR = Color3.fromRGB(180, 40, 60)

local factionOverlay = Instance.new("Frame")
factionOverlay.Name = "TitleOverlay"
factionOverlay.Size = UDim2.fromScale(1, 1)
factionOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
factionOverlay.BackgroundTransparency = 0.35
factionOverlay.BorderSizePixel = 0
factionOverlay.Visible = false
factionOverlay.ZIndex = 30
factionOverlay.Parent = screenGui

local titleBackdropClose = Instance.new("TextButton")
titleBackdropClose.Name = "BackdropClose"
titleBackdropClose.Size = UDim2.fromScale(1, 1)
titleBackdropClose.BackgroundTransparency = 1
titleBackdropClose.BorderSizePixel = 0
titleBackdropClose.Text = ""
titleBackdropClose.AutoButtonColor = false
titleBackdropClose.ZIndex = 30
titleBackdropClose.Parent = factionOverlay
titleBackdropClose.MouseButton1Click:Connect(function()
	if titlePanelShowing and hideTitlePanel then
		hudLog("Title panel closed from backdrop")
		hideTitlePanel()
	end
end)

local factionPanel = Instance.new("Frame")
factionPanel.Name = "TitlePanel"
factionPanel.Size = UDim2.fromOffset(620, 440)
factionPanel.Position = UDim2.fromScale(0.5, 0.5)
factionPanel.AnchorPoint = Vector2.new(0.5, 0.5)
factionPanel.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
factionPanel.BackgroundTransparency = 0.05
factionPanel.BorderSizePixel = 0
factionPanel.ZIndex = 31
factionPanel.Parent = factionOverlay
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = factionPanel
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(80, 85, 100)
	s.Thickness = 1.5
	s.Parent = factionPanel
end

local factionTitle = Instance.new("TextLabel")
factionTitle.Name = "Title"
factionTitle.Size = UDim2.new(1, 0, 0, 40)
factionTitle.Position = UDim2.fromOffset(0, 10)
factionTitle.BackgroundTransparency = 1
factionTitle.Font = Enum.Font.GothamBold
factionTitle.TextSize = 20
factionTitle.TextColor3 = TEXT_COLOR
factionTitle.TextStrokeColor3 = SHADOW_COLOR
factionTitle.TextStrokeTransparency = 0.3
factionTitle.Text = "TITLES"
factionTitle.ZIndex = 32
factionTitle.Parent = factionPanel

local factionSubtitle = Instance.new("TextLabel")
factionSubtitle.Size = UDim2.new(1, 0, 0, 18)
factionSubtitle.Position = UDim2.fromOffset(0, 46)
factionSubtitle.BackgroundTransparency = 1
factionSubtitle.Font = Enum.Font.Gotham
factionSubtitle.TextSize = 12
factionSubtitle.TextColor3 = Color3.fromRGB(140, 140, 160)
factionSubtitle.Text = "Equip a title to gain its buff. Titles gain XP as you fight."
factionSubtitle.ZIndex = 32
factionSubtitle.Parent = factionPanel

local titleCloseBtn = Instance.new("TextButton")
titleCloseBtn.Name = "CloseButton"
titleCloseBtn.Size = UDim2.fromOffset(30, 30)
titleCloseBtn.Position = UDim2.new(1, -42, 0, 14)
titleCloseBtn.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
titleCloseBtn.BackgroundTransparency = 0.1
titleCloseBtn.BorderSizePixel = 0
titleCloseBtn.Font = Enum.Font.GothamBold
titleCloseBtn.TextSize = 14
titleCloseBtn.TextColor3 = Color3.fromRGB(220, 225, 235)
titleCloseBtn.Text = "X"
titleCloseBtn.AutoButtonColor = false
titleCloseBtn.ZIndex = 34
titleCloseBtn.Parent = factionPanel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = titleCloseBtn
end

local titleListFrame = Instance.new("ScrollingFrame")
titleListFrame.Name = "TitleList"
titleListFrame.Size = UDim2.new(1, -28, 1, -86)
titleListFrame.Position = UDim2.fromOffset(14, 74)
titleListFrame.BackgroundTransparency = 1
titleListFrame.BorderSizePixel = 0
titleListFrame.ScrollBarThickness = 5
titleListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 90, 120)
titleListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
titleListFrame.CanvasSize = UDim2.fromOffset(0, 0)
titleListFrame.ZIndex = 32
titleListFrame.Parent = factionPanel

local titleListLayout = Instance.new("UIListLayout")
titleListLayout.Padding = UDim.new(0, 8)
titleListLayout.SortOrder = Enum.SortOrder.LayoutOrder
titleListLayout.Parent = titleListFrame

local titleListPadding = Instance.new("UIPadding")
titleListPadding.PaddingRight = UDim.new(0, 6)
titleListPadding.Parent = titleListFrame

titleCloseBtn.MouseEnter:Connect(function()
	TweenService:Create(titleCloseBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(45, 50, 64),
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}):Play()
end)
titleCloseBtn.MouseLeave:Connect(function()
	TweenService:Create(titleCloseBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(25, 28, 38),
		TextColor3 = Color3.fromRGB(220, 225, 235),
	}):Play()
end)
titleCloseBtn.MouseButton1Click:Connect(function()
	if hideTitlePanel then
		hudLog("Title panel closed from close button")
		hideTitlePanel()
	else
		warn("[HUDController] Title close requested before hideTitlePanel was initialized")
	end
end)

local NORMAL_DISPLAY_ORDER = 30
local MODAL_DISPLAY_ORDER = 100

-- title card refs so we can refresh them
local titleCardRefs = {}

local function brightenColor(color)
	return Color3.new(
		math.clamp(color.R + 0.08, 0, 1),
		math.clamp(color.G + 0.08, 0, 1),
		math.clamp(color.B + 0.08, 0, 1)
	)
end

local function createTitleRow(titleId, layoutOrder)
	local titleDef = TitleModule and TitleModule.getTitle(titleId)
	if not titleDef then
		warn("[HUDController] Cannot create title row for unknown title: " .. tostring(titleId))
		return
	end
	local color = titleDef.Color or (titleDef.Faction == "Demon" and DEMON_COLOR or SLAYER_COLOR)
	local hoverColor = brightenColor(color)

	local card = Instance.new("Frame")
	card.Name = titleId .. "Row"
	card.Size = UDim2.new(1, 0, 0, 96)
	card.Position = UDim2.fromOffset(0, 0)
	card.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.ZIndex = 32
	card.Parent = titleListFrame

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = color
	cardStroke.Thickness = 2
	cardStroke.Transparency = 0.5
	cardStroke.Parent = card

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size = UDim2.fromOffset(52, 52)
	iconLbl.Position = UDim2.fromOffset(12, 12)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Font = Enum.Font.GothamBold
	iconLbl.TextSize = 30
	iconLbl.TextColor3 = color
	iconLbl.Text = titleDef.Icon or (titleDef.Faction == "Slayer" and "⚔" or "👹")
	iconLbl.ZIndex = 33
	iconLbl.Parent = card

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -190, 0, 22)
	nameLbl.Position = UDim2.fromOffset(70, 10)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 16
	nameLbl.TextColor3 = color
	nameLbl.TextStrokeColor3 = SHADOW_COLOR
	nameLbl.TextStrokeTransparency = 0.5
	nameLbl.Text = titleDef.Name
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.ZIndex = 33
	nameLbl.Parent = card

	local buffLbl = Instance.new("TextLabel")
	buffLbl.Name = "BuffLabel"
	buffLbl.Size = UDim2.new(1, -190, 0, 32)
	buffLbl.Position = UDim2.fromOffset(70, 34)
	buffLbl.BackgroundTransparency = 1
	buffLbl.Font = Enum.Font.Gotham
	buffLbl.TextSize = 10
	buffLbl.TextColor3 = Color3.fromRGB(180, 180, 195)
	buffLbl.TextWrapped = true
	buffLbl.TextXAlignment = Enum.TextXAlignment.Left
	buffLbl.Text = titleDef.Description or ""
	buffLbl.ZIndex = 33
	buffLbl.Parent = card

	-- XP bar area
	local xpBg = Instance.new("Frame")
	xpBg.Name = "XPBg"
	xpBg.Size = UDim2.new(1, -200, 0, 8)
	xpBg.Position = UDim2.fromOffset(70, 70)
	xpBg.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
	xpBg.BorderSizePixel = 0
	xpBg.ZIndex = 33
	xpBg.Parent = card
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = xpBg
	end

	local titleXPFill = Instance.new("Frame")
	titleXPFill.Name = "XPFill"
	titleXPFill.Size = UDim2.fromScale(0, 1)
	titleXPFill.BackgroundColor3 = color
	titleXPFill.BorderSizePixel = 0
	titleXPFill.ZIndex = 34
	titleXPFill.Parent = xpBg
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = titleXPFill
	end

	local xpLbl = Instance.new("TextLabel")
	xpLbl.Name = "XPLabel"
	xpLbl.Size = UDim2.new(0.5, -78, 0, 14)
	xpLbl.Position = UDim2.fromOffset(70, 80)
	xpLbl.BackgroundTransparency = 1
	xpLbl.Font = Enum.Font.GothamMedium
	xpLbl.TextSize = 9
	xpLbl.TextColor3 = Color3.fromRGB(140, 140, 160)
	xpLbl.TextXAlignment = Enum.TextXAlignment.Left
	xpLbl.Text = "Lv 0 — 0 / 100 XP"
	xpLbl.ZIndex = 33
	xpLbl.Parent = card

	local buffValueLbl = Instance.new("TextLabel")
	buffValueLbl.Name = "BuffValue"
	buffValueLbl.Size = UDim2.new(0.5, -20, 0, 14)
	buffValueLbl.Position = UDim2.new(0.5, -20, 0, 80)
	buffValueLbl.BackgroundTransparency = 1
	buffValueLbl.Font = Enum.Font.GothamBold
	buffValueLbl.TextSize = 10
	buffValueLbl.TextColor3 = GOLD_COLOR
	buffValueLbl.TextXAlignment = Enum.TextXAlignment.Left
	buffValueLbl.Text = "Buff: +5.0%"
	buffValueLbl.ZIndex = 33
	buffValueLbl.Parent = card

	-- Equip / Unequip button
	local equipBtn = Instance.new("TextButton")
	equipBtn.Name = "EquipBtn"
	equipBtn.Size = UDim2.fromOffset(96, 30)
	equipBtn.Position = UDim2.new(1, -108, 0, 16)
	equipBtn.BackgroundColor3 = color
	equipBtn.BorderSizePixel = 0
	equipBtn.Font = Enum.Font.GothamBold
	equipBtn.TextSize = 13
	equipBtn.TextColor3 = TEXT_COLOR
	equipBtn.Text = "Equip"
	equipBtn.AutoButtonColor = false
	equipBtn.ZIndex = 33
	equipBtn.Parent = card
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = equipBtn
	end

	-- Rebirth button (only visible at max level)
	local rebirthBtn = Instance.new("TextButton")
	rebirthBtn.Name = "RebirthBtn"
	rebirthBtn.Size = UDim2.fromOffset(96, 24)
	rebirthBtn.Position = UDim2.new(1, -108, 0, 54)
	rebirthBtn.BackgroundColor3 = Color3.fromRGB(180, 140, 20)
	rebirthBtn.BorderSizePixel = 0
	rebirthBtn.Font = Enum.Font.GothamBold
	rebirthBtn.TextSize = 11
	rebirthBtn.TextColor3 = TEXT_COLOR
	rebirthBtn.Text = "Rebirth"
	rebirthBtn.AutoButtonColor = false
	rebirthBtn.Visible = false
	rebirthBtn.ZIndex = 33
	rebirthBtn.Parent = card
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = rebirthBtn
	end

	equipBtn.MouseEnter:Connect(function()
		TweenService:Create(equipBtn, TweenInfo.new(0.12), {BackgroundColor3 = hoverColor}):Play()
		TweenService:Create(cardStroke, TweenInfo.new(0.12), {Transparency = 0}):Play()
	end)
	equipBtn.MouseLeave:Connect(function()
		TweenService:Create(equipBtn, TweenInfo.new(0.12), {BackgroundColor3 = color}):Play()
		TweenService:Create(cardStroke, TweenInfo.new(0.12), {Transparency = 0.5}):Play()
	end)
	equipBtn.MouseButton1Click:Connect(function()
		if not EquipTitleRemote then
			warn("[HUDController] EquipTitle remote missing; cannot equip title " .. tostring(titleId))
			return
		end
		local isEquipped = (cachedEquippedTitle == titleId)
		if not isEquipped then
			hudLog("EquipTitle requested: " .. tostring(titleId))
			EquipTitleRemote:FireServer(titleId, false)
		else
			hudLog("EquipTitle ignored because title is already equipped: " .. tostring(titleId))
		end
	end)

	rebirthBtn.MouseEnter:Connect(function()
		TweenService:Create(rebirthBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(220, 170, 30)}):Play()
	end)
	rebirthBtn.MouseLeave:Connect(function()
		TweenService:Create(rebirthBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(180, 140, 20)}):Play()
	end)
	rebirthBtn.MouseButton1Click:Connect(function()
		if TitleRebirthRemote then
			hudLog("TitleRebirth requested: " .. tostring(titleId))
			TitleRebirthRemote:FireServer(titleId)
		else
			warn("[HUDController] TitleRebirth remote missing; cannot rebirth title " .. tostring(titleId))
		end
	end)

	titleCardRefs[titleId] = {
		Card = card, Stroke = cardStroke,
		XPFill = titleXPFill, XPLabel = xpLbl,
		BuffValue = buffValueLbl, EquipBtn = equipBtn, RebirthBtn = rebirthBtn,
		Color = color,
	}
end

local function getTitleList()
	if not TitleModule then return {} end
	if TitleModule.getAllTitles then
		return TitleModule.getAllTitles()
	end
	local titles = {}
	for _, title in pairs(TitleModule.TITLES or {}) do
		table.insert(titles, title)
	end
	table.sort(titles, function(a, b)
		return (a.Name or a.Id) < (b.Name or b.Id)
	end)
	return titles
end

local function rebuildTitleRows()
	for _, child in titleListFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	titleCardRefs = {}

	local titles = getTitleList()
	if #titles == 0 then
		warn("[HUDController] Title list is empty; title panel has no selectable rows")
		return
	end

	for index, titleDef in ipairs(titles) do
		if titleDef.Id then
			createTitleRow(titleDef.Id, index)
		else
			warn("[HUDController] Skipping title with missing Id at title list index " .. tostring(index))
		end
	end
	hudLog("Title list rebuilt: " .. tostring(#titles) .. " titles")
end

local function refreshTitleCards()
	if not TitleModule then return end
	for titleId, refs in titleCardRefs do
		local titleDef = TitleModule.getTitle(titleId)
		if not titleDef then continue end

		local isEquipped = (cachedEquippedTitle == titleId)
		local td = cachedTitles[titleId]
		local level = td and (td.Level or 0) or 0
		local xp = td and (td.XP or 0) or 0
		local xpNeeded = TitleModule.xpForLevel(titleId, math.max(level, 1))
		local rebirthCount = td and (td.RebirthCount or 0) or 0
		local buff = TitleModule.computeBuff(titleId, math.max(level, 1), rebirthCount)

		local ratio = level >= titleDef.MaxLevel and 1 or math.clamp(xp / math.max(xpNeeded, 1), 0, 1)
		TweenService:Create(refs.XPFill, TweenInfo.new(0.3), {Size = UDim2.fromScale(ratio, 1)}):Play()
		refs.XPLabel.Text = level >= titleDef.MaxLevel
			and ("Lv " .. level .. " — MAX")
			or ("Lv " .. level .. " — " .. xp .. " / " .. xpNeeded .. " XP")
		refs.BuffValue.Text = string.format("Buff: +%.1f%%  |  Rebirth x%d", buff * 100, rebirthCount)

		refs.RebirthBtn.Visible = (level >= titleDef.MaxLevel and isEquipped)

		if isEquipped then
			refs.EquipBtn.Text = "Equipped"
			refs.EquipBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
			TweenService:Create(refs.Stroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
		else
			refs.EquipBtn.Text = "Equip"
			refs.EquipBtn.BackgroundColor3 = refs.Color
			TweenService:Create(refs.Stroke, TweenInfo.new(0.2), {Transparency = 0.5}):Play()
		end
	end
end

showTitlePanel = function()
	if not TitleModule then
		warn("[HUDController] Title panel requested before TitleModule loaded")
		return
	end
	if titlePanelShowing then return end
	titlePanelShowing = true
	rebuildTitleRows()
	refreshTitleCards()
	hudLog("Title panel opened")
	screenGui.DisplayOrder = MODAL_DISPLAY_ORDER
	factionOverlay.Visible = true
	factionPanel.Size = UDim2.fromOffset(620, 0)
	factionPanel.BackgroundTransparency = 1
	TweenService:Create(factionPanel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(620, 440),
		BackgroundTransparency = 0.05,
	}):Play()
	TweenService:Create(factionOverlay, TweenInfo.new(0.25), {BackgroundTransparency = 0.35}):Play()
end

hideTitlePanel = function()
	if not titlePanelShowing then return end
	hudLog("Title panel closing")
	TweenService:Create(factionPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(620, 0),
	}):Play()
	TweenService:Create(factionOverlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
	task.delay(0.25, function()
		factionOverlay.Visible = false
		titlePanelShowing = false
		screenGui.DisplayOrder = NORMAL_DISPLAY_ORDER
	end)
end

local titleConfirmSound = Instance.new("Sound")
titleConfirmSound.Name = "TitleConfirmSound"
titleConfirmSound.SoundId = "rbxassetid://9125402735"
titleConfirmSound.Volume = 0.7
titleConfirmSound.Parent = SoundService

ShowFactionSelectRemote.OnClientEvent:Connect(function()
	showTitlePanel()
end)

FactionChosenRemote.OnClientEvent:Connect(function(_faction)
	titleConfirmSound:Play()
	hideTitlePanel()
end)

if InventoryChangedRemote then
	InventoryChangedRemote.OnClientEvent:Connect(function(inventory, equippedStyle)
		cachedInventory = typeof(inventory) == "table" and inventory or {}
		cachedEquippedStyle = typeof(equippedStyle) == "string" and equippedStyle or cachedEquippedStyle
		updateInventoryIconBadge()
		hudLog("InventoryChanged received: items=" .. tostring(#cachedInventory) .. ", style=" .. tostring(cachedEquippedStyle))
		if invPanelOpen then
			rebuildInventoryPanel()
		end
	end)
end

if StyleChangedRemote then
	StyleChangedRemote.OnClientEvent:Connect(function(style)
		cachedEquippedStyle = typeof(style) == "string" and style or cachedEquippedStyle
		hudLog("StyleChanged received: style=" .. tostring(cachedEquippedStyle))
	end)
end

local TitleChangedRemote = Remotes:FindFirstChild("TitleChanged")
if TitleChangedRemote then
	TitleChangedRemote.OnClientEvent:Connect(function(titleId, titleData, equippedTitle)
		if typeof(titleId) == "string" and typeof(titleData) == "table" then
			cachedTitles[titleId] = titleData
		end
		if typeof(equippedTitle) == "string" then
			cachedEquippedTitle = equippedTitle
		end
		hudLog("TitleChanged received: title=" .. tostring(titleId) .. ", equipped=" .. tostring(cachedEquippedTitle))
		if titlePanelShowing then
			refreshTitleCards()
		end
	end)
end

task.spawn(function()
	local GetPlayerData = Remotes:FindFirstChild("GetPlayerData")
	if not GetPlayerData then return end
	local ok, result = pcall(function()
		return GetPlayerData:InvokeServer()
	end)
	if not (ok and result and typeof(result) == "table") then
		return
	end
	if typeof(result.Inventory) == "table" then
		cachedInventory = result.Inventory
	end
	updateInventoryIconBadge()
	cachedEquippedStyle = result.EquippedStyle or ""
	cachedEquippedTitle = result.EquippedTitle or ""
	if typeof(result.Titles) == "table" then
		cachedTitles = result.Titles
	end
	hudLog(
		"Initial player data: level=" .. tostring(result.Level)
			.. ", faction=" .. tostring(result.Faction)
			.. ", title=" .. tostring(cachedEquippedTitle)
			.. ", style=" .. tostring(cachedEquippedStyle)
			.. ", needsTitleSelection=" .. tostring(result.NeedsTitleSelection)
			.. ", inventory=" .. tostring(typeof(result.Inventory) == "table" and #result.Inventory or 0)
	)
	if result.NeedsTitleSelection or cachedEquippedTitle == "" then
		task.defer(function()
			hudLog("Initial player data requested title panel")
			showTitlePanel()
		end)
	end
end)

end

initTitleSelectionUI()

-- ==================== LUNGE COOLDOWN INDICATOR ====================
local function initLungeCooldownIndicator()
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
	hintLabel.Text = isGamepad and "Use the stats icon to close" or "Press [P] to close"
	lungeKeyLabel.Text = isGamepad and "L3" or "SHIFT"

	if cachedStatPoints > 0 then
		local key = isGamepad and "Stats icon" or "P"
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
end

initLungeCooldownIndicator()

-- ==================== MASTERY BAR SYSTEM ====================
local function initMasteryBarSystem()
	local currentMasteryFaction = ""
	local currentMasteryStyleId = ""
	local currentMasteryLevel = 0
	local currentMasteryXP = 0
	local currentMasteryXPNeeded = 30
	local masteryEquipped = false
	local masteryCache = {}
	local MASTERY_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local MASTERY_FLASH_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local function getActiveStyleFromSkills(faction)
		if cachedEquippedStyle ~= "" then
			return cachedEquippedStyle
		end
		local lookup = faction
		for _, slot in {"Q", "E", "R", "F", "V"} do
			local skill = SkillSystemModule.getSkillForSlot(lookup, slot)
			if skill then
				return skill.Style or ""
			end
		end
		return ""
	end

	local function getMasteryXPNeeded(level)
		return math.floor(30 * ((level or 1) ^ 1.25))
	end

	local function setDisplayedMastery(styleId)
		if typeof(styleId) ~= "string" or styleId == "" then
			masteryEquipped = false
			currentMasteryStyleId = ""
			currentMasteryLevel = 0
			currentMasteryXP = 0
			currentMasteryXPNeeded = 30
			return
		end

		local mastery = masteryCache[styleId]
		local level = mastery and (mastery.Level or 1) or 1
		currentMasteryStyleId = styleId
		currentMasteryLevel = level
		currentMasteryXP = mastery and (mastery.XP or 0) or 0
		currentMasteryXPNeeded = mastery and (mastery.XPNeeded or getMasteryXPNeeded(level)) or getMasteryXPNeeded(level)
		masteryEquipped = true
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

		local skill = SkillSystemModule.getSkillForSlot(currentMasteryStyleId, "Q")
		local displayName = currentMasteryStyleId
		local style = currentMasteryStyleId
		if style ~= "" then
			if style == "FlameBreathing" then
				displayName = "Flame Breath"
				local flameColor1 = Color3.fromRGB(255, 100, 20)
				local flameColor2 = Color3.fromRGB(200, 50, 10)
				masteryFill.BackgroundColor3 = flameColor1
				masteryFillGradient.Color = ColorSequence.new(flameColor1, flameColor2)
			elseif style == "TemariDemonArts" then
				displayName = "Temari Art"
				local temariColor1 = Color3.fromRGB(200, 60, 220)
				local temariColor2 = Color3.fromRGB(130, 20, 170)
				masteryFill.BackgroundColor3 = temariColor1
				masteryFillGradient.Color = ColorSequence.new(temariColor1, temariColor2)
			elseif skill and skill.Faction == "Slayer" then
				displayName = "Water Breath"
				masteryFill.BackgroundColor3 = MASTERY_BREATH_COLOR1
				masteryFillGradient.Color = ColorSequence.new(MASTERY_BREATH_COLOR1, MASTERY_BREATH_COLOR2)
			elseif skill and skill.Faction == "Demon" then
				displayName = "Blood Demon Art"
				masteryFill.BackgroundColor3 = MASTERY_DEMON_COLOR1
				masteryFillGradient.Color = ColorSequence.new(MASTERY_DEMON_COLOR1, MASTERY_DEMON_COLOR2)
			end
			if skill then
				currentMasteryFaction = skill.Faction
			end
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
			if typeof(styleId) == "string" and styleId ~= "" then
				masteryCache[styleId] = {
					Level = level or 1,
					XP = xp or 0,
					XPNeeded = xpNeeded or getMasteryXPNeeded(level or 1),
				}
			end
			local activeStyle = getActiveStyleFromSkills(currentMasteryFaction)
			if styleId == activeStyle or styleId == currentMasteryStyleId then
				setDisplayedMastery(styleId)
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
			setDisplayedMastery(activeStyle)
		else
			setDisplayedMastery("")
		end
		updateMasteryBarUI()
	end)

	if StyleChangedRemote then
		StyleChangedRemote.OnClientEvent:Connect(function(style)
			if typeof(style) ~= "string" or style == "" then return end
			local activeStyle = getActiveStyleFromSkills(currentMasteryFaction)
			if activeStyle ~= "" then
				setDisplayedMastery(activeStyle)
				updateMasteryBarUI()
			end
		end)
	end

	task.spawn(function()
		local GetPlayerData = Remotes:FindFirstChild("GetPlayerData")
		if GetPlayerData then
			local ok, result = pcall(function()
				return GetPlayerData:InvokeServer()
			end)
			if ok and result and typeof(result) == "table" then
				if typeof(result.Mastery) == "table" then
					masteryCache = result.Mastery
				end
				hudLog(
					"Mastery player data: faction=" .. tostring(result.Faction)
						.. ", title=" .. tostring(result.EquippedTitle)
						.. ", style=" .. tostring(result.EquippedStyle)
						.. ", needsTitleSelection=" .. tostring(result.NeedsTitleSelection)
				)
				if result.Faction and result.Faction ~= "" then
					currentMasteryFaction = result.Faction
					local activeStyle = getActiveStyleFromSkills(result.Faction)
					if activeStyle ~= "" then
						setDisplayedMastery(activeStyle)
					end
				elseif result.NeedsTitleSelection or result.Level then
					hudLog("No faction set; showing title panel from client-side check")
					showTitlePanel()
				end
				updateMasteryBarUI()
			end
		end
	end)

	updateMasteryBarUI()
end

initMasteryBarSystem()

print("[HUDController] Loaded")
