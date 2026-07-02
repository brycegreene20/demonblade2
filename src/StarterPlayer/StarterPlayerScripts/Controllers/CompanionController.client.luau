local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CompanionAction = Remotes:WaitForChild("CompanionAction")
local CompanionUpdate = Remotes:WaitForChild("CompanionUpdate")
local GetCompanionData = Remotes:WaitForChild("GetCompanionData")

local COLORS = {
	Background = Color3.fromRGB(10, 15, 21),
	Panel = Color3.fromRGB(17, 24, 33),
	Row = Color3.fromRGB(25, 34, 45),
	Selected = Color3.fromRGB(31, 62, 70),
	Text = Color3.fromRGB(239, 245, 250),
	Muted = Color3.fromRGB(145, 160, 177),
	Cyan = Color3.fromRGB(70, 210, 225),
	Gold = Color3.fromRGB(245, 195, 72),
	Green = Color3.fromRGB(75, 220, 125),
	Red = Color3.fromRGB(220, 80, 90),
}

local currentData = {
	Companions = {},
	EquippedCompanionId = "",
	CanGrantPrototype = false,
	Catalog = {},
}
local selectedId = ""
local pendingFusionId = ""
local panelOpen = false
local busy = false
local companionVisuals = {}

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local gui = Instance.new("ScreenGui")
gui.Name = "CompanionGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 19
gui.Parent = PlayerGui

local openButton = Instance.new("TextButton")
openButton.Name = "CompanionButton"
openButton.Size = UDim2.fromOffset(118, 46)
openButton.Position = UDim2.fromOffset(122, 58)
openButton.BackgroundColor3 = Color3.fromRGB(23, 47, 55)
openButton.BackgroundTransparency = 0.06
openButton.BorderSizePixel = 0
openButton.Font = Enum.Font.GothamBold
openButton.TextSize = 13
openButton.TextColor3 = COLORS.Cyan
openButton.Text = "COMPANIONS"
openButton.ZIndex = 10
openButton.Parent = gui
addCorner(openButton, 8)
addStroke(openButton, COLORS.Cyan, 0.3)

if UserInputService.TouchEnabled then
	openButton.Size = UDim2.fromOffset(96, 40)
	openButton.Position = UDim2.fromOffset(102, 140)
	openButton.TextSize = 11
end

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.36
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.ZIndex = 50
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(760, 510)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = COLORS.Panel
panel.BorderSizePixel = 0
panel.SelectionGroup = true
panel.ZIndex = 51
panel.Parent = overlay
addCorner(panel, 8)
addStroke(panel, Color3.fromRGB(65, 86, 102), 0.15)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(760, 540)
sizeConstraint.MinSize = Vector2.new(300, 350)
sizeConstraint.Parent = panel
if UserInputService.TouchEnabled then
	panel.Size = UDim2.new(1, -16, 1, -92)
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 54)
title.Position = UDim2.fromOffset(18, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.TextColor3 = COLORS.Text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "COMPANIONS"
title.ZIndex = 52
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -36, 0, 26)
subtitle.Position = UDim2.fromOffset(18, 44)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextColor3 = COLORS.Muted
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "Equip one companion. Fuse matching companions of the same tier to unlock more buffs."
subtitle.TextWrapped = true
subtitle.ZIndex = 52
subtitle.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(38, 38)
closeButton.Position = UDim2.new(1, -46, 0, 8)
closeButton.BackgroundColor3 = Color3.fromRGB(38, 47, 58)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 17
closeButton.TextColor3 = COLORS.Text
closeButton.Text = "X"
closeButton.ZIndex = 54
closeButton.Parent = panel
addCorner(closeButton, 6)

local list = Instance.new("ScrollingFrame")
list.Name = "CompanionList"
list.Size = UDim2.new(0.44, -18, 1, -124)
list.Position = UDim2.fromOffset(14, 78)
list.BackgroundColor3 = COLORS.Background
list.BackgroundTransparency = 0.12
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.ScrollBarImageColor3 = COLORS.Cyan
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.ZIndex = 52
list.Parent = panel
addCorner(list, 6)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 7)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list
local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 7)
listPadding.PaddingBottom = UDim.new(0, 7)
listPadding.PaddingLeft = UDim.new(0, 7)
listPadding.PaddingRight = UDim.new(0, 7)
listPadding.Parent = list

local detail = Instance.new("ScrollingFrame")
detail.Name = "CompanionDetail"
detail.Size = UDim2.new(0.56, -24, 1, -124)
detail.Position = UDim2.new(0.44, 4, 0, 78)
detail.BackgroundColor3 = COLORS.Background
detail.BackgroundTransparency = 0.12
detail.BorderSizePixel = 0
detail.ScrollBarThickness = 5
detail.ScrollBarImageColor3 = COLORS.Gold
detail.AutomaticCanvasSize = Enum.AutomaticSize.Y
detail.CanvasSize = UDim2.new()
detail.ZIndex = 52
detail.Parent = panel
addCorner(detail, 6)
if UserInputService.TouchEnabled then
	list.Size = UDim2.new(1, -28, 0.35, 0)
	detail.Size = UDim2.new(1, -28, 0.52, -10)
	detail.Position = UDim2.new(0, 14, 0.35, 86)
end

local detailLayout = Instance.new("UIListLayout")
detailLayout.Padding = UDim.new(0, 8)
detailLayout.SortOrder = Enum.SortOrder.LayoutOrder
detailLayout.Parent = detail
local detailPadding = Instance.new("UIPadding")
detailPadding.PaddingTop = UDim.new(0, 12)
detailPadding.PaddingBottom = UDim.new(0, 12)
detailPadding.PaddingLeft = UDim.new(0, 12)
detailPadding.PaddingRight = UDim.new(0, 12)
detailPadding.Parent = detail

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -28, 0, 28)
status.Position = UDim2.new(0, 14, 1, -36)
status.BackgroundColor3 = Color3.fromRGB(21, 29, 38)
status.BorderSizePixel = 0
status.Font = Enum.Font.GothamMedium
status.TextSize = 12
status.TextColor3 = COLORS.Muted
status.Text = "Ready"
status.ZIndex = 52
status.Parent = panel
addCorner(status, 5)

local rebuild

local function clearContainer(container, layout, padding)
	for _, child in container:GetChildren() do
		if child ~= layout and child ~= padding then
			child:Destroy()
		end
	end
end

local function getCompanion(companionId)
	for _, companion in currentData.Companions or {} do
		if companion.Id == companionId then return companion end
	end
	return nil
end

local function setStatus(message, success)
	status.Text = message or "Ready"
	status.TextColor3 = success == nil and COLORS.Muted or (success and COLORS.Green or COLORS.Red)
end

local function invoke(payload)
	if busy then return end
	busy = true
	setStatus("Working...", nil)
	local ok, response = pcall(function()
		return CompanionAction:InvokeServer(payload)
	end)
	busy = false
	if not ok or typeof(response) ~= "table" then
		setStatus("Companion request failed", false)
		warn("[CompanionController] Companion action failed:", response)
		return
	end
	if response.Data then currentData = response.Data end
	if response.Success then pendingFusionId = "" end
	setStatus(response.Message or (response.Success and "Done" or "Action failed"), response.Success)
	if rebuild then rebuild() end
end

local function addDetailText(text, color, size, bold)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, size and size + 10 or 28)
	label.BackgroundTransparency = 1
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextSize = size or 13
	label.TextColor3 = color or COLORS.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.ZIndex = 53
	label.Parent = detail
	return label
end

local function addActionButton(text, color, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 38)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = COLORS.Text
	button.Text = text
	button.ZIndex = 53
	button.Parent = detail
	addCorner(button, 6)
	button.Activated:Connect(callback)
	return button
end

local function renderDetail()
	clearContainer(detail, detailLayout, detailPadding)
	local companion = getCompanion(selectedId)
	if not companion then
		addDetailText("Select a companion", COLORS.Muted, 16, true)
		addDetailText("Each companion has one fixed identity stat and randomized bonus stats.", COLORS.Muted, 12, false)
		return
	end

	addDetailText(companion.Name, COLORS.Text, 21, true)
	addDetailText(
		("%s  |  Tier %d/%d  |  %d buff slots"):format(
			companion.Category,
			companion.Tier,
			companion.MaxTier,
			companion.BuffSlots
		),
		COLORS.Gold,
		12,
		true
	)
	addDetailText(companion.Description, COLORS.Muted, 12, false)
	addDetailText("Fixed companion stat", COLORS.Cyan, 13, true)
	addDetailText(companion.SetStat.Display, COLORS.Text, 13, false)
	addDetailText("Randomized buffs", COLORS.Cyan, 13, true)
	for _, buff in companion.Buffs do
		addDetailText(buff.Display, COLORS.Text, 13, false)
	end

	local equipped = currentData.EquippedCompanionId == companion.Id
	addActionButton(equipped and "UNEQUIP" or "EQUIP", equipped and COLORS.Red or COLORS.Green, function()
		invoke({ Action = "Equip", CompanionId = equipped and "" or companion.Id })
	end)

	if companion.Tier < companion.MaxTier then
		local candidates = {}
		for _, other in currentData.Companions do
			if other.Id ~= companion.Id
				and other.SpeciesId == companion.SpeciesId
				and other.Tier == companion.Tier
			then
				table.insert(candidates, other)
			end
		end
		if #candidates > 0 then
			local confirming = pendingFusionId == companion.Id
			addActionButton(
				confirming and "CONFIRM FUSION" or ("FUSE WITH MATCHING TIER " .. tostring(companion.Tier)),
				confirming and COLORS.Red or Color3.fromRGB(125, 75, 175),
				function()
					if not confirming then
						pendingFusionId = companion.Id
						setStatus("Press Confirm Fusion to consume one matching duplicate", nil)
						renderDetail()
						return
					end
					invoke({
						Action = "Fuse",
						PrimaryId = companion.Id,
						MaterialId = candidates[1].Id,
					})
				end
			)
		else
			addDetailText(
				("Fusion needs another %s at tier %d."):format(companion.Name, companion.Tier),
				COLORS.Muted,
				11,
				false
			)
		end
	else
		addDetailText("Maximum fusion tier reached", COLORS.Gold, 12, true)
	end
end

rebuild = function()
	clearContainer(list, listLayout, listPadding)
	if not getCompanion(selectedId) then
		selectedId = currentData.Companions[1] and currentData.Companions[1].Id or ""
	end

	for index, companion in currentData.Companions do
		local selected = companion.Id == selectedId
		local equipped = companion.Id == currentData.EquippedCompanionId
		local row = Instance.new("TextButton")
		row.Name = "Companion_" .. tostring(index)
		row.Size = UDim2.new(1, 0, 0, 72)
		row.BackgroundColor3 = selected and COLORS.Selected or COLORS.Row
		row.BorderSizePixel = 0
		row.Text = ""
		row.ZIndex = 53
		row.Parent = list
		addCorner(row, 6)
		if equipped then addStroke(row, COLORS.Green, 0.1) end

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(48, 48)
		icon.Position = UDim2.fromOffset(10, 12)
		icon.BackgroundColor3 = companion.Color or COLORS.Cyan
		icon.BackgroundTransparency = 0.65
		icon.BorderSizePixel = 0
		icon.Image = companion.Icon or ""
		icon.ImageColor3 = COLORS.Text
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 54
		icon.Parent = row
		addCorner(icon, 6)

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -72, 0, 26)
		name.Position = UDim2.fromOffset(66, 9)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 13
		name.TextColor3 = COLORS.Text
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = companion.Name
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.ZIndex = 54
		name.Parent = row

		local meta = Instance.new("TextLabel")
		meta.Size = UDim2.new(1, -72, 0, 26)
		meta.Position = UDim2.fromOffset(66, 35)
		meta.BackgroundTransparency = 1
		meta.Font = Enum.Font.Gotham
		meta.TextSize = 11
		meta.TextColor3 = equipped and COLORS.Green or COLORS.Muted
		meta.TextXAlignment = Enum.TextXAlignment.Left
		meta.Text = ("Tier %d  |  %d buffs%s"):format(
			companion.Tier,
			#companion.Buffs,
			equipped and "  |  Equipped" or ""
		)
		meta.ZIndex = 54
		meta.Parent = row

		row.Activated:Connect(function()
			selectedId = companion.Id
			pendingFusionId = ""
			rebuild()
		end)
	end

	if currentData.CanGrantPrototype then
		for _, prototype in {
			{ SpeciesId = "KasugaiCrow", Label = "STUDIO: ADD CROW" },
			{ SpeciesId = "PaperShikigami", Label = "STUDIO: ADD SHIKIGAMI" },
		} do
			local grant = Instance.new("TextButton")
			grant.Size = UDim2.new(1, 0, 0, 38)
			grant.BackgroundColor3 = Color3.fromRGB(45, 65, 80)
			grant.BorderSizePixel = 0
			grant.Font = Enum.Font.GothamBold
			grant.TextSize = 11
			grant.TextColor3 = COLORS.Cyan
			grant.Text = prototype.Label
			grant.ZIndex = 53
			grant.Parent = list
			addCorner(grant, 6)
			grant.Activated:Connect(function()
				invoke({
					Action = "DevGrant",
					SpeciesId = prototype.SpeciesId,
				})
			end)
		end
	end
	renderDetail()
end

local function setPanelOpen(isOpen)
	panelOpen = isOpen
	overlay.Visible = isOpen
	if isOpen then
		rebuild()
		GuiService.SelectedObject = closeButton
	end
end

openButton.Activated:Connect(function()
	setPanelOpen(not panelOpen)
end)
closeButton.Activated:Connect(function()
	setPanelOpen(false)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and panelOpen then
		setPanelOpen(false)
	end
end)

CompanionUpdate.OnClientEvent:Connect(function(data, message)
	if typeof(data) == "table" then
		currentData = data
		if rebuild then rebuild() end
	end
	if message then setStatus(message, true) end
end)

task.spawn(function()
	local ok, data = pcall(function()
		return GetCompanionData:InvokeServer()
	end)
	if ok and typeof(data) == "table" then
		currentData = data
		rebuild()
	else
		warn("[CompanionController] Initial companion data request failed")
	end
end)

local function destroyVisual(player)
	local visual = companionVisuals[player]
	if visual then visual:Destroy() end
	companionVisuals[player] = nil
end

local function createVisual(player, speciesId)
	destroyVisual(player)
	if speciesId == "" then return nil end

	local model = Instance.new("Model")
	model.Name = player.Name .. "_Companion"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Shape = speciesId == "KasugaiCrow" and Enum.PartType.Ball or Enum.PartType.Block
	root.Size = speciesId == "KasugaiCrow" and Vector3.new(0.75, 0.6, 0.9) or Vector3.new(0.75, 1, 0.18)
	root.Color = speciesId == "KasugaiCrow" and Color3.fromRGB(24, 27, 35) or Color3.fromRGB(220, 240, 245)
	root.Material = speciesId == "KasugaiCrow" and Enum.Material.SmoothPlastic or Enum.Material.Neon
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root

	for side = -1, 1, 2 do
		local wing = Instance.new("Part")
		wing.Name = side < 0 and "LeftWing" or "RightWing"
		wing.Size = speciesId == "KasugaiCrow" and Vector3.new(0.85, 0.12, 0.45) or Vector3.new(0.35, 0.7, 0.1)
		wing.Color = root.Color
		wing.Material = root.Material
		wing.Anchored = true
		wing.CanCollide = false
		wing.CanQuery = false
		wing.CanTouch = false
		wing.CastShadow = false
		wing.Parent = model
	end

	local labelGui = Instance.new("BillboardGui")
	labelGui.Size = UDim2.fromOffset(110, 22)
	labelGui.StudsOffset = Vector3.new(0, 0.9, 0)
	labelGui.AlwaysOnTop = false
	labelGui.MaxDistance = 90
	labelGui.Adornee = root
	labelGui.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 10
	label.TextColor3 = COLORS.Cyan
	label.TextStrokeTransparency = 0.35
	label.Text = speciesId == "KasugaiCrow" and "Kasugai Crow" or "Paper Shikigami"
	label.Parent = labelGui

	model.Parent = workspace
	companionVisuals[player] = model
	return model
end

local function watchPlayer(player)
	player:GetAttributeChangedSignal("EquippedCompanionSpecies"):Connect(function()
		createVisual(player, player:GetAttribute("EquippedCompanionSpecies") or "")
	end)
	createVisual(player, player:GetAttribute("EquippedCompanionSpecies") or "")
end

Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(destroyVisual)
for _, player in Players:GetPlayers() do watchPlayer(player) end

RunService.RenderStepped:Connect(function(deltaTime)
	local now = os.clock()
	for player, model in companionVisuals do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp or not model.PrimaryPart then continue end
		local right = hrp.CFrame.RightVector
		local targetPosition = hrp.Position + right * 2.2 + Vector3.new(0, 2.3 + math.sin(now * 2.4) * 0.18, 0)
		local target = CFrame.lookAt(targetPosition, hrp.Position + Vector3.new(0, 1.5, 0))
		local current = model:GetPivot()
		local nextCFrame = current:Lerp(target, math.min(1, 9 * deltaTime))
		model:PivotTo(nextCFrame)

		local flap = math.sin(now * 8) * math.rad(28)
		local leftWing = model:FindFirstChild("LeftWing")
		local rightWing = model:FindFirstChild("RightWing")
		if leftWing and leftWing:IsA("BasePart") then
			leftWing.CFrame = nextCFrame * CFrame.new(-0.65, 0, 0) * CFrame.Angles(0, 0, flap)
		end
		if rightWing and rightWing:IsA("BasePart") then
			rightWing.CFrame = nextCFrame * CFrame.new(0.65, 0, 0) * CFrame.Angles(0, 0, -flap)
		end
	end
end)

print("[CompanionController] Loaded")
