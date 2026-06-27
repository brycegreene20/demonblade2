local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ZoneChangedRemote = Remotes:WaitForChild("ZoneChanged")

local ZONE_CHECK_INTERVAL = 0.5
local SAFE_ZONE_NAME = "SafeZone"
local SAFE_ZONE_CENTER = Vector3.new(-4, 4, -4)
local SAFE_ZONE_SIZE = Vector3.new(46, 16, 46)
local DEBUG_ZONE_CHANGES = false

local zonesFolder = workspace:FindFirstChild("Zones")
local zoneParts = {}
local playerZones = {}

local function ensureZonesFolder()
	if not zonesFolder then
		zonesFolder = Instance.new("Folder")
		zonesFolder.Name = "Zones"
		zonesFolder.Parent = workspace
	end
end

local function createDefaultSafeZone()
	ensureZonesFolder()
	if zonesFolder:FindFirstChild(SAFE_ZONE_NAME) then return end

	local zonePart = Instance.new("Part")
	zonePart.Name = SAFE_ZONE_NAME
	zonePart.Size = SAFE_ZONE_SIZE
	zonePart.CFrame = CFrame.new(SAFE_ZONE_CENTER)
	zonePart.Anchored = true
	zonePart.CanCollide = false
	zonePart.CanQuery = false
	zonePart.CanTouch = false
	zonePart.Transparency = 1
	zonePart:SetAttribute("ZoneName", SAFE_ZONE_NAME)
	zonePart:SetAttribute("IsSafeZone", true)
	zonePart.Parent = zonesFolder

	local bubble = Instance.new("Part")
	bubble.Name = "SafeZoneBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(SAFE_ZONE_SIZE.X, SAFE_ZONE_SIZE.X, SAFE_ZONE_SIZE.X)
	bubble.CFrame = CFrame.new(SAFE_ZONE_CENTER)
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.Material = Enum.Material.ForceField
	bubble.Color = Color3.fromRGB(80, 180, 255)
	bubble.Transparency = 0.78
	bubble.Parent = zonesFolder

	local label = Instance.new("BillboardGui")
	label.Name = "SafeZoneLabel"
	label.Size = UDim2.fromOffset(220, 44)
	label.StudsOffset = Vector3.new(0, 8, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 120
	label.Parent = bubble

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(190, 235, 255)
	text.TextStrokeColor3 = Color3.fromRGB(0, 20, 40)
	text.TextStrokeTransparency = 0.25
	text.Text = "SAFE ZONE"
	text.Parent = label

	print("[ZoneServer] Created default SafeZone near trainers")
end

local function loadZones()
	createDefaultSafeZone()
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
