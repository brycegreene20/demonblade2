local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local InputModeValue = ReplicatedStorage:WaitForChild("InputMode")

local PROMPT_LABELS = {
	Xbox = "X",
	PlayStation = "□",
	Keyboard = "E",
}

local function getPromptLabel()
	return PROMPT_LABELS[InputModeValue.Value] or "E"
end

local HOLD_DURATION = 1.0
local CIRCLE_SIZE = 80
local RING_THICKNESS = 6
local BG_COLOR = Color3.fromRGB(12, 14, 22)
local RING_BG_COLOR = Color3.fromRGB(50, 50, 60)
local FILL_COLOR = Color3.fromRGB(255, 200, 50)
local COMPLETE_COLOR = Color3.fromRGB(80, 220, 100)
local TEXT_COLOR = Color3.fromRGB(240, 240, 245)
local TEXT_DIM = Color3.fromRGB(180, 180, 190)
local KEY_COLOR = Color3.fromRGB(255, 200, 50)

local TWEEN_SHOW = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_HIDE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local _TWEEN_PULSE = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InteractionPromptUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 15
screenGui.Parent = PlayerGui

local activePrompts = {}

local function _createSegment(parent, index, total, _innerRadius, _outerRadius, _color, _transparency)
	local segmentAngle = 360 / total
	local startAngle = (index - 1) * segmentAngle - 90

	local container = Instance.new("Frame")
	container.Name = "Segment_" .. index
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = true
	container.Parent = parent

	local mask = Instance.new("Frame")
	mask.Size = UDim2.fromScale(1, 1)
	mask.Position = UDim2.fromScale(0.5, 0.5)
	mask.AnchorPoint = Vector2.new(0.5, 0.5)
	mask.BackgroundTransparency = 1
	mask.Rotation = startAngle
	mask.ClipsDescendants = true
	mask.Parent = container

	local halfMask = Instance.new("Frame")
	halfMask.Size = UDim2.fromScale(0.5, 1)
	halfMask.Position = UDim2.fromScale(0.5, 0)
	halfMask.BackgroundTransparency = 1
	halfMask.ClipsDescendants = true
	halfMask.Parent = mask

	return container
end

local function createCircularPromptUI(prompt)
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "HoldPromptUI"
	billboardGui.Size = UDim2.fromOffset(160, 130)
	billboardGui.StudsOffset = Vector3.new(0, 4, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.Active = false
	billboardGui.ClipsDescendants = false

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromScale(1, 1)
	mainFrame.BackgroundTransparency = 1
	mainFrame.Parent = billboardGui

	local circleContainer = Instance.new("Frame")
	circleContainer.Name = "CircleContainer"
	circleContainer.Size = UDim2.fromOffset(CIRCLE_SIZE, CIRCLE_SIZE)
	circleContainer.Position = UDim2.fromScale(0.5, 0)
	circleContainer.AnchorPoint = Vector2.new(0.5, 0)
	circleContainer.BackgroundTransparency = 1
	circleContainer.Parent = mainFrame

	local outerRing = Instance.new("Frame")
	outerRing.Name = "OuterRing"
	outerRing.Size = UDim2.fromScale(1, 1)
	outerRing.Position = UDim2.fromScale(0.5, 0.5)
	outerRing.AnchorPoint = Vector2.new(0.5, 0.5)
	outerRing.BackgroundColor3 = RING_BG_COLOR
	outerRing.BackgroundTransparency = 0.3
	outerRing.Parent = circleContainer

	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(0.5, 0)
	outerCorner.Parent = outerRing

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = RING_BG_COLOR
	outerStroke.Thickness = 2
	outerStroke.Transparency = 0.5
	outerStroke.Parent = outerRing

	local innerCircle = Instance.new("Frame")
	innerCircle.Name = "InnerCircle"
	innerCircle.Size = UDim2.new(1, -RING_THICKNESS * 2, 1, -RING_THICKNESS * 2)
	innerCircle.Position = UDim2.fromScale(0.5, 0.5)
	innerCircle.AnchorPoint = Vector2.new(0.5, 0.5)
	innerCircle.BackgroundColor3 = BG_COLOR
	innerCircle.BackgroundTransparency = 0.1
	innerCircle.ZIndex = 3
	innerCircle.Parent = circleContainer

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0.5, 0)
	innerCorner.Parent = innerCircle

	local fillFrame = Instance.new("Frame")
	fillFrame.Name = "FillFrame"
	fillFrame.Size = UDim2.fromScale(1, 1)
	fillFrame.Position = UDim2.fromScale(0.5, 0.5)
	fillFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	fillFrame.BackgroundTransparency = 1
	fillFrame.ZIndex = 2
	fillFrame.ClipsDescendants = true
	fillFrame.Parent = circleContainer

	local fillCircle = Instance.new("Frame")
	fillCircle.Name = "FillCircle"
	fillCircle.Size = UDim2.fromScale(1, 1)
	fillCircle.BackgroundColor3 = FILL_COLOR
	fillCircle.BackgroundTransparency = 0
	fillCircle.Parent = fillFrame

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fillCircle

	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
	fillGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.499, 0),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	fillGradient.Rotation = 0
	fillGradient.Parent = fillCircle

	local fillCircle2 = fillCircle:Clone()
	fillCircle2.Name = "FillCircle2"
	fillCircle2.Parent = fillFrame
	local fillGradient2 = fillCircle2:FindFirstChildOfClass("UIGradient")

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyLabel"
	keyLabel.Size = UDim2.fromScale(1, 1)
	keyLabel.Position = UDim2.fromScale(0.5, 0.5)
	keyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text = "E"
	keyLabel.TextColor3 = KEY_COLOR
	keyLabel.TextSize = 28
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.ZIndex = 4
	keyLabel.Parent = circleContainer

	local keyStroke = Instance.new("UIStroke")
	keyStroke.Color = Color3.fromRGB(0, 0, 0)
	keyStroke.Thickness = 2
	keyStroke.Transparency = 0.3
	keyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	keyStroke.LineJoinMode = Enum.LineJoinMode.Round
	keyStroke.Parent = keyLabel

	local checkmark = Instance.new("TextLabel")
	checkmark.Name = "Checkmark"
	checkmark.Size = UDim2.fromScale(1, 1)
	checkmark.Position = UDim2.fromScale(0.5, 0.5)
	checkmark.AnchorPoint = Vector2.new(0.5, 0.5)
	checkmark.BackgroundTransparency = 1
	checkmark.Text = "✓"
	checkmark.TextColor3 = COMPLETE_COLOR
	checkmark.TextSize = 36
	checkmark.Font = Enum.Font.GothamBold
	checkmark.ZIndex = 5
	checkmark.Visible = false
	checkmark.Parent = circleContainer

	local checkStroke = Instance.new("UIStroke")
	checkStroke.Color = Color3.fromRGB(0, 0, 0)
	checkStroke.Thickness = 2
	checkStroke.Transparency = 0.3
	checkStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	checkStroke.LineJoinMode = Enum.LineJoinMode.Round
	checkStroke.Parent = checkmark

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "ActionLabel"
	actionLabel.Size = UDim2.new(1, 0, 0, 20)
	actionLabel.Position = UDim2.new(0.5, 0, 1, 8)
	actionLabel.AnchorPoint = Vector2.new(0.5, 0)
	actionLabel.BackgroundTransparency = 1
	actionLabel.Text = prompt.ActionText or "Hold to Talk"
	actionLabel.TextColor3 = TEXT_COLOR
	actionLabel.TextSize = 16
	actionLabel.Font = Enum.Font.GothamBold
	actionLabel.Parent = circleContainer

	local actionStroke = Instance.new("UIStroke")
	actionStroke.Color = Color3.fromRGB(0, 0, 0)
	actionStroke.Thickness = 1.5
	actionStroke.Transparency = 0.2
	actionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	actionStroke.LineJoinMode = Enum.LineJoinMode.Round
	actionStroke.Parent = actionLabel

	local npcParent = prompt.Parent and prompt.Parent.Parent
	local objectText = ""
	if npcParent then
		local nameTag = npcParent:FindFirstChild("NameBillboard")
		if nameTag then
			local nameLabel = nameTag:FindFirstChild("NameLabel", true)
			if nameLabel and nameLabel:IsA("TextLabel") then
				objectText = nameLabel.Text
			end
		end
		if objectText == "" then
			objectText = npcParent.Name:gsub("QuestNPC_", ""):gsub("(%l)(%u)", "%1 %2")
		end
	end

	if objectText ~= "" then
		local npcLabel = Instance.new("TextLabel")
		npcLabel.Name = "NPCLabel"
		npcLabel.Size = UDim2.new(1, 40, 0, 18)
		npcLabel.Position = UDim2.new(0.5, 0, 1, 28)
		npcLabel.AnchorPoint = Vector2.new(0.5, 0)
		npcLabel.BackgroundTransparency = 1
		npcLabel.Text = objectText
		npcLabel.TextColor3 = TEXT_DIM
		npcLabel.TextSize = 13
		npcLabel.Font = Enum.Font.Gotham
		npcLabel.Parent = circleContainer

		local npcStroke = Instance.new("UIStroke")
		npcStroke.Color = Color3.fromRGB(0, 0, 0)
		npcStroke.Thickness = 1
		npcStroke.Transparency = 0.3
		npcStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		npcStroke.LineJoinMode = Enum.LineJoinMode.Round
		npcStroke.Parent = npcLabel
	end

	mainFrame.Size = UDim2.new(0, 0, 0, 0)
	mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)

	return {
		billboard = billboardGui,
		mainFrame = mainFrame,
		fillGradient = fillGradient,
		fillGradient2 = fillGradient2,
		fillCircle = fillCircle,
		fillCircle2 = fillCircle2,
		outerRing = outerRing,
		outerStroke = outerStroke,
		innerCircle = innerCircle,
		keyLabel = keyLabel,
		checkmark = checkmark,
		circleContainer = circleContainer,
		holdProgress = 0,
		isHolding = false,
		holdConnection = nil,
		holdTween = nil,
		holdTween2 = nil,
	}
end

local function setFillProgress(ui, progress)
	progress = math.clamp(progress, 0, 1)

	local angle = progress * 360

	if angle <= 180 then
		ui.fillGradient.Rotation = angle
		ui.fillCircle.Visible = true
		ui.fillCircle2.Visible = false
	else
		ui.fillGradient.Rotation = 180
		ui.fillCircle.Visible = true
		ui.fillGradient2.Rotation = angle
		ui.fillCircle2.Visible = true
	end

	local r = FILL_COLOR.R + (COMPLETE_COLOR.R - FILL_COLOR.R) * progress
	local g = FILL_COLOR.G + (COMPLETE_COLOR.G - FILL_COLOR.G) * progress
	local b = FILL_COLOR.B + (COMPLETE_COLOR.B - FILL_COLOR.B) * progress
	local currentColor = Color3.new(r, g, b)

	ui.outerStroke.Color = currentColor
	ui.outerStroke.Transparency = 0.5 - progress * 0.3
end

local function showPromptUI(ui)
	ui.mainFrame.Size = UDim2.new(0, 0, 0, 0)
	ui.mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	ui.mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)

	local showTween = TweenService:Create(ui.mainFrame, TWEEN_SHOW, {
		Size = UDim2.fromScale(1, 1),
	})
	showTween:Play()

	setFillProgress(ui, 0)
	ui.fillCircle.Visible = false
	ui.fillCircle2.Visible = false
	ui.keyLabel.Visible = true
	ui.checkmark.Visible = false
end

local function hidePromptUI(ui)
	local hideTween = TweenService:Create(ui.mainFrame, TWEEN_HIDE, {
		Size = UDim2.new(0, 0, 0, 0),
	})
	hideTween:Play()
	hideTween.Completed:Connect(function()
		if ui.holdConnection then
			ui.holdConnection:Disconnect()
			ui.holdConnection = nil
		end
	end)
end

local function startHoldAnimation(ui)
	ui.isHolding = true
	ui.holdProgress = 0
	ui.fillCircle.Visible = true
	ui.fillCircle2.Visible = false

	local startTime = tick()
	local duration = HOLD_DURATION

	if ui.holdConnection then
		ui.holdConnection:Disconnect()
	end

	ui.holdConnection = RunService.RenderStepped:Connect(function()
		if not ui.isHolding then return end

		local elapsed = tick() - startTime
		local progress = math.clamp(elapsed / duration, 0, 1)
		ui.holdProgress = progress

		setFillProgress(ui, progress)

		if progress >= 1 then
			ui.keyLabel.Visible = false
			ui.checkmark.Visible = true

			ui.outerStroke.Color = COMPLETE_COLOR
			ui.outerStroke.Transparency = 0

			local scaleTween = TweenService:Create(ui.circleContainer, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(CIRCLE_SIZE + 8, CIRCLE_SIZE + 8),
			})
			scaleTween:Play()
			scaleTween.Completed:Connect(function()
				local revertTween = TweenService:Create(ui.circleContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.fromOffset(CIRCLE_SIZE, CIRCLE_SIZE),
				})
				revertTween:Play()
			end)

			if ui.holdConnection then
				ui.holdConnection:Disconnect()
				ui.holdConnection = nil
			end
		end
	end)
end

local function cancelHoldAnimation(ui)
	ui.isHolding = false

	if ui.holdConnection then
		ui.holdConnection:Disconnect()
		ui.holdConnection = nil
	end

	local resetProgress = ui.holdProgress
	if resetProgress > 0 then
		local startP = resetProgress
		local startTime = tick()
		local resetDuration = 0.2

		local resetConn
		resetConn = RunService.RenderStepped:Connect(function()
			local elapsed = tick() - startTime
			local t = math.clamp(elapsed / resetDuration, 0, 1)
			local progress = startP * (1 - t)
			setFillProgress(ui, progress)

			if t >= 1 then
				ui.fillCircle.Visible = false
				ui.fillCircle2.Visible = false
				ui.outerStroke.Color = RING_BG_COLOR
				ui.outerStroke.Transparency = 0.5
				resetConn:Disconnect()
			end
		end)
	end

	ui.holdProgress = 0
	ui.keyLabel.Visible = true
	ui.checkmark.Visible = false
end

ProximityPromptService.PromptShown:Connect(function(prompt, _inputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end

	local adornee = prompt.Parent
	if not adornee then return end

	local ui = createCircularPromptUI(prompt)

	ui.keyLabel.Text = getPromptLabel()

	ui.billboard.Adornee = adornee
	ui.billboard.Parent = PlayerGui

	activePrompts[prompt] = ui

	showPromptUI(ui)
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	local ui = activePrompts[prompt]
	if not ui then return end

	hidePromptUI(ui)

	task.delay(0.2, function()
		if ui.billboard then
			ui.billboard:Destroy()
		end
	end)

	activePrompts[prompt] = nil
end)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	local ui = activePrompts[prompt]
	if not ui then return end

	startHoldAnimation(ui)
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	local ui = activePrompts[prompt]
	if not ui then return end

	if ui.holdProgress < 1 then
		cancelHoldAnimation(ui)
	end
end)

InputModeValue.Changed:Connect(function()
	local label = getPromptLabel()
	for _, ui in activePrompts do
		if ui.keyLabel and ui.keyLabel.Parent then
			ui.keyLabel.Text = label
		end
	end
end)

print("[InteractionPromptUI] Loaded")