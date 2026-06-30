local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local toolbar = plugin:CreateToolbar("DemonBlade2")
local openButton = toolbar:CreateButton(
	"Tools",
	"Open DemonBlade2 coordinate and placement tools",
	"rbxassetid://7072719338"
)

local MARKERS_FOLDER_NAME = "DemonBlade2Markers"
local PLUGIN_GUI_ID = "DemonBlade2PlacementTools"
local PENDING_MARKER_SETTING = "PendingPlacementMarker"

local MARKER_DEFINITIONS = {
	{
		id = "SafeZone",
		displayName = "Safe Zone",
		description = "Creates a safe-zone marker. Blank name updates the primary spawn safe zone.",
		defaultName = "SafeZoneCenter",
		namePrefix = "SafeZone_",
		labelPrefix = "Safe Zone",
		color = Color3.fromRGB(80, 180, 255),
		size = Vector3.new(96, 1, 96),
		role = "SafeZone",
		attributes = {
			ZoneHeight = 18,
		},
	},
	{
		id = "QuestNPC_Elder",
		displayName = "Trainer Urokodaki",
		description = "Moves Trainer Urokodaki to the selected position.",
		fixedName = "QuestNPC_Elder",
		labelPrefix = "Trainer Urokodaki",
		color = Color3.fromRGB(255, 210, 80),
		size = Vector3.new(4, 1, 4),
		role = "NPC",
	},
	{
		id = "QuestNPC_Officer",
		displayName = "Corps Officer",
		description = "Moves the Corps Officer to the selected position.",
		fixedName = "QuestNPC_Officer",
		labelPrefix = "Corps Officer",
		color = Color3.fromRGB(120, 160, 255),
		size = Vector3.new(4, 1, 4),
		role = "NPC",
	},
	{
		id = "QuestNPC_Scout",
		displayName = "Merchant Aoi",
		description = "Moves Merchant Aoi to the selected position.",
		fixedName = "QuestNPC_Scout",
		labelPrefix = "Merchant Aoi",
		color = Color3.fromRGB(80, 220, 120),
		size = Vector3.new(4, 1, 4),
		role = "NPC",
	},
	{
		id = "TrainingDummyYard",
		displayName = "Training Dummy Yard",
		description = "Creates or moves the dummy-yard center marker.",
		fixedName = "TrainingDummyYard",
		labelPrefix = "Training Dummy Yard",
		color = Color3.fromRGB(255, 120, 80),
		size = Vector3.new(8, 1, 8),
		role = "DummyYard",
		attributes = {
			Columns = 4,
			Rows = 3,
			Spacing = 9,
		},
	},
}

local selectedDefinition = MARKER_DEFINITIONS[1]

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false,
	false,
	360,
	420,
	300,
	300
)

local widget = plugin:CreateDockWidgetPluginGui(PLUGIN_GUI_ID, widgetInfo)
widget.Title = "DemonBlade2 Tools"

local root = Instance.new("ScrollingFrame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(22, 24, 31)
root.BorderSizePixel = 0
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.CanvasSize = UDim2.fromOffset(0, 0)
root.ScrollBarThickness = 8
root.ScrollingDirection = Enum.ScrollingDirection.Y
root.Parent = widget

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = root

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root

local title = Instance.new("TextLabel")
title.Name = "Title"
title.LayoutOrder = 1
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245, 248, 255)
title.Text = "Placement Markers"
title.Parent = root

local info = Instance.new("TextLabel")
info.Name = "Info"
info.LayoutOrder = 2
info.Size = UDim2.new(1, 0, 0, 44)
info.BackgroundTransparency = 1
info.Font = Enum.Font.Gotham
info.TextSize = 12
info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextColor3 = Color3.fromRGB(190, 198, 214)
info.Text = "In Play mode, capture the live position. Stop Play, then apply the captured marker to the real map."
info.Parent = root

local selectorFrame = Instance.new("Frame")
selectorFrame.Name = "Selector"
selectorFrame.LayoutOrder = 3
selectorFrame.Size = UDim2.new(1, 0, 0, 158)
selectorFrame.BackgroundTransparency = 1
selectorFrame.Parent = root

local selectorLayout = Instance.new("UIListLayout")
selectorLayout.Padding = UDim.new(0, 6)
selectorLayout.SortOrder = Enum.SortOrder.LayoutOrder
selectorLayout.Parent = selectorFrame

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "NameLabel"
nameLabel.LayoutOrder = 4
nameLabel.Size = UDim2.new(1, 0, 0, 18)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamMedium
nameLabel.TextSize = 12
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.TextColor3 = Color3.fromRGB(210, 218, 235)
nameLabel.Text = "Optional safe-zone name"
nameLabel.Parent = root

local nameBox = Instance.new("TextBox")
nameBox.Name = "NameBox"
nameBox.LayoutOrder = 5
nameBox.Size = UDim2.new(1, 0, 0, 34)
nameBox.BackgroundColor3 = Color3.fromRGB(34, 38, 49)
nameBox.BorderSizePixel = 0
nameBox.ClearTextOnFocus = false
nameBox.Font = Enum.Font.Gotham
nameBox.PlaceholderText = "blank = primary SafeZoneCenter"
nameBox.Text = ""
nameBox.TextSize = 13
nameBox.TextColor3 = Color3.fromRGB(245, 248, 255)
nameBox.PlaceholderColor3 = Color3.fromRGB(126, 136, 156)
nameBox.Parent = root

local nameBoxCorner = Instance.new("UICorner")
nameBoxCorner.CornerRadius = UDim.new(0, 6)
nameBoxCorner.Parent = nameBox

local selectedText = Instance.new("TextLabel")
selectedText.Name = "SelectedText"
selectedText.LayoutOrder = 6
selectedText.Size = UDim2.new(1, 0, 0, 34)
selectedText.BackgroundTransparency = 1
selectedText.Font = Enum.Font.Gotham
selectedText.TextSize = 12
selectedText.TextWrapped = true
selectedText.TextXAlignment = Enum.TextXAlignment.Left
selectedText.TextYAlignment = Enum.TextYAlignment.Top
selectedText.TextColor3 = Color3.fromRGB(190, 198, 214)
selectedText.Parent = root

local actions = Instance.new("Frame")
actions.Name = "Actions"
actions.LayoutOrder = 7
actions.Size = UDim2.new(1, 0, 0, 82)
actions.BackgroundTransparency = 1
actions.Parent = root

local actionsLayout = Instance.new("UIListLayout")
actionsLayout.Padding = UDim.new(0, 8)
actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionsLayout.Parent = actions

local function makeActionButton(text, layoutOrder)
	local button = Instance.new("TextButton")
	button.LayoutOrder = layoutOrder
	button.Size = UDim2.new(1, 0, 0, 36)
	button.BackgroundColor3 = Color3.fromRGB(55, 118, 255)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	return button
end

local markButton = makeActionButton("Capture / Move Marker", 1)
markButton.Parent = actions

local printButton = makeActionButton("Print Selected Coordinates", 2)
printButton.BackgroundColor3 = Color3.fromRGB(44, 50, 64)
printButton.Parent = actions

local status = Instance.new("TextLabel")
status.Name = "Status"
status.LayoutOrder = 8
status.Size = UDim2.new(1, 0, 0, 46)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextColor3 = Color3.fromRGB(160, 232, 190)
status.Text = "Ready."
status.Parent = root

local selectorButtons = {}

local function sanitizeName(text)
	local cleaned = string.gsub(text or "", "[^%w_%- ]", "")
	cleaned = string.gsub(cleaned, "^%s+", "")
	cleaned = string.gsub(cleaned, "%s+$", "")
	cleaned = string.gsub(cleaned, "%s+", "")
	return cleaned
end

local function round(value)
	return math.floor(value * 1000 + 0.5) / 1000
end

local function formatVector3(value)
	return ("Vector3.new(%.3f, %.3f, %.3f)"):format(
		round(value.X),
		round(value.Y),
		round(value.Z)
	)
end

local function formatCFrame(cframe)
	local _, y, _ = cframe:ToOrientation()
	return ("%s, yaw %.2f"):format(formatVector3(cframe.Position), math.deg(y))
end

local function packCFrame(cframe)
	return { cframe:GetComponents() }
end

local function unpackCFrame(values)
	if type(values) ~= "table" or #values ~= 12 then
		return nil
	end
	return CFrame.new(
		values[1],
		values[2],
		values[3],
		values[4],
		values[5],
		values[6],
		values[7],
		values[8],
		values[9],
		values[10],
		values[11],
		values[12]
	)
end

local function packVector3(value)
	return { value.X, value.Y, value.Z }
end

local function unpackVector3(values)
	if type(values) ~= "table" or #values ~= 3 then
		return nil
	end
	return Vector3.new(values[1], values[2], values[3])
end

local function getSelectionCFrame()
	local selected = Selection:Get()
	for _, instance in selected do
		if instance:IsA("BasePart") then
			return instance.CFrame, instance:GetFullName()
		elseif instance:IsA("Model") then
			return instance:GetPivot(), instance:GetFullName()
		elseif instance:IsA("Attachment") then
			return instance.WorldCFrame, instance:GetFullName()
		end
	end

	local camera = workspace.CurrentCamera
	if camera then
		return camera.Focus, "camera focus"
	end

	return nil, nil
end

local function tryCopyToClipboard(text)
	local okService, studioService = pcall(function()
		return game:GetService("StudioService")
	end)
	if not okService or not studioService then
		return false
	end

	local okCopy = pcall(function()
		studioService:CopyToClipboard(text)
	end)
	return okCopy
end

local function ensureMarkersFolder()
	local folder = workspace:FindFirstChild(MARKERS_FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = MARKERS_FOLDER_NAME
	folder.Parent = workspace
	return folder
end

local function ensureLabel(marker, text)
	local label = marker:FindFirstChild("MarkerLabel")
	if not label or not label:IsA("BillboardGui") then
		if label then
			label:Destroy()
		end
		label = Instance.new("BillboardGui")
	end
	label.Name = "MarkerLabel"
	label.Size = UDim2.fromOffset(240, 34)
	label.StudsOffset = Vector3.new(0, 3, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 300
	label.Parent = marker

	local textLabel = label:FindFirstChild("Text")
	if not textLabel or not textLabel:IsA("TextLabel") then
		if textLabel then
			textLabel:Destroy()
		end
		textLabel = Instance.new("TextLabel")
	end
	textLabel.Name = "Text"
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.TextStrokeTransparency = 0.2
	textLabel.Text = text
	textLabel.Parent = label
end

local function updateSelectionUI()
	for definition, button in selectorButtons do
		local isSelected = definition == selectedDefinition
		button.BackgroundColor3 = isSelected and Color3.fromRGB(55, 118, 255) or Color3.fromRGB(34, 38, 49)
	end

	nameBox.Visible = selectedDefinition.id == "SafeZone"
	nameLabel.Visible = nameBox.Visible
	selectedText.Text = selectedDefinition.description
end

local function makeSelectorButton(definition, order)
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 26)
	button.BackgroundColor3 = Color3.fromRGB(34, 38, 49)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = Color3.fromRGB(245, 248, 255)
	button.Text = definition.displayName
	button.Parent = selectorFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	button.MouseButton1Click:Connect(function()
		selectedDefinition = definition
		updateSelectionUI()
	end)

	selectorButtons[definition] = button
end

for index, definition in MARKER_DEFINITIONS do
	makeSelectorButton(definition, index)
end
updateSelectionUI()

local function getMarkerIdentity(definition)
	if definition.fixedName then
		return definition.fixedName, definition.labelPrefix
	end

	local customName = sanitizeName(nameBox.Text)
	if customName == "" then
		return definition.defaultName, definition.labelPrefix .. " Primary"
	end

	local markerName = customName
	if not string.match(markerName, "^" .. definition.namePrefix) then
		markerName = definition.namePrefix .. markerName
	end
	return markerName, definition.labelPrefix .. " " .. customName
end

local function getDefinitionById(definitionId)
	for _, definition in MARKER_DEFINITIONS do
		if definition.id == definitionId then
			return definition
		end
	end
	return nil
end

local function applyMarker(definition, markerName, markerLabel, markerCFrame, sourceName)
	ChangeHistoryService:SetWaypoint("Before " .. markerLabel .. " Marker")

	local folder = ensureMarkersFolder()
	local marker = folder:FindFirstChild(markerName)
	if marker and not marker:IsA("BasePart") then
		marker:Destroy()
		marker = nil
	end

	if not marker then
		marker = Instance.new("Part")
		marker.Name = markerName
		marker.Size = definition.size
		marker.Parent = folder
	end

	marker.CFrame = markerCFrame
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Material = Enum.Material.Neon
	marker.Color = definition.color
	marker.Transparency = 0.45
	marker:SetAttribute("MarkerType", "DemonBlade2Placement")
	marker:SetAttribute("MarkerRole", definition.role)
	marker:SetAttribute("Label", markerLabel)
	marker:SetAttribute("FacingAngle", marker.Orientation.Y)
	marker:SetAttribute("SpawnSafeZone", markerName == "SafeZoneCenter")

	if definition.attributes then
		for key, value in definition.attributes do
			if marker:GetAttribute(key) == nil then
				marker:SetAttribute(key, value)
			end
		end
	end

	ensureLabel(marker, markerLabel)

	local message = ("%s marker set from %s at %s"):format(
		markerLabel,
		sourceName,
		formatCFrame(marker.CFrame)
	)
	print("[DemonBlade2Tools] " .. message)
	status.Text = message
	ChangeHistoryService:SetWaypoint("After " .. markerLabel .. " Marker")
	return marker
end

local function getPendingMarker()
	local ok, pending = pcall(function()
		return plugin:GetSetting(PENDING_MARKER_SETTING)
	end)
	if ok and type(pending) == "table" then
		return pending
	end
	return nil
end

local function setPendingMarker(pending)
	pcall(function()
		plugin:SetSetting(PENDING_MARKER_SETTING, pending)
	end)
end

local function clearPendingMarker()
	setPendingMarker(false)
end

local function refreshPendingStatus()
	local pending = getPendingMarker()
	if pending and not RunService:IsRunning() then
		status.Text = ("Captured marker waiting: %s. Click Capture / Move Marker to apply it."):format(
			pending.markerLabel or pending.markerName or "unknown"
		)
	elseif RunService:IsRunning() then
		status.Text = "Play mode: click Capture / Move Marker to capture a live position, then stop Play to apply it."
	end
end

local function capturePendingMarker(definition, markerName, markerLabel, markerCFrame, sourceName)
	local pending = {
		definitionId = definition.id,
		markerName = markerName,
		markerLabel = markerLabel,
		sourceName = sourceName,
		cframe = packCFrame(markerCFrame),
		size = packVector3(definition.size),
		capturedAt = os.time(),
	}
	setPendingMarker(pending)
	local message = ("Captured %s from Play mode. Stop Play, then click Capture / Move Marker to apply it."):format(markerLabel)
	print("[DemonBlade2Tools] " .. message)
	status.Text = message
end

local function applyPendingMarkerIfAvailable()
	local pending = getPendingMarker()
	if not pending then
		return false
	end

	local definition = getDefinitionById(pending.definitionId)
	local markerCFrame = unpackCFrame(pending.cframe)
	if not definition or not markerCFrame or type(pending.markerName) ~= "string" or type(pending.markerLabel) ~= "string" then
		clearPendingMarker()
		status.Text = "Discarded an invalid captured marker."
		warn("[DemonBlade2Tools] Discarded an invalid captured marker.")
		return true
	end

	applyMarker(
		definition,
		pending.markerName,
		pending.markerLabel,
		markerCFrame,
		pending.sourceName or "captured Play session"
	)
	clearPendingMarker()
	status.Text = status.Text .. " Captured marker applied."
	return true
end

local function printCoordinates()
	local selected = Selection:Get()
	local lines = {}

	if #selected == 0 then
		local cframe, sourceName = getSelectionCFrame()
		if cframe then
			table.insert(lines, ("%s: %s"):format(sourceName, formatCFrame(cframe)))
		end
	else
		for _, instance in selected do
			if instance:IsA("BasePart") then
				table.insert(lines, ("%s (%s): %s size %s"):format(
					instance:GetFullName(),
					instance.ClassName,
					formatCFrame(instance.CFrame),
					formatVector3(instance.Size)
				))
			elseif instance:IsA("Model") then
				local boxCFrame, boxSize = instance:GetBoundingBox()
				table.insert(lines, ("%s (Model): %s bounds %s"):format(
					instance:GetFullName(),
					formatCFrame(boxCFrame),
					formatVector3(boxSize)
				))
			elseif instance:IsA("Attachment") then
				table.insert(lines, ("%s (Attachment): %s"):format(
					instance:GetFullName(),
					formatCFrame(instance.WorldCFrame)
				))
			end
		end
	end

	if #lines == 0 then
		status.Text = "Select a BasePart, Model, or Attachment first."
		warn("[DemonBlade2Tools] Select a BasePart, Model, or Attachment first.")
		return
	end

	local output = table.concat(lines, "\n")
	print("[DemonBlade2Tools]\n" .. output)
	if tryCopyToClipboard(output) then
		status.Text = "Coordinates printed and copied."
	else
		status.Text = "Coordinates printed to Output."
	end
end

local function createMarker(definition)
	if RunService:IsRunning() then
		local sourceCFrame, sourceName = getSelectionCFrame()
		if not sourceCFrame then
			status.Text = "Select a BasePart, Model, Attachment, or camera view to capture."
			warn("[DemonBlade2Tools] Select something or aim the camera before capturing a marker.")
			return
		end

		local markerName, markerLabel = getMarkerIdentity(definition)
		capturePendingMarker(definition, markerName, markerLabel, sourceCFrame, sourceName)
		return
	end

	if applyPendingMarkerIfAvailable() then
		return
	end

	local sourceCFrame, sourceName = getSelectionCFrame()
	if not sourceCFrame then
		status.Text = "Select a BasePart, Model, or Attachment first."
		warn("[DemonBlade2Tools] Select a BasePart, Model, or Attachment first.")
		return
	end

	local markerName, markerLabel = getMarkerIdentity(definition)
	applyMarker(definition, markerName, markerLabel, sourceCFrame, sourceName)
end

markButton.MouseButton1Click:Connect(function()
	createMarker(selectedDefinition)
end)

printButton.MouseButton1Click:Connect(printCoordinates)

openButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	openButton:SetActive(widget.Enabled)
	if widget.Enabled then
		refreshPendingStatus()
	end
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	openButton:SetActive(widget.Enabled)
end)

refreshPendingStatus()

print("[DemonBlade2Tools] Loaded")
