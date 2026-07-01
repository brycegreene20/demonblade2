local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TeamInviteRemote = Remotes:WaitForChild("TeamInvite")
local TeamInviteResponseRemote = Remotes:WaitForChild("TeamInviteResponse")
local TeamLeaveRemote = Remotes:WaitForChild("TeamLeave")
local TeamUpdateRemote = Remotes:WaitForChild("TeamUpdate")

local currentMembers = {}
local maxMembers = 5
local panelOpen = false
local pendingInvite = nil
local sentInvites = {}
local inviteToastToken = 0
local INVITE_TOAST_SECONDS = 7
local highlightsEnabled = true

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TeamHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 32
screenGui.Parent = PlayerGui

local teamButton = Instance.new("TextButton")
teamButton.Name = "TeamButton"
teamButton.Size = UDim2.fromOffset(96, 46)
teamButton.Position = UDim2.fromOffset(18, 116)
teamButton.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
teamButton.BackgroundTransparency = 0.15
teamButton.BorderSizePixel = 0
teamButton.Text = ""
teamButton.ZIndex = 10
teamButton.Parent = screenGui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = teamButton
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(80, 130, 170)
	s.Thickness = 1
	s.Transparency = 0.2
	s.Parent = teamButton
end

local teamButtonIcon = Instance.new("Frame")
teamButtonIcon.Name = "GroupIcon"
teamButtonIcon.Size = UDim2.fromOffset(30, 30)
teamButtonIcon.Position = UDim2.fromOffset(8, 8)
teamButtonIcon.BackgroundTransparency = 1
teamButtonIcon.ZIndex = 11
teamButtonIcon.Parent = teamButton

for index, iconData in {
	{ Position = UDim2.fromOffset(2, 4), Size = 10 },
	{ Position = UDim2.fromOffset(16, 4), Size = 10 },
	{ Position = UDim2.fromOffset(9, 15), Size = 12 },
} do
	local person = Instance.new("Frame")
	person.Name = "Person" .. index
	person.Size = UDim2.fromOffset(iconData.Size, iconData.Size)
	person.Position = iconData.Position
	person.BackgroundColor3 = Color3.fromRGB(135, 205, 255)
	person.BorderSizePixel = 0
	person.ZIndex = 11
	person.Parent = teamButtonIcon
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = person
end

local teamButtonLabel = Instance.new("TextLabel")
teamButtonLabel.Name = "Label"
teamButtonLabel.Size = UDim2.new(1, -42, 1, 0)
teamButtonLabel.Position = UDim2.fromOffset(38, 0)
teamButtonLabel.BackgroundTransparency = 1
teamButtonLabel.Font = Enum.Font.GothamBold
teamButtonLabel.TextSize = 12
teamButtonLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
teamButtonLabel.TextXAlignment = Enum.TextXAlignment.Left
teamButtonLabel.Text = "TEAM"
teamButtonLabel.ZIndex = 11
teamButtonLabel.Parent = teamButton

local inviteBadge = Instance.new("TextLabel")
inviteBadge.Name = "InviteBadge"
inviteBadge.Size = UDim2.fromOffset(20, 20)
inviteBadge.Position = UDim2.new(1, -12, 0, -7)
inviteBadge.BackgroundColor3 = Color3.fromRGB(235, 75, 65)
inviteBadge.BorderSizePixel = 0
inviteBadge.Font = Enum.Font.GothamBold
inviteBadge.TextSize = 13
inviteBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
inviteBadge.Text = "!"
inviteBadge.Visible = false
inviteBadge.ZIndex = 14
inviteBadge.Parent = teamButton
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = inviteBadge
end

local panel = Instance.new("Frame")
panel.Name = "TeamPanel"
panel.Size = UDim2.fromOffset(350, 390)
panel.Position = UDim2.fromOffset(122, 116)
panel.BackgroundColor3 = Color3.fromRGB(14, 17, 24)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 20
panel.Parent = screenGui
if UserInputService.TouchEnabled then
	teamButton.Size = UDim2.fromOffset(82, 40)
	teamButton.Position = UDim2.fromOffset(12, 92)
	panel.Size = UDim2.new(1, -24, 1, -156)
	panel.Position = UDim2.fromOffset(12, 144)
end
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = panel
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(60, 80, 105)
	s.Thickness = 1.5
	s.Parent = panel
end

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -108, 0, 34)
title.Position = UDim2.fromOffset(42, 4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(230, 240, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "TEAM PARTY"
title.ZIndex = 21
title.Parent = panel

local titleIcon = teamButtonIcon:Clone()
titleIcon.Name = "TitleIcon"
titleIcon.Position = UDim2.fromOffset(10, 6)
titleIcon.Size = UDim2.fromOffset(28, 28)
titleIcon.ZIndex = 21
titleIcon.Parent = panel
for _, descendant in titleIcon:GetDescendants() do
	if descendant:IsA("GuiObject") then
		descendant.ZIndex = 21
	end
end

local memberCountBadge = Instance.new("TextLabel")
memberCountBadge.Name = "MemberCount"
memberCountBadge.Size = UDim2.fromOffset(42, 22)
memberCountBadge.Position = UDim2.new(1, -78, 0, 10)
memberCountBadge.BackgroundColor3 = Color3.fromRGB(37, 65, 90)
memberCountBadge.BorderSizePixel = 0
memberCountBadge.Font = Enum.Font.GothamBold
memberCountBadge.TextSize = 11
memberCountBadge.TextColor3 = Color3.fromRGB(190, 225, 255)
memberCountBadge.Text = "1/5"
memberCountBadge.ZIndex = 22
memberCountBadge.Parent = panel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = memberCountBadge
end

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.fromOffset(28, 28)
closeButton.Position = UDim2.new(1, -36, 0, 7)
closeButton.BackgroundColor3 = Color3.fromRGB(32, 36, 48)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.TextColor3 = Color3.fromRGB(220, 225, 235)
closeButton.Text = "X"
closeButton.ZIndex = 22
closeButton.Parent = panel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = closeButton
end

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -24, 0, 20)
statusLabel.Position = UDim2.fromOffset(12, 38)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(150, 165, 190)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Shared rewards are active while teammates stay nearby."
statusLabel.ZIndex = 21
statusLabel.Parent = panel

local memberLabel = Instance.new("TextLabel")
memberLabel.Name = "Members"
memberLabel.Size = UDim2.new(1, -24, 0, 54)
memberLabel.Position = UDim2.fromOffset(12, 64)
memberLabel.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
memberLabel.BackgroundTransparency = 0.25
memberLabel.BorderSizePixel = 0
memberLabel.Font = Enum.Font.GothamMedium
memberLabel.TextSize = 11
memberLabel.TextColor3 = Color3.fromRGB(220, 230, 245)
memberLabel.TextWrapped = true
memberLabel.TextXAlignment = Enum.TextXAlignment.Left
memberLabel.TextYAlignment = Enum.TextYAlignment.Top
memberLabel.Text = "SOLO\nInvite players in this server to form a team."
memberLabel.ZIndex = 21
memberLabel.Parent = panel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = memberLabel
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 8)
	p.PaddingRight = UDim.new(0, 8)
	p.PaddingTop = UDim.new(0, 6)
	p.Parent = memberLabel
end

local playerList = Instance.new("ScrollingFrame")
playerList.Name = "PlayerList"
playerList.Size = UDim2.new(1, -24, 1, -174)
playerList.Position = UDim2.fromOffset(12, 126)
playerList.BackgroundTransparency = 1
playerList.BorderSizePixel = 0
playerList.CanvasSize = UDim2.fromOffset(0, 0)
playerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerList.ScrollBarThickness = 4
playerList.ZIndex = 21
playerList.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = playerList

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.new(1, -24, 0, 30)
leaveButton.Position = UDim2.new(0, 12, 1, -40)
leaveButton.BackgroundColor3 = Color3.fromRGB(80, 34, 42)
leaveButton.BorderSizePixel = 0
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 12
leaveButton.TextColor3 = Color3.fromRGB(255, 210, 220)
leaveButton.Text = "Leave Team"
leaveButton.ZIndex = 21
leaveButton.Parent = panel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = leaveButton
end

local inviteToast = Instance.new("Frame")
inviteToast.Name = "InviteToast"
inviteToast.Size = UDim2.fromOffset(320, 92)
inviteToast.Position = UDim2.new(0.5, 0, 0, -120)
inviteToast.AnchorPoint = Vector2.new(0.5, 0)
inviteToast.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
inviteToast.BackgroundTransparency = 0.05
inviteToast.BorderSizePixel = 0
inviteToast.Visible = false
inviteToast.ZIndex = 40
inviteToast.Parent = screenGui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = inviteToast
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(90, 150, 210)
	s.Thickness = 1.5
	s.Parent = inviteToast
end

local inviteText = Instance.new("TextLabel")
inviteText.Size = UDim2.new(1, -20, 0, 34)
inviteText.Position = UDim2.fromOffset(10, 8)
inviteText.BackgroundTransparency = 1
inviteText.Font = Enum.Font.GothamBold
inviteText.TextSize = 13
inviteText.TextColor3 = Color3.fromRGB(230, 240, 255)
inviteText.TextWrapped = true
inviteText.Text = ""
inviteText.ZIndex = 41
inviteText.Parent = inviteToast

local acceptButton = Instance.new("TextButton")
acceptButton.Size = UDim2.fromOffset(120, 28)
acceptButton.Position = UDim2.fromOffset(34, 52)
acceptButton.BackgroundColor3 = Color3.fromRGB(55, 115, 80)
acceptButton.BorderSizePixel = 0
acceptButton.Font = Enum.Font.GothamBold
acceptButton.TextSize = 12
acceptButton.TextColor3 = Color3.fromRGB(230, 255, 235)
acceptButton.Text = "Accept"
acceptButton.ZIndex = 41
acceptButton.Parent = inviteToast

local declineButton = acceptButton:Clone()
declineButton.Position = UDim2.fromOffset(166, 52)
declineButton.BackgroundColor3 = Color3.fromRGB(90, 38, 48)
declineButton.TextColor3 = Color3.fromRGB(255, 220, 225)
declineButton.Text = "Decline"
declineButton.Parent = inviteToast
for _, button in { acceptButton, declineButton } do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = button
end

local function isMember(userId)
	for _, member in currentMembers do
		if member.UserId == userId then
			return true
		end
	end
	return false
end

local function isClanmate(player)
	local localClanId = LocalPlayer:GetAttribute("ClanId")
	return type(localClanId) == "string"
		and localClanId ~= ""
		and player:GetAttribute("ClanId") == localClanId
end

local function getRelationship(player)
	local teammate = isMember(player.UserId)
	local clanmate = isClanmate(player)
	if teammate and clanmate then
		return "TEAM + CLAN", Color3.fromRGB(70, 225, 220)
	elseif teammate then
		return "TEAMMATE", Color3.fromRGB(90, 175, 255)
	elseif clanmate then
		return "CLAN MEMBER", Color3.fromRGB(75, 225, 120)
	end
	return nil, nil
end

local function isLocalPlayerLeader()
	for _, member in currentMembers do
		if member.UserId == LocalPlayer.UserId then
			return member.IsLeader == true
		end
	end
	return false
end

local function clearTeammateVisual(player)
	local character = player.Character
	if character then
		local highlight = character:FindFirstChild("TeamHighlight")
		if highlight then highlight:Destroy() end
		local marker = character:FindFirstChild("TeamMarker")
		if marker then marker:Destroy() end
	end
end

local function applyTeammateVisual(player)
	local relationship, relationshipColor = getRelationship(player)
	if player == LocalPlayer or not relationship then
		clearTeammateVisual(player)
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head then return end

	local highlight = character:FindFirstChild("TeamHighlight")
	if not highlightsEnabled then
		if highlight then
			highlight:Destroy()
		end
	else
		if not highlight or not highlight:IsA("Highlight") then
			highlight = Instance.new("Highlight")
			highlight.Name = "TeamHighlight"
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.FillTransparency = 0.55
			highlight.OutlineTransparency = 0.0
			highlight.Adornee = character
			highlight.Parent = character
		end
		highlight.FillColor = relationshipColor
		highlight.OutlineColor = relationshipColor
	end

	local marker = character:FindFirstChild("TeamMarker")
	if not marker or not marker:IsA("BillboardGui") then
		marker = Instance.new("BillboardGui")
		marker.Name = "TeamMarker"
		marker.Adornee = head
		marker.Size = UDim2.fromOffset(100, 20)
		marker.StudsOffsetWorldSpace = Vector3.new(0, 5.1, 0)
		marker.AlwaysOnTop = true
		marker.MaxDistance = 0
		marker.Parent = character

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 11
		label.TextStrokeColor3 = Color3.fromRGB(5, 20, 35)
		label.TextStrokeTransparency = 0.2
		label.Parent = marker
	end
	local label = marker:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = relationship
		label.TextColor3 = relationshipColor
	end
end

local function refreshTeammateVisuals()
	for _, player in Players:GetPlayers() do
		applyTeammateVisual(player)
	end
end

local function observePlayerCharacter(player)
	player:GetAttributeChangedSignal("ClanId"):Connect(function()
		applyTeammateVisual(player)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.4)
		applyTeammateVisual(player)
	end)
	if player.Character then
		task.defer(applyTeammateVisual, player)
	end
end

LocalPlayer:GetAttributeChangedSignal("ClanId"):Connect(refreshTeammateVisuals)

local edgeMarkers = {}
local function getEdgeMarker(player)
	local marker = edgeMarkers[player]
	if marker then return marker end

	marker = Instance.new("Frame")
	marker.Name = "SocialDirection_" .. player.UserId
	marker.Size = UDim2.fromOffset(132, 30)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.BackgroundColor3 = Color3.fromRGB(10, 16, 22)
	marker.BackgroundTransparency = 0.16
	marker.BorderSizePixel = 0
	marker.ZIndex = 40
	marker.Visible = false
	marker.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = marker
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 1.5
	stroke.Parent = marker

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -30, 1, 0)
	nameLabel.Position = UDim2.fromOffset(6, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 11
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 41
	nameLabel.Parent = marker

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.fromOffset(24, 24)
	arrow.Position = UDim2.new(1, -27, 0.5, 0)
	arrow.AnchorPoint = Vector2.new(0, 0.5)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = ">"
	arrow.TextSize = 20
	arrow.ZIndex = 41
	arrow.Parent = marker

	edgeMarkers[player] = marker
	return marker
end

local edgeUpdateAccumulator = 0
RunService.RenderStepped:Connect(function(dt)
	edgeUpdateAccumulator += dt
	if edgeUpdateAccumulator < 0.1 then return end
	edgeUpdateAccumulator = 0

	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local center = viewport * 0.5
	local margin = Vector2.new(84, 50)

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then continue end
		local relationship, color = getRelationship(player)
		local marker = getEdgeMarker(player)
		if not relationship then
			marker.Visible = false
			continue
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local worldPosition = root and root.Position or player:GetAttribute("LobbyPosition")
		if typeof(worldPosition) ~= "Vector3" then
			marker.Visible = false
			continue
		end

		local screenPoint, onScreen = camera:WorldToViewportPoint(worldPosition)
		if onScreen and screenPoint.Z > 0 then
			marker.Visible = false
			continue
		end

		local rawDirection = Vector2.new(screenPoint.X, screenPoint.Y) - center
		if screenPoint.Z < 0 then rawDirection = -rawDirection end
		if rawDirection.Magnitude < 0.01 then rawDirection = Vector2.new(0, -1) end
		local direction = rawDirection.Unit
		local maxX = math.max(1, center.X - margin.X)
		local maxY = math.max(1, center.Y - margin.Y)
		local scale = math.min(
			math.abs(direction.X) > 0 and maxX / math.abs(direction.X) or math.huge,
			math.abs(direction.Y) > 0 and maxY / math.abs(direction.Y) or math.huge
		)
		local edgePosition = center + direction * scale
		marker.Position = UDim2.fromOffset(edgePosition.X, edgePosition.Y)
		marker.Visible = true
		local nameLabel = marker:FindFirstChild("NameLabel")
		local arrow = marker:FindFirstChild("Arrow")
		local stroke = marker:FindFirstChild("Stroke")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = player.DisplayName
			nameLabel.TextColor3 = color
		end
		if arrow and arrow:IsA("TextLabel") then
			arrow.TextColor3 = color
			arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X))
		end
		if stroke and stroke:IsA("UIStroke") then stroke.Color = color end
	end
end)

local function updateMembersText()
	if #currentMembers == 0 then
		memberLabel.Text = "SOLO\nInvite players in this server to form a team."
		memberCountBadge.Text = "1/" .. maxMembers
		leaveButton.Visible = false
		return
	end

	local names = {}
	for _, member in currentMembers do
		table.insert(names, (member.IsLeader and "Leader: " or "") .. member.DisplayName)
	end
	memberLabel.Text = "ACTIVE TEAM\n" .. table.concat(names, "  |  ")
	memberCountBadge.Text = #currentMembers .. "/" .. maxMembers
	leaveButton.Visible = true
end

local function rebuildPlayerList()
	for _, child in playerList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then continue end

		local row = Instance.new("Frame")
		row.Name = "PlayerRow_" .. player.UserId
		row.Size = UDim2.new(1, 0, 0, 50)
		row.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.ZIndex = 21
		row.Parent = playerList
		do
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = row
		end

		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.Size = UDim2.fromOffset(34, 34)
		avatar.Position = UDim2.fromOffset(8, 8)
		avatar.BackgroundColor3 = Color3.fromRGB(35, 42, 55)
		avatar.BorderSizePixel = 0
		avatar.Image = ""
		avatar.ZIndex = 22
		avatar.Parent = row
		do
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = avatar
		end
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(
					player.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size100x100
				)
			end)
			if ok and avatar.Parent then
				avatar.Image = image
			end
		end)

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -146, 0, 22)
		name.Position = UDim2.fromOffset(50, 5)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 12
		name.TextColor3 = Color3.fromRGB(220, 230, 245)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = player.DisplayName
		name.ZIndex = 22
		name.Parent = row

		local playerStatus = Instance.new("TextLabel")
		playerStatus.Name = "Status"
		playerStatus.Size = UDim2.new(1, -146, 0, 16)
		playerStatus.Position = UDim2.fromOffset(50, 26)
		playerStatus.BackgroundTransparency = 1
		playerStatus.Font = Enum.Font.GothamMedium
		playerStatus.TextSize = 10
		playerStatus.TextColor3 = isMember(player.UserId)
			and Color3.fromRGB(100, 220, 155)
			or Color3.fromRGB(135, 150, 175)
		playerStatus.TextXAlignment = Enum.TextXAlignment.Left
		playerStatus.Text = isMember(player.UserId) and "TEAMMATE" or ("@" .. player.Name)
		playerStatus.ZIndex = 22
		playerStatus.Parent = row

		local invite = Instance.new("TextButton")
		invite.Size = UDim2.fromOffset(82, 30)
		invite.Position = UDim2.new(1, -90, 0.5, 0)
		invite.AnchorPoint = Vector2.new(0, 0.5)
		invite.BackgroundColor3 = Color3.fromRGB(42, 74, 105)
		invite.BorderSizePixel = 0
		invite.Font = Enum.Font.GothamBold
		invite.TextSize = 11
		invite.TextColor3 = Color3.fromRGB(220, 240, 255)
		local inviteSent = sentInvites[player.UserId] == true
		local teammate = isMember(player.UserId)
		local canRemove = teammate and isLocalPlayerLeader()
		invite.Text = if canRemove then "Remove" elseif teammate then "Joined" elseif inviteSent then "Sent" else "+ Invite"
		invite.AutoButtonColor = canRemove or (not teammate and not inviteSent)
		if canRemove then
			invite.BackgroundColor3 = Color3.fromRGB(105, 42, 52)
			invite.TextColor3 = Color3.fromRGB(255, 220, 225)
		end
		if inviteSent then
			invite.BackgroundColor3 = Color3.fromRGB(48, 58, 72)
			invite.TextColor3 = Color3.fromRGB(140, 175, 205)
			playerStatus.Text = "INVITE SENT"
			playerStatus.TextColor3 = Color3.fromRGB(120, 190, 240)
		end
		invite.ZIndex = 22
		invite.Parent = row
		do
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = invite
		end
		if canRemove then
			invite.MouseButton1Click:Connect(function()
				invite.Text = "Removing..."
				invite.Active = false
				TeamLeaveRemote:FireServer(player.UserId)
				statusLabel.Text = "Removing " .. player.DisplayName
			end)
		elseif not teammate and not inviteSent then
			invite.MouseButton1Click:Connect(function()
				invite.Text = "Sending..."
				invite.Active = false
				TeamInviteRemote:FireServer(player.UserId)
				statusLabel.Text = "Sending invite to " .. player.DisplayName
			end)
		end
	end
end

local function setPanelOpen(open)
	panelOpen = open
	if panelOpen then
		updateMembersText()
		rebuildPlayerList()
		panel.Visible = true
		panel.BackgroundTransparency = 1
		TweenService:Create(panel, TweenInfo.new(0.18), { BackgroundTransparency = 0.05 }):Play()
	else
		TweenService:Create(panel, TweenInfo.new(0.14), { BackgroundTransparency = 1 }):Play()
		task.delay(0.16, function()
			if not panelOpen then
				panel.Visible = false
			end
		end)
	end
end

local function setInviteAttention(visible)
	inviteBadge.Visible = visible
	if visible then
		inviteBadge.Size = UDim2.fromOffset(14, 14)
		TweenService:Create(inviteBadge, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(20, 20),
		}):Play()
	end
end

local function hideInviteToast()
	inviteToastToken += 1
	TweenService:Create(inviteToast, TweenInfo.new(0.18), { Position = UDim2.new(0.5, 0, 0, -120) }):Play()
	task.delay(0.2, function()
		inviteToast.Visible = false
	end)
end

local function showInviteToast()
	if not pendingInvite then return end
	inviteToastToken += 1
	local token = inviteToastToken
	inviteText.Text = tostring(pendingInvite.DisplayName or pendingInvite.Name) .. " invited you to a team."
	inviteToast.Visible = true
	inviteToast.Position = UDim2.new(0.5, 0, 0, -120)
	TweenService:Create(inviteToast, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 72),
	}):Play()
	task.delay(INVITE_TOAST_SECONDS, function()
		if token ~= inviteToastToken or not pendingInvite then return end
		hideInviteToast()
		setInviteAttention(true)
	end)
end

teamButton.MouseButton1Click:Connect(function()
	setPanelOpen(not panelOpen)
	if pendingInvite then
		setInviteAttention(false)
		showInviteToast()
	end
end)

closeButton.MouseButton1Click:Connect(function()
	setPanelOpen(false)
end)

leaveButton.MouseButton1Click:Connect(function()
	TeamLeaveRemote:FireServer()
end)

local function respondToInvite(accepted)
	if not pendingInvite then return end
	TeamInviteResponseRemote:FireServer(pendingInvite.UserId, accepted)
	pendingInvite = nil
	setInviteAttention(false)
	hideInviteToast()
end

acceptButton.MouseButton1Click:Connect(function()
	respondToInvite(true)
end)

declineButton.MouseButton1Click:Connect(function()
	respondToInvite(false)
end)

TeamUpdateRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	currentMembers = typeof(payload.Members) == "table" and payload.Members or currentMembers
	maxMembers = payload.MaxMembers or maxMembers
	if payload.Message then
		statusLabel.Text = tostring(payload.Message)
	end
	if payload.Invite then
		pendingInvite = payload.Invite
		setInviteAttention(false)
		showInviteToast()
		local inviteUserId = payload.Invite.UserId
		task.delay(payload.Invite.ExpiresIn or 30, function()
			if pendingInvite and pendingInvite.UserId == inviteUserId then
				pendingInvite = nil
				setInviteAttention(false)
				hideInviteToast()
				statusLabel.Text = "Team invite expired"
			end
		end)
	end
	if payload.InviteSent then
		sentInvites[payload.InviteSent.UserId] = true
	end
	if payload.InviteResolved then
		sentInvites[payload.InviteResolved.UserId] = nil
	end
	if payload.InviteExpired then
		if pendingInvite and pendingInvite.UserId == payload.InviteExpired.UserId then
			pendingInvite = nil
			setInviteAttention(false)
			hideInviteToast()
		end
	end
	updateMembersText()
	refreshTeammateVisuals()
	if panelOpen then
		rebuildPlayerList()
	end
end)

for _, player in Players:GetPlayers() do
	observePlayerCharacter(player)
end

Players.PlayerAdded:Connect(function(player)
	observePlayerCharacter(player)
	if panelOpen then
		rebuildPlayerList()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	clearTeammateVisual(player)
	local marker = edgeMarkers[player]
	if marker then marker:Destroy() end
	edgeMarkers[player] = nil
	if panelOpen then
		rebuildPlayerList()
	end
end)

-- ── Highlight settings toggle ─────────────────────────────────────────────
local settingsBtn = Instance.new("TextButton")
settingsBtn.Name = "HighlightToggle"
settingsBtn.Size = UDim2.fromOffset(96, 26)
settingsBtn.Position = UDim2.fromOffset(18, 222)
settingsBtn.BackgroundColor3 = Color3.fromRGB(22, 28, 38)
settingsBtn.BackgroundTransparency = 0.2
settingsBtn.BorderSizePixel = 0
settingsBtn.Font = Enum.Font.GothamBold
settingsBtn.TextSize = 10
settingsBtn.TextColor3 = Color3.fromRGB(160, 200, 255)
settingsBtn.Text = "HIGHLIGHTS: ON"
settingsBtn.ZIndex = 10
settingsBtn.Parent = screenGui
if UserInputService.TouchEnabled then
	settingsBtn.Size = UDim2.fromOffset(82, 26)
	settingsBtn.Position = UDim2.fromOffset(12, 140)
end
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = settingsBtn
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(60, 90, 130)
	s.Transparency = 0.3
	s.Parent = settingsBtn
end

settingsBtn.Activated:Connect(function()
	highlightsEnabled = not highlightsEnabled
	settingsBtn.Text = highlightsEnabled and "HIGHLIGHTS: ON" or "HIGHLIGHTS: OFF"
	settingsBtn.TextColor3 = highlightsEnabled
		and Color3.fromRGB(160, 200, 255)
		or Color3.fromRGB(130, 130, 150)
	refreshTeammateVisuals()
end)

print("[TeamController] Loaded")
