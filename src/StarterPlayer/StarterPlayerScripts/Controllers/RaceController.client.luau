local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpinRaceRemote = Remotes:WaitForChild("SpinRace")
local RaceChangedRemote = Remotes:WaitForChild("RaceChanged")
local RaceModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RaceModule"))

local COLORS = {
	Human = Color3.fromRGB(145, 165, 185),
	DemonKing = Color3.fromRGB(215, 60, 95),
	Sun = Color3.fromRGB(255, 190, 45),
}

local currentRace = RaceModule.getPublicData(RaceModule.DEFAULT_RACE, 0)
local panelOpen = false
local rolling = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RaceHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 34
screenGui.Parent = PlayerGui

local raceButton = Instance.new("TextButton")
raceButton.Name = "RaceButton"
raceButton.Size = UDim2.fromOffset(96, 46)
raceButton.Position = UDim2.fromOffset(18, 170)
raceButton.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
raceButton.BackgroundTransparency = 0.1
raceButton.BorderSizePixel = 0
raceButton.Font = Enum.Font.GothamBold
raceButton.TextSize = 12
raceButton.TextColor3 = Color3.fromRGB(255, 215, 125)
raceButton.Text = "RACE"
raceButton.ZIndex = 10
raceButton.Parent = screenGui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = raceButton
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(170, 125, 45)
	s.Thickness = 1.25
	s.Transparency = 0.25
	s.Parent = raceButton
end

local raceDot = Instance.new("Frame")
raceDot.Name = "RaceIcon"
raceDot.Size = UDim2.fromOffset(18, 18)
raceDot.Position = UDim2.fromOffset(10, 14)
raceDot.BackgroundColor3 = COLORS.Human
raceDot.BorderSizePixel = 0
raceDot.ZIndex = 11
raceDot.Parent = raceButton
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = raceDot
end

local overlay = Instance.new("TextButton")
overlay.Name = "RaceOverlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.BorderSizePixel = 0
overlay.Text = ""
overlay.Visible = false
overlay.AutoButtonColor = false
overlay.ZIndex = 50
overlay.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "RacePanel"
panel.Size = UDim2.fromOffset(420, 360)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
panel.BorderSizePixel = 0
panel.ZIndex = 51
panel.Parent = overlay
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = panel
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(100, 110, 130)
	s.Thickness = 1.5
	s.Parent = panel
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -54, 0, 38)
title.Position = UDim2.fromOffset(16, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(240, 245, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "RACE SPINS"
title.ZIndex = 52
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(30, 30)
closeButton.Position = UDim2.new(1, -40, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(35, 39, 49)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.TextColor3 = Color3.fromRGB(225, 230, 240)
closeButton.Text = "X"
closeButton.ZIndex = 53
closeButton.Parent = panel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = closeButton
end

local raceCard = Instance.new("Frame")
raceCard.Size = UDim2.new(1, -32, 0, 116)
raceCard.Position = UDim2.fromOffset(16, 54)
raceCard.BackgroundColor3 = Color3.fromRGB(24, 29, 39)
raceCard.BorderSizePixel = 0
raceCard.ZIndex = 52
raceCard.Parent = panel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = raceCard
end

local raceName = Instance.new("TextLabel")
raceName.Size = UDim2.new(1, -24, 0, 30)
raceName.Position = UDim2.fromOffset(12, 10)
raceName.BackgroundTransparency = 1
raceName.Font = Enum.Font.GothamBold
raceName.TextSize = 22
raceName.TextXAlignment = Enum.TextXAlignment.Left
raceName.ZIndex = 53
raceName.Parent = raceCard

local rarity = Instance.new("TextLabel")
rarity.Size = UDim2.fromOffset(90, 20)
rarity.Position = UDim2.new(1, -102, 0, 14)
rarity.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
rarity.BorderSizePixel = 0
rarity.Font = Enum.Font.GothamBold
rarity.TextSize = 10
rarity.TextColor3 = Color3.fromRGB(230, 235, 245)
rarity.ZIndex = 53
rarity.Parent = raceCard
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = rarity
end

local buffText = Instance.new("TextLabel")
buffText.Size = UDim2.new(1, -24, 0, 54)
buffText.Position = UDim2.fromOffset(12, 48)
buffText.BackgroundTransparency = 1
buffText.Font = Enum.Font.GothamMedium
buffText.TextSize = 12
buffText.TextColor3 = Color3.fromRGB(185, 195, 215)
buffText.TextWrapped = true
buffText.TextXAlignment = Enum.TextXAlignment.Left
buffText.TextYAlignment = Enum.TextYAlignment.Top
buffText.ZIndex = 53
buffText.Parent = raceCard

local odds = Instance.new("TextLabel")
odds.Size = UDim2.new(1, -32, 0, 54)
odds.Position = UDim2.fromOffset(16, 184)
odds.BackgroundTransparency = 1
odds.Font = Enum.Font.GothamMedium
odds.TextSize = 11
odds.TextColor3 = Color3.fromRGB(145, 155, 175)
odds.TextWrapped = true
odds.TextXAlignment = Enum.TextXAlignment.Left
odds.Text = "DROP RATES\nHuman 75%   Demon King 20%   Sun 5%"
odds.ZIndex = 52
odds.Parent = panel

local spinsLabel = Instance.new("TextLabel")
spinsLabel.Size = UDim2.fromOffset(110, 28)
spinsLabel.Position = UDim2.fromOffset(16, 250)
spinsLabel.BackgroundColor3 = Color3.fromRGB(32, 37, 48)
spinsLabel.BorderSizePixel = 0
spinsLabel.Font = Enum.Font.GothamBold
spinsLabel.TextSize = 12
spinsLabel.TextColor3 = Color3.fromRGB(220, 225, 240)
spinsLabel.ZIndex = 52
spinsLabel.Parent = panel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = spinsLabel
end

local spinButton = Instance.new("TextButton")
spinButton.Size = UDim2.new(1, -150, 0, 42)
spinButton.Position = UDim2.fromOffset(134, 243)
spinButton.BackgroundColor3 = Color3.fromRGB(190, 130, 35)
spinButton.BorderSizePixel = 0
spinButton.Font = Enum.Font.GothamBold
spinButton.TextSize = 15
spinButton.TextColor3 = Color3.fromRGB(255, 250, 230)
spinButton.Text = "SPIN"
spinButton.ZIndex = 52
spinButton.Parent = panel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = spinButton
end

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -32, 0, 40)
status.Position = UDim2.fromOffset(16, 298)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 12
status.TextColor3 = Color3.fromRGB(145, 160, 185)
status.TextWrapped = true
status.Text = ""
status.ZIndex = 52
status.Parent = panel

local function updateRace(data)
	if typeof(data) ~= "table" then return end
	currentRace = data
	local color = COLORS[data.Id] or COLORS.Human
	raceDot.BackgroundColor3 = color
	raceName.Text = data.Name or data.Id or "Human"
	raceName.TextColor3 = color
	rarity.Text = string.upper(data.Rarity or "Common")
	buffText.Text = data.Description or ""
	spinsLabel.Text = "SPINS  " .. tostring(data.Spins or 0)
	spinButton.BackgroundColor3 = (data.Spins or 0) > 0
		and Color3.fromRGB(190, 130, 35)
		or Color3.fromRGB(65, 68, 76)
	spinButton.Text = (data.Spins or 0) > 0 and "SPIN - 1" or "NO SPINS"
end

local function setPanelOpen(open)
	panelOpen = open
	overlay.Visible = open
	if open then
		panel.Size = UDim2.fromOffset(420, 0)
		panel.BackgroundTransparency = 1
		TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(420, 360),
			BackgroundTransparency = 0,
		}):Play()
	end
end

raceButton.Activated:Connect(function()
	setPanelOpen(not panelOpen)
end)
closeButton.Activated:Connect(function()
	setPanelOpen(false)
end)
overlay.Activated:Connect(function()
	setPanelOpen(false)
end)

spinButton.Activated:Connect(function()
	if rolling or (currentRace.Spins or 0) <= 0 then return end
	rolling = true
	spinButton.Text = "ROLLING..."
	status.Text = ""
	local ok, result = pcall(function()
		return SpinRaceRemote:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		if result.Race then
			updateRace(result.Race)
		end
		status.Text = result.Message or ""
		status.TextColor3 = result.Success
			and Color3.fromRGB(120, 220, 155)
			or Color3.fromRGB(235, 115, 105)
	else
		status.Text = "Race spin failed. Please try again."
		status.TextColor3 = Color3.fromRGB(235, 115, 105)
	end
	rolling = false
	updateRace(currentRace)
end)

RaceChangedRemote.OnClientEvent:Connect(updateRace)

task.spawn(function()
	local getPlayerData = Remotes:WaitForChild("GetPlayerData")
	local ok, result = pcall(function()
		return getPlayerData:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		updateRace(RaceModule.getPublicData(result.Race, result.RaceSpins))
	end
end)

updateRace(currentRace)
print("[RaceController] Loaded")
