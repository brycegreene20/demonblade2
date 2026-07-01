local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClanAction = Remotes:WaitForChild("ClanAction")
local ClanUpdate = Remotes:WaitForChild("ClanUpdate")
local GetClanData = Remotes:WaitForChild("GetClanData")
local ClanModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClanModule"))

local COLORS = {
	Background = Color3.fromRGB(12, 16, 22),
	Panel = Color3.fromRGB(18, 24, 32),
	Row = Color3.fromRGB(25, 33, 44),
	Muted = Color3.fromRGB(145, 160, 178),
	Text = Color3.fromRGB(238, 244, 250),
	Green = Color3.fromRGB(75, 225, 120),
	Cyan = Color3.fromRGB(70, 215, 225),
	Gold = Color3.fromRGB(245, 197, 80),
	Red = Color3.fromRGB(210, 72, 82),
}

local currentData
local panelOpen = false
local activeTab = "Overview"
local selectedLogo = "Blossom"

local function formatNumber(value)
	local formatted = tostring(math.floor(tonumber(value) or 0))
	while true do
		local nextValue, replacements = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = nextValue
		if replacements == 0 then return formatted end
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "ClanGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 18
gui.Parent = PlayerGui

local clanButton = Instance.new("TextButton")
clanButton.Name = "ClanButton"
clanButton.Size = UDim2.fromOffset(96, 46)
clanButton.Position = UDim2.fromOffset(18, 58)
clanButton.BackgroundColor3 = Color3.fromRGB(20, 42, 34)
clanButton.BackgroundTransparency = 0.08
clanButton.BorderSizePixel = 0
clanButton.Font = Enum.Font.GothamBold
clanButton.TextSize = 14
clanButton.TextColor3 = COLORS.Green
clanButton.Text = "CLAN"
clanButton.ZIndex = 10
clanButton.Parent = gui
if UserInputService.TouchEnabled then
	clanButton.Size = UDim2.fromOffset(82, 40)
	clanButton.Position = UDim2.fromOffset(12, 40)
end
local clanButtonCorner = Instance.new("UICorner")
clanButtonCorner.CornerRadius = UDim.new(0, 8)
clanButtonCorner.Parent = clanButton
local clanButtonStroke = Instance.new("UIStroke")
clanButtonStroke.Color = COLORS.Green
clanButtonStroke.Transparency = 0.25
clanButtonStroke.Parent = clanButton

local attentionBadge = Instance.new("TextLabel")
attentionBadge.Size = UDim2.fromOffset(18, 18)
attentionBadge.Position = UDim2.new(1, -3, 0, 3)
attentionBadge.AnchorPoint = Vector2.new(1, 0)
attentionBadge.BackgroundColor3 = COLORS.Gold
attentionBadge.BorderSizePixel = 0
attentionBadge.Font = Enum.Font.GothamBlack
attentionBadge.TextSize = 11
attentionBadge.TextColor3 = COLORS.Background
attentionBadge.Text = "!"
attentionBadge.Visible = false
attentionBadge.ZIndex = 12
attentionBadge.Parent = clanButton
local attentionCorner = Instance.new("UICorner")
attentionCorner.CornerRadius = UDim.new(1, 0)
attentionCorner.Parent = attentionBadge

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.36
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.ZIndex = 50
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(780, 520)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = COLORS.Panel
panel.BorderSizePixel = 0
panel.SelectionGroup = true
panel.ZIndex = 51
panel.Parent = overlay
if UserInputService.TouchEnabled then
	panel.Size = UDim2.new(1, -16, 1, -100)
end
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(780, 560)
sizeConstraint.MinSize = Vector2.new(288, 340)
sizeConstraint.Parent = panel
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(62, 78, 96)
panelStroke.Transparency = 0.15
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 52)
title.Position = UDim2.fromOffset(18, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.TextColor3 = COLORS.Text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "CLANS"
title.ZIndex = 52
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(38, 38)
closeButton.Position = UDim2.new(1, -46, 0, 7)
closeButton.BackgroundColor3 = Color3.fromRGB(38, 45, 56)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.TextColor3 = COLORS.Text
closeButton.Text = "X"
closeButton.ZIndex = 53
closeButton.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

local tabBar = Instance.new("ScrollingFrame")
tabBar.Size = UDim2.new(1, -24, 0, 38)
tabBar.Position = UDim2.fromOffset(12, 52)
tabBar.BackgroundTransparency = 1
tabBar.BorderSizePixel = 0
tabBar.ScrollBarThickness = UserInputService.TouchEnabled and 3 or 0
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabBar.CanvasSize = UDim2.new()
tabBar.ZIndex = 52
tabBar.Parent = panel
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Parent = tabBar

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Size = UDim2.new(1, -24, 1, -134)
content.Position = UDim2.fromOffset(12, 96)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 5
content.ScrollBarImageColor3 = COLORS.Cyan
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.ZIndex = 52
content.Parent = panel
local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 8)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content
local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingBottom = UDim.new(0, 8)
contentPadding.PaddingRight = UDim.new(0, 5)
contentPadding.Parent = content

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -24, 0, 26)
status.Position = UDim2.new(0, 12, 1, -32)
status.BackgroundColor3 = Color3.fromRGB(20, 28, 36)
status.BackgroundTransparency = 0.08
status.BorderSizePixel = 0
status.Font = Enum.Font.GothamMedium
status.TextSize = 12
status.TextColor3 = COLORS.Muted
status.Text = "Ready"
status.ZIndex = 52
status.Parent = panel
local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 5)
statusCorner.Parent = status

local tabButtons = {}
local renderCurrentTab

local function styleButton(button, color)
	button.BackgroundColor3 = color or Color3.fromRGB(42, 58, 72)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = COLORS.Text
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
end

local function keepTextInside(label, maximumSize)
	label.TextScaled = true
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 9
	constraint.MaxTextSize = maximumSize or 13
	constraint.Parent = label
end

for _, tabName in ipairs({ "Overview", "Members", "Recruitment", "Leaderboard", "Achievements" }) do
	local button = Instance.new("TextButton")
	button.Name = tabName
	button.Size = UDim2.fromOffset(138, 38)
	button.Text = tabName
	button.ZIndex = 53
	button.Parent = tabBar
	styleButton(button)
	button.Activated:Connect(function()
		activeTab = tabName
		if renderCurrentTab then renderCurrentTab() end
	end)
	tabButtons[tabName] = button
end

local function clearContent()
	for _, child in content:GetChildren() do
		if child ~= contentLayout and child ~= contentPadding then
			child:Destroy()
		end
	end
end

local function addHeading(text, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 30)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 17
	label.TextColor3 = color or COLORS.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.ZIndex = 53
	label.Parent = content
	return label
end

local function addBody(text, color, height)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, height or 32)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextColor3 = color or COLORS.Muted
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = text
	label.ZIndex = 53
	label.Parent = content
	return label
end

local function addRow(height)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, height or 58)
	row.BackgroundColor3 = COLORS.Row
	row.BackgroundTransparency = 0.06
	row.BorderSizePixel = 0
	row.ZIndex = 53
	row.Parent = content
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = row
	return row
end

local function addAction(parent, text, position, size, color, callback)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.Text = text
	button.ZIndex = 55
	button.Parent = parent
	styleButton(button, color)
	button.Activated:Connect(callback)
	return button
end

local function addTextBox(parent, placeholder, position, size, multiline)
	local box = Instance.new("TextBox")
	box.Size = size
	box.Position = position
	box.BackgroundColor3 = Color3.fromRGB(12, 18, 25)
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Gotham
	box.TextSize = 13
	box.TextColor3 = COLORS.Text
	box.PlaceholderColor3 = COLORS.Muted
	box.PlaceholderText = placeholder
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.TextWrapped = multiline == true
	box.MultiLine = multiline == true
	box.ZIndex = 54
	box.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 7)
	padding.Parent = box
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = box
	return box
end

local function addFieldLabel(parent, text, position)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 0, 18)
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextColor3 = COLORS.Muted
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.ZIndex = 54
	label.Parent = parent
	return label
end

local function sendAction(payload)
	ClanAction:FireServer(payload)
	status.Text = "Updating clan..."
end

local function refreshData()
	local success, result = pcall(function()
		return GetClanData:InvokeServer()
	end)
	if success and type(result) == "table" then
		currentData = result
		if currentData.Clan and currentData.Clan.Logo then
			selectedLogo = currentData.Clan.Logo
		end
		return true
	end
	status.Text = "Clan data could not be loaded."
	return false
end

local function renderCreateClan()
	addHeading("CREATE A CLAN", COLORS.Green)
	addBody("Build a persistent community. Temporary teams remain separate and can contain clan or non-clan players.")
	local form = addRow(292)
	addFieldLabel(form, "CLAN NAME", UDim2.fromOffset(12, 8))
	local nameBox = addTextBox(form, "Enter a clan name", UDim2.fromOffset(12, 28), UDim2.new(1, -24, 0, 38), false)
	addFieldLabel(form, "DESCRIPTION", UDim2.fromOffset(12, 74))
	local descriptionBox = addTextBox(
		form,
		"Tell players what your clan is about",
		UDim2.fromOffset(12, 94),
		UDim2.new(1, -24, 0, 68),
		true
	)
	addFieldLabel(form, "EMBLEM", UDim2.fromOffset(12, 170))
	for index, logoName in ipairs({ "Blossom", "Flame", "Wave", "Moon" }) do
		addAction(
			form,
			logoName,
			UDim2.new((index - 1) * 0.25, 12 - (index - 1) * 2, 0, 192),
			UDim2.new(0.25, -15, 0, 32),
			logoName == selectedLogo and COLORS.Green or Color3.fromRGB(42, 58, 72),
			function()
				selectedLogo = logoName
				for _, child in form:GetChildren() do
					if child:IsA("TextButton") and table.find({ "Blossom", "Flame", "Wave", "Moon" }, child.Text) then
						child.BackgroundColor3 = child.Text == selectedLogo
							and COLORS.Green
							or Color3.fromRGB(42, 58, 72)
					end
				end
			end
		)
	end
	addAction(
		form,
		"CREATE",
		UDim2.new(1, -112, 1, -40),
		UDim2.fromOffset(100, 30),
		Color3.fromRGB(30, 125, 72),
		function()
			sendAction({
				Type = "Create",
				Name = nameBox.Text,
				Description = descriptionBox.Text,
				Logo = selectedLogo,
			})
		end
	)
end

local function addProgressBar(parent, progress, goal, color)
	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, -24, 0, 8)
	background.Position = UDim2.new(0, 12, 1, -16)
	background.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
	background.BorderSizePixel = 0
	background.ZIndex = 54
	background.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(goal > 0 and math.clamp(progress / goal, 0, 1) or 1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.ZIndex = 55
	fill.Parent = background
	for _, frame in { background, fill } do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
	end
end

local function addDefinition(titleText, bodyText, color)
	local row = addRow(64)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.3, -12, 1, 0)
	titleLabel.Position = UDim2.fromOffset(12, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 13
	titleLabel.TextColor3 = color
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = titleText
	titleLabel.ZIndex = 54
	titleLabel.Parent = row
	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Size = UDim2.new(0.7, -18, 1, -12)
	bodyLabel.Position = UDim2.new(0.3, 6, 0, 6)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextSize = 12
	bodyLabel.TextColor3 = COLORS.Muted
	bodyLabel.TextWrapped = true
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Center
	bodyLabel.Text = bodyText
	bodyLabel.ZIndex = 54
	bodyLabel.Parent = row
	keepTextInside(titleLabel, 13)
end

local function renderOverview()
	local clan = currentData and currentData.Clan
	if not clan then
		renderCreateClan()
		return
	end

	addHeading(("[%s] %s"):format(clan.Logo or "CLAN", clan.Name), COLORS.Green)
	addBody(clan.Description ~= "" and clan.Description or "No clan description yet.", COLORS.Muted, 38)
	local summary = addRow(92)
	local summaryText = Instance.new("TextLabel")
	summaryText.Size = UDim2.new(1, -24, 0, 58)
	summaryText.Position = UDim2.fromOffset(12, 8)
	summaryText.BackgroundTransparency = 1
	summaryText.Font = Enum.Font.GothamBold
	summaryText.TextSize = 13
	summaryText.TextColor3 = COLORS.Text
	summaryText.TextXAlignment = Enum.TextXAlignment.Left
	summaryText.TextYAlignment = Enum.TextYAlignment.Top
	local currentThreshold = ClanModule.LEVEL_THRESHOLDS[clan.Level] or 0
	local nextThreshold = clan.NextLevelPrestige
	local levelProgress = nextThreshold and math.max(0, clan.Prestige - currentThreshold) or 1
	local levelGoal = nextThreshold and math.max(1, nextThreshold - currentThreshold) or 1
	local progressText = nextThreshold
		and ("%s / %s Prestige toward Level %d"):format(
			formatNumber(levelProgress),
			formatNumber(levelGoal),
			math.min(ClanModule.MAX_LEVEL, clan.Level + 1)
		)
		or "Maximum clan level reached"
	summaryText.Text = ("CLAN LEVEL %d OF %d\n%s    Members %d/%d"):format(
		clan.Level,
		ClanModule.MAX_LEVEL,
		progressText,
		clan.MemberCount,
		clan.MaxMembers
	)
	summaryText.ZIndex = 54
	summaryText.Parent = summary
	keepTextInside(summaryText, 13)
	addProgressBar(summary, levelProgress, levelGoal, COLORS.Gold)

	local bonuses = currentData.Bonuses or {}
	local bonusRow = addRow(56)
	local bonusLabel = Instance.new("TextLabel")
	bonusLabel.Size = UDim2.new(1, -24, 1, 0)
	bonusLabel.Position = UDim2.fromOffset(12, 0)
	bonusLabel.BackgroundTransparency = 1
	bonusLabel.Font = Enum.Font.GothamBold
	bonusLabel.TextSize = 12
	bonusLabel.TextColor3 = COLORS.Cyan
	bonusLabel.TextWrapped = true
	bonusLabel.TextXAlignment = Enum.TextXAlignment.Left
	bonusLabel.Text = ("PROXIMITY BONUS    %d clanmates nearby    +%d%% XP    +%d%% damage"):format(
			currentData.NearbyClanMembers or 0,
			math.floor(((bonuses.XPMultiplier or 1) - 1) * 100 + 0.5),
			math.floor(((bonuses.DamageMultiplier or 1) - 1) * 100 + 0.5)
	)
	bonusLabel.ZIndex = 54
	bonusLabel.Parent = bonusRow

	addHeading("WHAT THE NUMBERS MEAN")
	addDefinition(
		"Clan Prestige",
		"Shared clan XP earned by all members. Prestige is the only value that raises Clan Level.",
		COLORS.Gold
	)
	addDefinition(
		"Member Reputation",
		"Your personal contribution score inside this clan. It shows who helps most; it does not raise character level.",
		COLORS.Green
	)
	addDefinition(
		"Clan Combat Bounty",
		"The sum of member bounty: " .. formatNumber(clan.ClanBounty)
			.. ". It represents combat notoriety only and does not level the clan.",
		Color3.fromRGB(235, 105, 105)
	)

	if clan.IsOwner then
		addHeading("CLAN SETTINGS")
		local settings = addRow(204)
		addFieldLabel(settings, "DESCRIPTION", UDim2.fromOffset(12, 8))
		local descriptionBox = addTextBox(
			settings,
			"Tell players what your clan is about",
			UDim2.fromOffset(12, 28),
			UDim2.new(1, -24, 0, 54),
			true
		)
		descriptionBox.Text = clan.Description or ""
		addFieldLabel(settings, "EMBLEM", UDim2.fromOffset(12, 90))
		for index, logoName in ipairs({ "Blossom", "Flame", "Wave", "Moon" }) do
			addAction(
				settings,
				logoName,
				UDim2.new((index - 1) * 0.25, 12 - (index - 1) * 2, 0, 112),
				UDim2.new(0.25, -15, 0, 30),
				logoName == selectedLogo and COLORS.Green or Color3.fromRGB(42, 58, 72),
				function()
					selectedLogo = logoName
					for _, child in settings:GetChildren() do
						if child:IsA("TextButton") and table.find({ "Blossom", "Flame", "Wave", "Moon" }, child.Text) then
							child.BackgroundColor3 = child.Text == selectedLogo
								and COLORS.Green
								or Color3.fromRGB(42, 58, 72)
						end
					end
				end
			)
		end
		addAction(
			settings,
			"SAVE SETTINGS",
			UDim2.new(1, -134, 1, -42),
			UDim2.fromOffset(122, 32),
			Color3.fromRGB(30, 112, 76),
			function()
				sendAction({
					Type = "UpdateSettings",
					Description = descriptionBox.Text,
					Logo = selectedLogo or clan.Logo,
				})
			end
		)
	end

	local leaveRow = addRow(50)
	addAction(
		leaveRow,
		clan.IsOwner and "DISBAND" or "LEAVE CLAN",
		UDim2.new(1, -132, 0.5, -16),
		UDim2.fromOffset(120, 32),
		COLORS.Red,
		function()
			sendAction({ Type = "Leave" })
		end
	)
end

local function renderMembers()
	local clan = currentData and currentData.Clan
	addHeading("CLAN MEMBERS", COLORS.Green)
	if not clan then
		addBody("Join or create a clan to view its member roster.")
		return
	end
	addBody(
		("Reputation measures each member's contribution. Clan Combat Bounty is %s and is informational only."):format(
			formatNumber(clan.ClanBounty)
		),
		COLORS.Muted,
		38
	)
	for _, member in ipairs(clan.Members or {}) do
		local row = addRow(56)
		local memberLabel = Instance.new("TextLabel")
		memberLabel.Size = UDim2.new(1, -24, 1, 0)
		memberLabel.Position = UDim2.fromOffset(12, 0)
		memberLabel.BackgroundTransparency = 1
		memberLabel.Font = Enum.Font.GothamBold
		memberLabel.TextSize = 13
		memberLabel.TextColor3 = member.UserId == LocalPlayer.UserId and COLORS.Cyan or COLORS.Text
		memberLabel.TextXAlignment = Enum.TextXAlignment.Left
		memberLabel.Text = ("%s    %s    Contribution Rep %s    Combat Bounty %s"):format(
			member.DisplayName,
			member.Role,
			formatNumber(member.Reputation),
			formatNumber(member.Bounty)
		)
		memberLabel.ZIndex = 54
		memberLabel.Parent = row
		keepTextInside(memberLabel, 13)
	end
end

local function renderInviteRows()
	for _, invite in ipairs(currentData.PendingInvites or {}) do
		local row = addRow(58)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -190, 1, 0)
		label.Position = UDim2.fromOffset(12, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = COLORS.Gold
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = invite.InviterName .. " invited you to " .. invite.ClanName
		label.ZIndex = 54
		label.Parent = row
		keepTextInside(label, 13)
		addAction(row, "ACCEPT", UDim2.new(1, -174, 0.5, -16), UDim2.fromOffset(78, 32), COLORS.Green, function()
			sendAction({ Type = "InviteResponse", ClanId = invite.ClanId, Accepted = true })
		end)
		addAction(row, "DECLINE", UDim2.new(1, -90, 0.5, -16), UDim2.fromOffset(78, 32), COLORS.Red, function()
			sendAction({ Type = "InviteResponse", ClanId = invite.ClanId, Accepted = false })
		end)
	end
end

local function renderRecruit()
	addHeading("JOIN AND INVITE", COLORS.Cyan)
	addBody("Browse persistent clans, request membership, or manage invitations from players in this server.")
	renderInviteRows()
	local clan = currentData and currentData.Clan
	if clan and clan.CanManage then
		addHeading("JOIN REQUESTS")
		if #(clan.Requests or {}) == 0 then addBody("No pending requests.") end
		for _, request in ipairs(clan.Requests or {}) do
			local row = addRow(54)
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, -190, 1, 0)
			label.Position = UDim2.fromOffset(12, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.TextSize = 13
			label.TextColor3 = COLORS.Text
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = request.DisplayName
			label.ZIndex = 54
			label.Parent = row
			addAction(row, "ACCEPT", UDim2.new(1, -174, 0.5, -16), UDim2.fromOffset(78, 32), COLORS.Green, function()
				sendAction({ Type = "ReviewRequest", UserId = request.UserId, Accepted = true })
			end)
			addAction(row, "DENY", UDim2.new(1, -90, 0.5, -16), UDim2.fromOffset(78, 32), COLORS.Red, function()
				sendAction({ Type = "ReviewRequest", UserId = request.UserId, Accepted = false })
			end)
		end

		addHeading("INVITE FROM THIS LOBBY")
		for _, player in Players:GetPlayers() do
			if player == LocalPlayer or player:GetAttribute("ClanId") ~= "" then continue end
			local row = addRow(48)
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, -120, 1, 0)
			label.Position = UDim2.fromOffset(12, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.TextSize = 13
			label.TextColor3 = COLORS.Text
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = player.DisplayName
			label.ZIndex = 54
			label.Parent = row
			addAction(row, "INVITE", UDim2.new(1, -92, 0.5, -15), UDim2.fromOffset(80, 30), COLORS.Cyan, function()
				sendAction({ Type = "Invite", UserId = player.UserId })
			end)
		end
	end

	addHeading("BROWSE CLANS")
	for _, browseClan in ipairs(currentData and currentData.Browse or {}) do
		local row = addRow(68)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -126, 1, 0)
		label.Position = UDim2.fromOffset(12, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = COLORS.Text
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = ("%s  |  Lv.%d  |  %s prestige  |  %d/%d"):format(
			browseClan.Name,
			browseClan.Level,
			formatNumber(browseClan.Prestige),
			browseClan.MemberCount,
			browseClan.MaxMembers
		)
		label.ZIndex = 54
		label.Parent = row
		keepTextInside(label, 14)
		if not clan then
			addAction(row, "REQUEST", UDim2.new(1, -104, 0.5, -16), UDim2.fromOffset(92, 32), COLORS.Green, function()
				sendAction({ Type = "RequestJoin", ClanId = browseClan.Id })
			end)
		end
	end
end

local function renderRanking()
	addHeading("PRESTIGE LEADERBOARD", COLORS.Gold)
	addBody("Clans are ranked by shared Prestige, the same value used to increase Clan Level.")
	local rankings = table.clone(currentData and currentData.Browse or {})
	table.sort(rankings, function(left, right)
		return (left.Prestige or 0) > (right.Prestige or 0)
	end)
	for index, clan in ipairs(rankings) do
		local row = addRow(52)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -24, 1, 0)
		label.Position = UDim2.fromOffset(12, 0)
		label.BackgroundTransparency = 1
		label.Font = index <= 3 and Enum.Font.GothamBlack or Enum.Font.GothamBold
		label.TextSize = 14
		label.TextColor3 = index <= 3 and COLORS.Gold or COLORS.Text
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = ("#%d    %s    Clan Lv.%d    %s Prestige"):format(
			index,
			clan.Name,
			clan.Level,
			formatNumber(clan.Prestige)
		)
		label.ZIndex = 54
		label.Parent = row
		keepTextInside(label, 14)
	end
end

local function renderAchievements()
	addHeading("CLAN ACHIEVEMENTS", COLORS.Gold)
	local clan = currentData and currentData.Clan
	if not clan then
		addBody("Join or create a clan to contribute to shared achievements.")
		return
	end
	for _, achievement in ipairs(clan.Achievements or {}) do
		local row = addRow(76)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -24, 0, 52)
		label.Position = UDim2.fromOffset(12, 7)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = achievement.Completed and COLORS.Green or COLORS.Text
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		label.Text = ("%s    %d/%d\n%s  Rewards: %s prestige + %s member reputation"):format(
			achievement.Name,
			achievement.Progress,
			achievement.Goal,
			achievement.Description,
			formatNumber(achievement.PrestigeReward),
			formatNumber(achievement.MemberReputationReward)
		)
		label.ZIndex = 54
		label.Parent = row
		addProgressBar(row, achievement.Progress, achievement.Goal, achievement.Completed and COLORS.Green or COLORS.Gold)
	end
end

renderCurrentTab = function()
	clearContent()
	for tabName, button in tabButtons do
		button.BackgroundColor3 = tabName == activeTab and Color3.fromRGB(38, 112, 88) or Color3.fromRGB(42, 58, 72)
		button.TextColor3 = tabName == activeTab and COLORS.Green or COLORS.Text
	end
	if activeTab == "Overview" then
		renderOverview()
	elseif activeTab == "Members" then
		renderMembers()
	elseif activeTab == "Recruitment" then
		renderRecruit()
	elseif activeTab == "Leaderboard" then
		renderRanking()
	else
		renderAchievements()
	end
end

local function setOpen(open)
	panelOpen = open
	overlay.Visible = open
	if not open then
		if UserInputService.GamepadEnabled then GuiService.SelectedObject = clanButton end
		return
	end
	attentionBadge.Visible = false
	status.Text = "Loading clan data..."
	if refreshData() then
		status.Text = "Clan data loaded."
		renderCurrentTab()
	end
	panel.BackgroundTransparency = 1
	TweenService:Create(panel, TweenInfo.new(0.18), { BackgroundTransparency = 0 }):Play()
	if UserInputService.GamepadEnabled then
		task.defer(function()
			GuiService.SelectedObject = tabButtons[activeTab]
		end)
	end
end

clanButton.Activated:Connect(function()
	setOpen(not panelOpen)
end)

closeButton.Activated:Connect(function()
	setOpen(false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not panelOpen then return end
	if input.KeyCode == Enum.KeyCode.ButtonB
		or (input.KeyCode == Enum.KeyCode.Escape and not gameProcessed)
	then
		setOpen(false)
	end
end)

-- ── Invite toast notifications ───────────────────────────────────────────────
local shownInviteToasts = {}
local activeToasts = {}
local TOAST_LIFETIME = 14

local function dismissToast(toast, clanId)
	if not toast or not toast.Parent then return end
	TweenService:Create(toast, TweenInfo.new(0.2), { Position = toast.Position + UDim2.fromOffset(0, -40), BackgroundTransparency = 1 }):Play()
	task.delay(0.25, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
	activeToasts[clanId] = nil
end

local toastYOffset = 0

local function showInviteToast(invite)
	if shownInviteToasts[invite.ClanId] then return end
	shownInviteToasts[invite.ClanId] = true

	local toastW = UserInputService.TouchEnabled and 280 or 320
	local toastH = 72
	local margin = 8
	toastYOffset += toastH + margin

	local toast = Instance.new("Frame")
	toast.Name = "InviteToast"
	toast.Size = UDim2.fromOffset(toastW, toastH)
	toast.Position = UDim2.new(0.5, -toastW / 2, 0, 56 + toastYOffset - toastH - margin)
	toast.AnchorPoint = Vector2.new(0, 0)
	toast.BackgroundColor3 = Color3.fromRGB(14, 20, 30)
	toast.BackgroundTransparency = 0.1
	toast.BorderSizePixel = 0
	toast.ZIndex = 60
	toast.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 8)
	toastCorner.Parent = toast
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Gold
	stroke.Transparency = 0.35
	stroke.Parent = toast

	local msg = Instance.new("TextLabel")
	msg.Size = UDim2.new(1, -16, 0, 32)
	msg.Position = UDim2.fromOffset(10, 6)
	msg.BackgroundTransparency = 1
	msg.Font = Enum.Font.GothamBold
	msg.TextSize = 11
	msg.TextColor3 = COLORS.Gold
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.TextTruncate = Enum.TextTruncate.AtEnd
	msg.Text = "🗡  " .. (invite.InviterName or "Someone") .. " invited you to  " .. (invite.ClanName or "a clan")
	msg.ZIndex = 61
	msg.Parent = toast

	local function makeBtn(label, xOffset, bgColor, action)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(90, 26)
		btn.Position = UDim2.fromOffset(xOffset, 40)
		btn.BackgroundColor3 = bgColor
		btn.BackgroundTransparency = 0.2
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.TextColor3 = Color3.fromRGB(240, 245, 255)
		btn.Text = label
		btn.ZIndex = 62
		btn.Parent = toast
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 5)
		btnCorner.Parent = btn
		btn.Activated:Connect(function()
			sendAction({ Type = "InviteResponse", ClanId = invite.ClanId, Accepted = action })
			dismissToast(toast, invite.ClanId)
			toastYOffset = math.max(0, toastYOffset - toastH - margin)
			if action then
				attentionBadge.Visible = false
				task.delay(0.4, function()
					if refreshData() then
						renderCurrentTab()
					end
				end)
			end
		end)
	end

	makeBtn("ACCEPT", 10, Color3.fromRGB(30, 120, 70), true)
	makeBtn("DECLINE", 108, Color3.fromRGB(120, 35, 40), false)

	activeToasts[invite.ClanId] = toast

	task.delay(TOAST_LIFETIME, function()
		if activeToasts[invite.ClanId] == toast then
			dismissToast(toast, invite.ClanId)
			toastYOffset = math.max(0, toastYOffset - toastH - margin)
		end
	end)
end

local function checkAndShowInviteToasts()
	local invites = currentData and currentData.PendingInvites
	if not invites then return end
	for _, invite in ipairs(invites) do
		showInviteToast(invite)
	end
end

ClanUpdate.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.Message then
		status.Text = tostring(payload.Message)
	end
	if panelOpen and payload.Refresh then
		task.delay(0.15, function()
			if panelOpen and refreshData() then
				renderCurrentTab()
			end
		end)
	elseif payload.Refresh then
		attentionBadge.Visible = true
		task.delay(0.3, function()
			if not panelOpen and refreshData() then
				checkAndShowInviteToasts()
			end
		end)
	end
end)

print("[ClanController] Loaded")
