local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ZoneChangedRemote = Remotes:WaitForChild("ZoneChanged")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local WorldSpawnConfigModule = require(Modules:WaitForChild("WorldSpawnConfigModule"))

local ZONE_CHECK_INTERVAL = 0.5
local SAFE_ZONE_NAME = "SafeZone"
local SAFE_ZONE_CENTER = WorldSpawnConfigModule.getSafeZoneCenter()
local SAFE_ZONE_SIZE = WorldSpawnConfigModule.getSafeZoneSize()
local MARKERS_FOLDER_NAME = "DemonBlade2Markers"
local PRIMARY_SAFE_ZONE_MARKER_NAME = "SafeZoneCenter"
local SAFE_ZONE_MARKER_PREFIX = "SafeZone_"
local DEBUG_ZONE_CHANGES = false

local zonesFolder = workspace:FindFirstChild("Zones")
local zoneParts = {}
local playerZones = {}
local resolvedSafeZoneCenter = SAFE_ZONE_CENTER
local resolvedSafeZoneSize = SAFE_ZONE_SIZE

local SAFE_ZONE_GROUND_SAMPLE_OFFSETS = {
	Vector2.new(0, 0),
	Vector2.new(12, 0),
	Vector2.new(-12, 0),
	Vector2.new(0, 12),
	Vector2.new(0, -12),
	Vector2.new(20, 20),
	Vector2.new(-20, 20),
	Vector2.new(20, -20),
	Vector2.new(-20, -20),
}

local function ensureZonesFolder()
	if not zonesFolder then
		zonesFolder = Instance.new("Folder")
		zonesFolder.Name = "Zones"
		zonesFolder.Parent = workspace
	end
end

local function getMarkersFolder()
	local markersFolder = workspace:FindFirstChild(MARKERS_FOLDER_NAME)
	return if markersFolder and markersFolder:IsA("Folder") then markersFolder else nil
end

local function getMarkerPart(markerName)
	local markersFolder = getMarkersFolder()
	if not markersFolder then return nil end
	local marker = markersFolder:FindFirstChild(markerName)
	if marker and marker:IsA("BasePart") then
		return marker
	end
	return nil
end

local function isSafeZoneMarker(marker)
	return marker:IsA("BasePart")
		and (
			marker:GetAttribute("MarkerRole") == "SafeZone"
			or marker.Name == PRIMARY_SAFE_ZONE_MARKER_NAME
			or string.sub(marker.Name, 1, #SAFE_ZONE_MARKER_PREFIX) == SAFE_ZONE_MARKER_PREFIX
		)
end

local function getSafeZoneMarkers()
	local markersFolder = getMarkersFolder()
	if not markersFolder then
		return {}
	end

	local markers = {}
	for _, child in markersFolder:GetChildren() do
		if isSafeZoneMarker(child) then
			table.insert(markers, child)
		end
	end

	table.sort(markers, function(left, right)
		if left.Name == PRIMARY_SAFE_ZONE_MARKER_NAME then
			return true
		end
		if right.Name == PRIMARY_SAFE_ZONE_MARKER_NAME then
			return false
		end
		local leftSpawn = left:GetAttribute("SpawnSafeZone") == true
		local rightSpawn = right:GetAttribute("SpawnSafeZone") == true
		if leftSpawn ~= rightSpawn then
			return leftSpawn
		end
		return left.Name < right.Name
	end)

	return markers
end

local function getMarkerAttributeNumber(marker, attributeName, fallback)
	local value = marker:GetAttribute(attributeName)
	return type(value) == "number" and value or fallback
end

local function getConfiguredSafeZoneCenter(marker)
	if marker then
		return marker.Position
	end
	return SAFE_ZONE_CENTER
end

local function getConfiguredSafeZoneSize(marker)
	if marker then
		return Vector3.new(
			math.max(SAFE_ZONE_SIZE.X, marker.Size.X),
			math.max(8, getMarkerAttributeNumber(marker, "ZoneHeight", SAFE_ZONE_SIZE.Y)),
			math.max(SAFE_ZONE_SIZE.Z, marker.Size.Z)
		)
	end
	return SAFE_ZONE_SIZE
end

local function resolveSafeZonePlacement(marker)
	ensureZonesFolder()
	local configuredCenter = getConfiguredSafeZoneCenter(marker)
	local configuredSize = getConfiguredSafeZoneSize(marker)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { zonesFolder }
	local markersFolder = getMarkersFolder()
	if markersFolder then
		table.insert(excluded, markersFolder)
	end
	raycastParams.FilterDescendantsInstances = excluded
	raycastParams.IgnoreWater = true
	raycastParams.RespectCanCollide = true

	local groundY = nil
	for _, offset in SAFE_ZONE_GROUND_SAMPLE_OFFSETS do
		local result = workspace:Raycast(
			configuredCenter + Vector3.new(offset.X, 400, offset.Y),
			Vector3.new(0, -900, 0),
			raycastParams
		)
		if result and result.Normal.Y >= 0.65 then
			groundY = groundY and math.min(groundY, result.Position.Y) or result.Position.Y
		end
	end
	groundY = groundY or configuredCenter.Y
	local placedCenter = Vector3.new(configuredCenter.X, groundY + configuredSize.Y * 0.5, configuredCenter.Z)
	return placedCenter, configuredSize, groundY
end

local function getOrCreateZonePart(name)
	local existing = zonesFolder:FindFirstChild(name)
	if existing and existing:IsA("BasePart") then
		return existing
	end

	local part = Instance.new("Part")
	part.Name = name
	part.Parent = zonesFolder
	return part
end

local function createSafeZone(marker, index)
	ensureZonesFolder()
	local safeZoneCenter, safeZoneSize, groundY = resolveSafeZonePlacement(marker)
	local suffix = marker and marker.Name or "Default"
	local zonePartName = index == 1 and SAFE_ZONE_NAME or (SAFE_ZONE_NAME .. "_" .. suffix)
	local bubbleName = index == 1 and "SafeZoneBubble" or ("SafeZoneBubble_" .. suffix)
	local labelText = marker and (marker:GetAttribute("Label") or "SAFE ZONE") or "SAFE ZONE"

	if index == 1 then
		resolvedSafeZoneCenter = safeZoneCenter
		resolvedSafeZoneSize = safeZoneSize
	end

	local zonePart = getOrCreateZonePart(zonePartName)
	zonePart.Size = safeZoneSize
	zonePart.CFrame = CFrame.new(safeZoneCenter)
	zonePart.Anchored = true
	zonePart.CanCollide = false
	zonePart.CanQuery = false
	zonePart.CanTouch = false
	zonePart.Transparency = 1
	zonePart:SetAttribute("ZoneName", SAFE_ZONE_NAME)
	zonePart:SetAttribute("IsSafeZone", true)
	zonePart:SetAttribute("GroundY", groundY)
	zonePart:SetAttribute("SafeZoneId", suffix)

	local bubble = getOrCreateZonePart(bubbleName)
	local bubbleDiameter = math.max(safeZoneSize.X, safeZoneSize.Z)
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(bubbleDiameter, bubbleDiameter, bubbleDiameter)
	bubble.CFrame = CFrame.new(safeZoneCenter.X, groundY + bubbleDiameter * 0.5, safeZoneCenter.Z)
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.Material = Enum.Material.ForceField
	bubble.Color = Color3.fromRGB(80, 180, 255)
	bubble.Transparency = 0.78

	local label = bubble:FindFirstChild("SafeZoneLabel")
	if not label or not label:IsA("BillboardGui") then
		label = Instance.new("BillboardGui")
	end
	label.Name = "SafeZoneLabel"
	label.Size = UDim2.fromOffset(220, 44)
	label.StudsOffset = Vector3.new(0, 8, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 120
	label.Parent = bubble

	local text = label:FindFirstChild("Text")
	if not text or not text:IsA("TextLabel") then
		text = Instance.new("TextLabel")
	end
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(190, 235, 255)
	text.TextStrokeColor3 = Color3.fromRGB(0, 20, 40)
	text.TextStrokeTransparency = 0.25
	text.Text = string.upper(tostring(labelText))
	text.Parent = label

	print(("[ZoneServer] Created SafeZone '%s' at %s"):format(suffix, tostring(safeZoneCenter)))
end

local function loadZones()
	local safeZoneMarkers = getSafeZoneMarkers()
	if #safeZoneMarkers > 0 then
		for index, marker in safeZoneMarkers do
			createSafeZone(marker, index)
		end
	else
		createSafeZone(nil, 1)
	end

	zoneParts = {}
	for _, child in zonesFolder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("ZoneName") then
			table.insert(zoneParts, {
				part = child,
				name = child:GetAttribute("ZoneName"),
				minLevel = child:GetAttribute("MinLevel") or 1,
				maxLevel = child:GetAttribute("MaxLevel") or 100,
				isSafeZone = child:GetAttribute("IsSafeZone") == true,
			})
			print("[ZoneServer] Registered zone: " .. child:GetAttribute("ZoneName"))
		end
	end
end

local function isPointInPart(point, part)
	local relative = part.CFrame:PointToObjectSpace(point)
	local halfSize = part.Size / 2
	return math.abs(relative.X) <= halfSize.X
		and math.abs(relative.Y) <= halfSize.Y
		and math.abs(relative.Z) <= halfSize.Z
end

local function getZoneForPosition(position)
	for _, zone in zoneParts do
		if isPointInPart(position, zone.part) then
			return zone.name
		end
	end
	return "Wilderness"
end

local function checkPlayerZones()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end

		local newZone = getZoneForPosition(hrp.Position)
		local oldZone = playerZones[player]

		if newZone ~= oldZone then
			playerZones[player] = newZone
			ZoneChangedRemote:FireClient(player, newZone, oldZone or "")
			if DEBUG_ZONE_CHANGES or newZone == SAFE_ZONE_NAME or oldZone == SAFE_ZONE_NAME then
				print("[ZoneServer] " .. player.Name .. " entered zone: " .. newZone)
			end
		end
	end
end

-- selene: allow(global_usage)
shared.ZoneServer = {
	getPlayerZone = function(player)
		return playerZones[player] or "Wilderness"
	end,
	getZoneForPosition = getZoneForPosition,
	isSafeZone = function(player)
		return playerZones[player] == SAFE_ZONE_NAME
	end,
	isSafePosition = function(position)
		return getZoneForPosition(position) == SAFE_ZONE_NAME
	end,
	getSafeSpawnCFrame = function()
		return CFrame.new(resolvedSafeZoneCenter + WorldSpawnConfigModule.SAFE_ZONE.spawnOffset)
	end,
	getSafeZoneSize = function()
		return resolvedSafeZoneSize
	end,
}

Players.PlayerRemoving:Connect(function(player)
	playerZones[player] = nil
end)

loadZones()

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= ZONE_CHECK_INTERVAL then
		elapsed = 0
		checkPlayerZones()
	end
end)

print("[ZoneServer] Loaded - " .. #zoneParts .. " zones registered")
