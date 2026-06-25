local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local Fusion = require(OnyxUI.Parent.Fusion)
local Util = require(OnyxUI.Util)
local Components = require(OnyxUI.Components)
local HudLeaderboard = require(ReplicatedStorage.UITemplates.HudLeaderboard)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetLeaderboard = Remotes:WaitForChild("GetLeaderboard")

local Scope = Fusion.scoped(Fusion, Util, Components)

local Camera = workspace.CurrentCamera
local BaseResolution = Vector2.new(1920, 1080)
local ScreenSize = Scope:Value(Camera.ViewportSize)
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	ScreenSize:set(Camera.ViewportSize)
end)
local DynamicScale = Scope:Computed(function(Use)
	local Size = Use(ScreenSize)
	local Ratio = 1 / math.max(BaseResolution.X / Size.X, BaseResolution.Y / Size.Y)
	return math.clamp(Ratio, 0.5, 2)
end)

local EXPANDED_WIDTH = 380
local COLLAPSED_WIDTH = 28
local PANEL_HEIGHT = 800
local COLLAPSED_TAB_HEIGHT = 80
local TWEEN_TIME = 0.2
local TWEEN_INFO = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local isExpanded = true

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HudLeaderboard"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 5
screenGui.Parent = Players.LocalPlayer.PlayerGui

local scaleFrame = Instance.new("Frame")
scaleFrame.Name = "ScaleContainer"
scaleFrame.BackgroundTransparency = 1
scaleFrame.AnchorPoint = Vector2.new(1, 0)
scaleFrame.Position = UDim2.new(1, -10, 0, 10)
scaleFrame.Size = UDim2.fromOffset(EXPANDED_WIDTH, PANEL_HEIGHT)
scaleFrame.Parent = screenGui

local uiScale = Instance.new("UIScale")
uiScale.Parent = scaleFrame
Scope:Observer(DynamicScale):onChange(function()
	uiScale.Scale = Fusion.peek(DynamicScale)
end)
uiScale.Scale = Fusion.peek(DynamicScale)

local panelContainer = Instance.new("Frame")
panelContainer.Name = "PanelContainer"
panelContainer.BackgroundTransparency = 1
panelContainer.Size = UDim2.fromScale(1, 1)
panelContainer.ClipsDescendants = true
panelContainer.Parent = scaleFrame

local gui = HudLeaderboard(Scope, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(EXPANDED_WIDTH, PANEL_HEIGHT),
	DynamicScale = Scope:Value(1),
	OnClose = nil,
})
gui.Parent = panelContainer

local chevronBtn = Instance.new("TextButton")
chevronBtn.Name = "ChevronToggle"
chevronBtn.AnchorPoint = Vector2.new(1, 0)
chevronBtn.Position = UDim2.fromOffset(0, 6)
chevronBtn.Size = UDim2.fromOffset(22, 40)
chevronBtn.BackgroundColor3 = Color3.fromHex("1A1F25")
chevronBtn.BackgroundTransparency = 0.15
chevronBtn.BorderSizePixel = 0
chevronBtn.Text = "‹"
chevronBtn.TextColor3 = Color3.fromHex("A0A8B0")
chevronBtn.TextSize = 18
chevronBtn.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
chevronBtn.AutoButtonColor = true
chevronBtn.ZIndex = 10
chevronBtn.Parent = scaleFrame

local chevronCorner = Instance.new("UICorner")
chevronCorner.CornerRadius = UDim.new(0, 6)
chevronCorner.Parent = chevronBtn

local collapsedTab = Instance.new("Frame")
collapsedTab.Name = "CollapsedTab"
collapsedTab.AnchorPoint = Vector2.new(1, 0)
collapsedTab.Position = UDim2.fromScale(1, 0)
collapsedTab.Size = UDim2.fromOffset(COLLAPSED_WIDTH, COLLAPSED_TAB_HEIGHT)
collapsedTab.BackgroundColor3 = Color3.fromHex("0F1519")
collapsedTab.BackgroundTransparency = 0.1
collapsedTab.BorderSizePixel = 0
collapsedTab.Visible = false
collapsedTab.Parent = scaleFrame

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0, 6)
tabCorner.Parent = collapsedTab

local tabStroke = Instance.new("UIStroke")
tabStroke.Color = Color3.fromHex("2A3038")
tabStroke.Thickness = 1
tabStroke.Parent = collapsedTab

local ranksLabel = Instance.new("TextLabel")
ranksLabel.Name = "RanksLabel"
ranksLabel.AnchorPoint = Vector2.new(0.5, 0.5)
ranksLabel.Position = UDim2.fromScale(0.5, 0.35)
ranksLabel.Size = UDim2.fromOffset(70, 20)
ranksLabel.Rotation = 90
ranksLabel.BackgroundTransparency = 1
ranksLabel.Text = "RANKS"
ranksLabel.TextColor3 = Color3.fromHex("A0A8B0")
ranksLabel.TextSize = 11
ranksLabel.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
ranksLabel.Parent = collapsedTab

local topPlayerLabel = Instance.new("TextLabel")
topPlayerLabel.Name = "TopPlayerLabel"
topPlayerLabel.AnchorPoint = Vector2.new(0.5, 1)
topPlayerLabel.Position = UDim2.new(0.5, 0, 1, -4)
topPlayerLabel.Size = UDim2.fromOffset(COLLAPSED_WIDTH - 4, 20)
topPlayerLabel.BackgroundTransparency = 1
topPlayerLabel.Text = "#1"
topPlayerLabel.TextColor3 = Color3.fromHex("FFD700")
topPlayerLabel.TextSize = 8
topPlayerLabel.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold)
topPlayerLabel.TextWrapped = true
topPlayerLabel.Parent = collapsedTab

local function updateTopPlayer()
	local success, data = pcall(function()
		return GetLeaderboard:InvokeServer("Slayer")
	end)
	if success and data and data.entries and #data.entries > 0 then
		local top = data.entries[1]
		local name = top.name or top.Name or "???"
		local bounty = top.bounty or top.Bounty or 0
		if #name > 6 then
			name = string.sub(name, 1, 5) .. "…"
		end
		topPlayerLabel.Text = "#1 " .. name .. "\n" .. tostring(bounty)
	end
end

task.spawn(updateTopPlayer)

local tweening = false

local function togglePanel()
	if tweening then return end
	tweening = true

	isExpanded = not isExpanded

	if isExpanded then
		collapsedTab.Visible = false
		panelContainer.Visible = true

		local expandTween = TweenService:Create(scaleFrame, TWEEN_INFO, {
			Size = UDim2.fromOffset(EXPANDED_WIDTH, PANEL_HEIGHT),
		})
		local chevronTween = TweenService:Create(chevronBtn, TWEEN_INFO, {
			Rotation = 0,
		})
		expandTween:Play()
		chevronTween:Play()
		chevronBtn.Text = "‹"

		expandTween.Completed:Once(function()
			tweening = false
		end)
	else
		local collapseTween = TweenService:Create(scaleFrame, TWEEN_INFO, {
			Size = UDim2.fromOffset(COLLAPSED_WIDTH, COLLAPSED_TAB_HEIGHT),
		})
		local chevronTween = TweenService:Create(chevronBtn, TWEEN_INFO, {
			Rotation = 180,
		})
		collapseTween:Play()
		chevronTween:Play()
		chevronBtn.Text = "›"

		collapseTween.Completed:Once(function()
			panelContainer.Visible = false
			collapsedTab.Visible = true
			tweening = false
		end)
	end
end

chevronBtn.MouseButton1Click:Connect(togglePanel)

collapsedTab.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		togglePanel()
	end
end)
